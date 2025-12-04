// src/api/mockData.js
import { getStatus, getNetwork, getMisc, getNetworkConfig, getUartConfig, getCommTunnel, getOfflineCache } from './services'

// 获取状态数据
export async function fetchStatusData() {
    try {
        const data = await getStatus()
        console.log('✓ 获取成功 - GET /download_flex.cgi?name=status:', data)
        return data
    } catch (error) {
        console.error('✗ 获取失败 - GET /download_flex.cgi?name=status:', error)
        return getDefaultStatusData()
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
        return getDefaultNetworkData()
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
        return getDefaultNetworkConfigData()
    }
}

// 获取杂项数据
export async function fetchMiscData() {
    try {
        return await getMisc()
    } catch (error) {
        console.error('获取杂项数据失败:', error)
        return getDefaultMiscData()
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
        return getDefaultUartConfigData()
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
        return getDefaultCommTunnelData()
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
        return getDefaultOfflineCacheData()
    }
}

// 默认状态数据
function getDefaultStatusData() {
    return {
        systime: 1763950948,
        runtime: 1575947,
        cloud_sta: 1,
        socketa_sta: 0,
        socketb_sta: 0,
        mqtt1_sta: 0,
        mqtt2_sta: 0,
        soft_ver: "V1.0.13.000000.0000",
        mac: "D4AD20DBBF2F",
        sn: "03300225101400005387",
        user_sn: "ÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿ"
    }
}

function getDefaultNetworkData() {
    return {
        netdev: "EtherNET",
        eth: {
            link_sta: 1,
            ip_mode: 0,
            ip: "192.168.2.177",
            dns: "223.5.5.5",
            sdns: "223.6.6.6",
            netmask: "255.255.255.0"
        },
        lte: {
            ver: "16009.1037.00.01.53.05",
            iccid: "89861125204091384377",
            imei: "868892078327435",
            csq: 21,
            mode: "4G",
            oper: 1,
            sim: 1,
            cimi: "460113957693001",
            lte_sta: "Connected",
            lte_ip: "10.42.78.154",
            lte_netmask: "255.255.255.255",
            lte_dns: "202.96.128.86",
            lte_sdns: "202.96.134.133"
        }
    }
}

function getDefaultMiscData() {
    return {
        host_name: "N720",
        web_lang: 1
    }
}

