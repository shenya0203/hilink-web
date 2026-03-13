<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading">{{ t('common.loading') }}</div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

    <!-- MQTT配置标题 -->
    <div class="description-box">
      <div class="desc-title">{{ t('mqtt.title') }}</div>
    </div>

    <!-- 标签页选择 -->
    <div class="tabs">
      <button 
        v-for="(item, index) in mqttList"
        :key="index"
        class="tab-btn" 
        :class="{ active: activeTab === index, 'has-error': hasTabError(index) }"
        @click="activeTab = index"
      >
        {{ item.name }}
      </button>
    </div>

    <!-- MQTT配置表单 -->
    <form v-if="mqttList[activeTab]">
      <!-- MQTT使能设置 -->
      <div class="form-section">
        <div class="form-group">
          <label>{{ t('mqtt.enable') }}:</label>
          <select v-model.number="mqttList[activeTab].enable">
            <option :value="0">{{ t('common.disable') }}</option>
            <option :value="1">{{ t('common.enable') }}</option>
          </select>
        </div>

        <!-- 仅在MQTT使能为开启时显示配置 -->
        <template v-if="mqttList[activeTab].enable === 1">
          <div class="form-group">
            <label>{{ t('mqtt.protocol') }}:</label>
            <select v-model.number="mqttList[activeTab].mqtt_ver">
              <option :value="3">MQTT-3.1</option>
              <option :value="4">MQTT-3.1.1</option>
            </select>
          </div>

          <div class="form-group">
            <label>{{ t('mqtt.clientId') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model="mqttList[activeTab].client_id" 
                type="text" 
                :class="{ 'input-error': getFieldError(activeTab, 'client_id') }"
              />
              <span v-if="getFieldError(activeTab, 'client_id')" class="field-error-text">
                {{ getFieldError(activeTab, 'client_id') }}
              </span>
            </div>
          </div>

          <div class="form-group">
            <label>{{ t('mqtt.serverAddress') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model="mqttList[activeTab].server_ip" 
                type="text" 
                :class="{ 'input-error': getFieldError(activeTab, 'server_ip') }"
              />
              <span v-if="getFieldError(activeTab, 'server_ip')" class="field-error-text">
                {{ getFieldError(activeTab, 'server_ip') }}
              </span>
            </div>
          </div>

          <div class="form-group">
            <label>{{ t('mqtt.remotePort') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model.number="mqttList[activeTab].server_port" 
                type="number" 
                :class="{ 'input-error': getFieldError(activeTab, 'server_port') }"
              />
              <span v-if="getFieldError(activeTab, 'server_port')" class="field-error-text">
                {{ getFieldError(activeTab, 'server_port') }}
              </span>
            </div>
          </div>

          <div class="form-group">
            <label>{{ t('mqtt.keepalive') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model.number="mqttList[activeTab].keepalive" 
                type="number" 
                :class="{ 'input-error': getFieldError(activeTab, 'keepalive') }"
              />
              <span v-if="getFieldError(activeTab, 'keepalive')" class="field-error-text">
                {{ getFieldError(activeTab, 'keepalive') }}
              </span>
            </div>
          </div>

          <div class="form-group">
            <label>{{ t('mqtt.reconnectInterval') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model.number="mqttList[activeTab].reconn_space" 
                type="number" 
                :class="{ 'input-error': getFieldError(activeTab, 'reconn_space') }"
              />
              <span v-if="getFieldError(activeTab, 'reconn_space')" class="field-error-text">
                {{ getFieldError(activeTab, 'reconn_space') }}
              </span>
            </div>
          </div>

          <div class="form-group">
            <label>{{ t('mqtt.cleanSession') }}:</label>
            <input type="checkbox" v-model="mqttList[activeTab].clean_session" :true-value="1" :false-value="0" />
          </div>

          <div class="form-group">
            <label>{{ t('mqtt.connectionAuth') }}:</label>
            <input type="checkbox" v-model="mqttList[activeTab].conn_verify" :true-value="1" :false-value="0" />
          </div>
          
          <!-- 连接验证开启时显示 -->
          <template v-if="mqttList[activeTab].conn_verify === 1">
            <div class="form-group">
              <label>{{ t('mqtt.username') }}:</label>
              <div class="input-wrapper">
                <input 
                  v-model="mqttList[activeTab].conn_user_name" 
                  type="text" 
                  :class="{ 'input-error': getFieldError(activeTab, 'conn_user_name') }"
                />
                <span v-if="getFieldError(activeTab, 'conn_user_name')" class="field-error-text">
                  {{ getFieldError(activeTab, 'conn_user_name') }}
                </span>
              </div>
            </div>
            <div class="form-group">
              <label>{{ t('mqtt.password') }}:</label>
              <div class="input-wrapper">
                <input 
                  v-model="mqttList[activeTab].conn_user_password" 
                  type="password" 
                  :class="{ 'input-error': getFieldError(activeTab, 'conn_user_password') }"
                />
                <span v-if="getFieldError(activeTab, 'conn_user_password')" class="field-error-text">
                  {{ getFieldError(activeTab, 'conn_user_password') }}
                </span>
              </div>
            </div>
          </template>

          <div class="form-group">
            <label>{{ t('mqtt.will') }}:</label>
            <input type="checkbox" v-model="mqttList[activeTab].will_flag" :true-value="1" :false-value="0" />
          </div>

          <!-- 遗嘱开启时显示 -->
          <template v-if="mqttList[activeTab].will_flag === 1">
            <div class="form-group">
              <label>{{ t('mqtt.willTopic') }}:</label>
              <div class="input-wrapper">
                <input 
                  v-model="mqttList[activeTab].will.topic" 
                  type="text" 
                  :class="{ 'input-error': getFieldError(activeTab, 'will_topic') }"
                />
                <span v-if="getFieldError(activeTab, 'will_topic')" class="field-error-text">
                  {{ getFieldError(activeTab, 'will_topic') }}
                </span>
              </div>
            </div>
            <div class="form-group">
              <label>{{ t('mqtt.willMessage') }}:</label>
              <div class="input-wrapper">
                <input 
                  v-model="mqttList[activeTab].will.msg" 
                  type="text" 
                  :class="{ 'input-error': getFieldError(activeTab, 'will_msg') }"
                />
                <span v-if="getFieldError(activeTab, 'will_msg')" class="field-error-text">
                  {{ getFieldError(activeTab, 'will_msg') }}
                </span>
              </div>
            </div>
            <div class="form-group">
              <label>{{ t('mqtt.willQos') }}:</label>
              <select v-model.number="mqttList[activeTab].will.qos">
                  <option :value="0">0</option>
                  <option :value="1">1</option>
                  <option :value="2">2</option>
              </select>
            </div>
            <div class="form-group">
              <label>{{ t('mqtt.willRetain') }}:</label>
              <select v-model.number="mqttList[activeTab].will.retention">
                  <option :value="0">{{ t('mqtt.noRetain') }}</option>
                  <option :value="1">{{ t('mqtt.retain') }}</option>
              </select>
            </div>
          </template>

          <div class="form-group">
            <label>{{ t('mqtt.offlineCache') }}:</label>
            <select v-model.number="mqttList[activeTab].offline_cache_enable">
              <option :value="0">{{ t('common.disable') }}</option>
              <option :value="1">{{ t('common.enable') }}</option>
            </select>
          </div>

          <div class="form-group">
            <label>{{ t('mqtt.sslEncrypt') }}:</label>
            <select v-model.number="mqttList[activeTab].ssl_mode">
              <option :value="0">{{ t('common.disable') }}</option>
              <option :value="1">{{ t('common.enable') }}</option>
            </select>
          </div>

          <!-- SSL加密开启时才显示认证相关选项 -->
          <template v-if="mqttList[activeTab].ssl_mode === 1">
            <div class="form-group">
              <label>{{ t('mqtt.authMethod') }}:</label>
              <select v-model.number="mqttList[activeTab].ssl_verify">
                <option :value="0">{{ t('mqtt.noAuth') }}</option>
                <option :value="1">{{ t('mqtt.serverAuth') }}</option>
                <option :value="2">{{ t('mqtt.mutualAuth') }}</option>
              </select>
            </div>

            <!-- 服务器证书上传 (ssl_verify >= 1) -->
            <template v-if="mqttList[activeTab].ssl_verify >= 1">
              <div class="form-group">
                <label>{{ t('mqtt.serverCert') }}:</label>
                <input type="file" ref="serverCertInput" @change="handleServerCertSelect" accept=".crt,.pem" style="display:none" />
                <button type="button" class="btn-upload" @click="triggerFileSelect('server')">{{ t('common.selectFile') }}</button>
                <button type="button" class="btn-upload" @click.prevent="uploadServerCert" :disabled="!serverCertFile">{{ t('common.upload') }}...</button>
                <span v-if="serverCertFile" class="file-name">
                  {{ t('common.selectedFile') }}: {{ serverCertFile.name }}
                </span>
                <span v-else-if="mqttList[activeTab].ssl_server_name && mqttList[activeTab].ssl_server_name !== 'null'" class="file-name">
                  {{ t('common.uploadedFile') }}: {{ mqttList[activeTab].ssl_server_name }}
                </span>
              </div>
            </template>

            <!-- 客户端证书和私钥上传 (ssl_verify == 2) -->
            <template v-if="mqttList[activeTab].ssl_verify === 2">
              <div class="form-group">
                <label>{{ t('mqtt.clientCert') }}:</label>
                <input type="file" ref="clientCertInput" @change="handleClientCertSelect" accept=".crt,.pem" style="display:none" />
                <button type="button" class="btn-upload" @click="triggerFileSelect('client_cert')">{{ t('common.selectFile') }}</button>
                <button type="button" class="btn-upload" @click.prevent="uploadClientCert" :disabled="!clientCertFile">{{ t('common.upload') }}...</button>
                <span v-if="clientCertFile" class="file-name">
                  {{ t('common.selectedFile') }}: {{ clientCertFile.name }}
                </span>
                <span v-else-if="mqttList[activeTab].ssl_client_name && mqttList[activeTab].ssl_client_name !== 'null'" class="file-name">
                  {{ t('common.uploadedFile') }}: {{ mqttList[activeTab].ssl_client_name }}
                </span>
              </div>

              <div class="form-group">
                <label>{{ t('mqtt.clientKey') }}:</label>
                <input type="file" ref="clientKeyInput" @change="handleClientKeySelect" accept=".key,.pem" style="display:none" />
                <button type="button" class="btn-upload" @click="triggerFileSelect('client_key')">{{ t('common.selectFile') }}</button>
                <button type="button" class="btn-upload" @click.prevent="uploadClientKey" :disabled="!clientKeyFile">{{ t('common.upload') }}...</button>
                <span v-if="clientKeyFile" class="file-name">
                  {{ t('common.selectedFile') }}: {{ clientKeyFile.name }}
                </span>
                <span v-else-if="mqttList[activeTab].ssl_client_key && mqttList[activeTab].ssl_client_key !== 'null'" class="file-name">
                  {{ t('common.uploadedFile') }}: {{ mqttList[activeTab].ssl_client_key }}
                </span>
              </div>
            </template>
          </template>
        </template>
        
      </div>
    </form>

    <!-- 应用保存按钮 -->
    <div class="button-group">
      <button class="btn-save" @click="saveConfig" :disabled="!isConfigValid" :class="{ 'btn-disabled': !isConfigValid }">{{ t('common.save') }}</button>
    </div>

    <!-- 重启确认弹窗 -->
    <div v-if="showRestartModal" class="modal-overlay">
      <div class="modal">
        <div class="modal-header"><h3>{{ t('common.saveSuccess') }}</h3></div>
        <div class="modal-body">
          <p>{{ t('mqtt.restartRequired') }}</p>
          <div class="modal-actions">
            <button class="btn-restart" @click="handleRestart">{{ t('system.restartNow') }}</button>
            <button class="btn-continue" @click="handleContinue">{{ t('mqtt.continueConfig') }}</button>
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
import { ref, onMounted, computed } from 'vue'
import { getCommTunnel, getOfflineCache, updateConfig, restartDevice } from '../api/services'
import apiClient from '../api/services'
import { useI18n } from '../i18n/useI18n.js'
import { isValidServerAddress, isValidPort, isValidReconnectInterval, isValidClientId } from '../utils/validation.js'
import { useServiceControl } from '../composables/useServiceControl.js'

// 使用 i18n
const { t } = useI18n()
const { isServiceRestarting, restartService } = useServiceControl()

// 响应式数据
const loading = ref(true)
const error = ref(null)
const mqttList = ref([])
const activeTab = ref(0)
const offlineCacheData = ref(null)
const showRestartModal = ref(false)

// DOM 元素引用 (用于触发点击)
const serverCertInput = ref(null)
const clientCertInput = ref(null)
const clientKeyInput = ref(null)

// 选中的文件数据
const serverCertFile = ref(null)
const clientCertFile = ref(null)
const clientKeyFile = ref(null)

// 字节长度计算辅助函数
const getByteLen = (val) => {
  if (!val) return 0
  let len = 0
  for (let i = 0; i < val.length; i++) {
    const a = val.charAt(i);
    if (a.match(/[^\x00-\xff]/ig) != null) len += 3; // 汉字一般占3字节(UTF-8)
    else len += 1;
  }
  return len
}

// 验证逻辑
const mqttErrors = computed(() => {
  const errors = {}
  
  mqttList.value.forEach((mqtt, index) => {
    if (mqtt.enable !== 1) return
    
    // Client ID
    if (!isValidClientId(mqtt.client_id)) {
       errors[`${index}_client_id`] = t('mqtt.invalidClientId')
    }
    
    // Server Address
    if (!isValidServerAddress(mqtt.server_ip)) {
      errors[`${index}_server_ip`] = t('mqtt.invalidServerAddress')
    }
    
    // Server Port
    if (!isValidPort(mqtt.server_port)) {
      errors[`${index}_server_port`] = t('mqtt.invalidPort')
    }
    
    // Keepalive
    const keepalive = Number(mqtt.keepalive);
    if (!Number.isInteger(keepalive) || keepalive < 5 || keepalive > 600) {
        errors[`${index}_keepalive`] = t('mqtt.invalidKeepalive');
    }

    // Reconnect Interval
    if (!isValidReconnectInterval(mqtt.reconn_space)) {
      errors[`${index}_reconn_space`] = t('mqtt.invalidReconnectInterval')
    }

    // Will Topic & Message Validation
    if (mqtt.will_flag === 1) {
      const topicLen = getByteLen(mqtt.will?.topic)
      if (topicLen < 1 || topicLen > 200) {
        errors[`${index}_will_topic`] = t('mqtt.invalidWillTopic') || 'Length limit 1-200 bytes'
      }

      const msgLen = getByteLen(mqtt.will?.msg)
      if (msgLen < 1 || msgLen > 200) {
        errors[`${index}_will_msg`] = t('mqtt.invalidWillMessage') || 'Length limit 1-200 bytes'
      }
    }

    // Username & Password Validation
    if (mqtt.conn_verify === 1) {
      const userLen = getByteLen(mqtt.conn_user_name);
      if (userLen > 200) {
        errors[`${index}_conn_user_name`] = t('mqtt.invalidUsername') || 'Length limit 0-200 bytes';
      }

      const passLen = getByteLen(mqtt.conn_user_password);
      if (passLen > 200) {
        errors[`${index}_conn_user_password`] = t('mqtt.invalidPassword') || 'Length limit 0-200 bytes';
      }
    }
  })
  
  return errors
})

const isConfigValid = computed(() => {
  return Object.keys(mqttErrors.value).length === 0
})

const getFieldError = (index, field) => {
  return mqttErrors.value[`${index}_${field}`]
}

const hasTabError = (index) => {
  return Object.keys(mqttErrors.value).some(key => key.startsWith(`${index}_`))
}

// 触发文件选择点击
const triggerFileSelect = (type) => {
  if (type === 'server' && serverCertInput.value) {
    serverCertInput.value.click()
  } else if (type === 'client_cert' && clientCertInput.value) {
    clientCertInput.value.click()
  } else if (type === 'client_key' && clientKeyInput.value) {
    clientKeyInput.value.click()
  }
}

// 文件选择处理
const handleServerCertSelect = (event) => {
  const files = event.target.files
  if (files && files.length > 0) {
    serverCertFile.value = files[0]
    console.log('选择了服务器证书文件:', files[0].name)
  }
}

const handleClientCertSelect = (event) => {
  const files = event.target.files
  if (files && files.length > 0) {
    clientCertFile.value = files[0]
    console.log('选择了客户端证书文件:', files[0].name)
  }
}

const handleClientKeySelect = (event) => {
  const files = event.target.files
  if (files && files.length > 0) {
    clientKeyFile.value = files[0]
    console.log('选择了客户端私钥文件:', files[0].name)
  }
}

// 上传服务器证书
const uploadServerCert = async () => {
  const file = serverCertFile.value
  
  if (!file) {
    alert(t('common.selectFile'))
    return
  }

  console.log('开始上传服务器证书:', file)
  console.log('文件属性 - 名称:', file.name, '类型:', file.type, '大小:', file.size)

  try {
    // 检查文件对象是否有效（检查属性而不是类型）
    if (!file.name || typeof file.size !== 'number') {
      console.error('文件对象无效:', file)
      throw new Error('无效的文件对象')
    }

    // 检查 FormData 是否可用
    if (typeof FormData === 'undefined') {
      throw new Error('浏览器不支持 FormData API')
    }

    const formData = new FormData()
    
    if (!formData) {
      throw new Error('无法创建 FormData 对象')
    }

    console.log('FormData 对象创建成功:', formData)
    
    const mqttName = mqttList.value[activeTab.value].name
    console.log('MQTT名称:', mqttName)
    
    // 直接添加文件对象
    formData.append('c', file, mqttName)

    console.log('文件已添加到 FormData，准备发送请求')

    // POST 上传证书
    const uploadResponse = await apiClient.post('/upload/scert', formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    })

    console.log('上传响应:', uploadResponse.data)

    // GET 更新配置
    const mqttIndex = activeTab.value
    const filename = file.name
    const configResponse = await apiClient.get('/update_nv.cgi', {
      params: {
        file: 'comm_tunnel',
        [`s_MQTT[${mqttIndex}].ssl_server_name`]: filename
      }
    })

    console.log('配置更新响应:', configResponse.data)

    // 更新本地数据
    mqttList.value[activeTab.value].ssl_server_name = filename
    alert(t('common.uploadSuccess'))
    
    // 清空文件选择
    serverCertFile.value = null
  } catch (err) {
    console.error('上传服务器证书失败，详细错误:', err)
    console.error('错误堆栈:', err.stack)
    alert(t('common.uploadFailed') + ': ' + (err.response?.data?.msg || err.message))
  }
}

// 上传客户端证书
const uploadClientCert = async () => {
  const file = clientCertFile.value
  
  if (!file) {
    alert(t('common.selectFile'))
    return
  }

  console.log('开始上传客户端证书:', file.name)

  try {
    const formData = new FormData()
    const mqttName = mqttList.value[activeTab.value].name
    
    // 检查文件对象是否有效
    if (!file.name || typeof file.size !== 'number') {
      console.error('文件对象无效:', file)
      throw new Error('无效的文件对象')
    }
    
    formData.append('c', file, mqttName)

    await apiClient.post('/upload/ccert', formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    })

    const mqttIndex = activeTab.value
    const filename = file.name
    await apiClient.get('/update_nv.cgi', {
      params: {
        file: 'comm_tunnel',
        [`s_MQTT[${mqttIndex}].ssl_client_name`]: filename
      }
    })

    mqttList.value[activeTab.value].ssl_client_name = filename
    alert(t('common.uploadSuccess'))
    
    clientCertFile.value = null
  } catch (err) {
    console.error('上传客户端证书失败:', err)
    alert(t('common.uploadFailed') + ': ' + (err.response?.data?.msg || err.message))
  }
}

// 上传客户端私钥
const uploadClientKey = async () => {
  const file = clientKeyFile.value
  
  if (!file) {
    alert(t('common.selectFile'))
    return
  }

  console.log('开始上传客户端私钥:', file.name)

  try {
    const formData = new FormData()
    const mqttName = mqttList.value[activeTab.value].name
    
    // 检查文件对象是否有效
    if (!file.name || typeof file.size !== 'number') {
      console.error('文件对象无效:', file)
      throw new Error('无效的文件对象')
    }
    
    formData.append('c', file, mqttName)

    await apiClient.post('/upload/ckey', formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    })

    const mqttIndex = activeTab.value
    const filename = file.name
    await apiClient.get('/update_nv.cgi', {
      params: {
        file: 'comm_tunnel',
        [`s_MQTT[${mqttIndex}].ssl_client_key`]: filename
      }
    })

    mqttList.value[activeTab.value].ssl_client_key = filename
    alert(t('common.uploadSuccess'))
    
    clientKeyFile.value = null
  } catch (err) {
    console.error('上传客户端私钥失败:', err)
    alert(t('common.uploadFailed') + ': ' + (err.response?.data?.msg || err.message))
  }
}

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
    
    console.log('=== MQTT配置页面数据加载 ===')
    console.log('CommTunnel:', commTunnel)
    console.log('OfflineCache:', offlineCache)
    
    if (commTunnel && commTunnel.MQTT && Array.isArray(commTunnel.MQTT)) {
      mqttList.value = commTunnel.MQTT
      offlineCacheData.value = offlineCache
      
      // 合并断网缓存配置
      if (offlineCache && offlineCache.tunnel && Array.isArray(offlineCache.tunnel)) {
        mqttList.value.forEach(mqtt => {
          const cacheConfig = offlineCache.tunnel.find(t => t.name === mqtt.name)
          if (cacheConfig) {
            mqtt.offline_cache_enable = cacheConfig.enable
          } else {
            mqtt.offline_cache_enable = 0
          }
        })
      }
    }
  } catch (err) {
    error.value = t('common.loadError') + ': ' + err.message
    console.error('配置加载错误:', err)
  } finally {
    loading.value = false
  }
}

// 构建 MQTT 参数
const buildMqttParams = (mqtt, i) => {
  const p = []
  // 基本配置
  p.push(`n_MQTT[${i}].enable=${mqtt.enable}`)
  p.push(`s_MQTT[${i}].name=${mqtt.name || ''}`)
  p.push(`n_MQTT[${i}].mqtt_ver=${mqtt.mqtt_ver || 4}`)
  p.push(`s_MQTT[${i}].client_id=${mqtt.client_id || ''}`)
  p.push(`s_MQTT[${i}].server_ip=${mqtt.server_ip || ''}`)
  p.push(`n_MQTT[${i}].server_port=${mqtt.server_port || 1883}`)
  p.push(`n_MQTT[${i}].keepalive=${mqtt.keepalive || 60}`)
  p.push(`n_MQTT[${i}].reconn_space=${mqtt.reconn_space || 5}`)
  p.push(`n_MQTT[${i}].clean_session=${mqtt.clean_session || 0}`)
  
  // 连接验证
  p.push(`n_MQTT[${i}].conn_verify=${mqtt.conn_verify || 0}`)
  p.push(`s_MQTT[${i}].conn_user_name=${mqtt.conn_user_name || ''}`)
  p.push(`s_MQTT[${i}].conn_user_password=${mqtt.conn_user_password || ''}`)
  
  // SSL配置
  p.push(`n_MQTT[${i}].ssl_mode=${mqtt.ssl_mode || 0}`)
  p.push(`n_MQTT[${i}].ssl_verify=${mqtt.ssl_verify || 0}`)
  
  // 遗嘱配置
  p.push(`n_MQTT[${i}].will_flag=${mqtt.will_flag || 0}`)
  if (mqtt.will) {
    p.push(`s_MQTT[${i}].will.topic=${mqtt.will.topic || ''}`)
    p.push(`s_MQTT[${i}].will.msg=${mqtt.will.msg || ''}`)
    p.push(`n_MQTT[${i}].will.qos=${mqtt.will.qos || 0}`)
    p.push(`n_MQTT[${i}].will.retention=${mqtt.will.retention || 0}`)
  }
  
  return p
}

// 保存配置
const saveConfig = async () => {
  try {
    // 构建 MQTT 参数
    const mqttParams = []
    mqttList.value.forEach((mqtt, i) => mqttParams.push(...buildMqttParams(mqtt, i)))
    
    // 构建断网缓存参数
    const cacheParams = []
    if (offlineCacheData.value && offlineCacheData.value.tunnel) {
      mqttList.value.forEach((mqtt, mqttIndex) => {
        // 查找对应的 tunnel 索引
        const tunnelIndex = offlineCacheData.value.tunnel.findIndex(t => t.name === mqtt.name)
        if (tunnelIndex >= 0) {
          cacheParams.push(`n_tunnel[${tunnelIndex}].enable=${mqtt.offline_cache_enable || 0}`)
        }
      })
    }
    
    // 并行调用两个接口保存配置
    const promises = [updateConfig('comm_tunnel', mqttParams.join('&'))]
    if (cacheParams.length > 0) {
      promises.push(updateConfig('offline_cache', cacheParams.join('&')))
    }
    
    await Promise.all(promises)
    showRestartModal.value = true
  } catch (err) {
    alert(t('common.saveFailed') + ': ' + err.message)
  }
}

// 处理重启
const handleRestart = async () => {
  showRestartModal.value = false
  await restartService()
}

// 继续配置
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
  background-color: #0066cc; /* Blue background like Uart */
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

.tab-btn.has-error {
  background-color: #d32f2f;
}

.tab-btn.active.has-error {
  background-color: #c62828;
}

/* 表单区域样式 */
.form-section {
  padding: 20px 15px;
  background-color: white;
}

.form-group {
  display: flex;
  align-items: flex-start;
  margin-bottom: 15px;
  gap: 20px;
}

.form-group:last-child {
  margin-bottom: 0;
}

.form-group label {
  font-weight: 600;
  width: 150px;
  text-align: right;
  flex-shrink: 0;
  font-size: 13px;
  margin-top: 6px;
}

.form-group input[type="text"],
.form-group input[type="number"],
.form-group input[type="password"],
.form-group select {
  width: 100%;
  max-width: 300px;
  padding: 6px 10px;
  border: 1px solid #ddd;
  border-radius: 2px;
  font-size: 13px;
}

.form-group input[type="checkbox"] {
    width: 16px;
    height: 16px;
    margin-top: 6px;
}

.form-group input:focus,
.form-group select:focus {
  outline: none;
  border-color: #0066cc;
}

.input-wrapper {
  flex: 1;
  max-width: 300px;
  display: flex;
  flex-direction: column;
}

.input-error {
  border-color: #d32f2f !important;
  background-color: #ffebee;
}

.field-error-text {
  color: #d32f2f;
  font-size: 12px;
  margin-top: 4px;
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

.btn-disabled {
  background-color: #ccc !important;
  cursor: not-allowed;
}

.btn-upload {
  padding: 6px 16px;
  background-color: #666;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 13px;
  margin-right: 10px;
}

.btn-upload:hover {
  background-color: #555;
}

.btn-upload:disabled {
  background-color: #ccc;
  cursor: not-allowed;
}

.file-name {
  color: #666;
  font-size: 12px;
  margin-left: 10px;
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
