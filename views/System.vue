<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading">加载中...</div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

    <!-- 系统设置标题 -->
    <div class="description-box">
      <div class="desc-title">系统设置</div>
    </div>
    <div class="desc-content">设置系统参数</div>

    <!-- 标签页选择 -->
    <div class="tabs">
      <button 
        class="tab-btn" 
        :class="{ active: activeTab === 0 }"
        @click="activeTab = 0"
      >
        参数设置
      </button>
      <button 
        class="tab-btn" 
        :class="{ active: activeTab === 1 }"
        @click="activeTab = 1"
      >
        系统时间
      </button>
      <button 
        class="tab-btn" 
        :class="{ active: activeTab === 2 }"
        @click="activeTab = 2"
      >
        设备管理
      </button>
      <button 
        class="tab-btn" 
        :class="{ active: activeTab === 3 }"
        @click="activeTab = 3"
      >
        TF卡管理
      </button>
    </div>

    <!-- 参数设置 Tab -->
    <div v-if="activeTab === 0" class="form-section">
      <div class="form-group">
        <label>主机名称:</label>
        <input v-model="miscConfig.host_name" type="text" />
      </div>

      <div class="form-group">
        <label>用户名:</label>
        <input v-model="miscConfig.web_user" type="text" />
      </div>

      <div class="form-group">
        <label>密码:</label>
        <input v-model="miscConfig.web_psw" type="password" />
      </div>

      <div class="form-group">
        <label>网页端口号:</label>
        <input v-model.number="miscConfig.web_port" type="number" />
      </div>

      <div class="form-group">
        <label>参数导出:</label>
        <button type="button" class="btn-action" @click="exportParams">导出</button>
      </div>

      <div class="form-group">
        <label>参数导入:</label>
        <input type="file" ref="importFileInput" @change="handleImportFileSelect" accept=".json" style="display:none" />
        <button type="button" class="btn-action" @click="triggerImportFile">选择文件</button>
        <button type="button" class="btn-action" @click="importParams" :disabled="!importFile">导入</button>
        <span v-if="importFile" class="file-name">已选择文件: {{ importFile.name }}</span>
      </div>

      <!-- 应用保存按钮 -->
      <div class="button-group">
        <button class="btn-save" @click="saveParamsConfig">应用&保存</button>
      </div>
    </div>

    <!-- 系统时间 Tab -->
    <div v-if="activeTab === 1" class="form-section">
      <div class="form-group">
        <label>时区:</label>
        <select v-model.number="miscConfig.ntp_utc">
          <option v-for="tz in timezoneOptions" :key="tz.value" :value="tz.value">{{ tz.label }}</option>
        </select>
      </div>

      <div class="form-group">
        <label>NTP 使能:</label>
        <select v-model.number="miscConfig.ntp_sync_en">
          <option :value="0">关闭</option>
          <option :value="1">开启</option>
        </select>
      </div>

      <template v-if="miscConfig.ntp_sync_en === 1">
        <div class="form-group">
          <label>NTP服务器地址:</label>
          <input v-model="miscConfig.ntp_url[0]" type="text" />
        </div>

        <div class="form-group">
          <label>NTP服务器地址 2:</label>
          <input v-model="miscConfig.ntp_url[1]" type="text" />
        </div>

        <div class="form-group">
          <label>NTP服务器地址 3:</label>
          <input v-model="miscConfig.ntp_url[2]" type="text" />
        </div>

        <div class="form-group">
          <label>NTP服务器地址 4:</label>
          <input v-model="miscConfig.ntp_url[3]" type="text" />
        </div>
      </template>

      <div class="form-group">
        <label>当前时间:</label>
        <span class="time-display">{{ currentTime }}</span>
        <button type="button" class="btn-action" @click="syncBrowserTime">同步</button>
      </div>

      <div class="form-group">
        <label>时间设置:</label>
        <input type="datetime-local" v-model="manualTime" class="datetime-input" />
        <button type="button" class="btn-action" @click="setManualTime">时间设置</button>
      </div>

      <!-- 应用保存按钮 -->
      <div class="button-group">
        <button class="btn-save" @click="saveTimeConfig">应用&保存</button>
      </div>
    </div>

    <!-- 设备管理 Tab -->
    <div v-if="activeTab === 2" class="form-section">
      <div class="form-group">
        <label>固件升级:</label>
        <input type="file" ref="firmwareFileInput" @change="handleFirmwareFileSelect" accept=".bin,.img,.fw" style="display:none" />
        <button type="button" class="btn-action" @click="triggerFirmwareFile">选择文件</button>
        <button type="button" class="btn-action" @click="upgradeFirmware" :disabled="!firmwareFile">刷写固件</button>
        <span v-if="firmwareFile" class="file-name">已选择文件: {{ firmwareFile.name }}</span>
      </div>

      <div class="form-group">
        <label>恢复出厂:</label>
        <button type="button" class="btn-action btn-danger" @click="factoryReset">恢复出厂</button>
      </div>

      <div class="form-group">
        <label>重新启动:</label>
        <button type="button" class="btn-action" @click="restartDevice">立即重启</button>
      </div>

      <div class="form-group">
        <label>定时重启:</label>
        <select v-model.number="miscConfig.timing_reset.enable">
          <option :value="0">关闭</option>
          <option :value="1">开启</option>
        </select>
      </div>

      <template v-if="miscConfig.timing_reset.enable === 1">
        <div class="form-group">
          <label>时间选择:</label>
          <div class="time-picker">
            <input type="number" v-model.number="miscConfig.timing_reset.hh" min="0" max="23" class="time-input" placeholder="时" /> :
            <input type="number" v-model.number="miscConfig.timing_reset.mm" min="0" max="59" class="time-input" placeholder="分" /> :
            <input type="number" v-model.number="miscConfig.timing_reset.ss" min="0" max="59" class="time-input" placeholder="秒" />
          </div>
        </div>
      </template>

      <!-- 应用保存按钮 -->
      <div class="button-group">
        <button class="btn-save" @click="saveDeviceConfig">应用&保存</button>
      </div>
    </div>

    <!-- TF卡管理 Tab -->
    <div v-if="activeTab === 3" class="form-section">
      <div class="form-group">
        <label>已用空间/总空间:</label>
        <span class="info-text">{{ tfInfo.usedSpace }} / {{ tfInfo.totalSpace }}</span>
        <div class="progress-bar">
          <div class="progress-fill" :style="{ width: tfInfo.usagePercent + '%' }"></div>
        </div>
      </div>

      <div class="form-group">
        <label>TF卡 状态:</label>
        <span :class="['status-badge', tfInfo.status === 1 ? 'status-ok' : 'status-error']">
          {{ tfInfo.status === 1 ? '已插入' : '未插入' }}
        </span>
      </div>

      <div class="form-group">
        <label>TF卡格式化:</label>
        <button type="button" class="btn-action btn-danger" @click="formatTfCard" :disabled="tfInfo.status !== 1">格式化</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import apiClient from '../api/services'

