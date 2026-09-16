<template>
  <div>
    <div v-if="loading" class="loading">{{ t('common.loading') }}</div>
    <div v-if="error" class="error">{{ error }}</div>

    <div class="description-box" v-if="!embedded">
      <div class="desc-title">{{ t('dtu.title') }}</div>
      <div class="desc-content">{{ t('dtu.description') }}</div>
    </div>

    <div class="tabs" v-if="visibleTabIndices.length">
      <button
        v-for="i in visibleTabIndices"
        :key="i"
        class="tab-btn"
        :class="{ active: activeTab === i, 'has-error': hasTabError(i), 'tab-off': !isChannelEnabled(i) }"
        @click="activeTab = i"
      >
        {{ tabName(i) }}
      </button>
    </div>

    <div v-if="current && !isChannelEnabled(activeTab)" class="feature-off">
      <div class="feature-off-title">{{ t('dtu.featureDisabled') }}</div>
      <div class="feature-off-desc">{{ t('dtu.featureDisabledHint') }}</div>
      <button v-if="embedded" type="button" class="btn-link" @click="emit('goto-roles')">
        {{ t('dtu.gotoRoles') }}
      </button>
    </div>

    <form v-else-if="current">
      <div class="form-section" v-if="!embedded">
        <div class="form-group">
          <label>{{ t('dtu.enable') }}:</label>
          <select v-model.number="current.enable">
            <option :value="0">{{ t('common.disable') }}</option>
            <option :value="1">{{ t('common.enable') }}</option>
          </select>
        </div>
      </div>

      <template v-if="embedded || current.enable === 1">
        <div class="form-section">
          <div class="section-title">{{ t('dtu.uartSection') }}</div>
          <div class="hint-text">{{ fixedChannelHint(activeTab) }}</div>
          <div class="form-group" v-if="currentUart">
            <label>{{ t('uart.baudRate') }}:</label>
            <select v-model.number="currentUart.baud_rate">
              <option :value="1200">1200</option>
              <option :value="2400">2400</option>
              <option :value="4800">4800</option>
              <option :value="9600">9600</option>
              <option :value="19200">19200</option>
              <option :value="38400">38400</option>
              <option :value="57600">57600</option>
              <option :value="115200">115200</option>
              <option :value="230400">230400</option>
            </select>
          </div>
          <div class="form-group" v-if="currentUart">
            <label>{{ t('uart.dataBits') }}:</label>
            <select v-model.number="currentUart.data_bit">
              <option :value="7">7</option>
              <option :value="8">8</option>
            </select>
          </div>
          <div class="form-group" v-if="currentUart">
            <label>{{ t('uart.parity') }}:</label>
            <select v-model.number="currentUart.parity">
              <option :value="0">{{ t('uart.parityNone') }}</option>
              <option :value="1">{{ t('uart.parityOdd') }}</option>
              <option :value="2">{{ t('uart.parityEven') }}</option>
            </select>
          </div>
          <div class="form-group" v-if="currentUart">
            <label>{{ t('uart.stopBits') }}:</label>
            <select v-model.number="currentUart.stop_bit">
              <option :value="1">1</option>
              <option :value="2">2</option>
            </select>
          </div>
          <div class="form-group">
            <label>{{ t('dtu.packLen') }}:</label>
            <div class="input-wrapper">
              <input v-model.number="current.pack_len" type="number" min="5" max="2048"
                :class="{ 'input-error': !!getFieldError(activeTab, 'pack_len') }" />
              <span v-if="getFieldError(activeTab, 'pack_len')" class="field-error-text">
                {{ getFieldError(activeTab, 'pack_len') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('dtu.packTime') }}:</label>
            <div class="input-wrapper">
              <input v-model.number="current.pack_time" type="number" min="10" max="60000"
                :class="{ 'input-error': !!getFieldError(activeTab, 'pack_time') }" />
              <span v-if="getFieldError(activeTab, 'pack_time')" class="field-error-text">
                {{ getFieldError(activeTab, 'pack_time') }}
              </span>
            </div>
          </div>
        </div>

        <div class="form-section">
          <div class="form-group">
            <label>{{ t('dtu.workMode') }}:</label>
            <select v-model.number="current.wkmod">
              <option :value="0">{{ t('dtu.modeNet') }}</option>
              <option :value="1">{{ t('dtu.modeHttp') }}</option>
              <option :value="2">{{ t('dtu.modeMqtt') }}</option>
            </select>
          </div>
        </div>

        <!-- NET：数传专用 Socket（mode 非 HTTP） -->
        <div v-if="current.wkmod === 0" class="form-section">
          <div class="section-title">{{ t('dtu.sockSection') }}</div>
          <div v-if="getFieldError(activeTab, 'bind')" class="field-error-text block">
            {{ getFieldError(activeTab, 'bind') }}
          </div>
          <div class="hint-text">{{ t('dtu.sockHint') }}</div>
          <DtuSockFields v-if="currentSock" :sock="currentSock" />
        </div>

        <!-- HTTP：数传 Socket 强制 HTTP Client -->
        <div v-if="current.wkmod === 1" class="form-section">
          <div class="section-title">{{ t('dtu.modeHttp') }}</div>
          <div v-if="getFieldError(activeTab, 'bind')" class="field-error-text block">
            {{ getFieldError(activeTab, 'bind') }}
          </div>
          <div class="hint-text">{{ t('dtu.httpHint') }}</div>
          <DtuSockFields v-if="currentSock" :sock="currentSock" />
        </div>

        <!-- MQTT：连接参数 + 透传主题 -->
        <div v-if="current.wkmod === 2" class="form-section">
          <div class="section-title">{{ t('dtu.modeMqtt') }}</div>
          <div v-if="getFieldError(activeTab, 'bind')" class="field-error-text block">
            {{ getFieldError(activeTab, 'bind') }}
          </div>
          <div class="hint-text">{{ t('dtu.mqttConnHint') }}</div>

          <template v-if="currentMqtt">
            <div class="form-group">
              <label>{{ t('mqtt.enable') }}:</label>
              <select v-model.number="currentMqtt.enable">
                <option :value="0">{{ t('common.disable') }}</option>
                <option :value="1">{{ t('common.enable') }}</option>
              </select>
            </div>
            <template v-if="currentMqtt.enable === 1">
              <div class="form-group">
                <label>{{ t('mqtt.protocol') }}:</label>
                <select v-model.number="currentMqtt.mqtt_ver">
                  <option :value="3">MQTT-3.1</option>
                  <option :value="4">MQTT-3.1.1</option>
                </select>
              </div>
              <div class="form-group">
                <label>{{ t('mqtt.clientId') }}:</label>
                <input v-model="currentMqtt.client_id" type="text" />
              </div>
              <div class="form-group">
                <label>{{ t('mqtt.serverAddress') }}:</label>
                <input v-model="currentMqtt.server_ip" type="text" />
              </div>
              <div class="form-group">
                <label>{{ t('mqtt.remotePort') }}:</label>
                <input v-model.number="currentMqtt.server_port" type="number" />
              </div>
              <div class="form-group">
                <label>{{ t('mqtt.keepalive') }}:</label>
                <input v-model.number="currentMqtt.keepalive" type="number" />
              </div>
              <div class="form-group">
                <label>{{ t('mqtt.reconnectInterval') }}:</label>
                <input v-model.number="currentMqtt.reconn_space" type="number" />
              </div>
              <div class="form-group">
                <label>{{ t('mqtt.cleanSession') }}:</label>
                <select v-model.number="currentMqtt.clean_session">
                  <option :value="0">{{ t('common.disable') }}</option>
                  <option :value="1">{{ t('common.enable') }}</option>
                </select>
              </div>
              <div class="form-group">
                <label>{{ t('mqtt.connectionAuth') }}:</label>
                <select v-model.number="currentMqtt.conn_verify">
                  <option :value="0">{{ t('common.disable') }}</option>
                  <option :value="1">{{ t('common.enable') }}</option>
                </select>
              </div>
              <template v-if="currentMqtt.conn_verify === 1">
                <div class="form-group">
                  <label>{{ t('mqtt.username') }}:</label>
                  <input v-model="currentMqtt.conn_user_name" type="text" />
                </div>
                <div class="form-group">
                  <label>{{ t('mqtt.password') }}:</label>
                  <input v-model="currentMqtt.conn_user_password" type="password" />
                </div>
              </template>
            </template>
          </template>

          <div class="section-title" style="margin-top: 20px;">{{ t('dtu.topicSection') }}</div>
          <div class="form-group">
            <label>{{ t('dtu.pubTopic') }}:</label>
            <div class="input-wrapper">
              <input v-model="current.pub_topic" type="text" maxlength="128"
                :class="{ 'input-error': !!getFieldError(activeTab, 'pub_topic') }" />
              <span v-if="getFieldError(activeTab, 'pub_topic')" class="field-error-text">
                {{ getFieldError(activeTab, 'pub_topic') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('dtu.prefixEnable') }}:</label>
            <select v-model.number="current.prefix_enable">
              <option :value="1">{{ t('dtu.prefixOn') }}</option>
              <option :value="0">{{ t('dtu.prefixOff') }}</option>
            </select>
          </div>
          <div class="section-title" style="margin-top: 20px;">{{ t('dtu.subList') }}</div>
          <div v-for="(sub, idx) in current.subsActive" :key="idx" class="sub-row">
            <span class="sub-index">#{{ idx + 1 }}</span>
            <input v-model="sub.topic" type="text" maxlength="128" :placeholder="t('dtu.subTopic')" class="sub-topic" />
            <select v-model.number="sub.qos" class="sub-qos">
              <option :value="0">QoS0</option>
              <option :value="1">QoS1</option>
              <option :value="2">QoS2</option>
            </select>
            <button type="button" class="btn-small btn-danger" @click="removeSub(idx)">{{ t('common.delete') }}</button>
          </div>
          <button type="button" class="btn-outline" :disabled="current.subsActive.length >= 15" @click="addSub">
            {{ t('dtu.addSub') }}
          </button>
        </div>
      </template>
    </form>

    <div class="button-group" v-if="isChannelEnabled(activeTab)">
      <button class="btn-save" @click="saveConfig" :disabled="!isValid" :class="{ 'btn-disabled': !isValid }">
        {{ t('common.save') }}
      </button>
    </div>

    <div v-if="showRestartModal" class="modal-overlay">
      <div class="modal">
        <div class="modal-header"><h3>{{ t('common.saveSuccess') }}</h3></div>
        <div class="modal-body">
          <p>{{ t('dtu.restartRequired') }}</p>
          <div class="modal-actions">
            <button class="btn-restart" @click="handleRestart">{{ t('system.restartNow') }}</button>
            <button class="btn-continue" @click="showRestartModal = false">{{ t('socket.continueConfig') }}</button>
          </div>
        </div>
      </div>
    </div>

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
import { ref, computed, onMounted, watch } from 'vue'
import { getDtuConfig, getUartConfig, updateConfig } from '../api/services'
import { useI18n } from '../i18n/useI18n.js'
import { useServiceControl } from '../composables/useServiceControl.js'
import DtuSockFields from '../components/DtuSockFields.vue'

