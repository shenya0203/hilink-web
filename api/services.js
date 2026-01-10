import axios from 'axios'
// import { getBasicAuth } from '../config/auth'

// 获取 Basic Auth 凭证
// const BASIC_AUTH = getBasicAuth()

// 创建 axios 实例，带有代理配置和 Basic Auth
const apiClient = axios.create({
    timeout: 5000,
    headers: {
        // 'Content-Type': 'application/json', // 移除默认 Content-Type，让 axios 根据数据类型自动处理 (特别是 FormData)
        // 'Authorization': `Basic ${BASIC_AUTH}`  // 移除硬编码的 Basic Auth，生产环境由浏览器自动处理
    }
})

// 响应拦截器处理错误
apiClient.interceptors.response.use(
    response => response,
    error => {
        console.error('API 请求错误:', error.message)
        return Promise.reject(error)
    }
)

/**
 * 获取设备状态数据
 */
export function getStatus() {
    return apiClient.get('/download_flex.cgi?name=status')
        .then(res => res.data)
}

/**
 * 获取网络配置数据
 */
export function getNetwork() {
    return apiClient.get('/download_flex.cgi?name=network')
        .then(res => res.data)
}

/**
 * 获取杂项配置数据
 */
export function getMisc() {
    return apiClient.get('/download_nv.cgi?name=misc')
        .then(res => res.data)
}

/**
 * 获取通信隧道配置
 */
export function getCommTunnel() {
    return apiClient.get('/download_nv.cgi?name=comm_tunnel')
        .then(res => res.data)
}

/**
 * 获取网络配置（nv 版本）
 */
export function getNetworkConfig() {
    return apiClient.get('/download_nv.cgi?name=network')
        .then(res => res.data)
}

/**
 * 获取串口配置
 */
export function getUartConfig() {
    return apiClient.get('/download_nv.cgi?name=uart')
        .then(res => res.data)
}

/**
 * 获取断网缓存配置
 */
export function getOfflineCache() {
    return apiClient.get('/download_nv.cgi?name=offline_cache')
        .then(res => res.data)
}

/**
 * 保存配置 (通用)
 * @param {string} file 模块名称 (如 uart, network)
 * @param {string} queryString 参数字符串
 */
export function updateConfig(file, queryString) {
    return apiClient.get(`/update_nv.cgi?file=${file}&${queryString}`)
        .then(res => res.data)
}

/**
 * 重启设备
 */
export function restartDevice() {
    return apiClient.get('/action_restart.cgi')
        .then(res => res.data)
}

export default apiClient
