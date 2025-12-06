<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading">{{ t('common.loading') }}</div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

    <!-- Socket配置标题 -->
    <form>
      <legend>{{ t('socket.title') }}</legend>
      <div class="config-subtitle">{{ t('socket.description') }}</div>
    </form>

    <!-- 标签页选择 -->
    <div class="tabs">
      <button class="tab-btn" :class="{ active: activeTab === 0 }" @click="activeTab = 0">SocketA</button>
      <button v-if="socketList.length > 1" class="tab-btn" :class="{ active: activeTab === 1 }" @click="activeTab = 1">SocketB</button>
    </div>

    <!-- Socket配置表单 -->
    <form v-if="socketList[activeTab]">
      <div class="form-section">
        <div class="form-group">
          <label>{{ t('socket.enable') }}:</label>
          <select v-model.number="socketList[activeTab].enable">
            <option :value="0">{{ t('common.disable') }}</option>
            <option :value="1">{{ t('common.enable') }}</option>
          </select>
        </div>
      </div>

      <template v-if="socketList[activeTab].enable === 1">
        <div class="form-section">
          <div class="form-group">
            <label>{{ t('socket.workMode') }}:</label>
            <select v-model.number="socketList[activeTab].mode">
              <option :value="0">{{ t('socket.tcpClient') }}</option>
              <option :value="1">{{ t('socket.tcpServer') }}</option>
              <option :value="2">{{ t('socket.udpClient') }}</option>
              <option :value="3">HTTP Client</option>
            </select>
          </div>
        </div>

        <!-- TCP Client 配置 -->
        <div v-if="socketList[activeTab].mode === 0" class="form-section">
          <div class="form-group">
            <label>{{ t('socket.serverAddress') }}:</label>
            <input v-model="socketList[activeTab].tcpc.server_ip" type="text" />
          </div>
          <div class="form-group">
            <label>{{ t('socket.localPort') }}:</label>
            <input v-model.number="socketList[activeTab].tcpc.local_port" type="number" />
          </div>
          <div class="form-group">
            <label>{{ t('socket.remotePort') }}:</label>
            <input v-model.number="socketList[activeTab].tcpc.server_port" type="number" />
          </div>
          <div class="form-group">
            <label>{{ t('socket.reconnectInterval') }}:</label>
            <input v-model.number="socketList[activeTab].tcpc.reconn_interval" type="number" />
          </div>
          <div class="form-group">
            <label>{{ t('socket.sslEncrypt') }}:</label>
            <select v-model.number="socketList[activeTab].tcpc.ssl_mode">
              <option :value="0">{{ t('common.disable') }}</option>
              <option :value="1">TLS1.2</option>
            </select>
          </div>

          <!-- SSL认证方式 (仅TLS1.2时可选) -->
          <template v-if="socketList[activeTab].tcpc.ssl_mode === 1">
            <div class="form-group">
              <label>{{ t('socket.authMethod') }}:</label>
              <select v-model.number="socketList[activeTab].tcpc.ssl_verify">
                <option :value="0">{{ t('socket.noAuth') }}</option>
                <option :value="1">{{ t('socket.serverAuth') }}</option>
                <option :value="2">{{ t('socket.mutualAuth') }}</option>
              </select>
            </div>

            <!-- 服务器证书上传 -->
            <template v-if="socketList[activeTab].tcpc.ssl_verify >= 1">
              <div class="form-group">
                <label>{{ t('socket.serverCert') }}:</label>
                <input type="file" ref="serverCertInput" @change="handleServerCertSelect" accept=".crt,.pem" style="display:none" />
                <button type="button" class="btn-upload" @click="triggerFileSelect('server')">{{ t('common.selectFile') }}</button>
                <button type="button" class="btn-upload" @click.prevent="uploadServerCert" :disabled="!serverCertFile">{{ t('common.upload') }}...</button>
                <span v-if="socketList[activeTab].tcpc.ssl_server_name && socketList[activeTab].tcpc.ssl_server_name !== 'null'" class="file-name">
                  {{ t('common.selectedFile') }}: {{ socketList[activeTab].tcpc.ssl_server_name }}
                </span>
              </div>
            </template>

            <!-- 客户端证书和私钥上传 (双向认证) -->
            <template v-if="socketList[activeTab].tcpc.ssl_verify === 2">
              <div class="form-group">
                <label>{{ t('socket.clientCert') }}:</label>
                <input type="file" ref="clientCertInput" @change="handleClientCertSelect" accept=".crt,.pem" style="display:none" />
                <button type="button" class="btn-upload" @click="triggerFileSelect('client_cert')">{{ t('common.selectFile') }}</button>
                <button type="button" class="btn-upload" @click.prevent="uploadClientCert" :disabled="!clientCertFile">{{ t('common.upload') }}...</button>
                <span v-if="socketList[activeTab].tcpc.ssl_client_name && socketList[activeTab].tcpc.ssl_client_name !== 'null'" class="file-name">
                  {{ t('common.selectedFile') }}: {{ socketList[activeTab].tcpc.ssl_client_name }}
                </span>
              </div>
              <div class="form-group">
                <label>{{ t('socket.clientKey') }}:</label>
                <input type="file" ref="clientKeyInput" @change="handleClientKeySelect" accept=".key,.pem" style="display:none" />
                <button type="button" class="btn-upload" @click="triggerFileSelect('client_key')">{{ t('common.selectFile') }}</button>
                <button type="button" class="btn-upload" @click.prevent="uploadClientKey" :disabled="!clientKeyFile">{{ t('common.upload') }}...</button>
                <span v-if="socketList[activeTab].tcpc.ssl_client_key && socketList[activeTab].tcpc.ssl_client_key !== 'null'" class="file-name">
                  {{ t('common.selectedFile') }}: {{ socketList[activeTab].tcpc.ssl_client_key }}
                </span>
              </div>
            </template>
          </template>

          <!-- 注册包配置 -->
          <div class="form-group">
            <label>{{ t('socket.registerPacket') }}:</label>
            <select v-model.number="socketList[activeTab].tcpc.regp_en">
              <option :value="0">{{ t('common.disable') }}</option>
              <option :value="1">{{ t('common.enable') }}</option>
            </select>
          </div>
          <template v-if="socketList[activeTab].tcpc.regp_en === 1">
            <div class="form-group">
              <label>{{ t('socket.registerSendMode') }}:</label>
              <select v-model.number="socketList[activeTab].tcpc.regp_tim">
                <option :value="0">{{ t('socket.onConnect') }}</option>
                <option :value="1">{{ t('socket.onSend') }}</option>
                <option :value="2">{{ t('socket.both') }}</option>
              </select>
            </div>
            <div class="form-group">
              <label>{{ t('socket.registerContent') }}:</label>
              <select v-model.number="socketList[activeTab].tcpc.regp_fmt">
                <option :value="0">MAC</option>
                <option :value="1">IMEI</option>
                <option :value="2">SN</option>
                <option :value="3">{{ t('socket.custom') }}</option>
              </select>
            </div>
            <div v-if="socketList[activeTab].tcpc.regp_fmt === 3" class="form-group-with-hint">
              <div class="form-group">
                <label>{{ t('socket.customContent') }}:</label>
                <input v-model="socketList[activeTab].tcpc.regp_ctx" type="text" maxlength="128" />
              </div>
              <div class="hint-text">{{ t('socket.customContentHint') }}</div>
            </div>
          </template>

          <!-- 心跳包配置 -->
          <div class="form-group">
            <label>{{ t('socket.heartbeat') }}:</label>
            <select v-model.number="socketList[activeTab].tcpc.hrtp_en">
              <option :value="0">{{ t('common.disable') }}</option>
              <option :value="1">{{ t('common.enable') }}</option>
            </select>
          </div>
          <template v-if="socketList[activeTab].tcpc.hrtp_en === 1">
            <div class="form-group">
              <label>{{ t('socket.heartbeatInterval') }}:</label>
              <input v-model.number="socketList[activeTab].tcpc.hrtp_tim" type="number" min="1" />
            </div>
            <div class="form-group">
              <label>{{ t('socket.heartbeatContent') }}:</label>
              <select v-model.number="socketList[activeTab].tcpc.hrtp_fmt">
                <option :value="0">MAC</option>
                <option :value="1">IMEI</option>
                <option :value="2">{{ t('socket.custom') }}</option>
              </select>
            </div>
            <div v-if="socketList[activeTab].tcpc.hrtp_fmt === 2" class="form-group-with-hint">
              <div class="form-group">
                <label>{{ t('socket.heartbeatCustomContent') }}:</label>
                <input v-model="socketList[activeTab].tcpc.hrtp_ctx" type="text" maxlength="128" />
              </div>
              <div class="hint-text">{{ t('socket.customContentHint') }}</div>
            </div>
          </template>

          <!-- 断网缓存 -->
          <div class="form-group">
            <label>{{ t('socket.offlineCache') }}:</label>
            <select v-model.number="offlineCacheList[activeTab]">
              <option :value="0">{{ t('common.disable') }}</option>
              <option :value="1">{{ t('common.enable') }}</option>
            </select>
          </div>
        </div>

        <!-- TCP Server 配置 -->
        <div v-if="socketList[activeTab].mode === 1" class="form-section">
          <div class="form-group">
            <label>{{ t('socket.localPort') }}:</label>
            <input v-model.number="socketList[activeTab].tcps.local_port" type="number" />
          </div>
          <div class="form-group">
            <label>{{ t('socket.maxConnections') }}:</label>
            <input v-model.number="socketList[activeTab].tcps.conn_max_num" type="number" />
          </div>
          <div class="form-group">
            <label>{{ t('socket.overflowHandle') }}:</label>
            <select v-model.number="socketList[activeTab].tcps.timeout_handling">
              <option :value="0">KEEP</option>
              <option :value="1">KICK</option>
            </select>
          </div>
          <div class="form-group">
            <label>{{ t('socket.offlineCache') }}:</label>
            <select v-model.number="offlineCacheList[activeTab]">
              <option :value="0">{{ t('common.disable') }}</option>
              <option :value="1">{{ t('common.enable') }}</option>
            </select>
          </div>
        </div>

        <!-- UDP Client 配置 -->
        <div v-if="socketList[activeTab].mode === 2" class="form-section">
          <div class="section-title">{{ t('socket.udpClient') }} {{ t('socket.config') }}</div>
          <div class="form-group">
            <label>{{ t('socket.serverAddress') }}:</label>
            <input v-model="socketList[activeTab].udpc.server_ip" type="text" />
          </div>
          <div class="form-group">
            <label>{{ t('socket.localPort') }}:</label>
            <input v-model.number="socketList[activeTab].udpc.local_port" type="number" />
          </div>
          <div class="form-group">
            <label>{{ t('socket.remotePort') }}:</label>
            <input v-model.number="socketList[activeTab].udpc.server_port" type="number" />
          </div>
          <div class="form-group">
            <label>{{ t('socket.offlineCache') }}:</label>
            <select v-model.number="offlineCacheList[activeTab]">
              <option :value="0">{{ t('common.disable') }}</option>
              <option :value="1">{{ t('common.enable') }}</option>
            </select>
          </div>
        </div>

        <!-- HTTP Client 配置 -->
        <div v-if="socketList[activeTab].mode === 3" class="form-section">
          <div class="section-title">HTTP Client {{ t('socket.config') }}</div>
          <div class="form-group">
            <label>HTTP {{ t('socket.workMode') }}:</label>
            <select v-model.number="socketList[activeTab].httpc.mode">
              <option :value="0">GET</option>
              <option :value="1">POST</option>
            </select>
          </div>
          <div class="form-group">
            <label>{{ t('socket.serverAddress') }}:</label>
            <input v-model="socketList[activeTab].httpc.server_ip" type="text" />
          </div>
          <div class="form-group">
            <label>{{ t('socket.serverPort') }}:</label>
            <input v-model.number="socketList[activeTab].httpc.server_port" type="number" />
          </div>
          <div class="form-group">
            <label>URL {{ t('socket.path') }}:</label>
            <input v-model="socketList[activeTab].httpc.url" type="text" />
          </div>
          <div class="form-group">
            <label>{{ t('socket.offlineCache') }}:</label>
            <select v-model.number="offlineCacheList[activeTab]">
              <option :value="0">{{ t('common.disable') }}</option>
              <option :value="1">{{ t('common.enable') }}</option>
            </select>
          </div>
        </div>
      </template>
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
import { fetchSocketConfigData, fetchOfflineCacheData } from '../api/mockData'
import { updateConfig, restartDevice } from '../api/services'
import apiClient from '../api/services'
import { useI18n } from '../i18n/useI18n.js'

