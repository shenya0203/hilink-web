<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading">{{ t('common.loading') }}</div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

    <!-- 系统设置标题 -->
    <div class="description-box">
      <div class="desc-title">{{ t('system.title') }}</div>
    </div>
    <div class="desc-content">{{ t('system.description') }}</div>

    <!-- 标签页选择 -->
    <div class="tabs">
      <button 
        class="tab-btn" 
        :class="{ active: activeTab === 0 }"
        @click="activeTab = 0"
      >
        {{ t('system.tabParams') }}
      </button>
      <button 
        class="tab-btn" 
        :class="{ active: activeTab === 1 }"
        @click="activeTab = 1"
      >
        {{ t('system.tabTime') }}
      </button>
      <button 
        class="tab-btn" 
        :class="{ active: activeTab === 2 }"
        @click="activeTab = 2"
      >
        {{ t('system.tabDevice') }}
      </button>
      <button 
        v-if="FEATURE_TF_CARD_ENABLED"
        class="tab-btn" 
        :class="{ active: activeTab === 3 }"
        @click="activeTab = 3"
      >
        {{ t('system.tabTfCard') }}
      </button>
    </div>

    <!-- 参数设置 Tab -->
    <div v-if="activeTab === 0" class="form-section">
      <div class="form-group" :class="{ 'has-error': hostNameError }">
        <label>{{ t('system.hostName') }}:</label>
        <div class="input-wrapper">
          <input v-model="miscConfig.host_name" type="text" :class="{ 'input-error': hostNameError }" />
          <span v-if="hostNameError" class="field-error-text">{{ hostNameError }}</span>
        </div>
      </div>

      <div class="form-group" :class="{ 'has-error': userNameError }">
        <label>{{ t('system.username') }}:</label>
        <div class="input-wrapper">
          <input v-model="miscConfig.web_user" type="text" :class="{ 'input-error': userNameError }" />
          <span v-if="userNameError" class="field-error-text">{{ userNameError }}</span>
        </div>
      </div>

      <div class="form-group" :class="{ 'has-error': passwordError }">
        <label>{{ t('system.password') }}:</label>
        <div class="input-wrapper">
          <input v-model="miscConfig.web_psw" type="password" :class="{ 'input-error': passwordError }" />
          <span v-if="passwordError" class="field-error-text">{{ passwordError }}</span>
        </div>
      </div>

      <div class="form-group" :class="{ 'has-error': webPortError }">
        <label>{{ t('system.webPort') }}:</label>
        <div class="input-wrapper">
          <input v-model.number="miscConfig.web_port" type="number" :class="{ 'input-error': webPortError }" />
          <span v-if="webPortError" class="field-error-text">{{ webPortError }}</span>
        </div>
      </div>

      <div class="form-group">
        <label>{{ t('system.exportParams') }}:</label>
        <button type="button" class="btn-action" @click="exportParams">{{ t('common.export') }}</button>
      </div>

      <div class="form-group">
        <label>{{ t('system.importParams') }}:</label>
        <input type="file" ref="importFileInput" @change="handleImportFileSelect" accept=".json" style="display:none" />
        <button type="button" class="btn-action" @click="triggerImportFile">{{ t('common.selectFile') }}</button>
        <button type="button" class="btn-action" @click="importParams" :disabled="!importFile">{{ t('common.import') }}</button>
        <span v-if="importFile" class="file-name">{{ t('common.selectedFile') }}: {{ importFile.name }}</span>
      </div>

      <!-- 应用保存按钮 -->
      <div class="button-group">
        <button class="btn-save" @click="saveParamsConfig" :disabled="!isParamsConfigValid" :class="{ 'btn-disabled': !isParamsConfigValid }">{{ t('common.save') }}</button>
      </div>
    </div>

    <!-- 系统时间 Tab -->
    <div v-if="activeTab === 1" class="form-section">
      <div class="form-group">
        <label>{{ t('system.timezone') }}:</label>
        <select v-model.number="miscConfig.ntp_utc">
          <option v-for="tz in timezoneOptions" :key="tz.value" :value="tz.value">{{ tz.label }}</option>
        </select>
      </div>

      <div class="form-group">
        <label>{{ t('system.ntpEnable') }}:</label>
        <select v-model.number="miscConfig.ntp_sync_en">
          <option :value="0">{{ t('common.disable') }}</option>
          <option :value="1">{{ t('common.enable') }}</option>
        </select>
      </div>

      <template v-if="miscConfig.ntp_sync_en === 1">
        <div class="form-group">
          <label>{{ t('system.ntpServer') }}:</label>
          <input v-model="miscConfig.ntp_url[0]" type="text" />
        </div>

        <div class="form-group">
          <label>{{ t('system.ntpServer2') }}:</label>
          <input v-model="miscConfig.ntp_url[1]" type="text" />
        </div>

        <div class="form-group">
          <label>{{ t('system.ntpServer3') }}:</label>
          <input v-model="miscConfig.ntp_url[2]" type="text" />
        </div>

        <div class="form-group">
          <label>{{ t('system.ntpServer4') }}:</label>
          <input v-model="miscConfig.ntp_url[3]" type="text" />
        </div>
      </template>

      <div class="form-group">
        <label>{{ t('system.currentTime') }}:</label>
        <span class="time-display">{{ currentTime }}</span>
        <button type="button" class="btn-action" @click="syncBrowserTime">{{ t('system.sync') }}</button>
      </div>

      <div class="form-group">
        <label>{{ t('system.timeSettings') }}:</label>
        <input type="datetime-local" v-model="manualTime" class="datetime-input" />
        <button type="button" class="btn-action" @click="setManualTime">{{ t('system.setTime') }}</button>
      </div>

      <!-- 应用保存按钮 -->
      <div class="button-group">
        <button class="btn-save" @click="saveTimeConfig">{{ t('common.save') }}</button>
      </div>
    </div>

    <!-- 设备管理 Tab -->
    <div v-if="activeTab === 2" class="form-section">
      <div class="form-group">
        <label>{{ t('system.firmwareUpgrade') }}:</label>
        <input type="file" ref="firmwareFileInput" @change="handleFirmwareFileSelect" accept=".bin,.img,.fw" style="display:none" />
        <button type="button" class="btn-action" @click="triggerFirmwareFile">{{ t('common.selectFile') }}</button>
        <button type="button" class="btn-action" @click="upgradeFirmware" :disabled="!firmwareFile">{{ t('system.flashFirmware') }}</button>
        <span v-if="firmwareFile" class="file-name">{{ t('common.selectedFile') }}: {{ firmwareFile.name }}</span>
      </div>

      <div class="form-group">
        <label>{{ t('system.factoryReset') }}:</label>
        <button type="button" class="btn-action btn-danger" @click="factoryReset">{{ t('system.factoryReset') }}</button>
      </div>

      <div class="form-group">
        <label>{{ t('system.restart') }}:</label>
        <button type="button" class="btn-action" @click="restartDevice">{{ t('system.restartNow') }}</button>
      </div>

      <div class="form-group">
        <label>{{ t('system.scheduledRestart') }}:</label>
        <select v-model.number="miscConfig.timing_reset.enable">
          <option :value="0">{{ t('common.disable') }}</option>
          <option :value="1">{{ t('common.enable') }}</option>
        </select>
      </div>

      <template v-if="miscConfig.timing_reset.enable === 1">
        <div class="form-group">
          <label>{{ t('system.timeSelect') }}:</label>
          <div class="time-picker">
            <input type="number" v-model.number="miscConfig.timing_reset.hh" min="0" max="23" class="time-input" placeholder="时" /> :
            <input type="number" v-model.number="miscConfig.timing_reset.mm" min="0" max="59" class="time-input" placeholder="分" /> :
            <input type="number" v-model.number="miscConfig.timing_reset.ss" min="0" max="59" class="time-input" placeholder="秒" />
          </div>
        </div>
      </template>

      <!-- 应用保存按钮 -->
      <div class="button-group">
        <button class="btn-save" @click="saveDeviceConfig">{{ t('common.save') }}</button>
      </div>
    </div>

    <!-- TF卡管理 Tab -->
    <div v-if="activeTab === 3 && FEATURE_TF_CARD_ENABLED" class="form-section">
      <div class="form-group">
        <label>{{ t('system.spaceUsed') }}:</label>
        <span class="info-text">{{ tfInfo.usedSpace }} / {{ tfInfo.totalSpace }}</span>
        <div class="progress-bar">
          <div class="progress-fill" :style="{ width: tfInfo.usagePercent + '%' }"></div>
        </div>
      </div>

      <div class="form-group">
        <label>{{ t('system.tfStatus') }}:</label>
        <span :class="['status-badge', tfInfo.status === 1 ? 'status-ok' : 'status-error']">
          {{ tfInfo.status === 1 ? t('system.inserted') : t('system.notInserted') }}
        </span>
      </div>

      <div class="form-group">
        <label>{{ t('system.formatTf') }}:</label>
        <button type="button" class="btn-action btn-danger" @click="formatTfCard" :disabled="tfInfo.status !== 1">{{ t('system.format') }}</button>
      </div>
    </div>
    <!-- 重启确认弹窗 -->
    <div v-if="showRestartModal" class="modal-overlay">
      <div class="modal">
        <div class="modal-header"><h3>{{ t('common.saveSuccess') }}</h3></div>
        <div class="modal-body">
          <p>{{ t('system.restartRequired') }}</p>
          <div class="modal-actions">
            <button class="btn-restart" @click="handleRestart">{{ t('system.restartNow') }}</button>
            <button class="btn-continue" @click="handleContinue">{{ t('system.continueConfig') }}</button>
          </div>
        </div>
      </div>
    </div>

    <!-- 升级确认弹窗 -->
    <div v-if="showUpgradeConfirmModal" class="modal-overlay">
      <div class="modal">
        <div class="modal-header"><h3>192.168.18.254</h3></div>
        <div class="modal-body">
          <p>{{ t('system.confirmUpgrade') }} {{ t('system.dontPowerOff') }}</p>
          <div class="checkbox-group" style="margin: 15px 0;">
            <label>
              <input type="checkbox" v-model="upgradeResetFactory"> {{ t('system.factoryReset') }}
            </label>
          </div>
          <div class="modal-actions">
            <button class="btn-restart" @click="executeUpgrade">{{ t('common.confirm') }}</button>
            <button class="btn-continue" @click="showUpgradeConfirmModal = false">{{ t('common.cancel') }}</button>
          </div>
        </div>
      </div>
    </div>

    <!-- 升级进度弹窗 -->
    <div v-if="isUpgrading" class="modal-overlay">
      <div class="modal">
        <div class="modal-header"><h3>{{ t('system.firmwareUpgrade') }}</h3></div>
        <div class="modal-body">
          <p>{{ upgradeStatus }}</p>
          <div class="progress-bar-container">
            <div class="progress-bar-fill" :style="{ width: upgradeProgress + '%' }"></div>
            <span class="progress-text">{{ upgradeProgress }}%</span>
          </div>
          <p class="warning-text">{{ t('system.upgradeDontPowerOff') }}</p>
        </div>
      </div>
    </div>

    <!-- 上传中弹窗 -->
    <div v-if="isUploading" class="modal-overlay">
      <div class="modal">
        <div class="modal-header"><h3>{{ t('system.firmwareUpgrade') }}</h3></div>
        <div class="modal-body">
          <div class="loading-spinner"></div>
          <p style="margin-top: 15px;">{{ t('system.uploading') }}</p>
          <p class="warning-text">{{ t('system.upgradeDontPowerOff') }}</p>
        </div>
      </div>
    </div>

    <!-- 通用重启/恢复出厂等待弹窗 -->
    <div v-if="isRebooting" class="modal-overlay">
      <div class="modal">
        <div class="modal-header">
          <h3>{{ isFactoryResetMode ? t('system.factoryReset') : t('system.restart') }}</h3>
        </div>
        <div class="modal-body">
          <p>{{ rebootStatus }}</p>
          <div v-if="!showResetGuide" class="progress-bar-container">
            <div class="progress-bar-fill" :style="{ width: rebootProgress + '%' }"></div>
            <span class="progress-text">{{ rebootProgress }}%</span>
          </div>
          <div v-if="showResetGuide" class="modal-actions" style="flex-direction: column; gap: 10px; margin-top: 20px;">
            <button class="btn-restart" style="width: 100%;" @click="goToDefaultIp">{{ t('system.goToDefaultIp') }} ({{ DEFAULT_DEVICE_IP }})</button>
            <button class="btn-continue" style="width: 100%;" @click="refreshCurrentPage">{{ t('system.refreshCurrent') }}</button>
          </div>
          <p v-if="!showResetGuide" class="warning-text">{{ t('system.dontPowerOff') }}</p>
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

    <!-- 恢复出厂确认弹窗 -->
    <div v-if="showFactoryResetConfirmModal" class="modal-overlay">
      <div class="modal">
        <div class="modal-header"><h3>{{ t('system.factoryReset') }}</h3></div>
        <div class="modal-body">
          <p>{{ t('system.confirmFactoryReset') }}</p>
          <div class="modal-actions">
            <button class="btn-restart" @click="executeFactoryReset">{{ t('common.confirm') }}</button>
            <button class="btn-continue" @click="showFactoryResetConfirmModal = false">{{ t('common.cancel') }}</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import apiClient from '../api/services'
