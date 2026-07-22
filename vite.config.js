import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { getProxyConfig, DEVICE_HTTPS_URL } from './config/auth'

const proxyConfig = getProxyConfig()
const proxyTarget = DEVICE_HTTPS_URL

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    host: true,
    proxy: {
      '/login.cgi': { target: proxyTarget, ...proxyConfig },
      '/login_pubkey.cgi': { target: proxyTarget, ...proxyConfig },
      '/logout.cgi': { target: proxyTarget, ...proxyConfig },
      '/auth_check.cgi': { target: proxyTarget, ...proxyConfig },
      '/download_flex.cgi': { target: proxyTarget, ...proxyConfig },
      '/download_nv.cgi': { target: proxyTarget, ...proxyConfig },
      '/download_file.cgi': { target: proxyTarget, ...proxyConfig },
      '/download_multi_file.cgi': { target: proxyTarget, ...proxyConfig },
      '/download_cert_bundle.cgi': { target: proxyTarget, ...proxyConfig },
      '/update_nv.cgi': { target: proxyTarget, ...proxyConfig },
      '/update_flex.cgi': { target: proxyTarget, ...proxyConfig },
      '/action_wifi.cgi': { target: proxyTarget, ...proxyConfig },
      '/action_restart.cgi': { target: proxyTarget, ...proxyConfig },
      '/action_restart_service.cgi': { target: proxyTarget, ...proxyConfig },
      '/action_reset.cgi': { target: proxyTarget, ...proxyConfig },
      '/action_upgrade.cgi': { target: proxyTarget, ...proxyConfig },
      '/action_time.cgi': { target: proxyTarget, ...proxyConfig },
      '/action_tf.cgi': { target: proxyTarget, ...proxyConfig },
      '/upload': { target: proxyTarget, ...proxyConfig }
    }
  }
})