// 使用 i18n
const { t } = useI18n()

const loading = ref(true)
const error = ref(null)
const socketList = ref([])
const offlineCacheList = ref([0, 0])
const activeTab = ref(0)
const showRestartModal = ref(false)

// 证书文件引用
const serverCertInput = ref(null)
const clientCertInput = ref(null)
const clientKeyInput = ref(null)
const serverCertFile = ref(null)
const clientCertFile = ref(null)
const clientKeyFile = ref(null)

const triggerFileSelect = (type) => {
  if (type === 'server' && serverCertInput.value) serverCertInput.value.click()
  else if (type === 'client_cert' && clientCertInput.value) clientCertInput.value.click()
  else if (type === 'client_key' && clientKeyInput.value) clientKeyInput.value.click()
}

const handleServerCertSelect = (e) => { if (e.target.files?.length) serverCertFile.value = e.target.files[0] }
const handleClientCertSelect = (e) => { if (e.target.files?.length) clientCertFile.value = e.target.files[0] }
const handleClientKeySelect = (e) => { if (e.target.files?.length) clientKeyFile.value = e.target.files[0] }

const uploadServerCert = async () => {
  if (!serverCertFile.value) return alert(t('common.selectFile'))
  try {
    const formData = new FormData()
    const sockIndex = activeTab.value
    const filename = serverCertFile.value.name
    formData.append('c', serverCertFile.value, `SOCK${sockIndex}`)
    
    // POST 上传证书
    await apiClient.post('/upload/scert', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
    
    // GET 更新配置
    await apiClient.get('/update_nv.cgi', {
      params: {
        file: 'comm_tunnel',
        [`s_SOCK[${sockIndex}].tcpc.ssl_server_name`]: filename
      }
    })
    
    socketList.value[sockIndex].tcpc.ssl_server_name = filename
    alert(t('common.uploadSuccess'))
    serverCertFile.value = null
  } catch (err) { alert(t('common.uploadFailed') + ': ' + err.message) }
}

const uploadClientCert = async () => {
  if (!clientCertFile.value) return alert(t('common.selectFile'))
  try {
    const formData = new FormData()
    const sockIndex = activeTab.value
    const filename = clientCertFile.value.name
    formData.append('c', clientCertFile.value, `SOCK${sockIndex}`)
    
    // POST 上传证书
    await apiClient.post('/upload/ccert', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
    
    // GET 更新配置
    await apiClient.get('/update_nv.cgi', {
      params: {
        file: 'comm_tunnel',
        [`s_SOCK[${sockIndex}].tcpc.ssl_client_name`]: filename
      }
    })
    
    socketList.value[sockIndex].tcpc.ssl_client_name = filename
    alert(t('common.uploadSuccess'))
    clientCertFile.value = null
  } catch (err) { alert(t('common.uploadFailed') + ': ' + err.message) }
}

const uploadClientKey = async () => {
  if (!clientKeyFile.value) return alert(t('common.selectFile'))
  try {
    const formData = new FormData()
    const sockIndex = activeTab.value
    const filename = clientKeyFile.value.name
    formData.append('c', clientKeyFile.value, `SOCK${sockIndex}`)
    
    // POST 上传证书私钥
    await apiClient.post('/upload/ckey', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
    
    // GET 更新配置
    await apiClient.get('/update_nv.cgi', {
      params: {
        file: 'comm_tunnel',
        [`s_SOCK[${sockIndex}].tcpc.ssl_client_key`]: filename
      }
    })
    
    socketList.value[sockIndex].tcpc.ssl_client_key = filename
    alert(t('common.uploadSuccess'))
    clientKeyFile.value = null
  } catch (err) { alert(t('common.uploadFailed') + ': ' + err.message) }
}

const loadData = async () => {
  try {
    loading.value = true
    error.value = null
    const [socketConfig, cacheConfig] = await Promise.all([fetchSocketConfigData(), fetchOfflineCacheData()])
    if (socketConfig?.SOCK && Array.isArray(socketConfig.SOCK)) socketList.value = socketConfig.SOCK.slice(0, 2)
    if (cacheConfig?.tunnel) offlineCacheList.value = [cacheConfig.tunnel[0]?.enable || 0, cacheConfig.tunnel[1]?.enable || 0]
  } catch (err) {
    error.value = t('common.loadError') + ': ' + err.message
  } finally {
    loading.value = false
  }
}

const buildSocketParams = (sock, i) => {
  const p = []
  p.push(`n_SOCK[${i}].enable=${sock.enable}`, `n_SOCK[${i}].mode=${sock.mode}`)
  // TCP Client
  p.push(`s_SOCK[${i}].tcpc.server_ip=${sock.tcpc.server_ip}`, `n_SOCK[${i}].tcpc.local_port=${sock.tcpc.local_port}`)
  p.push(`n_SOCK[${i}].tcpc.server_port=${sock.tcpc.server_port}`, `n_SOCK[${i}].tcpc.reconn_interval=${sock.tcpc.reconn_interval}`)
  p.push(`n_SOCK[${i}].tcpc.ssl_mode=${sock.tcpc.ssl_mode || 0}`, `n_SOCK[${i}].tcpc.ssl_verify=${sock.tcpc.ssl_verify || 0}`)
  p.push(`n_SOCK[${i}].tcpc.regp_en=${sock.tcpc.regp_en || 0}`, `n_SOCK[${i}].tcpc.regp_tim=${sock.tcpc.regp_tim || 0}`)
  p.push(`n_SOCK[${i}].tcpc.regp_fmt=${sock.tcpc.regp_fmt || 0}`, `s_SOCK[${i}].tcpc.regp_ctx=${sock.tcpc.regp_ctx || ''}`)
  p.push(`n_SOCK[${i}].tcpc.hrtp_en=${sock.tcpc.hrtp_en || 0}`, `n_SOCK[${i}].tcpc.hrtp_tim=${sock.tcpc.hrtp_tim || 60}`)
  p.push(`n_SOCK[${i}].tcpc.hrtp_fmt=${sock.tcpc.hrtp_fmt || 0}`, `s_SOCK[${i}].tcpc.hrtp_ctx=${sock.tcpc.hrtp_ctx || ''}`)
  // TCP Server
  p.push(`n_SOCK[${i}].tcps.local_port=${sock.tcps.local_port}`, `n_SOCK[${i}].tcps.conn_max_num=${sock.tcps.conn_max_num}`)
  p.push(`n_SOCK[${i}].tcps.timeout_handling=${sock.tcps.timeout_handling}`)
  // UDP Client
  p.push(`s_SOCK[${i}].udpc.server_ip=${sock.udpc.server_ip}`, `n_SOCK[${i}].udpc.dns_timeout=${sock.udpc.dns_timeout}`)
  p.push(`n_SOCK[${i}].udpc.local_port=${sock.udpc.local_port}`, `n_SOCK[${i}].udpc.server_port=${sock.udpc.server_port}`)
  p.push(`n_SOCK[${i}].udpc.ip_port_verify=${sock.udpc.ip_port_verify}`)
  // HTTP Client
  p.push(`n_SOCK[${i}].httpc.mode=${sock.httpc.mode}`, `s_SOCK[${i}].httpc.url=${sock.httpc.url}`)
  p.push(`s_SOCK[${i}].httpc.header=${sock.httpc.header}`, `s_SOCK[${i}].httpc.server_ip=${sock.httpc.server_ip}`)
  p.push(`n_SOCK[${i}].httpc.local_port=${sock.httpc.local_port}`, `n_SOCK[${i}].httpc.server_port=${sock.httpc.server_port}`)
  p.push(`n_SOCK[${i}].httpc.resp_timeout=${sock.httpc.resp_timeout}`, `n_SOCK[${i}].httpc.cut_header=${sock.httpc.cut_header}`)
  return p
}

const saveConfig = async () => {
  try {
    // 验证自定义内容
    for (let i = 0; i < socketList.value.length; i++) {
      const sock = socketList.value[i]
      // 检查Socket是否启用且为TCP Client模式
      if (sock.enable === 1 && sock.mode === 0) {
        // 检查注册包自定义内容
        if (sock.tcpc.regp_en === 1 && sock.tcpc.regp_fmt === 3) {
          const regpCtx = String(sock.tcpc.regp_ctx || '').trim()
          if (regpCtx === '') {
            alert(t('socket.registerCustomContentRequired'))
            return
          }
        }
        // 检查心跳包自定义内容
        if (sock.tcpc.hrtp_en === 1 && sock.tcpc.hrtp_fmt === 2) {
          const hrtpCtx = String(sock.tcpc.hrtp_ctx || '').trim()
          if (hrtpCtx === '') {
            alert(t('socket.heartbeatCustomContentRequired'))
            return
          }
        }
      }
    }
    
    const sockParams = []
    socketList.value.forEach((sock, i) => sockParams.push(...buildSocketParams(sock, i)))
    const cacheParams = offlineCacheList.value.map((en, i) => `n_tunnel[${i}].enable=${en}`)
    await Promise.all([updateConfig('comm_tunnel', sockParams.join('&')), updateConfig('offline_cache', cacheParams.join('&'))])
    showRestartModal.value = true
  } catch (err) { alert(t('common.saveFailed') + ': ' + err.message) }
}

const handleRestart = async () => {
  try { await restartDevice(); alert(t('system.restartSuccess')); showRestartModal.value = false } catch (err) { alert(t('system.restartFailed') + ': ' + err.message) }
}
const handleContinue = () => { showRestartModal.value = false }

onMounted(() => { loadData() })
</script>

<style scoped>
.config-subtitle { padding: 10px 15px; font-size: 12px; color: #666; border-bottom: 1px solid #e8e8e8; background-color: white; }
.tabs { display: flex; gap: 10px; margin: 20px 0; border-bottom: 1px solid #e8e8e8; }
.tab-btn { padding: 8px 20px; background-color: #494641; color: white; border: none; cursor: pointer; border-radius: 4px 4px 0 0; font-size: 13px; font-weight: 600; transition: background-color 0.2s; }
.tab-btn:hover { background-color: #ff8800; }
.tab-btn.active { background-color: #0066cc; }
.form-section { padding: 20px 15px; background-color: white; border-bottom: 1px solid #e8e8e8; }
.section-title { font-weight: 600; font-size: 13px; color: #333; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 1px solid #e8e8e8; }
.form-group { display: flex; align-items: center; margin-bottom: 15px; gap: 20px; }
.form-group:last-child { margin-bottom: 0; }
.form-group label { font-weight: 600; width: 150px; text-align: right; flex-shrink: 0; }
.form-group input, .form-group select { flex: 1; max-width: 300px; padding: 8px 12px; border: 1px solid #ddd; border-radius: 4px; font-size: 13px; }
.form-group input:focus, .form-group select:focus { outline: none; border-color: #0066cc; box-shadow: 0 0 0 2px rgba(0, 102, 204, 0.1); }
.btn-upload { padding: 6px 16px; background-color: #666; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 13px; margin-right: 10px; }
.btn-upload:hover { background-color: #555; }
.btn-upload:disabled { background-color: #ccc; cursor: not-allowed; }
.file-name { color: #0a0; font-size: 12px; margin-left: 10px; }
.button-group { display: flex; justify-content: center; padding: 20px; gap: 10px; background-color: #f9f9f9; }
.btn-save { padding: 10px 40px; background-color: #0066cc; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 14px; font-weight: 600; transition: background-color 0.2s; }
.btn-save:hover { background-color: #0052a3; }
.loading { text-align: center; padding: 40px 20px; color: #666; }
.error { background-color: #ffebee; border: 1px solid #ffcdd2; color: #c62828; padding: 12px 15px; border-radius: 4px; margin-bottom: 20px; }
.modal-overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background-color: rgba(0, 0, 0, 0.5); display: flex; justify-content: center; align-items: center; z-index: 1000; }
.modal { background-color: white; border-radius: 8px; width: 400px; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15); overflow: hidden; }
.modal-header { padding: 15px 20px; border-bottom: 1px solid #eee; background-color: #f8f9fa; }
.modal-header h3 { margin: 0; font-size: 16px; color: #333; }
.modal-body { padding: 20px; text-align: center; }
.modal-actions { display: flex; justify-content: center; gap: 15px; margin-top: 20px; }
.btn-restart { padding: 8px 20px; background-color: #0066cc; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: 600; }
.btn-continue { padding: 8px 20px; background-color: white; color: #666; border: 1px solid #ddd; border-radius: 4px; cursor: pointer; font-weight: 600; }
.btn-restart:hover { background-color: #0052a3; }
.btn-continue:hover { background-color: #f5f5f5; }
.form-group-with-hint { margin-bottom: 15px; }
.form-group-with-hint .form-group { margin-bottom: 5px; }
.hint-text { color: #ff0000; font-size: 12px; margin-left: 170px; }
</style>