import { useI18n } from '../i18n/useI18n.js'
import { useServiceControl } from '../composables/useServiceControl.js'
import { FEATURE_TF_CARD_ENABLED, DEFAULT_DEVICE_IP } from '../config/features.js'
import { isValidStringSafe } from '../utils/validation.js'

// 使用 i18n
const { t } = useI18n()
const { isServiceRestarting, restartService } = useServiceControl()

// 响应式数据
const loading = ref(true)
const error = ref(null)
const activeTab = ref(0)
const showRestartModal = ref(false)
const showUpgradeConfirmModal = ref(false)
const showFactoryResetConfirmModal = ref(false) // 恢复：恢复出厂确认框
const upgradeResetFactory = ref(false)         // 恢复：升级时是否恢复出厂
const isResetting = ref(false)
const isRebooting = ref(false) // 新增：设备重启/恢复出厂状态
const rebootProgress = ref(0)   // 新增：重启进度
const rebootStatus = ref('')     // 新增：当前状态文案
const isFactoryResetMode = ref(false) // 新增：是否是恢复出厂模式
const showResetGuide = ref(false)     // 新增：恢复出厂引导按钮

// Socket 配置数据 (用于冲突检测)
const socketConfig = ref([])

// ... existing code ...

// 处理重启 (改为重启服务)
const handleRestart = async () => {
  showRestartModal.value = false
  await restartService(miscConfig.value.web_port)
}

