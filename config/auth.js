/**
 * 认证与开发代理配置
 */
export const DEVICE_IP = '192.168.18.254'
export const DEVICE_HTTPS_URL = `https://${DEVICE_IP}`

/**
 * Vite 开发代理配置（Session Cookie，无 Basic Auth）
 */
export function getProxyConfig() {
    return {
        changeOrigin: true,
        secure: false, // 信任设备自签证书
        cookieDomainRewrite: ''
    }
}