function getDefaultCommTunnelData() {
    return {
        SOCK: [
            {
                enable: 1,
                name: "SOCKA",
                mode: 2,
                tcpc: {
                    server_ip: "192.168.0.201",
                    dns_timeout: 30,
                    reconn_interval: 5,
                    server_port: 8234,
                    local_port: 0,
                    ssl_mode: 0,
                    ssl_verify: 0,
                    ssl_server_name: "null",
                    ssl_client_name: "null",
                    ssl_client_key: "null",
                    regp_en: 0,
                    regp_fmt: 0,
                    regp_ctx: "",
                    regp_tim: 0,
                    hrtp_en: 0,
                    hrtp_fmt: 0,
                    hrtp_ctx: "",
                    hrtp_tim: 60
                },
                tcps: {
                    local_port: 8029,
                    conn_max_num: 4,
                    timeout_handling: 0,
                    idle_handling: 0,
                    idle_timeout: 3600
                },
                udpc: {
                    server_ip: "192.168.20.21",
                    dns_timeout: 30,
                    server_port: 1593,
                    local_port: 0,
                    ip_port_verify: 0
                },
                httpc: {
                    mode: 0,
                    url: "/1.php?",
                    header: "Accept:text/html",
                    cut_header: 1,
                    server_ip: "test.usr.cn",
                    server_port: 80,
                    resp_timeout: 10,
                    local_port: 0
                }
            },
            {
                enable: 0,
                name: "SOCKB",
                mode: 0,
                tcpc: {
                    server_ip: "192.168.0.201",
                    dns_timeout: 30,
                    reconn_interval: 5,
                    server_port: 8234,
                    local_port: 0,
                    ssl_mode: 0,
                    ssl_verify: 0,
                    ssl_server_name: "null",
                    ssl_client_name: "null",
                    ssl_client_key: "null",
                    regp_en: 0,
                    regp_fmt: 0,
                    regp_ctx: "",
                    regp_tim: 0,
                    hrtp_en: 0,
                    hrtp_fmt: 0,
                    hrtp_ctx: "",
                    hrtp_tim: 60
                },
                tcps: {
                    local_port: 20108,
                    conn_max_num: 4,
                    timeout_handling: 0,
                    idle_handling: 0,
                    idle_timeout: 3600
                },
                udpc: {
                    server_ip: "192.168.20.21",
                    dns_timeout: 30,
                    server_port: 1593,
                    local_port: 0,
                    ip_port_verify: 0
                },
                httpc: {
                    mode: 0,
                    url: "/1.php?",
                    header: "Accept:text/html",
                    cut_header: 1,
                    server_ip: "test.usr.cn",
                    server_port: 80,
                    resp_timeout: 10,
                    local_port: 0
                }
            }
        ],
        MQTT: [
            {
                enable: 0,
                name: "MQTT1",
                mqtt_ver: 4,
                server_ip: "192.168.0.201",
                ssl_mode: 0,
                ssl_verify: 0,
                ssl_server_name: "null",
                ssl_client_name: "null",
                ssl_client_key: "null",
                loacl_port: 0,
                server_port: 1883,
                keepalive: 60,
                reconn_space: 5,
                clean_session: 0,
                client_id: "",
                conn_verify: 0,
                conn_user_name: "",
                conn_user_password: "",
                will_flag: 0,
                will: {
                    topic: "/will",
                    msg: "offline",
                    qos: 0,
                    retention: 0
                }
            },
            {
                enable: 0,
                name: "MQTT2",
                mqtt_ver: 4,
                server_ip: "192.168.0.201",
                ssl_mode: 0,
                ssl_verify: 0,
                ssl_server_name: "null",
                ssl_client_name: "null",
                ssl_client_key: "null",
                loacl_port: 0,
                server_port: 1883,
                keepalive: 60,
                reconn_space: 5,
                clean_session: 0,
                client_id: "",
                conn_verify: 0,
                conn_user_name: "",
                conn_user_password: "",
                will_flag: 0,
                will: {
                    topic: "/will",
                    msg: "offline",
                    qos: 0,
                    retention: 0
                }
            }
        ],
        UCLOUD: {
            enable: 1,
            name: "Cloud",
            pvt_deploy_enable: 0,
            server_ip: "192.168.0.201",
            server_port: 1234
        }
    }
}

function getDefaultOfflineCacheData() {
    return {
        mgt: {
            rpt_time: 200,
            queue_type: 0
        },
        tunnel: [
            { name: "SOCKA", enable: 0 },
            { name: "SOCKB", enable: 0 },
            { name: "MQTT1", enable: 0 },
            { name: "MQTT2", enable: 0 },
            { name: "Cloud", enable: 0 }
        ]
    }
}

// 默认网络配置数据（nv 版本）
function getDefaultNetworkConfigData() {
    return {
        // 网络优先级选择
        net_select: 0,  // 0: 以太网优先, 1: 蜂窝网络优先 2: 仅以太网, 
        // 以太网配置
        eth_enable: 1,
        eth_ip_mode: 0,  // 0: 静态IP, 1: DHCP
        eth_ip: "192.168.2.177",
        eth_netmask: "255.255.255.0",
        eth_gw: "192.168.2.1",
        eth_dns: "223.5.5.5",
        eth_sdns: "223.6.6.6",
        // LTE/CAT1 配置
        lte_enable: 1,
        lte_apn: "",
        lte_user: "",
        lte_pwd: "",
        lte_auth: "NONE",
        lte_dns_mode: 0,  // 0: 自动获取, 1: 手动设置
        lte_dns: "202.96.128.86",
        lte_sdns: "202.96.134.133"
    }
}

// 默认串口配置数据
function getDefaultUartConfigData() {
    return {
        UART: [
            {
                enable: 1,
                name: "Uart1",
                work_mode: 2,
                baud_rate: 115200,
                data_bit: 8,
                stop_bit: 1,
                parity: 0,
                pack_len: 1460,
                pack_time: 0,
                func: 1
            },
            {
                enable: 1,
                select: 0,
                name: "Uart2",
                work_mode: 2,
                baud_rate: 9600,
                data_bit: 8,
                stop_bit: 1,
                parity: 0,
                pack_len: 1460,
                pack_time: 0
            }
        ]
    }
}

export const statusData = getDefaultStatusData()
export const networkData = getDefaultNetworkData()
export const miscData = getDefaultMiscData()

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