// misc 配置数据
const miscConfig = ref({
  web_lang: 2,
  host_name: '',
  websock_port: 6432,
  websocket_point: 9,
  web_port: '',
  web_user: '',
  web_psw: '',
  cache_buf: 0,
  reset_time: 0,
  telnet_en: 0,
  telnet_port: 22,
  ntp_sync_en: 1,
  ntp_url: [],
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
  loading.value = true
  try {
    // 1. 定义所有需要获取的配置项名称
    const configNames = [
      'misc', 
      'network', 
      'comm_tunnel', 
      'uart', 
      'offline_cache',
      'edge', 
      'edge_report', 
      'edge_access', 
      'edge_link_ctrl'
    ]

    // 2. 获取所有 JSON 配置
    const configResults = await Promise.all(configNames.map(name => 
      apiClient.get(`/download_nv.cgi?name=${name}`)
        .then(res => ({ type: 'config', name, data: res.data }))
        .catch(err => {
          console.warn(`Failed to fetch config ${name}:`, err)
          return { type: 'config', name, data: null, error: err.message }
        })
    ))

    // 3. 分析 edge_report 获取模板列表
    let templateNames = []
    const edgeReport = configResults.find(item => item.name === 'edge_report')
    if (edgeReport && edgeReport.data && Array.isArray(edgeReport.data.group)) {
      edgeReport.data.group.forEach(g => {
        if (g.tmpl_file) {
           // /template/Report1.json -> Report1
           const match = g.tmpl_file.match(/\/template\/(.+)\.json/)
           if (match && match[1]) {
             templateNames.push(match[1])
           }
        }
      })
    }
    templateNames = [...new Set(templateNames)] // 去重

    // 4. 获取特殊文件 (CSV等) 和 模板
    const filePromises = [
      // 边缘计算点位表
      apiClient.get('/download_file.cgi?name=edge')
        .then(res => ({ type: 'file', name: 'edge_points_csv', data: res.data })),
      // 协议转换映射表
      apiClient.get('/download_file.cgi?name=edge_proto_access')
        .then(res => ({ type: 'file', name: 'edge_proto_access_csv', data: res.data })),
    ]

    // 添加模板下载请求
    if (templateNames.length > 0) {
       const query = templateNames.map(n => `name=${encodeURIComponent(n)}`).join('&')
       filePromises.push(
         apiClient.get(`/download_multi_file.cgi?name=template&${query}`)
           .then(res => ({ type: 'template', name: 'templates', data: res.data }))
       )
    } else {
       filePromises.push(Promise.resolve({ type: 'template', name: 'templates', data: {} }))
    }

    // 4.1 [新增] 获取 Socket/MQTT 的 SSL 证书
    // 解析 comm_tunnel 配置，识别需要导出证书的服务
    const commTunnelRes = configResults.find(item => item.name === 'comm_tunnel')
    if (commTunnelRes && commTunnelRes.data) {
      const ct = commTunnelRes.data
      // console.log('Checking for certificates in comm_tunnel:', ct) // 调试日志
      const certServices = []
      
      // 检查 Socket (仅 TCP Client 模式且开启 SSL 需要证书)
      if (Array.isArray(ct.SOCK)) {
        ct.SOCK.forEach((s, i) => {
          // 使用 == 进行宽松比较，兼容后端返回字符串 "1" 的情况
          if (s.enable == 1 && s.mode == 0 && s.tcpc?.ssl_mode == 1) certServices.push(i === 0 ? 'SOCKA' : 'SOCKB')
        })
      }
      // 检查 MQTT (开启 SSL 需要证书)
      if (Array.isArray(ct.MQTT)) {
        ct.MQTT.forEach((m, i) => {
          // 使用 == 进行宽松比较
          if (m.enable == 1 && m.ssl_mode == 1) certServices.push(i === 0 ? 'MQTT1' : 'MQTT2')
        })
      }

      // 添加证书下载请求 (即使后端接口未就绪，catch 块也会保证导出流程不中断)
      certServices.forEach(srv => {
        filePromises.push(
          apiClient.get(`/download_cert_bundle.cgi?service=${srv}`)
            .then(res => ({ type: 'certificate', name: srv, data: res.data?.data }))
            .catch(err => {
              console.warn(`Certificate export skipped for ${srv}:`, err)
              return { type: 'certificate', name: srv, data: null }
            })
        )
      })
    }

    const fileResults = await Promise.all(filePromises.map(p => p.catch(err => {
      console.warn('Failed to fetch file:', err)
      return { type: 'error', error: err.message }
    })))

    const results = [...configResults, ...fileResults]

    // 5. 组装最终的导出对象
    const fullConfig = {
      meta: {
        version: '1.0',
        exportTime: new Date().toISOString(),
        timestamp: new Date().getTime()
      },
      configs: {},
      files: {},
      templates: {},
      certificates: {}
    }

    results.forEach(item => {
      if (item.data === null || item.type === 'error') return

      if (item.type === 'config') {
        fullConfig.configs[item.name] = item.data
      } else if (item.type === 'file') {
        fullConfig.files[item.name] = item.data
      } else if (item.type === 'template') {
        fullConfig.templates = item.data
      } else if (item.type === 'certificate' && item.data) {
        fullConfig.certificates[item.name] = item.data
      }
    })

    // 将模板内容注入到 edge_report 配置中，以便直观查看
    if (fullConfig.configs.edge_report && Array.isArray(fullConfig.configs.edge_report.group) && fullConfig.templates) {
        fullConfig.configs.edge_report.group.forEach(g => {
            if (g.tmpl_file) {
                 const match = g.tmpl_file.match(/\/template\/(.+)\.json/)
                 if (match && match[1] && fullConfig.templates[match[1]]) {
                     g.tmpl_content = fullConfig.templates[match[1]]
                 }
            }
        })
    }

    // 6. 创建下载
    const blob = new Blob([JSON.stringify(fullConfig, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `hilink_full_config_${new Date().toISOString().slice(0, 10)}.json`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
    
    alert(t('system.exportSuccess'))
  } catch (err) {
    console.error('参数导出失败:', err)
    alert(t('system.exportFailed') + ': ' + err.message)
  } finally {
    loading.value = false
  }
}

// 扁平化配置对象以适配后端 update_nv.cgi 接口
const flattenConfig = (moduleName, data) => {
  const result = {}
  
  // 定义必须作为数字处理的字段后缀 (针对 network 模块等)
  const forceNumberKeys = new Set([
    'ip_mode',
    'dns_mode',
    'sim_switch',
    'auth',
    'keepalive_period',
    'net_select'
  ])

  const process = (obj, prefix = '') => {
    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        const value = obj[key]
        const newKey = prefix ? `${prefix}.${key}` : key
        
        if (value === null || value === undefined) continue

        if (Array.isArray(value)) {
          // 特殊处理数组
          if (moduleName === 'uart') {
            // UART 数组: n_UART[0].baud_rate
            value.forEach((item, index) => {
              process(item, `UART[${index}]`)
            })
          } else if (moduleName === 'offline_cache' && key === 'tunnel') {
            // Offline Cache Tunnel: n_tunnel[0].enable
            value.forEach((item, index) => {
              process(item, `tunnel[${index}]`)
            })
          } else if (moduleName === 'edge_access' && key === 'group') {
             // Edge Access Group: n_group[0].id
             value.forEach((item, index) => {
               process(item, `group[${index}]`)
             })
          } else {
            // 普通数组 (如 dns_ip): s_eth0.dns_ip[0]
            // 同时也支持对象数组 (如 comm_tunnel.SOCK): s_SOCK[0].enable
            value.forEach((item, index) => {
              if (item && typeof item === 'object') {
                console.log("object array", item)
                process(item, `${newKey}[${index}]`)
              } else {
                const typePrefix = typeof item === 'number' ? 'n_' : 's_'
                result[`${typePrefix}${newKey}[${index}]`] = item
              }
            })
          }
        } else if (typeof value === 'object') {
          process(value, newKey)
        } else {
          // 判断是否强制转换为数字
          let finalValue = value
          let isNumber = typeof value === 'number'
          
          if (moduleName === 'network' && forceNumberKeys.has(key)) {
             const num = Number(value)
             if (!isNaN(num)) {
               finalValue = num
               isNumber = true
             }
          }

          // 基本类型，添加类型前缀
          const typePrefix = isNumber ? 'n_' : 's_'
          
          // 特殊处理 edge 模块
          if (moduleName === 'edge' && key === 'all_en') {
             result[`n_all_en`] = finalValue
          } else {
             result[`${typePrefix}${newKey}`] = finalValue
          }
        }
      }
    }
  }

  // 特殊模块预处理
  if (moduleName === 'uart' && data.UART) {
      process({ UART: data.UART }) // 保持原有结构处理
  } else {
      process(data)
  }
  
  // 补充 module 参数
  result['file'] = moduleName
  return result
}

// Base64 转 Blob 辅助函数 (用于恢复证书)
const base64ToBlob = (base64) => {
  try {
    // 移除可能存在的空白字符
    const raw = window.atob(base64.replace(/\s/g, ''))
    const rawLength = raw.length
    const uInt8Array = new Uint8Array(rawLength)
    for (let i = 0; i < rawLength; ++i) {
      uInt8Array[i] = raw.charCodeAt(i)
    }
    return new Blob([uInt8Array], { type: 'application/octet-stream' })
  } catch (e) {
    console.error('Certificate decode failed:', e)
    return null
  }
}

// 导入参数
const importParams = async () => {
  if (!importFile.value) {
    alert(t('common.selectFile'))
    return
  }

  loading.value = true
  try {
    const reader = new FileReader()
    reader.onload = async (e) => {
      try {
        const fullConfig = JSON.parse(e.target.result)
        
        // 验证文件格式
        if (!fullConfig.configs && !fullConfig.files) {
           throw new Error('Invalid configuration file format')
        }

        // 1. 恢复普通配置 (通过 update_nv.cgi)
        const configModules = ['misc', 'network', 'comm_tunnel', 'uart', 'offline_cache', 'edge', 'edge_access', 'edge_link_ctrl']
        
        for (const name of configModules) {
          if (fullConfig.configs && fullConfig.configs[name]) {
            console.log(`Restoring config: ${name}`)
            const flatParams = flattenConfig(name, fullConfig.configs[name])
            
            // 构建查询字符串
            const queryString = Object.entries(flatParams)
              .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
              .join('&')
            
            await apiClient.get(`/update_nv.cgi?${queryString}`)
          }
        }

        // 2. 恢复 Edge Report (通过上传文件)
        if (fullConfig.configs && fullConfig.configs.edge_report) {
           console.log('Restoring Edge Report...')
           // 构造符合后端预期的 JSON 结构 (包含 group 字段)
           const reportData = fullConfig.configs.edge_report
           // 后端 entry.lua 中 handle_upload -> /upload/nv1 处理 edge_report
           // 需要包含 "group" 关键字来触发逻辑
           const blob = new Blob([JSON.stringify(reportData)], { type: 'application/json' })
           const formData = new FormData()
           formData.append('file', blob, 'edge_report.json') // Filename doesn't matter much here, content does
           
           // 注意：后端逻辑是通过检查内容包含 "group" 来判断是 edge_report
           await apiClient.post('/upload/nv1', formData)
        }

        // 3. 恢复 CSV 文件
        if (fullConfig.files) {
          // Edge Points
          if (fullConfig.files.edge_points_csv) {
            console.log('Restoring Edge Points CSV...')
            const blob = new Blob([fullConfig.files.edge_points_csv], { type: 'text/plain' })
            const formData = new FormData()
            formData.append('file', blob, 'points.csv')
            await apiClient.post('/upload/edge', formData)
          }
          
          // Protocol Access
          if (fullConfig.files.edge_proto_access_csv) {
            console.log('Restoring Protocol Access CSV...')
            const blob = new Blob([fullConfig.files.edge_proto_access_csv], { type: 'text/plain' })
            const formData = new FormData()
            formData.append('file', blob, 'proto.csv')
            await apiClient.post('/upload/conver_csv', formData)
          }
        }

        // 4. 恢复模板
        let templatesToRestore = fullConfig.templates || {}
        
        // 从 edge_report 中提取内嵌的模板内容 (如果有)
        if (fullConfig.configs && fullConfig.configs.edge_report && Array.isArray(fullConfig.configs.edge_report.group)) {
             fullConfig.configs.edge_report.group.forEach(g => {
                 if (g.tmpl_file && g.tmpl_content) {
                     const match = g.tmpl_file.match(/\/template\/(.+)\.json/)
                     if (match && match[1]) {
                         // 优先使用内嵌的内容，因为用户可能直接修改了这里
                         templatesToRestore[match[1]] = g.tmpl_content
                     }
                 }
             })
        }

        if (Object.keys(templatesToRestore).length > 0) {
          console.log('Restoring Templates...')
          // 转换为 Key:Value 格式
          let templateContent = ''
          for (const [key, value] of Object.entries(templatesToRestore)) {
            const jsonStr = typeof value === 'string' ? value : JSON.stringify(value)
            templateContent += `${key}:${jsonStr}\n`
          }
          
          if (templateContent) {
            const blob = new Blob([templateContent], { type: 'text/plain' })
            const formData = new FormData()
            formData.append('file', blob, 'templates.txt')
            await apiClient.post('/upload/template', formData)
          }
        }

        // 5. [新增] 恢复 SSL 证书
        if (fullConfig.certificates) {
          console.log('Restoring SSL Certificates...')
          // 服务名到上传文件名的映射表 (参考 entry.lua 的 dir_map)
          const certServiceMap = {
            'SOCKA': 'SOCK0',
            'SOCKB': 'SOCK1',
            'MQTT1': 'MQTT1',
            'MQTT2': 'MQTT2'
          }

          const certPromises = []

          for (const [serviceName, certData] of Object.entries(fullConfig.certificates)) {
            const targetName = certServiceMap[serviceName]
            if (!targetName || !certData) continue

            // 定义通用的单文件上传函数
            const pushUpload = (url, content) => {
              if (!content) return
              const blob = base64ToBlob(content)
              if (!blob) return

              const fd = new FormData()
              // key必须为 'c', filename 用于后端路由 (如 SOCK0)
              fd.append('c', blob, targetName) 
              certPromises.push(apiClient.post(url, fd))
            }

            // 分别上传三种证书文件
            pushUpload('/upload/scert', certData.server_cert) // 服务器公钥
            pushUpload('/upload/ccert', certData.client_cert) // 客户端公钥
            pushUpload('/upload/ckey',  certData.client_key)  // 客户端私钥
          }

          if (certPromises.length > 0) {
            // 使用 Promise.allSettled 或 catch 确保个别证书失败不阻断整体流程
            await Promise.all(certPromises.map(p => p.catch(e => console.warn('Cert restore warning:', e))))
          }
        }
        
        alert(t('system.importSuccess'))
        importFile.value = null
        showRestartModal.value = true // 提示重启

      } catch (parseErr) {
        console.error(parseErr)
        alert(t('system.configFormatError') + ': ' + parseErr.message)
      } finally {
        loading.value = false
      }
    }
    reader.readAsText(importFile.value)
  } catch (err) {
    loading.value = false
    console.error('参数导入失败:', err)
    alert(t('system.importFailed') + ': ' + err.message)
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
    
    alert(t('system.syncSuccess'))
    updateCurrentTime()
  } catch (err) {
    console.error('时间同步失败:', err)
    alert(t('system.syncFailed') + ': ' + err.message)
  }
}

// 设置手动时间
const setManualTime = async () => {
  if (!manualTime.value) {
    alert(t('common.selectFile'))
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
    
    alert(t('system.timeSetSuccess'))
    updateCurrentTime()
  } catch (err) {
    console.error('时间设置失败:', err)
    alert(t('system.timeSetFailed') + ': ' + err.message)
  }
}

// 升级状态
const isUpgrading = ref(false)
const isUploading = ref(false)
const upgradeProgress = ref(0)
const upgradeStatus = ref('')

// 固件升级
// 固件升级
const upgradeFirmware = () => {
  if (!firmwareFile.value) {
    alert(t('common.selectFile'))
    return
  }
  showUpgradeConfirmModal.value = true
  upgradeResetFactory.value = false
}

const executeUpgrade = async () => {
  showUpgradeConfirmModal.value = false
  
  try {
    isUploading.value = true
    // 1. 上传固件
    const formData = new FormData()
    formData.append('firmware', firmwareFile.value)
    
    await apiClient.post('/upload/firmware', formData, {
      timeout: 300000 // 5分钟超时
    })
    
    // 2. 触发升级
    await apiClient.get('/action_upgrade.cgi', {
      params: {
        reset_factory: upgradeResetFactory.value ? 1 : 0
      }
    })
    
    // 3. 进入升级流程
    isUploading.value = false
    isUpgrading.value = true
    upgradeProgress.value = 0
    upgradeStatus.value = t('system.upgrading') // "正在升级中..."
    
    startUpgradeProcess()
    
  } catch (err) {
    isUploading.value = false
    console.error('固件升级失败:', err)
    alert(t('system.upgradeFailed') + ': ' + err.message)
  }
}

// 升级流程控制
let upgradeTimer = null
const startUpgradeProcess = () => {
  const totalTime = 220 // 220秒超时
  const intervalTime = 1000 // 设置为1秒，因为后台标签页的定时器会被降频
  const startTime = Date.now() // 记录升级开始的真实时间戳
  upgradeCompleteTriggered = false // 重置完成标志位
  
  if (upgradeTimer) clearInterval(upgradeTimer)

  upgradeTimer = setInterval(() => {
    const elapsedTime = Date.now() - startTime;
    let progress = Math.floor((elapsedTime / (totalTime * 1000)) * 100);
    
    // 限制进度条最大值，最后由ping成功来完成
    if (progress > 99) progress = 99
    
    upgradeProgress.value = progress
    
    // 进度超过50%开始探测设备是否在线
    if (progress >= 50) {
      checkDeviceOnline()
    }
    
    // 超时处理 (基于真实流逝时间)
    if (elapsedTime >= totalTime * 1000) {
      clearInterval(upgradeTimer)
      upgradeTimer = n      // 再次确认设备是否真的离线，避免误报
      if (!upgradeCompleteTriggered) {
        isUpgrading.value = false
        alert(t('system.upgradeTimeout'))
        window.location.href = '/?t=' + Date.now()
      }
    }
  }, intervalTime)
}

// 检测设备是否在线
let isChecking = false
let upgradeCompleteTriggered = false // 新增：全局标志位，确保成功逻辑只跑一次

const checkDeviceOnline = async () => {
  // 如果正在检查，或者已经触发过完成逻辑，直接返回
  if (isChecking || upgradeCompleteTriggered) return
  isChecking = true
  
  try {
    // 尝试请求一个静态资源或API，设置较短超时
    await fetch('/favicon.ico?t=' + Date.now(), { 
      method: 'HEAD',
      cache: 'no-store',
      mode: 'no-cors',
      signal: AbortSignal.timeout(2000)
    })
    
    // 如果成功返回，说明设备已重启完成
    upgradeCompleteTriggered = true // 锁定，防止重复进入成功逻辑

    // 1. 彻底停止计时器
    if (upgradeTimer) {
      clearInterval(upgradeTimer)
      upgradeTimer = null
    }

    // 2. 更新 UI 状态
    upgradeProgress.value = 100
    // 直接修改状态文本，让用户在弹窗里看到变化，不需要 alert 阻塞
    upgradeStatus.value = t('system.upgradeComplete') 
    
    // 3. 静默跳转
    // 延迟 2 秒以确保：
    // a. 用户看到了 100% 进度和“完成”文本
    // b. 给浏览器留出响应时间，避免在跳转时执行未清理的闭包
    setTimeout(() => {
      // 在 URL 中注入随机数和时间戳，强制 Nginx 和浏览器放弃缓存
      const buster = Math.random().toString(36).substring(7);
      window.location.replace(`/?t=${Date.now()}&v=${buster}#/system`);
    }, 2000)
    
  } catch (e) {
    // 只有失败才重置 isChecking，允许下一轮周期探测
    isChecking = false
  }
}

// 重启/恢复出厂通用处理流程
let rebootTimer = null
const startRebootProcess = (totalTime, statusText, isFactory = false) => {
  isRebooting.value = true
  rebootStatus.value = statusText
  rebootProgress.value = 0
  isFactoryResetMode.value = isFactory
  
  const intervalTime = 1000
  const startTime = Date.now()
  let onlineCheckTriggered = false
  showResetGuide.value = false // 重置引导显示状态

  if (rebootTimer) clearInterval(rebootTimer)

  rebootTimer = setInterval(async () => {
    const elapsedTime = Date.now() - startTime
    let progress = Math.floor((elapsedTime / (totalTime * 1000)) * 100)
    
    // 限制进度条显示数值，留出探测余地
    if (progress > 95) progress = 95
    rebootProgress.value = progress

    // 进度超过 40% (约40秒) 开始探测设备是否在线
    if (progress >= 40 && !onlineCheckTriggered) {
      const isOnline = await checkDeviceOnlineSilently()
      if (isOnline) {
        onlineCheckTriggered = true
        clearInterval(rebootTimer)
        finishReboot()
      }
    }

    // 真正的硬超时处理
    if (elapsedTime >= (totalTime + 30) * 1000) { // 额外给30秒缓冲
      clearInterval(rebootTimer)
      if (!onlineCheckTriggered) {
        if (isFactoryResetMode.value) {
            // 策略 B: 恢复出厂超时，显示手动引导
            rebootProgress.value = 100
            rebootStatus.value = t('system.resetCompleteCheckIp')
            showResetGuide.value = true
        } else {
            rebootStatus.value = t('system.upgradeTimeout')
            setTimeout(() => {
              window.location.replace(`/?t=${Date.now()}`)
            }, 2000)
        }
      }
    }
  }, intervalTime)
}

// 跳转到默认 IP
const goToDefaultIp = () => {
  const protocol = window.location.protocol
  const port = window.location.port ? `:${window.location.port}` : ''
  // 注意：如果恢复出厂后端口也恢复了 80，这里可能需要处理
  window.location.href = `${protocol}//${DEFAULT_DEVICE_IP}${port}/`
}

// 手动刷新当前页
const refreshCurrentPage = () => {
  window.location.reload()
}

// 静默探测设备在线状态
const checkDeviceOnlineSilently = async () => {
  try {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 2000)
    
    // 尝试请求静态资源
    await fetch('/favicon.ico?t=' + Date.now(), { 
      method: 'HEAD',
      cache: 'no-store',
      mode: 'no-cors',
      signal: controller.signal
    })
    
    clearTimeout(timeoutId)
    return true
  } catch (e) {
    return false
  }
}

// 完成重启流程，执行清理并跳转
const finishReboot = async () => {
  rebootProgress.value = 100
  rebootStatus.value = t('system.upgradeComplete') // "重启成功，正在刷新..."

  if (isFactoryResetMode.value) {
    // 1. 清理应用相关的各类本地存储参数
    localStorage.removeItem('status_panel_collapse')
    // 如果有其他 auth 相关的 token 也应在此清除
    // localStorage.removeItem('auth_token') 
    
    // 2. 尝试清除浏览器的 Basic Auth 凭证 (Trick: 通过 XMLHttpRequest 发送一个错误的凭证)
    try {
      const xhr = new XMLHttpRequest();
      xhr.open('GET', '/favicon.ico?logout=' + Date.now(), true, 'logout', 'logout');
      xhr.send();
    } catch (e) {
      console.warn('Attempt to clear basic auth failed', e);
    }
  }

  // 延迟后刷新，确保用户看到成功状态
  setTimeout(() => {
    const buster = Math.random().toString(36).substring(7);
    // 恢复出厂或重启后，跳转回根目录（强制展示登录页）
    window.location.replace(`/?t=${Date.now()}&v=${buster}#/`);
  }, 2000)
}

// 恢复出厂设置
const factoryReset = () => {
  showFactoryResetConfirmModal.value = true
}

const executeFactoryReset = async () => {
  showFactoryResetConfirmModal.value = false
  try {
    // 发送 API 前先锁定状态，防止重复点击
    await apiClient.get('/action_reset.cgi', {
      params: { act: 'factory' }
    })
    
    // 开始 90s 的等待流程
    startRebootProcess(90, t('system.resetting'), true)
    
  } catch (err) {
    console.error('恢复出厂失败:', err)
    alert(t('system.factoryResetFailed') + ': ' + err.message)
  }
}

// 重启设备
const restartDevice = async () => {
  if (!confirm(t('system.confirmRestart'))) {
    return
  }

  try {
    await apiClient.get('/action_restart.cgi')
    // 开始 90s 的等待流程
    startRebootProcess(90, t('system.restarting'), false)
  } catch (err) {
    console.error('重启设备失败:', err)
    alert(t('system.restartFailed') + ': ' + err.message)
  }
}



// 格式化TF卡
const formatTfCard = async () => {
  if (!confirm(t('system.confirmFormat'))) {
    return
  }

  try {
    await apiClient.get('/action_tf.cgi', {
      params: { act: 'format' }
    })
    
    alert(t('system.formatSuccess'))
    await loadTfInfo()
  } catch (err) {
    console.error('TF卡格式化失败:', err)
    alert(t('system.formatFailed') + ': ' + err.message)
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
    showRestartModal.value = true
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
      'n_web_port': miscConfig.value.web_port,
      'n_ntp_utc': miscConfig.value.ntp_utc,
      'n_ntp_sync_en': miscConfig.value.ntp_sync_en,
      'n_timing_reset.enable': miscConfig.value.timing_reset.enable,
      's_ntp_url[0]': miscConfig.value.ntp_url[0],
      's_ntp_url[1]': miscConfig.value.ntp_url[1],
      's_ntp_url[2]': miscConfig.value.ntp_url[2],
      's_ntp_url[3]': miscConfig.value.ntp_url[3]
    }
    
    const queryString = Object.entries(params)
      .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
      .join('&')
    
    await apiClient.get(`/update_nv.cgi?${queryString}`)
    showRestartModal.value = true
  } catch (err) {
    console.error('保存时间配置失败:', err)
    alert('保存配置失败: ' + err.message)
  }
}

