<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading">{{ t('common.loading') }}</div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

    <!-- Cloud配置标题 -->
    <div class="description-box">
      <div class="desc-title">{{ t('cloud.title') }}</div>
      <div class="desc-content">{{ t('cloud.description') }}</div>
    </div>

    <!-- Cloud配置表单 -->
    <form v-if="cloudConfig">
      <div class="form-section">
        <div class="form-group">
          <label>{{ t('cloud.enable') }}:</label>
          <select v-model.number="cloudConfig.enable">
            <option :value="0">{{ t('common.disable') }}</option>
            <option :value="1">{{ t('common.enable') }}</option>
          </select>
        </div>

        <div class="form-group">
          <label>{{ t('socket.offlineCache') }}:</label>
          <select v-model.number="offlineCacheEnable">
            <option :value="0">{{ t('common.disable') }}</option>
            <option :value="1">{{ t('common.enable') }}</option>
          </select>
        </div>
      </div>
    </form>

    <!-- 应用保存按钮 -->
    <div class="button-group">
      <button class="btn-save" @click="saveConfig">{{ t('common.save') }}</button>
    </div>
    <!-- 重启确认弹窗 -->
    <div v-if="showRestartModal" class="modal-overlay">
      <div class="modal">
        <div class="modal-header"><h3>{{ t('common.saveSuccess') }}</h3></div>
        <div class="modal-body">
          <p>{{ t('socket.restartRequired') }}</p>
          <div class="modal-actions">
            <button class="btn-restart" @click="handleRestart">{{ t('system.restartNow') }}</button>
            <button class="btn-continue" @click="handleContinue">{{ t('socket.continueConfig') }}</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getCommTunnel, getOfflineCache, restartDevice } from '../api/services'
import apiClient from '../api/services'
import { useI18n } from '../i18n/useI18n.js'

// 使用 i18n
const { t } = useI18n()

// 响应式数据
const loading = ref(true)
const error = ref(null)
const cloudConfig = ref(null)
const offlineCacheEnable = ref(0)
const offlineCacheData = ref(null)
const showRestartModal = ref(false)

// 加载配置
const loadData = async () => {
  try {
    loading.value = true
    error.value = null
    
    // 并行获取数据
    const [commTunnel, offlineCache] = await Promise.all([
      getCommTunnel(),
      getOfflineCache()
    ])
    
    console.log('=== Cloud配置页面数据加载 ===')
    console.log('CommTunnel:', commTunnel)
    console.log('OfflineCache:', offlineCache)
    
    // 提取UCLOUD配置
    if (commTunnel && commTunnel.UCLOUD) {
      cloudConfig.value = commTunnel.UCLOUD
    } else {
      // 默认配置
      cloudConfig.value = {
        enable: 0,
        name: "Cloud",
        pvt_deploy_enable: 0,
        server_ip: "",
        server_port: 0
      }
    }
    
    // 提取断网缓存配置
    offlineCacheData.value = offlineCache
    if (offlineCache && offlineCache.tunnel && Array.isArray(offlineCache.tunnel)) {
      const cloudCache = offlineCache.tunnel.find(t => t.name === 'Cloud')
      if (cloudCache) {
        offlineCacheEnable.value = cloudCache.enable
      }
    }
    
  } catch (err) {
    error.value = t('common.loadError') + ': ' + err.message
    console.error('配置加载错误:', err)
  } finally {
    loading.value = false
  }
}

// 保存配置
const saveConfig = async () => {
  try {
    // 保存Cloud使能配置
    await apiClient.get('/update_nv.cgi', {
      params: {
        file: 'comm_tunnel',
        'n_UCLOUD.enable': cloudConfig.value.enable
      }
    })
    
    // 查找Cloud在tunnel数组中的索引
    let cloudIndex = -1
    if (offlineCacheData.value && offlineCacheData.value.tunnel) {
      cloudIndex = offlineCacheData.value.tunnel.findIndex(t => t.name === 'Cloud')
    }
    
    // 保存断网缓存配置
    if (cloudIndex >= 0) {
      await apiClient.get('/update_nv.cgi', {
        params: {
          file: 'offline_cache',
          [`n_tunnel[${cloudIndex}].enable`]: offlineCacheEnable.value
        }
      })
    }
    
    console.log('保存Cloud配置:', {
      enable: cloudConfig.value.enable,
      offlineCacheEnable: offlineCacheEnable.value
    })
    
    showRestartModal.value = true
    //alert(t('common.saveSuccess'))
  } catch (err) {
    console.error('保存配置失败:', err)
    alert(t('common.saveFailed') + ': ' + (err.response?.data?.msg || err.message))
  }
}

const handleRestart = async () => {
  try {
    await restartDevice()
    alert(t('system.restartSuccess'))
    showRestartModal.value = false
  } catch (err) {
    alert(t('system.restartFailed') + ': ' + err.message)
  }
}

const handleContinue = () => {
  showRestartModal.value = false
}

// 组件挂载时加载数据
onMounted(() => {
  loadData()
})
</script>

<style scoped>
.description-box {
  background-color: #0066cc;
  color: white;
  padding: 10px 15px;
  margin-bottom: 20px;
}

.desc-title {
  font-weight: bold;
  font-size: 14px;
  margin-bottom: 5px;
}

.desc-content {
  font-size: 12px;
  background-color: white;
  color: #333;
  padding: 10px;
  border: 1px solid #ddd;
}

/* 表单区域样式 */
.form-section {
  padding: 20px 15px;
  background-color: white;
}

.form-group {
  display: flex;
  align-items: center;
  margin-bottom: 15px;
  gap: 20px;
}

.form-group:last-child {
  margin-bottom: 0;
}

.form-group label {
  font-weight: 600;
  width: 120px;
  text-align: right;
  flex-shrink: 0;
  font-size: 13px;
}

.form-group select {
  flex: 1;
  max-width: 300px;
  padding: 6px 10px;
  border: 1px solid #ddd;
  border-radius: 2px;
  font-size: 13px;
}

.form-group select:focus {
  outline: none;
  border-color: #0066cc;
}

/* 按钮组样式 */
.button-group {
  display: flex;
  justify-content: center;
  padding: 20px;
  gap: 10px;
  background-color: #f9f9f9;
}

.btn-save {
  padding: 8px 30px;
  background-color: #0066cc;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 600;
}

.btn-save:hover {
  background-color: #0052a3;
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

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
}

.modal {
  background-color: white;
  border-radius: 8px;
  width: 400px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  overflow: hidden;
}

.modal-header {
  padding: 15px 20px;
  border-bottom: 1px solid #eee;
  background-color: #f8f9fa;
}

.modal-header h3 {
  margin: 0;
  font-size: 16px;
  color: #333;
}

.modal-body {
  padding: 20px;
  text-align: center;
}

.modal-actions {
  display: flex;
  justify-content: center;
  gap: 15px;
  margin-top: 20px;
}

.btn-restart {
  padding: 8px 20px;
  background-color: #0066cc;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-weight: 600;
}

.btn-continue {
  padding: 8px 20px;
  background-color: white;
  color: #666;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
  font-weight: 600;
}

.btn-restart:hover {
  background-color: #0052a3;
}

.btn-continue:hover {
  background-color: #f5f5f5;
}
</style>
