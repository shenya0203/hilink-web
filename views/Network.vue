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

    <!-- 第一部分：网络信息 -->
    <form v-if="!loading">
      <legend>{{ t('network.title') }}</legend>
      <table>
        <tbody>
          <tr>
            <td class="title">{{ t('status.currentNetwork') }}:</td>
            <td>{{ networkData.netdev }}</td>
          </tr>
        </tbody>
      </table>
    </form>

    <!-- 以太网部分 -->
    <form style="margin-top: 20px;" v-if="!loading">
      <legend>{{ t('status.ethernet') }}</legend>
      <table>
        <tbody>
          <tr>
            <td class="title">{{ t('status.connectionStatus') }}:</td>
            <td>{{ networkData.eth?.link_sta === 1 ? t('status.pluggedIn') : t('status.unplugged') }}</td>
          </tr>
          <tr>
            <td class="title">{{ t('network.workMode') }}:</td>
            <td>{{ networkData.eth?.ip_mode === 0 ? t('network.staticMode') : t('network.dhcpMode') }}</td>
          </tr>
          <tr>
            <td class="title">{{ t('status.localIP') }}:</td>
            <td>{{ networkData.eth?.ip }}</td>
          </tr>
          <tr>
            <td class="title">{{ t('status.netmask') }}:</td>
            <td>{{ networkData.eth?.netmask }}</td>
          </tr>
          <tr>
            <td class="title">{{ t('network.primaryDns') }}:</td>
            <td>{{ networkData.eth?.dns }}</td>
          </tr>
          <tr>
            <td class="title">{{ t('network.backupDns') }}:</td>
            <td>{{ networkData.eth?.sdns }}</td>
          </tr>
        </tbody>
      </table>
    </form>

    <!-- 蜂窝网络部分 -->
    <form style="margin-top: 20px;" v-if="!loading && networkData.lte">
      <legend>{{ t('status.cellular') }}</legend>
      <table>
        <tbody>
          <tr>
            <td class="title">{{ t('status.activeSim') }}:</td>
            <td>{{ networkData.lte?.sim === "1" ? 'SIM1' : 'SIM2' }}</td>
          </tr>
          <tr>
            <td class="title">{{ t('status.networkType') }}:</td>
            <td>{{ networkData.lte?.mode }}</td>
          </tr>
          <tr>
            <td class="title">{{ t('status.connectionStatus') }}:</td>
            <td>{{ networkData.lte?.lte_sta }}</td>
          </tr>
          <tr>
            <td class="title">{{ t('status.signalStrength') }}:</td>
            <td>{{ networkData.lte?.csq }}</td>
          </tr>
          <tr>
            <td class="title">{{ t('status.imei') }}:</td>
            <td>{{ networkData.lte?.imei }}</td>
          </tr>
          <tr>
            <td class="title">{{ t('status.iccid') }}:</td>
            <td>{{ networkData.lte?.iccid }}</td>
          </tr>
          <tr>
            <td class="title">{{ t('status.cimi') }}:</td>
            <td>{{ networkData.lte?.cimi }}</td>
          </tr>
          <tr>
            <td class="title">{{ t('status.localIP') }}:</td>
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
import { useI18n } from '../i18n/useI18n.js'

// 使用 i18n
const { t } = useI18n()

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
    error.value = t('common.loadError') + ': ' + err.message
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
  width: 40px;
  height: 40px;
  border: 4px solid #f3f3f3;
  border-top: 4px solid #0066cc;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

.loading-text {
  color: #666;
  font-size: 14px;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

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