// 保存设备配置
const saveDeviceConfig = async () => {
  try {
    // 最终校验一遍数据
    const tr = miscConfig.value.timing_reset;
    const hh = Math.min(23, Math.max(0, Number(tr.hh) || 0));
    const mm = Math.min(59, Math.max(0, Number(tr.mm) || 0));
    const ss = Math.min(59, Math.max(0, Number(tr.ss) || 0));

    const params = {
      file: 'misc',
      'n_timing_reset.enable': tr.enable,
      'n_timing_reset.hh': hh,
      'n_timing_reset.mm': mm,
      'n_timing_reset.ss': ss
    }
    
    const queryString = Object.entries(params)
      .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
      .join('&')
    
    await apiClient.get(`/update_nv.cgi?${queryString}`)
    showRestartModal.value = true
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
    
    // 强制转换为 Number 类型，解决 enable === 1 判断失效和输入框回显问题
    if (miscConfig.value.timing_reset) {
      miscConfig.value.timing_reset.enable = Number(miscConfig.value.timing_reset.enable) || 0
      miscConfig.value.timing_reset.hh = Number(miscConfig.value.timing_reset.hh) || 0
      miscConfig.value.timing_reset.mm = Number(miscConfig.value.timing_reset.mm) || 0
      miscConfig.value.timing_reset.ss = Number(miscConfig.value.timing_reset.ss) || 0
    } else {
      miscConfig.value.timing_reset = { enable: 0, hh: 0, mm: 0, ss: 0 }
    }
    
    // 确保 ntp_url 是数组
    if (!Array.isArray(miscConfig.value.ntp_url)) {
      miscConfig.value.ntp_url = ['', '', '', '']
    }
    
  } catch (err) {
    console.error('加载misc配置失败:', err)
    throw err
  }
}