// 响应式数据
const loading = ref(true)
const error = ref(null)
const activeTab = ref(0)

// misc 配置数据
const miscConfig = ref({
  web_lang: 2,
  host_name: 'N720',
  websock_port: 6432,
  websocket_point: 9,
  web_port: 80,
  web_user: 'admin',
  web_psw: 'admin',
  cache_buf: 0,
  reset_time: 0,
  telnet_en: 0,
  telnet_port: 22,
  ntp_sync_en: 1,
  ntp_url: ['ntp1.aliyun.com', 'time1.cloud.tencent.com', 'time.ustc.edu.cn', 'cn.pool.ntp.org'],
  ntp_utc: 8,
  f485_en: 0,
  f485_t: 10,
  port_max: 2,
  port_view: 0,
  timing_reset: {
    enable: 0,
    hh: 0,
    mm: 0,
    ss: 0
  }
})

// TF卡信息
const tfInfo = ref({
  status: 0,
  err: 0,
  usedSpace: '0 MB',
  totalSpace: '0 MB',
  usagePercent: 0
})

// 时区选项
const timezoneOptions = computed(() => {
  const options = []
  for (let i = 12; i >= -12; i--) {
    options.push({
      value: i,
      label: `UTC${i >= 0 ? '+' : ''}${i}`
    })
  }
  return options
})

// 当前时间
const currentTime = ref('')
let timeInterval = null

// 手动设置时间
const manualTime = ref('')

// 文件上传相关
const importFileInput = ref(null)
const firmwareFileInput = ref(null)
const importFile = ref(null)
const firmwareFile = ref(null)

