<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading">加载中...</div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

    <!-- 第一部分：当前状态 -->
    <form>
      <legend>系统</legend>
      <table>
        <tbody>
          <tr>
            <td class="title">设备名称:</td>
            <td>{{ miscInfo.host_name || '-' }}</td>
          </tr>
          <tr>
            <td class="title">产品型号:</td>
            <td>{{ miscInfo.host_name || '-' }}</td>
          </tr>
          <tr>
            <td class="title">固件版本:</td>
            <td>{{ statusInfo.soft_ver || '-' }}</td>
          </tr>
          <tr>
            <td class="title">产品类型:</td>
            <td>{{ getProductType() }}</td>
          </tr>
          <tr>
            <td class="title">运行时间:</td>
            <td>{{ formatSeconds(statusInfo.runtime) }}</td>
          </tr>
          <tr>
            <td class="title">操作系统:</td>
            <td>OpenHarmonyOS</td>
          </tr>
          <tr>
            <td class="title">MAC:</td>
            <td>{{ formatMac(statusInfo.mac) }}</td>
          </tr>
          <tr>
            <td class="title">SN:</td>
            <td>{{ statusInfo.sn || '-' }}</td>
          </tr>
          <tr>
            <td class="title">系统时间:</td>
            <td>{{ formatTimestamp(statusInfo.systime) }}</td>
          </tr>
          <tr>
            <td class="title">当前运行网络:</td>
            <td>{{ networkInfo.netdev || '-' }}</td>
          </tr>
        </tbody>
      </table>
    </form>

    <!-- 第二部分：以太网 -->
    <form>
      <legend>以太网</legend>
      <table>
        <tbody>
          <tr>
            <td class="title">连接状态:</td>
            <td>{{ networkInfo.eth?.link_sta === 1 ? '已接入' : '未接入' }}</td>
          </tr>
          <tr>
            <td class="title">网络类型:</td>
            <td>{{ networkInfo.eth?.ip_mode === 0 ? 'Static IP' : 'DHCP' }}</td>
          </tr>
          <tr>
            <td class="title">本地IP:</td>
            <td>{{ networkInfo.eth?.ip }}</td>
          </tr>
        </tbody>
      </table>
    </form>

    <!-- 第三部分：蜂窝网络 -->
    <form>
      <legend>蜂窝网络</legend>
      <table>
        <tbody>
          <tr>
            <td class="title">联网SIM:</td>
            <td>{{ networkInfo.lte?.sim === 1 ? 'SIM1' : 'SIM2' }}</td>
          </tr>
          <tr>
            <td class="title">IMEI:</td>
            <td>{{ networkInfo.lte?.imei }}</td>
          </tr>
          <tr>
            <td class="title">ICCID:</td>
            <td>{{ networkInfo.lte?.iccid }}</td>
          </tr>
          <tr>
            <td class="title">CIMI:</td>
            <td>{{ networkInfo.lte?.cimi }}</td>
          </tr>
          <tr>
            <td class="title">信号值:</td>
            <td>{{ networkInfo.lte?.csq }}</td>
          </tr>
          <tr>
            <td class="title">信号强度:</td>
            <td>{{ getSignalStrength(networkInfo.lte?.csq) }}</td>
          </tr>
          <tr>
            <td class="title">本地IP:</td>
            <td>{{ networkInfo.lte?.lte_ip }}</td>
          </tr>
          <tr>
            <td class="title">网关地址:</td>
            <td>{{ networkInfo.lte?.lte_netmask }}</td>
          </tr>
          <tr>
            <td class="title">连接状态:</td>
            <td>{{ networkInfo.lte?.lte_sta || '-' }}</td>
          </tr>
        </tbody>
      </table>
    </form>

    <!-- 第四部分：TCP 连接状态 -->
    <form>
      <legend>TCP 连接状态</legend>
      <table>
        <tbody>
          <tr>
            <td class="title">socket1 连接状态:</td>
            <td>{{ getConnectionStatus(statusInfo.socketa_sta) }}</td>
          </tr>
          <tr>
            <td class="title">socket1 连接标识:</td>
            <td>{{ statusInfo.socketa_sta === 0 ? 'OFF' : 'ON' }}</td>
          </tr>
          <tr>
            <td class="title">socket2 连接状态:</td>
            <td>{{ getConnectionStatus(statusInfo.socketb_sta) }}</td>
          </tr>
          <tr>
            <td class="title">socket2 连接标识:</td>
            <td>{{ statusInfo.socketb_sta === 0 ? 'OFF' : 'ON' }}</td>
          </tr>
        </tbody>
      </table>
    </form>

    <!-- 第五部分：MQTT 连接状态 -->
    <form>
      <legend>MQTT 连接状态</legend>
      <table>
        <tbody>
          <tr>
            <td class="title">MQTT1 连接状态:</td>
            <td>{{ getConnectionStatus(statusInfo.mqtt1_sta) }}</td>
          </tr>
          <tr>
            <td class="title">MQTT1 连接标识:</td>
            <td>{{ statusInfo.mqtt1_sta === 0 ? 'OFF' : 'ON' }}</td>
          </tr>
          <tr>
            <td class="title">MQTT2 连接状态:</td>
            <td>{{ getConnectionStatus(statusInfo.mqtt2_sta) }}</td>
          </tr>
          <tr>
            <td class="title">MQTT2 连接标识:</td>
            <td>{{ statusInfo.mqtt2_sta === 0 ? 'OFF' : 'ON' }}</td>
          </tr>
        </tbody>
      </table>
    </form>

    <!-- 第六部分：Cloud 连接状态 -->
    <form>
      <legend>Cloud 连接状态</legend>
      <table>
        <tbody>
          <tr>
            <td class="title">Cloud 连接状态:</td>
            <td>{{ getConnectionStatus(statusInfo.cloud_sta) }}</td>
          </tr>
          <tr>
            <td class="title">Cloud 连接标识:</td>
            <td>{{ statusInfo.cloud_sta === 0 ? 'OFF' : 'ON' }}</td>
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