// 自动修正数值校验 (Clamping)
watch(() => miscConfig.value.timing_reset.hh, (val) => {
  if (val === undefined || val === null || val === '') return
  if (val > 23) miscConfig.value.timing_reset.hh = 23
  if (val < 0) miscConfig.value.timing_reset.hh = 0
})
watch(() => miscConfig.value.timing_reset.mm, (val) => {
  if (val === undefined || val === null || val === '') return
  if (val > 59) miscConfig.value.timing_reset.mm = 59
  if (val < 0) miscConfig.value.timing_reset.mm = 0
})
watch(() => miscConfig.value.timing_reset.ss, (val) => {
  if (val === undefined || val === null || val === '') return
  if (val > 59) miscConfig.value.timing_reset.ss = 59
  if (val < 0) miscConfig.value.timing_reset.ss = 0
})

// 加载 Socket 配置用于冲突检测
const loadSocketConfig = async () => {
  try {
    const response = await apiClient.get('/download_nv.cgi?name=comm_tunnel')
    if (response.data && Array.isArray(response.data.SOCK)) {
      socketConfig.value = response.data.SOCK
    }
  } catch (err) {
    console.error('加载Socket配置失败:', err)
  }
}

// 参数校验逻辑
const hostNameError = computed(() => {
  const val = miscConfig.value.host_name
  if (!val) return ''
  // 主机名验证规则：1-32字符，字母/数字/横杠，不能以横杠开头或结尾
  const reg = /^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$|^[a-zA-Z0-9]$/
  if (!reg.test(val) || val.length > 32) {
    return t('system.invalidHostName')
  }
  return ''
})