// 更新当前时间显示
const updateCurrentTime = () => {
  const now = new Date()
  const offset = miscConfig.value.ntp_utc * 60 // minutes
  const utc = now.getTime() + (now.getTimezoneOffset() * 60000)
  const targetTime = new Date(utc + (offset * 60000))
  
  const year = targetTime.getFullYear()
  const month = String(targetTime.getMonth() + 1).padStart(2, '0')
  const day = String(targetTime.getDate()).padStart(2, '0')
  const hours = String(targetTime.getHours()).padStart(2, '0')
  const minutes = String(targetTime.getMinutes()).padStart(2, '0')
  const seconds = String(targetTime.getSeconds()).padStart(2, '0')
  
  currentTime.value = `${year}/${month}/${day} ${hours}:${minutes}:${seconds}`
}

// 触发文件选择
const triggerImportFile = () => {
  if (importFileInput.value) {
    importFileInput.value.click()
  }
}

const triggerFirmwareFile = () => {
  if (firmwareFileInput.value) {
    firmwareFileInput.value.click()
  }
}

// 文件选择处理
const handleImportFileSelect = (event) => {
  const files = event.target.files
  if (files && files.length > 0) {
    importFile.value = files[0]
    console.log('选择了导入文件:', files[0].name)
  }
}

const handleFirmwareFileSelect = (event) => {
  const files = event.target.files
  if (files && files.length > 0) {
    firmwareFile.value = files[0]
    console.log('选择了固件文件:', files[0].name)
  }
}

// 导出参数
const exportParams = async () => {
  try {
    const response = await apiClient.get('/download_nv.cgi?name=misc')
    const data = response.data
    
    // 创建下载
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `config_${new Date().toISOString().slice(0, 10)}.json`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
    
    alert('参数导出成功')
  } catch (err) {
    console.error('参数导出失败:', err)
    alert('参数导出失败: ' + err.message)
  }
}

// 导入参数
const importParams = async () => {
  if (!importFile.value) {
    alert('请先选择文件')
    return
  }

  try {
    const reader = new FileReader()
    reader.onload = async (e) => {
      try {
        const config = JSON.parse(e.target.result)
        
        // 发送导入请求
        const formData = new FormData()
        formData.append('config', importFile.value)
        
        await apiClient.post('/upload/config', formData, {
          headers: {
            'Content-Type': 'multipart/form-data'
          }
        })
        
        // 更新本地配置
        Object.assign(miscConfig.value, config)
        alert('参数导入成功')
        importFile.value = null
      } catch (parseErr) {
        alert('配置文件格式错误: ' + parseErr.message)
      }
    }
    reader.readAsText(importFile.value)
  } catch (err) {
    console.error('参数导入失败:', err)
    alert('参数导入失败: ' + err.message)
  }
}

// 同步浏览器时间
const syncBrowserTime = async () => {
  try {
    const now = new Date()
    const timestamp = Math.floor(now.getTime() / 1000)
    
    await apiClient.get('/action_time.cgi', {
      params: {
        act: 'sync',
        time: timestamp
      }
    })
    
    alert('时间同步成功')
    updateCurrentTime()
  } catch (err) {
    console.error('时间同步失败:', err)
    alert('时间同步失败: ' + err.message)
  }
}

// 设置手动时间
const setManualTime = async () => {
  if (!manualTime.value) {
    alert('请先选择时间')
    return
  }

  try {
    const selectedTime = new Date(manualTime.value)
    const timestamp = Math.floor(selectedTime.getTime() / 1000)
    
    await apiClient.get('/action_time.cgi', {
      params: {
        act: 'set',
        time: timestamp
      }
    })
    
    alert('时间设置成功')
    updateCurrentTime()
  } catch (err) {
    console.error('时间设置失败:', err)
    alert('时间设置失败: ' + err.message)
  }
}

// 固件升级
const upgradeFirmware = async () => {
  if (!firmwareFile.value) {
    alert('请先选择固件文件')
    return
  }

  if (!confirm('确定要升级固件吗？升级过程中请勿断电或关闭页面。')) {
    return
  }

  try {
    const formData = new FormData()
    formData.append('firmware', firmwareFile.value)
    
    await apiClient.post('/upload/firmware', formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      },
      timeout: 300000 // 5分钟超时
    })
    
    alert('固件上传成功，设备即将重启进行升级...')
    firmwareFile.value = null
  } catch (err) {
    console.error('固件升级失败:', err)
    alert('固件升级失败: ' + err.message)
  }
}

// 恢复出厂设置
const factoryReset = async () => {
  if (!confirm('确定要恢复出厂设置吗？所有配置将被清除！')) {
    return
  }

  try {
    await apiClient.get('/action_reset.cgi', {
      params: { act: 'factory' }
    })
    
    alert('恢复出厂设置成功，设备即将重启...')
  } catch (err) {
    console.error('恢复出厂失败:', err)
    alert('恢复出厂失败: ' + err.message)
  }
}