const props = defineProps({
  embedded: { type: Boolean, default: false },
  skipEdgeCheck: { type: Boolean, default: false },
  autoLoad: { type: Boolean, default: true },
  enabledChannels: { type: Array, default: null },
  visibleChannels: { type: Array, default: null }
})

const emit = defineEmits(['saved', 'goto-roles'])

const { t } = useI18n()
const { isServiceRestarting, restartService } = useServiceControl()

const loading = ref(props.autoLoad)
const error = ref(null)
const showRestartModal = ref(false)
const activeTab = ref(0)
const dtuList = ref([])
const sockList = ref([])
const mqttList = ref([])
const uartList = ref([])

const tabName = (i) => `Uart${i + 1}`

const isChannelEnabled = (index) => {
  if (!props.embedded) return true
  const list = Array.isArray(props.enabledChannels)
    ? props.enabledChannels
    : (Array.isArray(props.visibleChannels) ? props.visibleChannels : null)
  if (list === null) return true
  return list.includes(index)
}

const visibleTabIndices = computed(() => {
  if (props.embedded) return dtuList.value.map((_, i) => i)
  if (!Array.isArray(props.visibleChannels) || props.visibleChannels.length === 0) {
    return dtuList.value.map((_, i) => i)
  }
  return props.visibleChannels.filter(i => i >= 0 && i < dtuList.value.length)
})