const userNameError = computed(() => {
  const val = miscConfig.value.web_user
  if (!val) return ''
  if (!isValidStringSafe(val, 4, 16)) {
    return t('system.invalidUsername')
  }
  return ''
})

const passwordError = computed(() => {
  const val = miscConfig.value.web_psw
  if (!val) return ''
  if (!isValidStringSafe(val, 5, 16)) {
    return t('system.invalidPassword')
  }
  return ''
})

const webPortError = computed(() => {
  const port = miscConfig.value.web_port
  if (port === '' || port === undefined || port === null) return ''
  const p = Number(port)
  
  // 范围校验
  if (!Number.isInteger(p) || p < 1 || p > 65535) {
    return t('system.invalidPortRange')
  }
  
  // 冲突排查：Telnet 和 WebSocket
  if (p === Number(miscConfig.value.telnet_port)) {
    return t('system.portConflictWith', { service: 'Telnet' })
  }
  if (p === Number(miscConfig.value.websock_port)) {
    return t('system.portConflictWith', { service: 'WebSocket' })
  }
  
  // 冲突排查：TCP Server
  for (let i = 0; i < socketConfig.value.length; i++) {
    const s = socketConfig.value[i]
    // mode 1 为 TCP Server (参考 Socket.vue)
    if (s.enable === 1 && s.mode === 1) {
      if (p === Number(s.tcps.local_port)) {
        const serviceName = i === 0 ? 'TCP Server (SOCKA)' : 'TCP Server (SOCKB)'
        return t('system.portConflictWith', { service: serviceName })
      }
    }
  }
  
  return ''
})

