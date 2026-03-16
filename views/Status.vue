<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading">{{ t('common.loading') }}</div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

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
            <td>{{ statusInfo.netdev || '-' }}</td>
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
      <legend>{{ t('status.cellular') }}</legend>
      <table>
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

    <!-- 第四部分：TCP 连接状态 -->
    <form>
      <legend>{{ t('status.tcpStatus') }}</legend>
      <table>
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
      <legend>{{ t('status.mqttStatus') }}</legend>
      <table>
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
      <legend>{{ t('status.cloudStatus') }}</legend>
      <table>
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
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
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
  if (!csq) return '-'
  const strength = parseInt(csq)
  if (strength === 0) return t('status.signalNone')
  if (strength <= 5) return t('status.signalVeryWeak')
  if (strength <= 10) return t('status.signalWeak')
  if (strength <= 15) return t('status.signalFair')
  if (strength <= 20) return t('status.signalGood')
  if (strength <= 30) return t('status.signalExcellent')
  return t('status.signalStrong')
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
