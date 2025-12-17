/**
 * 认证配置文件
 * 用于设置设备访问的认证信息
 */

// 设备 IP 地址
export const DEVICE_IP = '192.168.18.254'

// Basic Auth 认证信息 (仅用于开发环境代理，生产环境请勿依赖此配置)
export const AUTH = {
    username: 'admin',
    password: 'admin'
}

/**
 * 生成 Basic Auth 字符串
 * 用于 HTTP 请求中的 Authorization 头
 * 格式：Authorization: Basic <base64(username:password)>
 */
export function getBasicAuth() {
    const credentials = `${AUTH.username}:${AUTH.password}`
    return btoa(credentials)
}

/**
 * 获取代理配置
 * @returns {object} 代理配置对象
 */
export function getProxyConfig() {
    return {
        auth: `${AUTH.username}:${AUTH.password}`,
        changeOrigin: true,
        secure: false
    }
}