const isParamsConfigValid = computed(() => {
  return !hostNameError.value && !userNameError.value && !passwordError.value && !webPortError.value && 
         miscConfig.value.host_name && miscConfig.value.web_user && 
         miscConfig.value.web_psw && miscConfig.value.web_port
})

// 加载数据
const loadData = async () => {
  try {
    loading.value = true
    error.value = null
    
    // 同时加载常规配置和用于检测冲突的 Socket 配置
    const promises = [loadMiscConfig(), loadSocketConfig()]
    // 只有在开启TF卡功能时才加载TF卡信息
    if (FEATURE_TF_CARD_ENABLED) {
      promises.push(loadTfInfo())
    }
    await Promise.all(promises)
    
    console.log('=== 系统设置页面数据加载完成 ===')
    console.log('MiscConfig:', miscConfig.value)
    console.log('SocketConfig:', socketConfig.value)
    
  } catch (err) {
    error.value = t('common.loadError') + ': ' + err.message
    console.error('配置加载错误:', err)
  } finally {
    loading.value = false
  }
}



// 继续配置
const handleContinue = () => {
  showRestartModal.value = false
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
  if (upgradeTimer) {
    clearInterval(upgradeTimer)
    upgradeTimer = null
  }
  if (rebootTimer) {
    clearInterval(rebootTimer)
    rebootTimer = null
  }
})
</script>

