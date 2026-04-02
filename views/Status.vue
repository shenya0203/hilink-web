<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading-container">
      <div class="loading-wrapper">
        <div class="loading-spinner"></div>
        <div class="loading-text">{{ t('common.loading') }}</div>
      </div>
    </div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

    <div v-if="!loading">
      <!-- 第一部分：当前状态 -->
      <form>
        <legend>{{ t('status.system') }}</legend>
        <table>
          <tbody>
            <tr>
              <td class="title">{{ t('status.deviceName') }}:</td>
              <td>{{ miscInfo.host_name || '-' }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.productModel') }}:</td>
              <td>{{ miscInfo.productModel || '-' }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.firmwareVersion') }}:</td>
              <td>{{ statusInfo.soft_ver || '-' }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.productType') }}:</td>
              <td>{{ statusInfo.product_type || '-' }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.runtime') }}:</td>
              <td>{{ formatSeconds(statusInfo.runtime) }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.os') }}:</td>
              <td>{{statusInfo.os}}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.mac') }}:</td>
              <td>{{ statusInfo.mac}}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.sn') }}:</td>
              <td>{{ statusInfo.sn || '-' }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.systemTime') }}:</td>
              <td>{{ formatTimestamp(statusInfo.systime) }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.currentNetwork') }}:</td>
              <td>{{ networkInfo.netdev || '-' }}</td>
            </tr>
          </tbody>
        </table>
      </form>

      <!-- 第二部分：以太网 -->
      <form>
        <legend>{{ t('status.ethernet') }}</legend>
        <table>
          <tbody>
            <tr>
              <td class="title">{{ t('status.connectionStatus') }}:</td>
              <td>{{ networkInfo.eth?.link_sta === 1 ? t('status.pluggedIn') : t('status.unplugged') }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.networkType') }}:</td>
              <td>{{ networkInfo.eth?.ip_mode === 0 ? 'Static IP' : 'DHCP' }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.localIP') }}:</td>
              <td>{{ networkInfo.eth?.ip }}</td>
            </tr>
          </tbody>
        </table>
      </form>

      <!-- 第三部分：蜂窝网络 -->
      <form>
        <legend class="collapsible" @click="toggleSection('cellular')">
          {{ t('status.cellular') }}
          <span class="toggle-icon">{{ showCellular ? '▼' : '▶' }}</span>
        </legend>
        <table v-show="showCellular">
          <tbody>
            <tr>
              <td class="title">{{ t('status.activeSim') }}:</td>
              <td>{{ networkInfo.lte?.sim === '1' ? t('status.sim_ready') : t('status.sim_absent') }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.imei') }}:</td>
              <td>{{ networkInfo.lte?.imei }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.iccid') }}:</td>
              <td>{{ networkInfo.lte?.iccid }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.cimi') }}:</td>
              <td>{{ networkInfo.lte?.cimi }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.signalValue') }}:</td>
              <td>{{ networkInfo.lte?.csq }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.signalStrength') }}:</td>
              <td>{{ getSignalStrength(networkInfo.lte?.csq) }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.localIP') }}:</td>
              <td>{{ networkInfo.lte?.lte_ip }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.netmask') }}:</td>
              <td>{{ networkInfo.lte?.lte_netmask }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.connectionStatus') }}:</td>
              <td>{{ networkInfo.lte?.lte_sta || '-' }}</td>
            </tr>
          </tbody>
        </table>
      </form>

    <!-- 第四部分：WiFi STA -->
    <form>
      <legend>{{ t('status.wifiSta') }}</legend>
      <table>
        <tbody>
          <tr>
            <td class="title">{{ t('status.connectionStatus') }}:</td>
            <td>
              <span :class="{ 'status-connected': networkInfo.wifi_sta?.status === 'Connected', 'status-disconnected': networkInfo.wifi_sta?.status !== 'Connected' }">
                {{ networkInfo.wifi_sta?.status === 'Connected' ? t('common.connected') : t('common.disconnected') }}
              </span>
            </td>
          </tr>
          <tr>
            <td class="title">{{ t('status.localIP') }}:</td>
            <td>{{ networkInfo.wifi_sta?.ip || '-' }}</td>
          </tr>
          <tr>
            <td class="title">{{ t('status.signalStrength') }}:</td>
            <td>
              <div class="signal-container" v-if="networkInfo.wifi_sta?.signal">
                <span class="signal-value">{{ networkInfo.wifi_sta?.signal }} dBm</span>
                <div class="signal-bar-bg">
                   <div class="signal-bar-fill" :style="{ width: Math.min(Math.max((networkInfo.wifi_sta?.signal + 100) * 2, 0), 100) + '%', backgroundColor: getSignalColor(networkInfo.wifi_sta?.signal) }"></div>
                </div>
              </div>
              <span v-else>-</span>
            </td>
          </tr>
          <tr>
            <td class="title">{{ t('status.negotiatedRate') }}:</td>
            <td>{{ networkInfo.wifi_sta?.rate || '-' }}</td>
          </tr>
        </tbody>
      </table>
    </form>

    <!-- 第五部分：WiFi AP 设备列表 -->
    <form class="wide-form">
      <legend>{{ t('status.wifiApDeviceList') }}</legend>
      <div class="table-container">
        <table class="data-table">
          <thead>
            <tr>
              <th>{{ t('status.deviceName') }}</th>
              <th>{{ t('status.ipAddress') }}</th>
              <th>{{ t('status.mac') }}</th>
              <th>{{ t('status.signalStrength') }}</th>
              <th>{{ t('status.negotiatedRate') }}</th>
              <th>{{ t('status.leaseRemaining') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(client, index) in (networkInfo.wifi_ap?.clients || [])" :key="index">
              <td>{{ client.hostname || '-' }}</td>
              <td>{{ client.ip || '-' }}</td>
              <td>{{ client.mac }}</td>
              <td>{{ client.signal }} dBm</td>
              <td>{{ client.rates }}</td>
              <td>{{ formatLeaseTime(client.lease_remaining) }}</td>
            </tr>
            <tr v-if="!networkInfo.wifi_ap?.clients || networkInfo.wifi_ap.clients.length === 0">
              <td colspan="6" class="text-center">{{ t('common.none') }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </form>
      <!-- 第四部分：TCP 连接状态 -->
      <form>
        <legend class="collapsible" @click="toggleSection('tcp')">
          {{ t('status.tcpStatus') }}
          <span class="toggle-icon">{{ showTcp ? '▼' : '▶' }}</span>
        </legend>
        <table v-show="showTcp">
          <tbody>
            <tr>
              <td class="title">{{ t('status.socket1Status') }}:</td>
              <td>{{ getConnectionStatus(statusInfo.socketa_sta) }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.socket1Flag') }}:</td>
              <td>{{ statusInfo.socketa_enable === 0 ? t('common.off') : t('common.on') }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.socket2Status') }}:</td>
              <td>{{ getConnectionStatus(statusInfo.socketb_sta) }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.socket2Flag') }}:</td>
              <td>{{ statusInfo.socketb_enable === 0 ? t('common.off') : t('common.on') }}</td>
            </tr>
          </tbody>
        </table>
      </form>

      <!-- 第五部分：MQTT 连接状态 -->
      <form>
        <legend class="collapsible" @click="toggleSection('mqtt')">
          {{ t('status.mqttStatus') }}
          <span class="toggle-icon">{{ showMqtt ? '▼' : '▶' }}</span>
        </legend>
        <table v-show="showMqtt">
          <tbody>
            <tr>
              <td class="title">{{ t('status.mqtt1Status') }}:</td>
              <td>{{ getConnectionStatus(statusInfo.mqtt1_sta) }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.mqtt1Flag') }}:</td>
              <td>{{ statusInfo.mqtt1_enable === 0 ? t('common.off') : t('common.on') }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.mqtt2Status') }}:</td>
              <td>{{ getConnectionStatus(statusInfo.mqtt2_sta) }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.mqtt2Flag') }}:</td>
              <td>{{ statusInfo.mqtt2_enable === 0 ? t('common.off') : t('common.on') }}</td>
            </tr>
          </tbody>
        </table>
      </form>

      <!-- 第六部分：CLOUD 连接状态 -->
      <form>
        <legend class="collapsible" @click="toggleSection('cloud')">
          {{ t('status.cloudStatus') }}
          <span class="toggle-icon">{{ showCloud ? '▼' : '▶' }}</span>
        </legend>
        <table v-show="showCloud">
          <tbody>
            <tr>
              <td class="title">{{ t('status.cloudConnectionStatus') }}:</td>
              <td>{{ getConnectionStatus(statusInfo.cloud_sta) }}</td>
            </tr>
            <tr>
              <td class="title">{{ t('status.cloudConnectionFlag') }}:</td>
              <td>{{ statusInfo.cloud_enable === 0 ? t('common.off') : t('common.on') }}</td>
            </tr>
          </tbody>
        </table>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

// ---- 折叠面板：localStorage 持久化 ----
const COLLAPSE_KEY = 'status_panel_collapse'

// 从 localStorage 读取上次状态，默认均为 false（折叠）
const loadCollapseState = () => {
  try {
    const saved = localStorage.getItem(COLLAPSE_KEY)
    return saved ? JSON.parse(saved) : {}
  } catch {
    return {}
  }
}

const savedState = loadCollapseState()
const showCellular = ref(savedState.cellular ?? false)
const showTcp      = ref(savedState.tcp      ?? false)
const showMqtt     = ref(savedState.mqtt     ?? false)
const showCloud    = ref(savedState.cloud    ?? false)

// 切换折叠状态并同步写入 localStorage
const toggleSection = (key) => {
  const map = { cellular: showCellular, tcp: showTcp, mqtt: showMqtt, cloud: showCloud }
  if (!map[key]) return
  map[key].value = !map[key].value
  try {
    const current = loadCollapseState()
    current[key] = map[key].value
    localStorage.setItem(COLLAPSE_KEY, JSON.stringify(current))
  } catch { /* ignore */ }
}
// ---- 折叠面板 END ----
import { 
  fetchStatusData,
  fetchNetworkData,
  fetchMiscData,
  formatSeconds,
  formatTimestamp 
} from '../api/mockData'
import { useI18n } from '../i18n/useI18n.js'

// 使用 i18n
const { t } = useI18n()

// 响应式数据
const statusInfo = ref({})
const networkInfo = ref({})
const miscInfo = ref({})
const loading = ref(true)
const error = ref(null)
let refreshTimer = null

// 辅助格式化 MAC 地址 D4AD20... -> D4:AD:20...
const formatMac = (macStr) => {
  if (!macStr) return '-'
  return macStr.match(/.{1,2}/g)?.join(':') || macStr
}

// 辅助函数：获取连接状态描述
const getConnectionStatus = (status) => {
  if (status === 0) return t('common.disconnected')
  if (status === 1) return t('common.connected')
  return '-'
}

// 辅助函数：获取信号强度描述
const getSignalStrength = (csq) => {
  if (!csq || csq === 'N/A') return '-'
  const strength = parseInt(csq)
  if (strength === 0) return t('status.signalNone')
  if (strength <= 5) return t('status.signalVeryWeak')
  if (strength <= 10) return t('status.signalWeak')
  if (strength <= 15) return t('status.signalFair')
  if (strength <= 20) return t('status.signalGood')
  if (strength <= 30) return t('status.signalExcellent')
  return t('status.signalStrong')
}

// 辅助函数：获取信号颜色
const getSignalColor = (signal) => {
  if (!signal) return '#ccc'
  if (signal >= -50) return '#4caf50' // Strong Green
  if (signal >= -70) return '#ff9800' // Medium Orange
  return '#f44336' // Weak Red
}

// 辅助函数：格式化租约时间
const formatLeaseTime = (seconds) => {
  if (seconds === 'Static' || seconds === -1) return t('status.static')
  if (!seconds || seconds < 0) return '-'
  
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  return `${h}小时${m}分`
}

// 加载所有数据（首次加载，显示 loading 状态）
const loadData = async () => {
  try {
    loading.value = true
    error.value = null
    
    // 只加载 status 和 network 数据（符合要求）
    const [status, network] = await Promise.all([
      fetchStatusData(),
      fetchNetworkData()
    ])
    
    statusInfo.value = status
    networkInfo.value = network
    
    // 获取 misc 数据用于设备名称等信息
    const misc = await fetchMiscData()
    miscInfo.value = misc
  } catch (err) {
    error.value = t('common.loadError') + ': ' + err.message
    console.error('数据加载错误:', err)
  } finally {
    loading.value = false
  }
}

// 静默刷新数据（不显示 loading 状态，只更新对应参数）
const refreshData = async () => {
  try {
    // 并行获取所有数据
    const [status, network, misc] = await Promise.all([
      fetchStatusData(),
      fetchNetworkData(),
      fetchMiscData()
    ])
    
    // 只更新数据，不触发 loading 状态
    statusInfo.value = status
    networkInfo.value = network
    miscInfo.value = misc
    
    // 清除之前可能存在的错误
    error.value = null
  } catch (err) {
    // 静默刷新失败时，不覆盖当前显示的数据
    console.error('数据刷新错误:', err)

    // 熔断机制：检测 401 或网络错误
    // 如果是 401 (Unauthorized) 错误，或者发生了网络错误（通常没有 response），立即停止轮询
    if (err.response?.status === 401 || !err.response) {
      if (refreshTimer) {
        clearInterval(refreshTimer)
        refreshTimer = null
      }
    }
  }
}

// 页面可见性变化处理
const handleVisibilityChange = () => {
  if (document.hidden) {
    // 页面不可见，清除定时器
    if (refreshTimer) {
      clearInterval(refreshTimer)
      refreshTimer = null
    }
  } else {
    // 页面重新可见
    // 立即执行一次数据加载
    refreshData()
    // 重启定时器（如果未启动）
    if (!refreshTimer) {
      refreshTimer = setInterval(refreshData, 5000)
    }
  }
}

// 组件挂载时加载数据
onMounted(() => {
  // 立即加载一次数据（首次加载显示 loading）
  loadData()
  
  // 每 5 秒自动静默刷新数据（不显示 loading，只更新参数）
  refreshTimer = setInterval(() => {
    refreshData()
  }, 5000)

  // 监听页面可见性变化
  document.addEventListener('visibilitychange', handleVisibilityChange)
})

// 组件卸载时清除定时器
onUnmounted(() => {
  if (refreshTimer) {
    clearInterval(refreshTimer)
  }
  // 移除事件监听器
  document.removeEventListener('visibilitychange', handleVisibilityChange)
})
</script>

<style scoped>
/* 可折叠面板标题栏 */
legend.collapsible {
  cursor: pointer;
  user-select: none;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

legend.collapsible:hover {
  opacity: 0.85;
}

/* 折叠箭头图标 */
.toggle-icon {
  font-size: 0.75em;
  margin-left: 8px;
  flex-shrink: 0;
}

/* 加载动画样式 */
.loading-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 400px;
  width: 100%;
}

.loading-wrapper {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 15px;
}

.loading-spinner {
  border: 4px solid #f3f3f3;
  border-top: 4px solid #0066cc;
  border-radius: 50%;
  width: 40px;
  height: 40px;
  animation: spin 1s linear infinite;
}

.loading-text {
  color: #666;
  font-size: 14px;
}

.loading {
  text-align: center;
  padding: 40px 20px;
  color: #666;
  font-size: 14px;
}

.error {
  background-color: #ffebee;
  border: 1px solid #ffcdd2;
  color: #c62828;
  padding: 12px 15px;
  border-radius: 4px;
  margin-bottom: 20px;
  font-size: 13px;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
</style>
