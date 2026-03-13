import { ref } from 'vue'
import apiClient from '../api/services'
import { useI18n } from '../i18n/useI18n.js'

export function useServiceControl() {
    const { t } = useI18n()
    const isServiceRestarting = ref(false)

    /**
     * 轮询检测服务是否恢复
     * 每 2 秒请求一次轻量级接口，直到成功返回
     * @param {number|string} targetPort - 可选的目标端口号
     */
    const pollServiceRecovery = (targetPort) => {
        const pollInterval = 2000 // 2 秒
        const maxAttempts = 60 // 最多尝试 60 次 (2分钟)
        let attempts = 0

        const protocol = window.location.protocol
        const hostname = window.location.hostname
        let requestUrl = '/favicon.ico'
        let targetUrl = null

        // 检查端口是否发生改变
        const currentPort = window.location.port || (protocol === 'https:' ? '443' : '80')
        if (targetPort && String(targetPort) !== String(currentPort)) {
            const portSuffix = (String(targetPort) === '80' && protocol === 'http:') || (String(targetPort) === '443' && protocol === 'https:') ? '' : `:${targetPort}`
            targetUrl = `${protocol}//${hostname}${portSuffix}`
            requestUrl = `${targetUrl}/favicon.ico?t=${Date.now()}`
        } else {
            requestUrl = `/favicon.ico?t=${Date.now()}`
        }

        const poll = () => {
            attempts++
            console.log(`Polling service recovery... attempt ${attempts}, url: ${requestUrl}`)

            // 使用 fetch 而不是 apiClient，避免拦截器影响
            // 请求一个轻量级接口（favicon 或状态接口）
            fetch(requestUrl, {
                method: 'GET',
                cache: 'no-store',
                mode: targetUrl ? 'no-cors' : 'cors', // 跨域/跨端口时采用 no-cors 模式
                credentials: 'omit', // ★ 解决 401 弹窗死循环的关键：禁止 fetch 自动触发浏览器的 Basic Auth 弹窗
                // 添加超时控制，避免死等
                signal: AbortSignal.timeout ? AbortSignal.timeout(2000) : undefined
            })
                .then(response => {
                    // no-cors 下请求成功会得到 opaque 类型的 response（状态码为 0）。说明 Socket 连通未被拒绝。
                    // 只要服务器正常响应了 HTTP（哪怕是由于新密码导致的 401 或 403 拦截），都说明服务本身已经恢复上线了
                    if (targetUrl || response.ok || response.status === 200 || response.status === 304 || response.status === 401 || response.status === 403 || response.type === 'opaque') {
                        console.log('Service recovered, reloading/redirecting page...')
                        if (targetUrl) {
                            window.location.href = `${targetUrl}/${window.location.hash}`
                        } else {
                            window.location.reload()
                        }
                    } else {
                        // 服务可能返回了 5xx 等错误，继续轮询
                        if (attempts < maxAttempts) {
                            setTimeout(poll, pollInterval)
                        } else {
                            console.error('Service recovery timeout, reloading anyway...')
                            if (targetUrl) {
                                window.location.href = `${targetUrl}/${window.location.hash}`
                            } else {
                                window.location.reload()
                            }
                        }
                    }
                })
                .catch(err => {
                    console.log('Service not ready yet:', err.message)
                    // 取消基于 TimeoutError 的强行刷新，只有当服务端真真正正返回 401 等状态时才刷新
                    // 这样可以彻底杜绝由于网络物理断开重启导致 fetch 失败（ERR_CONNECTION_REFUSED / TimeoutError）
                    // 却被提前强制 reload 而显示“连接已中断”原生的丑陋浏览器异常界面。
                    
                    // 继续轮询
                    if (attempts < maxAttempts) {
                        setTimeout(poll, pollInterval)
                    } else {
                        console.error('Service recovery max attempts reached, reloading anyway...')
                        if (targetUrl) {
                            window.location.href = `${targetUrl}/${window.location.hash}`
                        } else {
                            window.location.reload()
                        }
                    }
                })
        }

        // 延迟 5 秒后开始第一次探测（给服务重启留出时间）
        setTimeout(poll, 5000)
    }

    const restartService = async (targetPort) => {
        // 1. 显示重启遮罩层
        isServiceRestarting.value = true

        try {
            // 2. 尝试发送重启指令
            await apiClient.get('/action_restart_service.cgi')
            console.log('Service restart command sent successfully')
            
            // 3. 开始轮询探测服务恢复
            pollServiceRecovery(targetPort)
        } catch (err) {
            console.log('Caught error during restart request:', err)
            
            // 4. 判断是否为网络相关错误（重启导致的正常现象）
            const message = err && err.message ? err.message : ''
            const code = err && err.code ? err.code : ''
            
            // 网络错误、连接重置、超时等都视为"重启指令已发送"
            const isExpectedError = 
                message.includes('Network Error') ||
                message.includes('Connection Reset') ||
                message.includes('timeout') ||
                message.includes('ECONNRESET') ||
                message.includes('ETIMEDOUT') ||
                code === 'ECONNABORTED' ||
                code === 'ECONNRESET'
            
            if (isExpectedError) {
                console.log('Network error detected (expected during restart), starting recovery polling...')
                // 5. 视为成功，开始轮询探测服务恢复
                pollServiceRecovery(targetPort)
            } else {
                // 6. 其他未知错误，报错并取消重启状态
                console.error('Unexpected error during service restart:', err)
                alert(t('common.operationFailed') + ': ' + message)
                isServiceRestarting.value = false
            }
        }
    }

    return {
        isServiceRestarting,
        restartService
    }
}