// 重启设备
const restartDevice = async () => {
  if (!confirm('确定要重启设备吗？')) {
    return
  }

  try {
    await apiClient.get('/action_restart.cgi')
    alert('设备即将重启...')
  } catch (err) {
    console.error('重启设备失败:', err)
    alert('重启设备失败: ' + err.message)
  }
}

// 格式化TF卡
const formatTfCard = async () => {
  if (!confirm('确定要格式化TF卡吗？所有数据将被清除！')) {
    return
  }

  try {
    await apiClient.get('/action_tf.cgi', {
      params: { act: 'format' }
    })
    
    alert('TF卡格式化成功')
    await loadTfInfo()
  } catch (err) {
    console.error('TF卡格式化失败:', err)
    alert('TF卡格式化失败: ' + err.message)
  }
}

// 保存参数配置
const saveParamsConfig = async () => {
  try {
    const params = {
      file: 'misc',
      's_host_name': miscConfig.value.host_name,
      's_web_user': miscConfig.value.web_user,
      's_web_psw': miscConfig.value.web_psw,
      'n_web_port': miscConfig.value.web_port
    }
    
    const queryString = Object.entries(params)
      .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
      .join('&')
    
    await apiClient.get(`/update_nv.cgi?${queryString}`)
    alert('参数配置保存成功')
  } catch (err) {
    console.error('保存参数配置失败:', err)
    alert('保存配置失败: ' + err.message)
  }
}

// 保存时间配置
const saveTimeConfig = async () => {
  try {
    const params = {
      file: 'misc',
      'n_ntp_utc': miscConfig.value.ntp_utc,
      'n_ntp_sync_en': miscConfig.value.ntp_sync_en,
      's_ntp_url[0]': miscConfig.value.ntp_url[0],
      's_ntp_url[1]': miscConfig.value.ntp_url[1],
      's_ntp_url[2]': miscConfig.value.ntp_url[2],
      's_ntp_url[3]': miscConfig.value.ntp_url[3]
    }
    
    const queryString = Object.entries(params)
      .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
      .join('&')
    
    await apiClient.get(`/update_nv.cgi?${queryString}`)
    alert('时间配置保存成功')
  } catch (err) {
    console.error('保存时间配置失败:', err)
    alert('保存配置失败: ' + err.message)
  }
}

// 保存设备配置
const saveDeviceConfig = async () => {
  try {
    const params = {
      file: 'misc',
      'n_timing_reset.enable': miscConfig.value.timing_reset.enable,
      'n_timing_reset.hh': miscConfig.value.timing_reset.hh,
      'n_timing_reset.mm': miscConfig.value.timing_reset.mm,
      'n_timing_reset.ss': miscConfig.value.timing_reset.ss
    }
    
    const queryString = Object.entries(params)
      .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
      .join('&')
    
    await apiClient.get(`/update_nv.cgi?${queryString}`)
    alert('设备配置保存成功')
  } catch (err) {
    console.error('保存设备配置失败:', err)
    alert('保存配置失败: ' + err.message)
  }
}

// 加载TF卡信息
const loadTfInfo = async () => {
  try {
    const response = await apiClient.get('/action_tf.cgi', {
      params: { act: 'getinfo' }
    })
    
    const data = response.data
    tfInfo.value.status = data.status || 0
    tfInfo.value.err = data.err || 0
    
    // 如果有容量信息
    if (data.total && data.used) {
      tfInfo.value.totalSpace = formatBytes(data.total)
      tfInfo.value.usedSpace = formatBytes(data.used)
      tfInfo.value.usagePercent = Math.round((data.used / data.total) * 100)
    }
  } catch (err) {
    console.error('加载TF卡信息失败:', err)
  }
}