<style scoped>
.description-box {
  background-color: #0066cc; /* Blue background like Uart */
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
  gap: 10px;
  margin: 20px 0;
  border-bottom: 1px solid #e8e8e8;
}

.tab-btn {
  padding: 8px 20px;
  background-color: #494641; /* Dark gray for inactive */
  color: white;
  border: none;
  cursor: pointer;
  border-radius: 4px 4px 0 0;
  font-size: 13px;
  font-weight: 600;
  transition: background-color 0.2s;
}

.tab-btn:hover {
  background-color: #ff8800; /* Orange on hover */
}

.tab-btn.active {
  background-color: #0066cc; /* Blue when active */
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

.progress-bar-container {
  width: 100%;
  height: 20px;
  background-color: #f0f0f0;
  border-radius: 10px;
  margin: 15px 0;
  overflow: hidden;
  position: relative;
}

.progress-bar-fill {
  height: 100%;
  background-color: #0066cc;
  transition: width 0.3s ease;
}

.progress-text {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  color: #333;
  font-size: 12px;
  font-weight: bold;
  pointer-events: none;
  z-index: 2;
  text-shadow: 0 0 2px rgba(255, 255, 255, 0.8);
}

.warning-text {
  color: #ff4d4f;
  font-size: 12px;
  margin-top: 10px;
  text-align: center;
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

/* 错误状态样式 */
.input-wrapper {
  flex: 1;
  max-width: 300px;
  display: flex;
  flex-direction: column;
}

.input-error {
  border-color: #ff4d4f !important;
  background-color: #fff2f0;
}

.field-error-text {
  color: #ff4d4f;
  font-size: 11px;
  margin-top: 4px;
  text-align: left;
}

.btn-disabled {
  background-color: #ccc !important;
  cursor: not-allowed;
  opacity: 0.6;
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

/* 模态框样式 */
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
  background-color: #f0f0f0;
  color: #333;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
}

.btn-continue:hover {
  background-color: #e0e0e0;
}

.time-picker {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 14px;
}

.time-input {
  width: 70px;
  flex: none;
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

.loading-spinner {
  border: 4px solid #f3f3f3;
  border-top: 4px solid #0066cc;
  border-radius: 50%;
  width: 40px;
  height: 40px;
  animation: spin 1s linear infinite;
  margin: 0 auto;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
</style>
