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
      <button class="tab-btn" :class="{ active: activeTab === 0, 'has-error': hasTabError(0) }" @click="activeTab = 0">SOCKA</button>
      <button v-if="socketList.length > 1" class="tab-btn" :class="{ active: activeTab === 1, 'has-error': hasTabError(1) }" @click="activeTab = 1">SOCKB</button>
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
              <!-- <option :value="2">{{ t('socket.udpClient') }}</option> -->
              <!-- <option :value="3">HTTP Client</option> -->
            </select>
          </div>
        </div>

        <!-- TCP Client 配置 -->
        <div v-if="socketList[activeTab].mode === 0" class="form-section">
          <div class="form-group">
            <label>{{ t('socket.serverAddress') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model="socketList[activeTab].tcpc.server_ip" 
                type="text" 
                :class="{ 'input-error': getFieldError(activeTab, 'tcpc_server_ip') }"
              />
              <span v-if="getFieldError(activeTab, 'tcpc_server_ip')" class="field-error-text">
                {{ getFieldError(activeTab, 'tcpc_server_ip') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('socket.localPort') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model.number="socketList[activeTab].tcpc.local_port" 
                type="number" 
                :class="{ 'input-error': getFieldError(activeTab, 'tcpc_local_port') }"
              />
              <span v-if="getFieldError(activeTab, 'tcpc_local_port')" class="field-error-text">
                {{ getFieldError(activeTab, 'tcpc_local_port') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('socket.remotePort') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model.number="socketList[activeTab].tcpc.server_port" 
                type="number" 
                :class="{ 'input-error': getFieldError(activeTab, 'tcpc_server_port') }"
              />
              <span v-if="getFieldError(activeTab, 'tcpc_server_port')" class="field-error-text">
                {{ getFieldError(activeTab, 'tcpc_server_port') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('socket.reconnectInterval') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model.number="socketList[activeTab].tcpc.reconn_interval" 
                type="number" 
                :class="{ 'input-error': getFieldError(activeTab, 'tcpc_reconn_interval') }"
              />
              <span v-if="getFieldError(activeTab, 'tcpc_reconn_interval')" class="field-error-text">
                {{ getFieldError(activeTab, 'tcpc_reconn_interval') }}
              </span>
            </div>
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
                <span v-if="serverCertFile" class="file-name">
                  {{ t('common.selectedFile')}}: {{ serverCertFile.name }}
                </span>
                <span v-else-if="socketList[activeTab].tcpc.ssl_server_name && socketList[activeTab].tcpc.ssl_server_name !== 'null'" class="file-name">
                  {{ t('common.uploadedFile') }}: {{ socketList[activeTab].tcpc.ssl_server_name }}
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
                <span v-if="clientCertFile" class="file-name">
                  {{ t('common.selectedFile')}}: {{ clientCertFile.name }}
                </span>
                <span v-else-if="socketList[activeTab].tcpc.ssl_client_name && socketList[activeTab].tcpc.ssl_client_name !== 'null'" class="file-name">
                  {{ t('common.uploadedFile')}}: {{ socketList[activeTab].tcpc.ssl_client_name }}
                </span>
              </div>
              <div class="form-group">
                <label>{{ t('socket.clientKey') }}:</label>
                <input type="file" ref="clientKeyInput" @change="handleClientKeySelect" accept=".key,.pem" style="display:none" />
                <button type="button" class="btn-upload" @click="triggerFileSelect('client_key')">{{ t('common.selectFile') }}</button>
                <button type="button" class="btn-upload" @click.prevent="uploadClientKey" :disabled="!clientKeyFile">{{ t('common.upload') }}...</button>
                <span v-if="clientKeyFile" class="file-name">
                  {{ t('common.selectedFile')}}: {{ clientKeyFile.name }}
                </span>
                <span v-else-if="socketList[activeTab].tcpc.ssl_client_key && socketList[activeTab].tcpc.ssl_client_key !== 'null'" class="file-name">
                  {{ t('common.uploadedFile')}}: {{ socketList[activeTab].tcpc.ssl_client_key }}
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
                <div class="input-wrapper">
                  <input 
                    v-model="socketList[activeTab].tcpc.regp_ctx" 
                    type="text" 
                    maxlength="128" 
                    :class="{ 'input-error': getFieldError(activeTab, 'tcpc_regp_ctx') }"
                  />
                  <span v-if="getFieldError(activeTab, 'tcpc_regp_ctx')" class="field-error-text">
                    {{ getFieldError(activeTab, 'tcpc_regp_ctx') }}
                  </span>
                </div>
              </div>
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
              <div class="input-wrapper">
                <input 
                  v-model.number="socketList[activeTab].tcpc.hrtp_tim" 
                  type="number" 
                  min="30"
                  max="300"
                  :class="{ 'input-error': getFieldError(activeTab, 'tcpc_hrtp_tim') }"
                />
                <span v-if="getFieldError(activeTab, 'tcpc_hrtp_tim')" class="field-error-text">
                  {{ getFieldError(activeTab, 'tcpc_hrtp_tim') }}
                </span>
              </div>
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
                <div class="input-wrapper">
                  <input 
                    v-model="socketList[activeTab].tcpc.hrtp_ctx" 
                    type="text" 
                    maxlength="128" 
                    :class="{ 'input-error': getFieldError(activeTab, 'tcpc_hrtp_ctx') }"
                  />
                  <span v-if="getFieldError(activeTab, 'tcpc_hrtp_ctx')" class="field-error-text">
                    {{ getFieldError(activeTab, 'tcpc_hrtp_ctx') }}
                  </span>
                </div>
              </div>
            </div>
          </template>

          <!-- 断网缓存 -->
          <div class="form-group">
            <label>{{ t('socket.offlineCache') }}:</label>
            <select v-model.number="offlineCacheList[activeTab]" :disabled="!FEATURE_TF_CARD_ENABLED">
              <option :value="0">{{ t('common.disable') }}</option>
              <option :value="1">{{ t('common.enable') }}</option>
            </select>
          </div>
        </div>

        <!-- TCP Server 配置 -->
        <div v-if="socketList[activeTab].mode === 1" class="form-section">
          <div class="form-group">
            <label>{{ t('socket.localPort') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model.number="socketList[activeTab].tcps.local_port" 
                type="number" 
                :class="{ 'input-error': getFieldError(activeTab, 'tcps_local_port') }"
              />
              <span v-if="getFieldError(activeTab, 'tcps_local_port')" class="field-error-text">
                {{ getFieldError(activeTab, 'tcps_local_port') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('socket.maxConnections') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model.number="socketList[activeTab].tcps.conn_max_num" 
                type="number" 
                :class="{ 'input-error': getFieldError(activeTab, 'tcps_conn_max_num') }"
              />
              <span v-if="getFieldError(activeTab, 'tcps_conn_max_num')" class="field-error-text">
                {{ getFieldError(activeTab, 'tcps_conn_max_num') }}
              </span>
            </div>
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
            <select v-model.number="offlineCacheList[activeTab]" :disabled="!FEATURE_TF_CARD_ENABLED">
              <option :value="0">{{ t('common.disable') }}</option>
              <option :value="1">{{ t('common.enable') }}</option>
            </select>
          </div>
        </div>

        <!-- UDP Client 配置 -->
        <!-- 已隐藏：设备不支持 UDP Client 模式
        <div v-if="socketList[activeTab].mode === 2" class="form-section">
          <div class="section-title">{{ t('socket.udpClient') }} {{ t('socket.config') }}</div>
          <div class="form-group">
            <label>{{ t('socket.serverAddress') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model="socketList[activeTab].udpc.server_ip" 
                type="text" 
                :class="{ 'input-error': getFieldError(activeTab, 'udpc_server_ip') }"
              />
              <span v-if="getFieldError(activeTab, 'udpc_server_ip')" class="field-error-text">
                {{ getFieldError(activeTab, 'udpc_server_ip') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('socket.localPort') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model.number="socketList[activeTab].udpc.local_port" 
                type="number" 
                :class="{ 'input-error': getFieldError(activeTab, 'udpc_local_port') }"
              />
              <span v-if="getFieldError(activeTab, 'udpc_local_port')" class="field-error-text">
                {{ getFieldError(activeTab, 'udpc_local_port') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('socket.remotePort') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model.number="socketList[activeTab].udpc.server_port" 
                type="number" 
                :class="{ 'input-error': getFieldError(activeTab, 'udpc_server_port') }"
              />
              <span v-if="getFieldError(activeTab, 'udpc_server_port')" class="field-error-text">
                {{ getFieldError(activeTab, 'udpc_server_port') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('socket.offlineCache') }}:</label>
            <select v-model.number="offlineCacheList[activeTab]">
              <option :value="0">{{ t('common.disable') }}</option>
              <option :value="1">{{ t('common.enable') }}</option>
            </select>
          </div>
        </div>
        -->

        <!-- HTTP Client 配置 -->
        <!-- 已隐藏：设备不支持 HTTP Client 模式
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
            <div class="input-wrapper">
              <input 
                v-model="socketList[activeTab].httpc.server_ip" 
                type="text" 
                :class="{ 'input-error': getFieldError(activeTab, 'httpc_server_ip') }"
              />
              <span v-if="getFieldError(activeTab, 'httpc_server_ip')" class="field-error-text">
                {{ getFieldError(activeTab, 'httpc_server_ip') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('socket.serverPort') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model.number="socketList[activeTab].httpc.server_port" 
                type="number" 
                :class="{ 'input-error': getFieldError(activeTab, 'httpc_server_port') }"
              />
              <span v-if="getFieldError(activeTab, 'httpc_server_port')" class="field-error-text">
                {{ getFieldError(activeTab, 'httpc_server_port') }}
              </span>
            </div>
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
        -->
      </template>
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
          <p>{{ t('socket.restartRequired') }}</p>
          <div class="modal-actions">
            <button class="btn-restart" @click="handleRestart">{{ t('system.restartNow') }}</button>
            <button class="btn-continue" @click="handleContinue">{{ t('socket.continueConfig') }}</button>
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
import { fetchSocketConfigData, fetchOfflineCacheData } from '../api/mockData'
import { updateConfig, restartDevice } from '../api/services'
import apiClient from '../api/services'
import { useI18n } from '../i18n/useI18n.js'
import { isValidServerAddress, isValidPort, isValidReconnectInterval, isValidCustomContent, isValidMaxConnections } from '../utils/validation.js'
import { useServiceControl } from '../composables/useServiceControl.js'
import { FEATURE_TF_CARD_ENABLED } from '../config/features.js'

// 使用 i18n
const { t } = useI18n()
const { isServiceRestarting, restartService } = useServiceControl()

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

// 验证逻辑
const socketErrors = computed(() => {
  const errors = {}
  
  socketList.value.forEach((sock, index) => {
    if (sock.enable !== 1) return
    
    // TCP Client
    if (sock.mode === 0) {
      if (!isValidServerAddress(sock.tcpc.server_ip)) {
        errors[`${index}_tcpc_server_ip`] = t('socket.invalidServerAddress') || 'Invalid Server Address'
      }
      // TCP Client 本地端口允许为 0 (系统自动分配)
      if (!isValidPort(sock.tcpc.local_port, true)) {
        errors[`${index}_tcpc_local_port`] = t('socket.invalidPort') || 'Invalid Port (1024-65534)'
      }
      if (!isValidPort(sock.tcpc.server_port)) {
        errors[`${index}_tcpc_server_port`] = t('socket.invalidPort') || 'Invalid Port (1024-65534)'
      }
      if (!isValidReconnectInterval(sock.tcpc.reconn_interval)) {
        errors[`${index}_tcpc_reconn_interval`] = t('socket.invalidReconnectInterval') || 'Invalid Interval (5-60s)'
      }

      // 心跳包间隔验证
      if (sock.tcpc.hrtp_en === 1) {
        const hrtp_tim = Number(sock.tcpc.hrtp_tim);
        if (!Number.isInteger(hrtp_tim) || hrtp_tim < 30 || hrtp_tim > 300) {
            errors[`${index}_tcpc_hrtp_tim`] = t('socket.invalidHeartbeatInterval') || '心跳时间范围为30-300秒';
        }
      }

      // 注册包自定义内容验证
      if (sock.tcpc.regp_en === 1 && sock.tcpc.regp_fmt === 3) {
        if (!isValidCustomContent(sock.tcpc.regp_ctx)) {
          errors[`${index}_tcpc_regp_ctx`] = t('socket.customContentHint');
        }
      }

      // 心跳包自定义内容验证
      if (sock.tcpc.hrtp_en === 1 && sock.tcpc.hrtp_fmt === 2) {
        if (!isValidCustomContent(sock.tcpc.hrtp_ctx)) {
          errors[`${index}_tcpc_hrtp_ctx`] = t('socket.customContentHint');
        }
      }
    }
    // TCP Server
    else if (sock.mode === 1) {
      if (!isValidPort(sock.tcps.local_port)) {
        errors[`${index}_tcps_local_port`] = t('socket.invalidPort') || 'Invalid Port (1024-65534)'
      }
      if (!isValidMaxConnections(sock.tcps.conn_max_num)) {
        errors[`${index}_tcps_conn_max_num`] = t('socket.invalidMaxConnections') || 'Max connections must be between 1-32'
      }
    }
    // UDP Client
    else if (sock.mode === 2) {
      if (!isValidServerAddress(sock.udpc.server_ip)) {
        errors[`${index}_udpc_server_ip`] = t('socket.invalidServerAddress') || 'Invalid Server Address'
      }
      if (!isValidPort(sock.udpc.local_port)) {
        errors[`${index}_udpc_local_port`] = t('socket.invalidPort') || 'Invalid Port (1024-65534)'
      }
      if (!isValidPort(sock.udpc.server_port)) {
        errors[`${index}_udpc_server_port`] = t('socket.invalidPort') || 'Invalid Port (1024-65534)'
      }
    }
    // HTTP Client
    else if (sock.mode === 3) {
      if (!isValidServerAddress(sock.httpc.server_ip)) {
        errors[`${index}_httpc_server_ip`] = t('socket.invalidServerAddress') || 'Invalid Server Address'
      }
      if (!isValidPort(sock.httpc.server_port)) {
        errors[`${index}_httpc_server_port`] = t('socket.invalidPort') || 'Invalid Port (1024-65534)'
      }
    }
  })

  // TCP Server 端口冲突检测
  if (socketList.value.length >= 2) {
    const s0 = socketList.value[0]
    const s1 = socketList.value[1]
    
    if (s0.enable === 1 && s0.mode === 1 && s1.enable === 1 && s1.mode === 1) {
      if (Number(s0.tcps.local_port) === Number(s1.tcps.local_port)) {
        const msg = t('socket.portConflict') || 'Port already in use'
        errors[`0_tcps_local_port`] = msg
        errors[`1_tcps_local_port`] = msg
      }
    }
  }

  return errors
})

const isConfigValid = computed(() => {
  return Object.keys(socketErrors.value).length === 0
})

const getFieldError = (index, field) => {
  return socketErrors.value[`${index}_${field}`]
}

const hasTabError = (index) => {
  return Object.keys(socketErrors.value).some(key => key.startsWith(`${index}_`))
}

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
    if (cacheConfig?.tunnel) {
      // 如果 TF 卡功能禁用，强制显示关闭状态
      const t0 = FEATURE_TF_CARD_ENABLED ? (cacheConfig.tunnel[0]?.enable || 0) : 0
      const t1 = FEATURE_TF_CARD_ENABLED ? (cacheConfig.tunnel[1]?.enable || 0) : 0
      offlineCacheList.value = [t0, t1]
    }
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
    const sockParams = []
    socketList.value.forEach((sock, i) => sockParams.push(...buildSocketParams(sock, i)))
    // 保存时，如果 TF 卡功能被禁用，强制保存为 0
    const cacheParams = offlineCacheList.value.map((en, i) => `n_tunnel[${i}].enable=${FEATURE_TF_CARD_ENABLED ? en : 0}`)
    await Promise.all([updateConfig('comm_tunnel', sockParams.join('&')), updateConfig('offline_cache', cacheParams.join('&'))])
    showRestartModal.value = true
  } catch (err) { alert(t('common.saveFailed') + ': ' + err.message) }
}

const handleRestart = async () => {
  showRestartModal.value = false
  await restartService()
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
.tab-btn.has-error { background-color: #d32f2f; }
.tab-btn.active.has-error { background-color: #c62828; }

.form-section { padding: 20px 15px; background-color: white; border-bottom: 1px solid #e8e8e8; }
.section-title { font-weight: 600; font-size: 13px; color: #333; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 1px solid #e8e8e8; }
.form-group { display: flex; align-items: flex-start; margin-bottom: 15px; gap: 20px; }
.form-group:last-child { margin-bottom: 0; }
.form-group label { font-weight: 600; width: 150px; text-align: right; flex-shrink: 0; margin-top: 8px; }
.form-group input, .form-group select { width: 100%; max-width: 300px; padding: 8px 12px; border: 1px solid #ddd; border-radius: 4px; font-size: 13px; }
.form-group input:focus, .form-group select:focus { outline: none; border-color: #0066cc; box-shadow: 0 0 0 2px rgba(0, 102, 204, 0.1); }

.input-wrapper { flex: 1; max-width: 300px; display: flex; flex-direction: column; }
.input-error { border-color: #d32f2f !important; background-color: #ffebee; }
.field-error-text { color: #d32f2f; font-size: 12px; margin-top: 4px; }

.btn-upload { padding: 6px 16px; background-color: #666; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 13px; margin-right: 10px; margin-top: 2px; }
.btn-upload:hover { background-color: #555; }
.btn-upload:disabled { background-color: #ccc; cursor: not-allowed; }
.file-name { color: #0a0; font-size: 12px; margin-left: 10px; margin-top: 8px; }
.button-group { display: flex; justify-content: center; padding: 20px; gap: 10px; background-color: #f9f9f9; }
.btn-save { padding: 10px 40px; background-color: #0066cc; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 14px; font-weight: 600; transition: background-color 0.2s; }
.btn-save:hover { background-color: #0052a3; }
.btn-disabled { background-color: #ccc !important; cursor: not-allowed; }

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