const current = computed(() => dtuList.value[activeTab.value] || null)
const currentSock = computed(() => sockList.value[activeTab.value] || null)
const currentMqtt = computed(() => mqttList.value[activeTab.value] || null)
const currentUart = computed(() => uartList.value[activeTab.value] || null)

const fixedChannelHint = (uartIndex) => {
  if (uartIndex === 0) return t('dtu.fixedChannelUart1')
  return t('dtu.fixedChannelUart2')
}

watch(() => current.value?.wkmod, (mod) => {
  const sock = currentSock.value
  if (!sock) return
  if (mod === 1) {
    sock.mode = 3
    sock.enable = 1
  } else if (mod === 0 && Number(sock.mode) === 3) {
    sock.mode = 0
  }
})

const channelErrors = (ch, index) => {
  const errors = {}
  const treatEnabled = props.embedded ? isChannelEnabled(index) : (ch && ch.enable === 1)
  if (!ch || !treatEnabled) return errors

  const pl = Number(ch.pack_len)
  if (!Number.isInteger(pl) || pl < 5 || pl > 2048) errors.pack_len = t('dtu.invalidPackLen')
  const pt = Number(ch.pack_time)
  if (!Number.isInteger(pt) || pt < 10 || pt > 60000) errors.pack_time = t('dtu.invalidPackTime')

  const s = sockList.value[index]
  const m = mqttList.value[index]

  if (ch.wkmod === 0) {
    // Socket 关闭仅表示功能不生效，仍允许保存其它配置
    if (s && Number(s.enable) === 1 && Number(s.mode) === 3) {
      errors.bind = t('dtu.netModeConflict')
    }
  } else if (ch.wkmod === 1) {
    if (s && Number(s.enable) === 1 && Number(s.mode) !== 3) {
      errors.bind = t('dtu.httpModeRequired')
    }
  } else if (ch.wkmod === 2) {
    // MQTT 关闭时不强制主题；开启时至少配一项才有意义
    if (m && Number(m.enable) === 1) {
      const pub = (ch.pub_topic || '').trim()
      const hasSub = (ch.subsActive || []).some(sub => (sub.topic || '').trim())
      if (!pub && !hasSub) errors.pub_topic = t('dtu.topicRequired')
    }
  }
  return errors
}

