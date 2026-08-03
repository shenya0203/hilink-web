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
          <div class="form-group">
            <label>{{ t('dtu.workMode') }}:</label>
            <select v-model.number="current.wkmod">
              <option :value="0">{{ t('dtu.modeNet') }}</option>
              <option :value="1">{{ t('dtu.modeHttp') }}</option>
              <option :value="2">{{ t('dtu.modeMqtt') }}</option>
            </select>
          </div>
        </div>

        <div class="form-section">
          <div class="section-title">{{ t('dtu.uartSection') }}</div>
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

        <div v-if="current.wkmod === 0" class="form-section">
          <div class="section-title">{{ t('dtu.modeNet') }}</div>
          <div v-if="getFieldError(activeTab, 'httpMode')" class="field-error-text block">
            {{ getFieldError(activeTab, 'httpMode') }}
          </div>
          <div class="hint-text">{{ fixedChannelHint(activeTab) }} {{ t('dtu.sockHint') }}</div>
        </div>

        <div v-if="current.wkmod === 1" class="form-section">
          <div class="section-title">{{ t('dtu.modeHttp') }}</div>
          <div v-if="getFieldError(activeTab, 'httpMode')" class="field-error-text block">
            {{ getFieldError(activeTab, 'httpMode') }}
          </div>
          <div class="hint-text">{{ fixedChannelHint(activeTab) }} {{ t('dtu.httpHint') }}</div>
        </div>

        <div v-if="current.wkmod === 2" class="form-section">
          <div class="section-title">{{ t('dtu.modeMqtt') }}</div>
          <div class="hint-text">{{ fixedChannelHint(activeTab) }} {{ t('dtu.mqttConnHint') }}</div>

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
import { getDtuConfig, getCommTunnel, updateConfig } from '../api/services'
import { useI18n } from '../i18n/useI18n.js'
import { useServiceControl } from '../composables/useServiceControl.js'

const props = defineProps({
  embedded: { type: Boolean, default: false },
  skipEdgeCheck: { type: Boolean, default: false },
  // 嵌入时：可配置数传的通道下标；未列入的通道显示「功能未开启」。null = 全部可配
  enabledChannels: { type: Array, default: null },
  // 兼容旧 prop：若传入则等同于只展示这些通道（已废弃，优先用 enabledChannels）
  visibleChannels: { type: Array, default: null }
})

const emit = defineEmits(['saved', 'goto-roles'])

const { t } = useI18n()
const { isServiceRestarting, restartService } = useServiceControl()

const loading = ref(true)
const error = ref(null)
const showRestartModal = ref(false)
const activeTab = ref(0)
const dtuList = ref([])
const sockList = ref([])

const tabName = (i) => `Uart${i + 1}`

const isChannelEnabled = (index) => {
  if (!props.embedded) return true
  const list = Array.isArray(props.enabledChannels)
    ? props.enabledChannels
    : (Array.isArray(props.visibleChannels) ? props.visibleChannels : null)
  if (list === null) return true
  return list.includes(index)
}

// 嵌入时始终展示两路，便于看到未开启状态
const visibleTabIndices = computed(() => {
  if (props.embedded) {
    return dtuList.value.map((_, i) => i)
  }
  if (!Array.isArray(props.visibleChannels) || props.visibleChannels.length === 0) {
    return dtuList.value.map((_, i) => i)
  }
  return props.visibleChannels.filter(i => i >= 0 && i < dtuList.value.length)
})

const current = computed(() => dtuList.value[activeTab.value] || null)

/** Uart1→SOCKA/MQTT1，Uart2→SOCKB/MQTT2 */
const fixedChannelHint = (uartIndex) => {
  if (uartIndex === 0) return t('dtu.fixedChannelUart1')
  return t('dtu.fixedChannelUart2')
}

const channelErrors = (ch, index) => {
  const errors = {}
  const treatEnabled = props.embedded
    ? isChannelEnabled(index)
    : (ch && ch.enable === 1)
  if (!ch || !treatEnabled) return errors
  const pl = Number(ch.pack_len)
  if (!Number.isInteger(pl) || pl < 5 || pl > 2048) errors.pack_len = t('dtu.invalidPackLen')
  const pt = Number(ch.pack_time)
  if (!Number.isInteger(pt) || pt < 10 || pt > 60000) errors.pack_time = t('dtu.invalidPackTime')
  const s = sockList.value[index]
  if (ch.wkmod === 1) {
    if (!s || s.mode !== 3) errors.httpMode = t('dtu.httpModeRequired')
  }
  if (ch.wkmod === 0) {
    if (s && s.mode === 3) errors.httpMode = t('dtu.netModeConflict')
  }
  if (ch.wkmod === 2) {
    const pub = (ch.pub_topic || '').trim()
    const hasSub = (ch.subsActive || []).some(sub => (sub.topic || '').trim())
    if (!pub && !hasSub) errors.pub_topic = t('dtu.topicRequired')
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

const loadData = async () => {
  try {
    loading.value = true
    error.value = null
    const [dtu, tunnel] = await Promise.all([getDtuConfig(), getCommTunnel()])
    let arr = []
    if (Array.isArray(dtu?.DTU)) {
      arr = dtu.DTU
    } else if (dtu && (dtu.enable !== undefined || dtu.wkmod !== undefined)) {
      const idx = Number(dtu.uart_index) || 0
      arr = [emptyChannel(0), emptyChannel(1)]
      arr[Math.min(Math.max(idx, 0), 1)] = dtu
    }
    dtuList.value = [
      normalizeChannel(arr[0], 0),
      normalizeChannel(arr[1], 1)
    ]
    sockList.value = Array.isArray(tunnel?.SOCK) ? tunnel.SOCK : []
    if (!sockList.value.length) sockList.value = [{ name: 'SOCKA' }, { name: 'SOCKB' }]
    const tabs = visibleTabIndices.value
    if (tabs.length && !tabs.includes(activeTab.value)) {
      activeTab.value = tabs[0]
    }
  } catch (err) {
    error.value = t('common.loadError') + ': ' + err.message
  } finally {
    loading.value = false
  }
}

const buildParams = () => {
  const p = []
  dtuList.value.forEach((c, i) => {
    let enable = c.enable
    if (props.embedded) {
      enable = isChannelEnabled(i) ? 1 : 0
    }
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
  if (tabs.length && !tabs.includes(activeTab.value)) {
    activeTab.value = tabs[0]
  }
})

watch(() => props.enabledChannels, () => {
  if (!props.embedded) return
  if (isChannelEnabled(activeTab.value)) return
  const firstOn = visibleTabIndices.value.find(i => isChannelEnabled(i))
  if (firstOn !== undefined) activeTab.value = firstOn
})

onMounted(() => { loadData() })

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
.hint-text { color: #888; font-size: 12px; margin: 4px 15px 0; line-height: 1.5; }
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
</style>
