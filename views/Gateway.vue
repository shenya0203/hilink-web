<template>
  <div>
    <div v-if="loading" class="loading">{{ t('common.loading') }}</div>
    <div v-if="error" class="error">{{ error }}</div>

    <div class="description-box">
      <div class="desc-title">{{ t('gatewayPage.title') }}</div>
      <div class="desc-content">{{ t('gatewayPage.description') }}</div>
    </div>

    <div class="tabs">
      <button
        v-for="tab in mainTabs"
        :key="tab.id"
        type="button"
        class="tab-btn"
        :class="{ active: mainTab === tab.id }"
        @click="mainTab = tab.id"
      >
        {{ tab.label }}
      </button>
    </div>

    <!-- Tab: 串口角色 -->
    <div v-show="mainTab === 'role'" class="tab-panel">
      <div class="form-section">
        <div
          v-for="(role, i) in pendingRoles"
          :key="i"
          class="form-group"
        >
          <label>{{ t('gatewayPage.uartRole', { n: i + 1 }) }}:</label>
          <select v-model.number="pendingRoles[i]">
            <option :value="0">{{ t('gatewayPage.modeOff') }}</option>
            <option :value="1">{{ t('gatewayPage.modeDtu') }}</option>
            <option :value="2">{{ t('gatewayPage.modeEdge') }}</option>
          </select>
        </div>
        <div class="hint-text">{{ t('gatewayPage.modeHint') }}</div>
        <div class="mode-actions">
          <button
            class="btn-save"
            :disabled="!rolesDirty"
            :class="{ 'btn-disabled': !rolesDirty }"
            @click="applyRoles"
          >
            {{ t('gatewayPage.applyMode') }}
          </button>
          <span v-if="rolesDirty" class="pending-tip">{{ t('gatewayPage.pendingTip') }}</span>
        </div>
      </div>
    </div>

    <!-- Tab: 数传（始终可进；未开数传的串口在子页提示） -->
    <div v-show="mainTab === 'dtu'" class="tab-panel">
      <Dtu
        ref="dtuRef"
        embedded
        skip-edge-check
        :enabled-channels="dtuChannelIndices"
        @saved="onChildSaved"
        @goto-roles="mainTab = 'role'"
      />
    </div>

    <!-- Tab: 边缘（始终可进；支持纯 TCP） -->
    <div v-show="mainTab === 'edge'" class="tab-panel">
      <EdgeCompute :allowed-serial-ports="edgeSerialPorts" />
    </div>

    <div v-if="showRestartModal" class="modal-overlay">
      <div class="modal">
        <div class="modal-header"><h3>{{ t('common.saveSuccess') }}</h3></div>
        <div class="modal-body">
          <p>{{ t('gatewayPage.restartRequired') }}</p>
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
import { ref, computed, onMounted } from 'vue'
import Dtu from './Dtu.vue'
import EdgeCompute from './EdgeCompute.vue'
import { getDtuConfig, getUartConfig, updateConfig } from '../api/services'
import { useI18n } from '../i18n/useI18n.js'
import { useServiceControl } from '../composables/useServiceControl.js'

const { t } = useI18n()
const { isServiceRestarting, restartService } = useServiceControl()

const ROLE_OFF = 0
const ROLE_DTU = 1
const ROLE_EDGE = 2

const loading = ref(true)
const error = ref(null)
const pendingRoles = ref([ROLE_OFF, ROLE_OFF])
const activeRoles = ref([ROLE_OFF, ROLE_OFF])
const showRestartModal = ref(false)
const dtuRef = ref(null)
const mainTab = ref('role')

const mainTabs = computed(() => [
  { id: 'role', label: t('gatewayPage.tabRole') },
  { id: 'dtu', label: t('gatewayPage.tabDtu') },
  { id: 'edge', label: t('gatewayPage.tabEdge') }
])