const allErrors = computed(() => {
  const map = {}
  dtuList.value.forEach((ch, i) => {
    const e = channelErrors(ch, i)
    Object.keys(e).forEach((k) => { map[`${i}_${k}`] = e[k] })
  })
  return map
})

const isValid = computed(() => Object.keys(allErrors.value).length === 0)
const getFieldError = (index, field) => allErrors.value[`${index}_${field}`]
const hasTabError = (index) => Object.keys(allErrors.value).some(k => k.startsWith(`${index}_`))

const addSub = () => {
  const ch = current.value
  if (!ch || ch.subsActive.length >= 15) return
  ch.subsActive.push({ topic: '', qos: 0 })
}

const removeSub = (idx) => {
  const ch = current.value
  if (!ch) return
  ch.subsActive.splice(idx, 1)
}

const normalizeSubs = (subs) => {
  const list = []
  if (!subs) return list
  for (let i = 0; i < 15; i++) {
    const s = Array.isArray(subs) ? subs[i] : (subs[i] || subs[String(i + 1)] || subs[String(i)])
    if (s && (s.topic || '').trim()) list.push({ topic: s.topic, qos: Number(s.qos) || 0 })
  }
  return list
}

const emptyChannel = (uartIndex) => ({
  enable: 0,
  wkmod: 0,
  uart_index: uartIndex,
  sock_index: uartIndex,
  mqtt_index: uartIndex,
  pack_len: 1024,
  pack_time: 50,
  pub_topic: '',
  prefix_enable: 1,
  subsActive: []
})

