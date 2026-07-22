import { ref } from 'vue'
import apiClient from '../api/services'
import { useI18n } from '../i18n/useI18n.js'

export function useServiceControl() {
    const { t } = useI18n()
    const isServiceRestarting = ref(false)

    /**
     * 轮询检测服务是否恢复
     * 每 2 秒请求一次轻量级接口，直到成功返回
     * @param {number|string} targetPort - 可选的目标 HTTPS 端口号
     */
    const pollServiceRecovery = (targetHost, targetPort) => {
        const pollInterval = 2000 // 2 秒
        const maxAttempts = 60 // 最多尝试 60 次 (2分钟)
        let attempts = 0

        // 管理页已强制 HTTPS
        const protocol = 'https:'
        const hostname = targetHost || window.location.hostname
        let requestUrl = '/favicon.ico'
        let targetUrl = null

        const currentPort = window.location.port || '443'
        const currentHost = window.location.hostname

        const hostChanged = targetHost && targetHost !== currentHost
        const portChanged = targetPort && String(targetPort) !== String(currentPort)

        if (hostChanged || portChanged) {
            const effectivePort = targetPort || currentPort
            const portSuffix = String(effectivePort) === '443' ? '' : `:${effectivePort}`
            targetUrl = `${protocol}//${hostname}${portSuffix}`
            requestUrl = `${targetUrl}/favicon.ico?t=${Date.now()}`
        } else {
            requestUrl = `/favicon.ico?t=${Date.now()}`
        }

        const poll = () => {
            attempts++

            fetch(requestUrl, {
                method: 'GET',
                cache: 'no-store',
                mode: targetUrl ? 'no-cors' : 'cors',
                credentials: 'omit',
                signal: AbortSignal.timeout ? AbortSignal.timeout(2000) : undefined
            })
                .then(response => {
                    if (targetUrl || response.ok || response.status === 200 || response.status === 304 || response.status === 401 || response.status === 403 || response.type === 'opaque') {
                        console.log('Service recovered, reloading/redirecting page...')
                        if (targetUrl) {
                            window.location.href = `${targetUrl}/#/login`
                        } else {
                            window.location.hash = '#/login'
                            window.location.reload()
                        }
                    } else {
                        if (attempts < maxAttempts) {
                            setTimeout(poll, pollInterval)
                        } else {
                            console.error('Service recovery timeout, reloading anyway...')
                            if (targetUrl) {
                                window.location.href = `${targetUrl}/#/login`
                            } else {
                                window.location.hash = '#/login'
                                window.location.reload()
                            }
                        }
                    }
                })
                .catch(() => {
                    if (attempts < maxAttempts) {
                        setTimeout(poll, pollInterval)
                    } else {
                        console.error('Service recovery max attempts reached, reloading anyway...')
                        if (targetUrl) {
                            window.location.href = `${targetUrl}/#/login`
                        } else {
                            window.location.hash = '#/login'
                            window.location.reload()
                        }
                    }
                })
        }

        setTimeout(poll, 5000)
    }

    const restartService = async (targetHost, targetPort) => {
        if (isServiceRestarting.value) return
        isServiceRestarting.value = true

        try {
            await apiClient.get('/action_restart_service.cgi?apply=0')
            pollServiceRecovery(targetHost, targetPort)
            apiClient.get('/action_restart_service.cgi?apply=1').catch(err => {
                console.warn('apply=1 restart request error (may be expected during restart):', err.message)
            })
        } catch (err) {
            console.error('重启服务失败:', err)
            isServiceRestarting.value = false
            alert(t('system.restartFailed') + ': ' + (err.message || ''))
        }
    }

    return {
        isServiceRestarting,
        restartService,
        pollServiceRecovery
    }
}