// 响应式数据
const statusInfo = ref({})
const networkInfo = ref({})
const miscInfo = ref({})
const loading = ref(true)
const error = ref(null)
let refreshTimer = null

// 辅助函数：从 SN 获取产品类型
const getProductType = () => {
  const sn = statusInfo.value.sn || ''
  // 示例：根据 SN 的某些位判断产品类型
  // 可根据实际需求修改
  return '-C1'
}

// 辅助格式化 MAC 地址 D4AD20... -> D4:AD:20...
const formatMac = (macStr) => {
  if (!macStr) return '-'
  return macStr.match(/.{1,2}/g)?.join(':') || macStr
}

// 辅助函数：获取连接状态描述
const getConnectionStatus = (status) => {
  if (status === 0) return 'Disconnected'
  if (status === 1) return 'Connected'
  return '-'
}

// 辅助函数：获取信号强度描述
const getSignalStrength = (csq) => {
  if (!csq) return '-'
  const strength = parseInt(csq)
  if (strength === 0) return '无信号'
  if (strength <= 5) return '极弱'
  if (strength <= 10) return '弱'
  if (strength <= 15) return '一般'
  if (strength <= 20) return '良好'
  if (strength <= 30) return '优秀'
  return '极强'
}

// 加载所有数据
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
    error.value = '加载数据失败: ' + err.message
    console.error('数据加载错误:', err)
  } finally {
    loading.value = false
  }
}

// 组件挂载时加载数据
onMounted(() => {
  // 立即加载一次数据
  loadData()
  
  // 每 5 秒自动刷新一次数据
  refreshTimer = setInterval(() => {
    loadData()
  }, 5000)
})

// 组件卸载时清除定时器
onUnmounted(() => {
  if (refreshTimer) {
    clearInterval(refreshTimer)
  }
})
</script>