const normalizeChannel = (raw, uartIndex) => ({
  enable: Number(raw?.enable) || 0,
  wkmod: Number(raw?.wkmod) || 0,
  uart_index: uartIndex,
  sock_index: uartIndex,
  mqtt_index: uartIndex,
  pack_len: Number(raw?.pack_len) || 1024,
  pack_time: Number(raw?.pack_time) || 50,
  pub_topic: raw?.pub_topic || '',
  prefix_enable: raw?.prefix_enable === undefined ? 1 : Number(raw.prefix_enable),
  subsActive: normalizeSubs(raw?.subs)
})

const emptySock = (i) => ({
  enable: 0,
  name: `SOCK_DTU${i}`,
  mode: 0,
  tcpc: {
    server_ip: '', local_port: 0, server_port: 8234, dns_timeout: 30, reconn_interval: 5,
    ssl_mode: 0, ssl_verify: 0, ssl_server_name: 'null', ssl_client_name: 'null', ssl_client_key: 'null',
    regp_en: 0, regp_fmt: 0, regp_ctx: '', regp_tim: 0, hrtp_en: 0, hrtp_fmt: 0, hrtp_ctx: '', hrtp_tim: 60
  },
  tcps: { local_port: 8029, conn_max_num: 4, timeout_handling: 0, idle_handling: 0, idle_timeout: 3600 },
  udpc: {
    server_ip: '192.168.20.21', local_port: 0, server_port: 1593, dns_timeout: 30, ip_port_verify: 0,
    short_en: 0, short_timeout: 60, keepalive: 0, sock_timeout: 5
  },
  httpc: {
    mode: 0, url: '/Api/echo?', header: 'Connection: close\r\n', cut_header: 1,
    server_ip: 'test.hlktech.com', server_port: 80, resp_timeout: 10, local_port: 0
  }
})

const normalizeSock = (raw, i) => {
  const base = emptySock(i)
  if (!raw) return base
  return {
    ...base,
    ...raw,
    name: `SOCK_DTU${i}`,
    tcpc: { ...base.tcpc, ...(raw.tcpc || {}) },
    tcps: { ...base.tcps, ...(raw.tcps || {}) },
    udpc: { ...base.udpc, ...(raw.udpc || {}) },
    httpc: { ...base.httpc, ...(raw.httpc || {}) }
  }
}

const emptyMqtt = (i) => ({
  enable: 0,
  name: `MQTT_DTU${i}`,
  mqtt_ver: 4,
  client_id: '',
  server_ip: '',
  server_port: 1883,
  keepalive: 60,
  reconn_space: 5,
  clean_session: 1,
  conn_verify: 0,
  conn_user_name: '',
  conn_user_password: '',
  ssl_mode: 0,
  ssl_verify: 0,
  will_flag: 0,
  will: { topic: '/will', msg: 'offline', qos: 0, retention: 0 }
})

const normalizeMqtt = (raw, i) => ({
  ...emptyMqtt(i),
  ...(raw || {}),
  name: `MQTT_DTU${i}`,
  will: { ...emptyMqtt(i).will, ...(raw?.will || {}) }
})

const loadData = async () => {
  try {
    loading.value = true
    error.value = null
    const [dtu, uart] = await Promise.all([getDtuConfig(), getUartConfig()])
    let arr = []
    if (Array.isArray(dtu?.DTU)) {
      arr = dtu.DTU
    } else if (dtu && (dtu.enable !== undefined || dtu.wkmod !== undefined)) {
      const idx = Number(dtu.uart_index) || 0
      arr = [emptyChannel(0), emptyChannel(1)]
      arr[Math.min(Math.max(idx, 0), 1)] = dtu
    }
    dtuList.value = [normalizeChannel(arr[0], 0), normalizeChannel(arr[1], 1)]

    const dtuSocks = Array.isArray(dtu?.SOCK) ? dtu.SOCK : []
    sockList.value = [normalizeSock(dtuSocks[0], 0), normalizeSock(dtuSocks[1], 1)]

    const mqtts = Array.isArray(dtu?.MQTT) ? dtu.MQTT : []
    mqttList.value = [normalizeMqtt(mqtts[0], 0), normalizeMqtt(mqtts[1], 1)]

    const uarts = Array.isArray(uart?.UART) ? uart.UART : []
    uartList.value = [
      { baud_rate: 115200, data_bit: 8, stop_bit: 1, parity: 0, ...(uarts[0] || {}) },
      { baud_rate: 9600, data_bit: 8, stop_bit: 1, parity: 0, ...(uarts[1] || {}) }
    ]

    const tabs = visibleTabIndices.value
    if (tabs.length && !tabs.includes(activeTab.value)) activeTab.value = tabs[0]
  } catch (err) {
    error.value = t('common.loadError') + ': ' + err.message
    throw err
  } finally {
    loading.value = false
  }
}

