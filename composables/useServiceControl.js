import { ref } from 'vue'
import apiClient from '../api/services'
import { useI18n } from '../i18n/useI18n.js'

export function useServiceControl() {
    const { t } = useI18n()
    const isServiceRestarting = ref(false)

    /**
     * 轮询检测服务是否恢复
     * 每 2 秒请求一次轻量级接口，直到成功返回
     */
    const pollServiceRecovery = () => {
        const pollInterval = 2000 // 2 秒
        const maxAttempts = 60 // 最多尝试 60 次 (2分钟)
        let attempts = 0

        const poll = () => {
            attempts++
            console.log(`Polling service recovery... attempt ${attempts}`)

            // 使用 fetch 而不是 apiClient，避免拦截器影响
            // 请求一个轻量级接口（favicon 或状态接口）
            fetch('/favicon.ico', {
                method: 'GET',
                cache: 'no-cache',
                // 添加超时控制
                signal: AbortSignal.timeout ? AbortSignal.timeout(2000) : undefined
            })
                .then(response => {
                    if (response.ok || response.status === 200 || response.status === 304) {
                        console.log('Service recovered, reloading page...')
                        window.location.reload()
                    } else {
                        // 继续轮询
                        if (attempts < maxAttempts) {
                            setTimeout(poll, pollInterval)
                        } else {
                            console.error('Service recovery timeout, reloading anyway...')
                            window.location.reload()
                        }
                    }
                })
                .catch(err => {
                    console.log('Service not ready yet:', err.message)
                    // 继续轮询
                    if (attempts < maxAttempts) {
                        setTimeout(poll, pollInterval)
                    } else {
                        console.error('Service recovery timeout, reloading anyway...')
                        window.location.reload()
                    }
                })
        }

        // 延迟 5 秒后开始第一次探测（给服务重启留出时间）
        setTimeout(poll, 5000)
    }

    const restartService = async () => {
        // 1. 显示重启遮罩层
        isServiceRestarting.value = true

        try {
            // 2. 尝试发送重启指令
            await apiClient.get('/action_restart_service.cgi')
            console.log('Service restart command sent successfully')
            
            // 3. 开始轮询探测服务恢复
            pollServiceRecovery()
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
                pollServiceRecovery()
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
