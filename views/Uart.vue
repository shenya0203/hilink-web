<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading">{{ t('common.loading') }}</div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

    <!-- 串口配置标题 -->
    <form>
      <legend>{{ t('uart.title') }}</legend>
      <div class="config-subtitle">{{ t('uart.description') }}</div>
    </form>

    <!-- 标签页选择 -->
    <div class="tabs">
      <button 
        class="tab-btn" 
        :class="{ active: activeTab === 0 }"
        @click="activeTab = 0"
      >
        {{ t('uart.portName') }}1
      </button>
      <button 
        v-if="uartList.length > 1"
        class="tab-btn" 
        :class="{ active: activeTab === 1 }"
        @click="activeTab = 1"
      >
        {{ t('uart.portName') }}2
      </button>
    </div>

    <!-- 串口配置表单 -->
    <form v-if="uartList[activeTab]">
      <div class="form-section">
        <div class="form-group">
          <label>{{ t('uart.baudRate') }}:</label>
          <select v-model.number="uartList[activeTab].baud_rate">
            <option :value="9600">9600</option>
            <option :value="19200">19200</option>
            <option :value="38400">38400</option>
            <option :value="57600">57600</option>
            <option :value="115200">115200</option>
            <option :value="230400">230400</option>
          </select>
        </div>
        <div class="form-group">
          <label>{{ t('uart.dataBits') }}:</label>
          <select v-model.number="uartList[activeTab].data_bit">
            <option :value="7">7</option>
            <option :value="8">8</option>
          </select>
        </div>
        <div class="form-group">
          <label>{{ t('uart.parity') }}:</label>
          <select v-model.number="uartList[activeTab].parity">
            <option :value="0">{{ t('uart.parityNone') }}</option>
            <option :value="1">{{ t('uart.parityOdd') }}</option>
            <option :value="2">{{ t('uart.parityEven') }}</option>
          </select>
        </div>

        <div class="form-group">
          <label>{{ t('uart.stopBits') }}:</label>
          <select v-model.number="uartList[activeTab].stop_bit">
            <option :value="1">1</option>
            <option :value="2">2</option>
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
        <div class="modal-header">
          <h3>{{ t('common.saveSuccess') }}</h3>
        </div>
        <div class="modal-body">
          <p>{{ t('uart.restartRequired') }}</p>
          <div class="modal-actions">
            <button class="btn-restart" @click="handleRestart">{{ t('system.restartNow') }}</button>
            <button class="btn-continue" @click="handleContinue">{{ t('uart.continueConfig') }}</button>
          </div>
        </div>
      </div>
    </div>

    <!-- 服务重启等待弹窗 -->
    <div v-if="isServiceRestarting" class="modal-overlay">
      <div class="modal">
        <div class="modal-header"><h3>{{ t('system.restart') }}</h3></div>
        <div class="modal-body">
          <div class="loading-spinner"></div>
          <p style="margin-top: 15px;">{{ t('system.serviceRestarting') }}</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getUartConfig, updateConfig, restartDevice } from '../api/services'
import { useI18n } from '../i18n/useI18n.js'
import { useServiceControl } from '../composables/useServiceControl.js'

// 使用 i18n
const { t } = useI18n()
const { isServiceRestarting, restartService } = useServiceControl()

// 响应式数据
const loading = ref(true)
const error = ref(null)
const uartList = ref([])
const activeTab = ref(0)
const showRestartModal = ref(false)

// 加载串口配置
const loadData = async () => {
  try {
    loading.value = true
    error.value = null
    
    const uartConfig = await getUartConfig()
    
    console.log('=== 串口配置页面数据加载 ===')
    console.log('获取到的串口配置:', uartConfig)
    
    if (uartConfig && uartConfig.UART && Array.isArray(uartConfig.UART)) {
      // 只取前两路串口
      uartList.value = uartConfig.UART.slice(0, 2)
      console.log('处理后的串口列表:', uartList.value)
    }
  } catch (err) {
    error.value = t('common.loadError') + ': ' + err.message
    console.error('串口配置加载错误:', err)
  } finally {
    loading.value = false
  }
}

// 保存配置
const saveConfig = async () => {
  try {
    const params = []
    uartList.value.forEach((uart, index) => {
      // Iterate over keys and build params
      // Format: n_UART[0].baud_rate=115200
      for (const key in uart) {
        if (Object.hasOwnProperty.call(uart, key)) {
           params.push(`n_UART[${index}].${key}=${uart[key]}`)
        }
      }
    })
    
    const queryString = params.join('&')
    console.log('Saving config with query:', queryString)
    
    await updateConfig('uart', queryString)
    showRestartModal.value = true
    
  } catch (err) {
    alert(t('common.saveFailed') + ': ' + err.message)
    console.error(err)
  }
}

const handleRestart = async () => {
  showRestartModal.value = false
  await restartService()
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
.config-subtitle {
  padding: 10px 15px;
  font-size: 12px;
  color: #666;
  border-bottom: 1px solid #e8e8e8;
  background-color: white;
}

.tabs {
  display: flex;
  gap: 10px;
  margin: 20px 0;
  border-bottom: 1px solid #e8e8e8;
}

.tab-btn {
  padding: 8px 20px;
  background-color: #494641;
  color: white;
  border: none;
  cursor: pointer;
  border-radius: 4px 4px 0 0;
  font-size: 13px;
  font-weight: 600;
  transition: background-color 0.2s;
}

.tab-btn:hover {
  background-color: #ff8800;
}

.tab-btn.active {
  background-color: #0066cc;
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

.form-group label {
  font-weight: 600;
  width: 150px;
  text-align: right;
  flex-shrink: 0;
}

.form-group input,
.form-group select {
  flex: 1;
  max-width: 300px;
  padding: 8px 12px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 13px;
}

.form-group input:focus,
.form-group select:focus {
  outline: none;
  border-color: #0066cc;
  box-shadow: 0 0 0 2px rgba(0, 102, 204, 0.1);
}

/* 按钮组样式 */
.button-group {
  display: flex;
  justify-content: center;
  padding: 20px;
  gap: 10px;
}

.btn-save {
  padding: 10px 40px;
  background-color: #0066cc;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 600;
  transition: background-color 0.2s;
}

.btn-save:hover {
  background-color: #0052a3;
}

.btn-save:active {
  background-color: #003d7a;
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

/* Modal Styles */
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
  border-color: #ccc;
}
</style>