const buildDtuSockParams = (sock, i) => {
  const p = []
  const pre = (ns, key, val) => p.push(`${ns}_DTU_SOCK[${i}].${key}=${val}`)
  pre('n', 'enable', sock.enable)
  pre('n', 'mode', sock.mode)
  pre('s', 'tcpc.server_ip', sock.tcpc.server_ip || '')
  pre('n', 'tcpc.local_port', sock.tcpc.local_port ?? 0)
  pre('n', 'tcpc.server_port', sock.tcpc.server_port ?? 8234)
  pre('n', 'tcpc.reconn_interval', sock.tcpc.reconn_interval ?? 5)
  pre('n', 'tcpc.ssl_mode', sock.tcpc.ssl_mode || 0)
  pre('n', 'tcpc.ssl_verify', sock.tcpc.ssl_verify || 0)
  pre('n', 'tcpc.regp_en', sock.tcpc.regp_en || 0)
  pre('n', 'tcpc.regp_tim', sock.tcpc.regp_tim || 0)
  pre('n', 'tcpc.regp_fmt', sock.tcpc.regp_fmt || 0)
  pre('s', 'tcpc.regp_ctx', sock.tcpc.regp_ctx || '')
  pre('n', 'tcpc.hrtp_en', sock.tcpc.hrtp_en || 0)
  pre('n', 'tcpc.hrtp_tim', sock.tcpc.hrtp_tim || 60)
  pre('n', 'tcpc.hrtp_fmt', sock.tcpc.hrtp_fmt || 0)
  pre('s', 'tcpc.hrtp_ctx', sock.tcpc.hrtp_ctx || '')
  pre('n', 'tcps.local_port', sock.tcps.local_port ?? 8029)
  pre('n', 'tcps.conn_max_num', sock.tcps.conn_max_num ?? 4)
  pre('n', 'tcps.timeout_handling', sock.tcps.timeout_handling ?? 0)
  const udpc = sock.udpc || {}
  pre('s', 'udpc.server_ip', udpc.server_ip || '')
  pre('n', 'udpc.local_port', udpc.local_port ?? 0)
  pre('n', 'udpc.server_port', udpc.server_port ?? 1593)
  pre('n', 'udpc.short_en', udpc.short_en ?? 0)
  pre('n', 'udpc.short_timeout', udpc.short_timeout ?? 60)
  pre('n', 'udpc.keepalive', udpc.keepalive ?? 0)
  pre('n', 'udpc.sock_timeout', udpc.sock_timeout ?? 5)
  const httpc = sock.httpc || {}
  pre('n', 'httpc.mode', httpc.mode ?? 0)
  pre('s', 'httpc.url', encodeURIComponent(httpc.url || ''))
  pre('s', 'httpc.header', encodeURIComponent(httpc.header || ''))
  pre('s', 'httpc.server_ip', httpc.server_ip || '')
  pre('n', 'httpc.server_port', httpc.server_port ?? 80)
  pre('n', 'httpc.resp_timeout', httpc.resp_timeout ?? 10)
  pre('n', 'httpc.cut_header', httpc.cut_header ?? 1)
  pre('n', 'httpc.local_port', httpc.local_port ?? 0)
  return p
}