// 格式化字节
const formatBytes = (bytes) => {
  if (bytes === 0) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

// 加载misc配置
const loadMiscConfig = async () => {
  try {
    const response = await apiClient.get('/download_nv.cgi?name=misc')
    const data = response.data
    
    // 合并数据
    Object.assign(miscConfig.value, data)
    
    // 确保 ntp_url 是数组
    if (!Array.isArray(miscConfig.value.ntp_url)) {
      miscConfig.value.ntp_url = ['', '', '', '']
    }
    
    // 确保 timing_reset 对象存在
    if (!miscConfig.value.timing_reset) {
      miscConfig.value.timing_reset = { enable: 0, hh: 0, mm: 0, ss: 0 }
    }
    
  } catch (err) {
    console.error('加载misc配置失败:', err)
    throw err
  }
}

// 加载数据
const loadData = async () => {
  try {
    loading.value = true
    error.value = null
    
    await Promise.all([
      loadMiscConfig(),
      loadTfInfo()
    ])
    
    console.log('=== 系统设置页面数据加载完成 ===')
    console.log('MiscConfig:', miscConfig.value)
    console.log('TfInfo:', tfInfo.value)
    
  } catch (err) {
    error.value = '加载配置失败: ' + err.message
    console.error('配置加载错误:', err)
  } finally {
    loading.value = false
  }
}

// 组件挂载时加载数据
onMounted(() => {
  loadData()
  updateCurrentTime()
  timeInterval = setInterval(updateCurrentTime, 1000)
})

// 组件卸载时清理定时器
onUnmounted(() => {
  if (timeInterval) {
    clearInterval(timeInterval)
  }
})
</script>

<style scoped>
.description-box {
  background-color: #ff8800;
  color: white;
  padding: 10px 15px;
  margin-bottom: 0;
}

.desc-title {
  font-weight: bold;
  font-size: 14px;
}

.desc-content {
  font-size: 12px;
  background-color: white;
  color: #333;
  padding: 10px 15px;
  border: 1px solid #ddd;
  margin-bottom: 20px;
}

.tabs {
  display: flex;
  gap: 2px;
  margin-bottom: 0;
  border-bottom: 2px solid #0066cc;
}

.tab-btn {
  padding: 8px 30px;
  background-color: #0066cc;
  color: white;
  border: none;
  cursor: pointer;
  font-size: 13px;
  font-weight: 600;
}

.tab-btn.active {
  background-color: #ff8800;
}

.tab-btn:hover:not(.active) {
  background-color: #0052a3;
}

/* 表单区域样式 */
.form-section {
  padding: 20px 15px;
  background-color: white;
  border: 1px solid #ddd;
  border-top: none;
}

.form-group {
  display: flex;
  align-items: center;
  margin-bottom: 15px;
  gap: 15px;
}

.form-group:last-child {
  margin-bottom: 0;
}

.form-group label {
  font-weight: 600;
  width: 130px;
  text-align: right;
  flex-shrink: 0;
  font-size: 13px;
}

.form-group input[type="text"],
.form-group input[type="number"],
.form-group input[type="password"],
.form-group select {
  flex: 1;
  max-width: 300px;
  padding: 6px 10px;
  border: 1px solid #ddd;
  border-radius: 2px;
  font-size: 13px;
}

.form-group input:focus,
.form-group select:focus {
  outline: none;
  border-color: #0066cc;
}

.datetime-input {
  padding: 6px 10px;
  border: 1px solid #ddd;
  border-radius: 2px;
  font-size: 13px;
}

.time-display {
  font-size: 14px;
  color: #0066cc;
  font-weight: 500;
  min-width: 150px;
}

.time-picker {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 14px;
}

.time-input {
  width: 50px;
  padding: 6px 8px;
  border: 1px solid #ddd;
  border-radius: 2px;
  font-size: 13px;
  text-align: center;
}

.time-input:focus {
  outline: none;
  border-color: #0066cc;
}

/* 按钮样式 */
.btn-action {
  padding: 6px 16px;
  background-color: #666;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 13px;
  margin-right: 8px;
}

.btn-action:hover {
  background-color: #555;
}

.btn-action:disabled {
  background-color: #ccc;
  cursor: not-allowed;
}

.btn-danger {
  background-color: #dc3545;
}

.btn-danger:hover {
  background-color: #c82333;
}

.btn-danger:disabled {
  background-color: #ccc;
}

/* 按钮组样式 */
.button-group {
  display: flex;
  justify-content: center;
  padding: 20px;
  gap: 10px;
  background-color: #f9f9f9;
  margin-top: 20px;
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

.file-name {
  color: #666;
  font-size: 12px;
  margin-left: 5px;
}

.info-text {
  font-size: 14px;
  color: #333;
  min-width: 150px;
}

/* 进度条 */
.progress-bar {
  width: 200px;
  height: 20px;
  background-color: #e0e0e0;
  border-radius: 10px;
  overflow: hidden;
  margin-left: 10px;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #4caf50, #8bc34a);
  transition: width 0.3s ease;
}

/* 状态标签 */
.status-badge {
  padding: 4px 12px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
}

.status-ok {
  background-color: #d4edda;
  color: #155724;
}

.status-error {
  background-color: #f8d7da;
  color: #721c24;
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
</style>
