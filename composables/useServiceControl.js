import { ref } from 'vue'
import apiClient from '../api/services'
import { useI18n } from '../i18n/useI18n.js'

export function useServiceControl() {
    const { t } = useI18n()
    const isServiceRestarting = ref(false)

    const restartService = async () => {
        // Confirm before restarting? The user's previous code in System.vue didn't have a confirm for the new service restart, 
        // but the old restartDevice had one. The new flow seems to be triggered from a "Save Success" modal which acts as the confirmation step 
        // or directly from a button.
        // In System.vue, it was triggered from "Save Success" modal -> "Restart Now".
        // In other components (like Cloud.vue), it might be a direct button.
        // If it's a direct button, we might want a confirmation.
        // However, the user's request is about "handleRestart".
        // Let's assume the confirmation is handled by the caller or UI context if needed, 
        // OR we can add a confirm parameter.

        // For now, let's stick to the logic we implemented in System.vue:
        // Set loading state -> Call API -> Wait -> Reload.

        isServiceRestarting.value = true
        try {
            await apiClient.get('/action_restart_service.cgi')

            // Wait 5 seconds then reload
            setTimeout(() => {
                window.location.reload()
            }, 5000)
        } catch (err) {
            console.error('Service restart failed:', err)
            alert(t('common.operationFailed') + ': ' + err.message)
            isServiceRestarting.value = false
        }
    }

    return {
        isServiceRestarting,
        restartService
    }
}