const buildMqttParams = (mqtt, i) => {
  const p = []
  const pre = (ns, key, val) => p.push(`${ns}_DTU_MQTT[${i}].${key}=${val}`)
  pre('n', 'enable', mqtt.enable)
  pre('s', 'name', mqtt.name || `MQTT_DTU${i}`)
  pre('n', 'mqtt_ver', mqtt.mqtt_ver || 4)
  pre('s', 'client_id', mqtt.client_id || '')
  pre('s', 'server_ip', mqtt.server_ip || '')
  pre('n', 'server_port', mqtt.server_port || 1883)
  pre('n', 'keepalive', mqtt.keepalive || 60)
  pre('n', 'reconn_space', mqtt.reconn_space || 5)
  pre('n', 'clean_session', mqtt.clean_session || 0)
  pre('n', 'conn_verify', mqtt.conn_verify || 0)
  pre('s', 'conn_user_name', mqtt.conn_user_name || '')
  pre('s', 'conn_user_password', mqtt.conn_user_password || '')
  pre('n', 'ssl_mode', mqtt.ssl_mode || 0)
  pre('n', 'ssl_verify', mqtt.ssl_verify || 0)
  return p
}

const buildParams = () => {
  const p = []
  dtuList.value.forEach((c, i) => {
    let enable = c.enable
    if (props.embedded) enable = isChannelEnabled(i) ? 1 : 0
    p.push(`n_DTU[${i}].enable=${enable}`)
    p.push(`n_DTU[${i}].wkmod=${c.wkmod}`)
    p.push(`n_DTU[${i}].sock_index=${i}`)
    p.push(`n_DTU[${i}].mqtt_index=${i}`)
    p.push(`n_DTU[${i}].pack_len=${c.pack_len}`)
    p.push(`n_DTU[${i}].pack_time=${c.pack_time}`)
    p.push(`s_DTU[${i}].pub_topic=${encodeURIComponent(c.pub_topic || '')}`)
    p.push(`n_DTU[${i}].prefix_enable=${c.prefix_enable}`)
    for (let s = 1; s <= 15; s++) {
      const sub = c.subsActive[s - 1] || { topic: '', qos: 0 }
      p.push(`s_DTU[${i}].sub${s}_topic=${encodeURIComponent(sub.topic || '')}`)
      p.push(`n_DTU[${i}].sub${s}_qos=${sub.qos || 0}`)
    }

    const treatOn = props.embedded ? isChannelEnabled(i) : enable === 1
    if (treatOn) {
      const uart = uartList.value[i]
      if (uart) {
        p.push(`n_UART[${i}].baud_rate=${uart.baud_rate}`)
        p.push(`n_UART[${i}].data_bit=${uart.data_bit}`)
        p.push(`n_UART[${i}].stop_bit=${uart.stop_bit}`)
        p.push(`n_UART[${i}].parity=${uart.parity}`)
      }
      if (c.wkmod === 0 || c.wkmod === 1) {
        const sock = sockList.value[i]
        if (sock) p.push(...buildDtuSockParams(sock, i))
      }
      if (c.wkmod === 2) {
        const mqtt = mqttList.value[i]
        if (mqtt) p.push(...buildMqttParams(mqtt, i))
      }
    }
  })
  return p.join('&')
}

const anyEnabled = () => dtuList.value.some(c => Number(c.enable) === 1)

const saveConfig = async () => {
  try {
    if (!isValid.value) return false
    await updateConfig('dtu', buildParams())
    showRestartModal.value = true
    emit('saved')
    return true
  } catch (err) {
    alert(t('common.saveFailed') + ': ' + err.message)
    return false
  }
}

const handleRestart = async () => {
  showRestartModal.value = false
  await restartService()
}

watch(visibleTabIndices, (tabs) => {
  if (tabs.length && !tabs.includes(activeTab.value)) activeTab.value = tabs[0]
})

watch(() => props.enabledChannels, () => {
  if (!props.embedded) return
  if (isChannelEnabled(activeTab.value)) return
  const firstOn = visibleTabIndices.value.find(i => isChannelEnabled(i))
  if (firstOn !== undefined) activeTab.value = firstOn
})

onMounted(() => {
  if (props.autoLoad) loadData()
})

defineExpose({
  saveConfig,
  isValid,
  anyEnabled,
  loadData,
  buildParams
})
</script>

