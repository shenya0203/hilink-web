<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading">加载中...</div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

    <!-- MQTT配置标题 -->
    <div class="description-box">
      <div class="desc-title">MQTT通信链路</div>
    </div>

    <!-- 标签页选择 -->
    <div class="tabs">
      <button 
        v-for="(item, index) in mqttList"
        :key="index"
        class="tab-btn" 
        :class="{ active: activeTab === index }"
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
          <label>MQTT使能:</label>
          <select v-model.number="mqttList[activeTab].enable">
            <option :value="0">关闭</option>
            <option :value="1">开启</option>
          </select>
        </div>

        <!-- 仅在MQTT使能为开启时显示配置 -->
        <template v-if="mqttList[activeTab].enable === 1">
          <div class="form-group">
            <label>MQTT协议:</label>
            <select v-model.number="mqttList[activeTab].mqtt_ver">
              <option :value="3">MQTT-3.1</option>
              <option :value="4">MQTT-3.1.1</option>
            </select>
          </div>

          <div class="form-group">
            <label>客户ID:</label>
            <input v-model="mqttList[activeTab].client_id" type="text" />
          </div>

          <div class="form-group">
            <label>服务器地址:</label>
            <input v-model="mqttList[activeTab].server_ip" type="text" />
          </div>

          <div class="form-group">
            <label>远程端口号:</label>
            <input v-model.number="mqttList[activeTab].server_port" type="number" />
          </div>

          <div class="form-group">
            <label>Keepalive:</label>
            <input v-model.number="mqttList[activeTab].keepalive" type="number" />
          </div>

          <div class="form-group">
            <label>重连间隔时间:</label>
            <input v-model.number="mqttList[activeTab].reconn_space" type="number" />
          </div>

          <div class="form-group">
            <label>清理会话:</label>
            <input type="checkbox" v-model="mqttList[activeTab].clean_session" :true-value="1" :false-value="0" />
          </div>

          <div class="form-group">
            <label>连接验证:</label>
            <input type="checkbox" v-model="mqttList[activeTab].conn_verify" :true-value="1" :false-value="0" />
          </div>
          
          <!-- 连接验证开启时显示 -->
          <template v-if="mqttList[activeTab].conn_verify === 1">
            <div class="form-group">
              <label>用户名:</label>
              <input v-model="mqttList[activeTab].conn_user_name" type="text" />
            </div>
            <div class="form-group">
              <label>密码:</label>
              <input v-model="mqttList[activeTab].conn_user_password" type="password" />
            </div>
          </template>

          <div class="form-group">
            <label>遗嘱:</label>
            <input type="checkbox" v-model="mqttList[activeTab].will_flag" :true-value="1" :false-value="0" />
          </div>

          <!-- 遗嘱开启时显示 -->
          <template v-if="mqttList[activeTab].will_flag === 1">
            <div class="form-group">
              <label>遗嘱Topic:</label>
              <input v-model="mqttList[activeTab].will.topic" type="text" />
            </div>
            <div class="form-group">
              <label>遗嘱消息:</label>
              <input v-model="mqttList[activeTab].will.msg" type="text" />
            </div>
            <div class="form-group">
              <label>遗嘱QoS:</label>
              <select v-model.number="mqttList[activeTab].will.qos">
                  <option :value="0">0</option>
                  <option :value="1">1</option>
                  <option :value="2">2</option>
              </select>
            </div>
            <div class="form-group">
              <label>遗嘱保留:</label>
              <select v-model.number="mqttList[activeTab].will.retention">
                  <option :value="0">不保留</option>
                  <option :value="1">保留</option>
              </select>
            </div>
          </template>

          <div class="form-group">
            <label>断网缓存:</label>
            <select v-model.number="mqttList[activeTab].offline_cache_enable">
              <option :value="0">关闭</option>
              <option :value="1">开启</option>
            </select>
          </div>

          <div class="form-group">
            <label>SSL加密:</label>
            <select v-model.number="mqttList[activeTab].ssl_mode">
              <option :value="0">关闭</option>
              <option :value="1">开启</option>
            </select>
          </div>

          <div class="form-group">
            <label>认证方式:</label>
            <select v-model.number="mqttList[activeTab].ssl_verify">
              <option :value="0">不认证证书</option>
              <option :value="1">认证服务器证书</option>
              <option :value="2">双向认证</option>
            </select>
          </div>

          <!-- 服务器证书上传 (ssl_verify >= 1) -->
          <template v-if="mqttList[activeTab].ssl_verify >= 1">
            <div class="form-group">
              <label>服务器根证书上传:</label>
              <input type="file" ref="serverCertInput" @change="handleServerCertSelect" accept=".crt,.pem" style="display:none" />
              <button type="button" class="btn-upload" @click="triggerFileSelect('server')">选择文件</button>
              <button type="button" class="btn-upload" @click.prevent="uploadServerCert" :disabled="!serverCertFile">上传...</button>
              <span v-if="mqttList[activeTab].ssl_server_name && mqttList[activeTab].ssl_server_name !== 'null'" class="file-name">
                已选文件: {{ mqttList[activeTab].ssl_server_name }}
              </span>
            </div>
          </template>

          <!-- 客户端证书和私钥上传 (ssl_verify == 2) -->
          <template v-if="mqttList[activeTab].ssl_verify === 2">
            <div class="form-group">
              <label>客户端证书上传:</label>
              <input type="file" ref="clientCertInput" @change="handleClientCertSelect" accept=".crt,.pem" style="display:none" />
              <button type="button" class="btn-upload" @click="triggerFileSelect('client_cert')">选择文件</button>
              <button type="button" class="btn-upload" @click.prevent="uploadClientCert" :disabled="!clientCertFile">上传...</button>
              <span v-if="mqttList[activeTab].ssl_client_name && mqttList[activeTab].ssl_client_name !== 'null'" class="file-name">
                已选文件: {{ mqttList[activeTab].ssl_client_name }}
              </span>
            </div>

            <div class="form-group">
              <label>客户端私钥上传:</label>
              <input type="file" ref="clientKeyInput" @change="handleClientKeySelect" accept=".key,.pem" style="display:none" />
              <button type="button" class="btn-upload" @click="triggerFileSelect('client_key')">选择文件</button>
              <button type="button" class="btn-upload" @click.prevent="uploadClientKey" :disabled="!clientKeyFile">上传...</button>
              <span v-if="mqttList[activeTab].ssl_client_key && mqttList[activeTab].ssl_client_key !== 'null'" class="file-name">
                已选文件: {{ mqttList[activeTab].ssl_client_key }}
              </span>
            </div>
          </template>
        </template>
        
      </div>
    </form>

    <!-- 应用保存按钮 -->
    <div class="button-group">
      <button class="btn-save" @click="saveConfig">应用保存</button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getCommTunnel, getOfflineCache } from '../api/services'
