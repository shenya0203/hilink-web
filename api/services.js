import axios from 'axios'

const CSRF_KEY = 'hlk_csrf'

export function getCsrfToken() {
    return sessionStorage.getItem(CSRF_KEY) || ''
}

export function setCsrfToken(token) {
    if (token) {
        sessionStorage.setItem(CSRF_KEY, token)
    } else {
        sessionStorage.removeItem(CSRF_KEY)
    }
}

function needsCsrf(url, method) {
    const m = (method || 'get').toUpperCase()
    const u = url || ''
    if (m !== 'GET' && m !== 'HEAD' && m !== 'OPTIONS') return true
    if (u.includes('/upload/')) return true
    if (u.includes('/update_')) return true
    if (u.includes('/action_')) return true
    return false
}

const apiClient = axios.create({
    timeout: 5000,
    withCredentials: true
})

apiClient.interceptors.request.use((config) => {
    const url = config.url || ''
    if (needsCsrf(url, config.method)) {
        const csrf = getCsrfToken()
        if (csrf) {
            config.headers = config.headers || {}
            config.headers['X-CSRF-Token'] = csrf
        }
    }
    return config
})

apiClient.interceptors.response.use(
    (response) => response,
    (error) => {
        const status = error.response && error.response.status
        if (status === 401) {
            setCsrfToken('')
            const hash = window.location.hash || ''
            if (!hash.includes('/login')) {
                const redirect = hash.replace(/^#/, '') || '/'
                window.location.hash = `#/login?redirect=${encodeURIComponent(redirect)}`
            }
        }
        console.error('API 请求错误:', error.message)
        return Promise.reject(error)
    }
)

export function fetchLoginPubkey() {
    return apiClient.get('/login_pubkey.cgi')
        .then((res) => {
            if (!res.data || !res.data.pubkey) {
                throw new Error('no pubkey')
            }
            return res.data.pubkey
        })
}

export function login(username, password_enc, nonce) {
    return apiClient.post('/login.cgi', { username, password_enc, nonce })
        .then((res) => {
            if (res.data && res.data.csrf) {
                setCsrfToken(res.data.csrf)
            }
            return res.data
        })
}

export function logout() {
    return apiClient.post('/logout.cgi')
        .then((res) => {
            setCsrfToken('')
            return res.data
        })
        .catch((err) => {
            setCsrfToken('')
            throw err
        })
}

export function authCheck() {
    return apiClient.get('/auth_check.cgi')
        .then((res) => {
            if (res.data && res.data.csrf) {
                setCsrfToken(res.data.csrf)
            }
            return res.data
        })
}

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
 * 获取首页聚合数据 (status + network)
 */
export function getHomepageData() {
    return apiClient.get('/download_flex.cgi?name=all')
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
 * 获取网络 LAN 配置（nv 版本）
 */
export function getNetworkLanConfig() {
    return apiClient.get('/download_nv.cgi?name=network_lan')
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
 * 获取离线缓存配置
 */
export function getOfflineCache() {
    return apiClient.get('/download_nv.cgi?name=offline_cache')
        .then(res => res.data)
}

/**
 * 更新配置
 * @param {string} file 配置文件名
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