<style scoped>
.description-box { background: white; padding: 15px; border-bottom: 1px solid #e8e8e8; }
.desc-title { font-weight: 600; font-size: 14px; margin-bottom: 6px; }
.desc-content { font-size: 12px; color: #666; }
.tabs { display: flex; gap: 10px; margin: 20px 0 0; border-bottom: 1px solid #e8e8e8; padding: 0 15px; }
.tab-btn { padding: 8px 20px; background-color: #494641; color: white; border: none; cursor: pointer; border-radius: 4px 4px 0 0; font-size: 13px; font-weight: 600; }
.tab-btn:hover { background-color: #ff8800; }
.tab-btn.active { background-color: #0066cc; }
.tab-btn.has-error { background-color: #d32f2f; }
.tab-btn.active.has-error { background-color: #c62828; }
.tab-btn.tab-off { opacity: 0.65; }
.feature-off {
  padding: 48px 20px;
  text-align: center;
  background: white;
  border-bottom: 1px solid #e8e8e8;
}
.feature-off-title { font-size: 15px; font-weight: 600; color: #666; margin-bottom: 8px; }
.feature-off-desc { font-size: 13px; color: #888; margin-bottom: 16px; line-height: 1.5; }
.btn-link {
  background: none;
  border: none;
  color: #0066cc;
  cursor: pointer;
  font-size: 13px;
  font-weight: 600;
  text-decoration: underline;
}
.form-section { padding: 20px 15px; background: white; border-bottom: 1px solid #e8e8e8; }
.section-title { font-weight: 600; font-size: 13px; color: #333; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 1px solid #e8e8e8; }
.form-group { display: flex; align-items: flex-start; margin-bottom: 15px; gap: 20px; }
.form-group label { font-weight: 600; width: 160px; text-align: right; flex-shrink: 0; margin-top: 8px; }
.form-group input, .form-group select { width: 100%; max-width: 320px; padding: 8px 12px; border: 1px solid #ddd; border-radius: 4px; font-size: 13px; }
.input-wrapper { flex: 1; max-width: 320px; display: flex; flex-direction: column; }
.input-error { border-color: #d32f2f !important; background: #ffebee; }
.field-error-text { color: #d32f2f; font-size: 12px; margin-top: 4px; }
.field-error-text.block { margin: 8px 0 8px 15px; }
.hint-text { color: #888; font-size: 12px; margin: 0 0 12px 15px; line-height: 1.5; }
.sub-row { display: flex; align-items: center; gap: 8px; margin-bottom: 10px; margin-left: 40px; }
.sub-index { width: 28px; font-size: 12px; color: #666; }
.sub-topic { flex: 1; max-width: 280px; padding: 6px 10px; border: 1px solid #ddd; border-radius: 4px; }
.sub-qos { width: 80px; padding: 6px; border: 1px solid #ddd; border-radius: 4px; }
.btn-outline { margin-left: 40px; padding: 6px 16px; background: white; border: 1px solid #0066cc; color: #0066cc; border-radius: 4px; cursor: pointer; }
.btn-outline:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-small { padding: 4px 10px; border: none; border-radius: 4px; cursor: pointer; font-size: 12px; }
.btn-danger { background: #d32f2f; color: white; }
.button-group { display: flex; justify-content: center; padding: 20px; background: #f9f9f9; }
.btn-save { padding: 10px 40px; background: #0066cc; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: 600; }
.btn-disabled { background: #ccc !important; cursor: not-allowed; }
.loading { text-align: center; padding: 40px; color: #666; }
.error { background: #ffebee; border: 1px solid #ffcdd2; color: #c62828; padding: 12px; border-radius: 4px; margin-bottom: 16px; }
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex; justify-content: center; align-items: center; z-index: 1000; }
.modal { background: white; border-radius: 8px; width: 400px; overflow: hidden; }
.modal-header { padding: 15px 20px; border-bottom: 1px solid #eee; background: #f8f9fa; }
.modal-header h3 { margin: 0; font-size: 16px; }
.modal-body { padding: 20px; text-align: center; }
.modal-actions { display: flex; justify-content: center; gap: 15px; margin-top: 20px; }
.btn-restart { padding: 8px 20px; background: #0066cc; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: 600; }
.btn-continue { padding: 8px 20px; background: white; color: #666; border: 1px solid #ddd; border-radius: 4px; cursor: pointer; font-weight: 600; }
.loading-spinner {
  width: 36px; height: 36px; margin: 0 auto;
  border: 3px solid #e5e7eb; border-top-color: #0066cc; border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
</style>