const rolesDirty = computed(() =>
  pendingRoles.value.some((r, i) => r !== activeRoles.value[i])
)

const dtuChannelIndices = computed(() =>
  activeRoles.value
    .map((r, i) => (r === ROLE_DTU ? i : -1))
    .filter(i => i >= 0)
)

// 空数组 = 无 RTU 口（仅 TCP）；勿回退成 [1,2]
const edgeSerialPorts = computed(() =>
  activeRoles.value
    .map((r, i) => (r === ROLE_EDGE ? i + 1 : -1))
    .filter(n => n > 0)
)

const inferRole = (uartIndex, dtu, uart) => {
  const ch = Array.isArray(dtu?.DTU) ? dtu.DTU[uartIndex] : null
  if (Number(ch?.enable) === 1) return ROLE_DTU
  const u = Array.isArray(uart?.UART) ? uart.UART[uartIndex] : null
  if (Number(u?.work_mode) === 1) return ROLE_EDGE
  return ROLE_OFF
}

const buildDtuRoleParams = (roles) => {
  return [0, 1].map(i => {
    const enable = roles[i] === ROLE_DTU ? 1 : 0
    return `n_DTU[${i}].enable=${enable}&n_role[${i}]=${roles[i]}`
  }).join('&')
}

const loadRoles = async () => {
  try {
    loading.value = true
    error.value = null
    const [dtu, uart] = await Promise.all([getDtuConfig(), getUartConfig()])
    const roles = [inferRole(0, dtu, uart), inferRole(1, dtu, uart)]
    pendingRoles.value = [...roles]
    activeRoles.value = [...roles]
  } catch (err) {
    error.value = t('common.loadError') + ': ' + err.message
  } finally {
    loading.value = false
  }
}

const applyRoles = async () => {
  const roles = pendingRoles.value.map(Number)
  try {
    await updateConfig('dtu', buildDtuRoleParams(roles))
    // 有串口选边缘时打开 all_en；没有时不强制关闭，避免关掉纯 TCP 边缘
    if (roles.some(r => r === ROLE_EDGE)) {
      await updateConfig('edge', 'n_all_en=1')
    }
    activeRoles.value = [...roles]
    showRestartModal.value = true
  } catch (err) {
    alert(t('common.saveFailed') + ': ' + err.message)
  }
}

const onChildSaved = () => {}

const handleRestart = async () => {
  showRestartModal.value = false
  await restartService()
}

onMounted(() => { loadRoles() })
</script>

<style scoped>
.description-box { background: white; padding: 15px; border-bottom: 1px solid #e8e8e8; }
.desc-title { font-weight: 600; font-size: 14px; margin-bottom: 6px; }
.desc-content { font-size: 12px; color: #666; }
.tabs {
  display: flex;
  gap: 10px;
  margin: 0;
  border-bottom: 1px solid #e8e8e8;
  padding: 0 15px;
  background: white;
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
}
.tab-btn:hover { background-color: #ff8800; }
.tab-btn.active { background-color: #0066cc; }
.tab-panel { background: white; }
.form-section { padding: 20px 15px; background: white; border-bottom: 1px solid #e8e8e8; }
.form-group { display: flex; align-items: flex-start; margin-bottom: 12px; gap: 20px; }
.form-group label { font-weight: 600; width: 160px; text-align: right; flex-shrink: 0; margin-top: 8px; }
.form-group select { width: 100%; max-width: 320px; padding: 8px 12px; border: 1px solid #ddd; border-radius: 4px; font-size: 13px; }
.hint-text { color: #888; font-size: 12px; margin-left: 180px; margin-bottom: 12px; }
.mode-actions { display: flex; align-items: center; gap: 16px; margin-left: 180px; }
.btn-save { padding: 10px 32px; background: #0066cc; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: 600; }
.btn-disabled { background: #ccc !important; cursor: not-allowed; }
.pending-tip { color: #e65100; font-size: 12px; }
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