import apiClient from '../api/services'

// 响应式数据
const loading = ref(true)
const error = ref(null)
const mqttList = ref([])
const activeTab = ref(0)
const offlineCacheData = ref(null)

// DOM 元素引用 (用于触发点击)
const serverCertInput = ref(null)
const clientCertInput = ref(null)
const clientKeyInput = ref(null)

// 选中的文件数据
const serverCertFile = ref(null)
const clientCertFile = ref(null)
const clientKeyFile = ref(null)

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
    alert('请先选择文件')
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
    alert('证书文件上传成功')
    
    // 清空文件选择
    serverCertFile.value = null
  } catch (err) {
    console.error('上传服务器证书失败，详细错误:', err)
    console.error('错误堆栈:', err.stack)
    alert('上传失败: ' + (err.response?.data?.msg || err.message))
  }
}

// 上传客户端证书
const uploadClientCert = async () => {
  const file = clientCertFile.value
  
  if (!file) {
    alert('请先选择文件')
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
    alert('证书文件上传成功')
    
    clientCertFile.value = null
  } catch (err) {
    console.error('上传客户端证书失败:', err)
    alert('上传失败: ' + (err.response?.data?.msg || err.message))
  }
}

// 上传客户端私钥
const uploadClientKey = async () => {
  const file = clientKeyFile.value
  
  if (!file) {
    alert('请先选择文件')
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
    alert('证书文件上传成功')
    
    clientKeyFile.value = null
  } catch (err) {
    console.error('上传客户端私钥失败:', err)
    alert('上传失败: ' + (err.response?.data?.msg || err.message))
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
    error.value = '加载配置失败: ' + err.message
    console.error('配置加载错误:', err)
  } finally {
    loading.value = false
  }
}

// 保存配置
const saveConfig = () => {
  console.log('保存MQTT配置:', mqttList.value)
  // 这里需要处理保存逻辑，可能需要拆分回两个接口的格式
  // 暂时只打印
  alert('配置已保存 (模拟)')
}

// 组件挂载时加载数据
onMounted(() => {
  loadData()
})
</script>

<style scoped>
.description-box {
  background-color: #ff8800; /* Orange background */
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
  gap: 2px;
  margin-bottom: 0;
  border-bottom: 2px solid #0066cc;
}

.tab-btn {
  padding: 8px 30px;
  background-color: #ff8800; /* Orange for active/default? Screenshot shows orange for active */
  color: white;
  border: none;
  cursor: pointer;
  font-size: 13px;
  font-weight: 600;
}

.tab-btn:not(.active) {
    background-color: #0066cc; /* Blue for inactive */
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
  width: 150px;
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

.form-group input[type="checkbox"] {
    width: 16px;
    height: 16px;
}

.form-group input:focus,
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
</style>
