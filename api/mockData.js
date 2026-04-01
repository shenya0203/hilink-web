// src/api/mockData.js
import { getStatus, getNetwork, getMisc, getNetworkConfig, getNetworkLanConfig, getUartConfig, getCommTunnel, getOfflineCache } from './services'

// 获取状态数据
export async function fetchStatusData() {
    try {
        const data = await getStatus()
        console.log('✓ 获取成功 - GET /download_flex.cgi?name=status:', data)
        return data
    } catch (error) {
        console.error('✗ 获取失败 - GET /download_flex.cgi?name=status:', error)
        return null
    }
}

// 获取网络数据
export async function fetchNetworkData() {
    try {
        const data = await getNetwork()
        console.log('✓ 获取成功 - GET /download_flex.cgi?name=network:', data)
        return data
    } catch (error) {
        console.error('✗ 获取失败 - GET /download_flex.cgi?name=network:', error)
        /*return getDefaultNetworkData()*/
        return null
    }
}

// 获取网络配置数据（nv 版本）
export async function fetchNetworkConfigData() {
    try {
        const data = await getNetworkConfig()
        console.log('✓ 获取成功 - GET /download_nv.cgi?name=network:', data)
        return data
    } catch (error) {
        console.error('✗ 获取失败 - GET /download_nv.cgi?name=network:', error)
        return null
    }
}

// 获取网络 LAN 配置数据（nv 版本）
export async function fetchNetworkLanConfigData() {
    try {
        const data = await getNetworkLanConfig()
        console.log('✓ 获取成功 - GET /download_nv.cgi?name=network_lan:', data)
        return data
    } catch (error) {
        console.error('✗ 获取失败 - GET /download_nv.cgi?name=network_lan:', error)
        return null
    }
}

// 获取杂项数据
export async function fetchMiscData() {
    try {
        return await getMisc()
    } catch (error) {
        console.error('获取杂项数据失败:', error)
        return null
    }
}

// 获取串口配置数据
export async function fetchUartConfigData() {
    try {
        const data = await getUartConfig()
        console.log('✓ 获取成功 - GET /download_nv.cgi?name=uart:', data)
        return data
    } catch (error) {
        console.error('✗ 获取失败 - GET /download_nv.cgi?name=uart:', error)
        return null
    }
}

// 获取Socket配置数据
export async function fetchSocketConfigData() {
    try {
        const data = await getCommTunnel()
        console.log('✓ 获取成功 - GET /download_nv.cgi?name=comm_tunnel:', data)
        return data
    } catch (error) {
        console.error('✗ 获取失败 - GET /download_nv.cgi?name=comm_tunnel:', error)
        // 不需要默认值
        return null
    }
}

// 获取断网缓存数据
export async function fetchOfflineCacheData() {
    try {
        const data = await getOfflineCache()
        console.log('✓ 获取成功 - GET /download_nv.cgi?name=offline_cache:', data)
        return data
    } catch (error) {
        console.error('✗ 获取失败 - GET /download_nv.cgi?name=offline_cache:', error)
        // 不需要默认值
        return null
    }
}



export const statusData = null
export const networkData = null
export const miscData = null

// 格式化运行时间（毫秒转换为 HH:mm:ss 格式）
export function formatSeconds(milliseconds) {
    // 将毫秒转换为秒
    const totalSeconds = Math.floor(milliseconds / 1000)

    const hours = Math.floor(totalSeconds / 3600).toString().padStart(2, '0')
    const minutes = Math.floor((totalSeconds % 3600) / 60).toString().padStart(2, '0')
    const seconds = Math.floor(totalSeconds % 60).toString().padStart(2, '0')

    return `${hours}:${minutes}:${seconds}`
}

// 格式化时间戳
export function formatTimestamp(ts) {
    if (!ts) return '-'
    const date = new Date(ts * 1000)
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    const seconds = String(date.getSeconds()).padStart(2, '0')
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`
}