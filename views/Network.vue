<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading">加载中...</div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

    <!-- 第一部分：网络信息 -->
    <form v-if="!loading">
      <legend>网络配置</legend>
      <table>
        <tbody>
          <tr>
            <td class="title">当前网络:</td>
            <td>{{ networkData.netdev }}</td>
          </tr>
        </tbody>
      </table>
    </form>

    <!-- 以太网部分 -->
    <form style="margin-top: 20px;" v-if="!loading">
      <legend>以太网</legend>
      <table>
        <tbody>
          <tr>
            <td class="title">连接状态:</td>
            <td>{{ networkData.eth?.link_sta === 1 ? '已接入' : '未接入' }}</td>
          </tr>
          <tr>
            <td class="title">IP配置方式:</td>
            <td>{{ networkData.eth?.ip_mode === 0 ? '静态IP' : 'DHCP' }}</td>
          </tr>
          <tr>
            <td class="title">IP地址:</td>
            <td>{{ networkData.eth?.ip }}</td>
          </tr>
          <tr>
            <td class="title">子网掩码:</td>
            <td>{{ networkData.eth?.netmask }}</td>
          </tr>
          <tr>
            <td class="title">DNS:</td>
            <td>{{ networkData.eth?.dns }}</td>
          </tr>
          <tr>
            <td class="title">备用DNS:</td>
            <td>{{ networkData.eth?.sdns }}</td>
          </tr>
        </tbody>
      </table>
    </form>

    <!-- 蜂窝网络部分 -->
    <form style="margin-top: 20px;" v-if="!loading && networkData.lte">
      <legend>蜂窝网络</legend>
      <table>
        <tbody>
          <tr>
            <td class="title">联网SIM:</td>
            <td>{{ networkData.lte?.sim === 1 ? 'SIM1' : 'SIM2' }}</td>
          </tr>
          <tr>
            <td class="title">网络模式:</td>
            <td>{{ networkData.lte?.mode }}</td>
          </tr>
          <tr>
            <td class="title">连接状态:</td>
            <td>{{ networkData.lte?.lte_sta }}</td>
          </tr>
          <tr>
            <td class="title">信号强度:</td>
            <td>{{ networkData.lte?.csq }}</td>
          </tr>
          <tr>
            <td class="title">IMEI:</td>
            <td>{{ networkData.lte?.imei }}</td>
          </tr>
          <tr>
            <td class="title">ICCID:</td>
            <td>{{ networkData.lte?.iccid }}</td>
          </tr>
          <tr>
            <td class="title">IMSI:</td>
            <td>{{ networkData.lte?.cimi }}</td>
          </tr>
          <tr>
            <td class="title">本地IP:</td>
            <td>{{ networkData.lte?.lte_ip }}</td>
          </tr>
        </tbody>
      </table>
    </form>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { fetchNetworkData } from '../api/mockData'

// 响应式数据
const networkData = ref({})
const loading = ref(true)
const error = ref(null)

// 加载数据
const loadData = async () => {
  try {
    loading.value = true
    error.value = null
    networkData.value = await fetchNetworkData()
  } catch (err) {
    error.value = '加载数据失败: ' + err.message
    console.error('数据加载错误:', err)
  } finally {
    loading.value = false
  }
}

// 组件挂载时加载数据
onMounted(() => {
  loadData()
  // 每30秒自动刷新一次数据
  setInterval(loadData, 30000)
})
</script>

<style scoped>
.loading {
  text-align: center;
  padding: 20px;
  color: #666;
}

.error {
  background-color: #fee;
  border: 1px solid #fcc;
  color: #c33;
  padding: 12px;
  border-radius: 4px;
  margin-bottom: 20px;
}
</style>
