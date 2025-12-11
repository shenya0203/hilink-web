<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading">{{ t('common.loading') }}</div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

    <!-- 网络配置标题 -->
    <form>
      <legend>{{ t('network.title') }}</legend>
      <div class="config-subtitle">{{ t('network.description') }}</div>
    </form>

    <!-- 标签页选择 -->
    <div class="tabs">
      <button 
        class="tab-btn" 
        :class="{ active: activeTab === 'ethernet' }"
        @click="activeTab = 'ethernet'"
      >
        {{ t('network.tabPriority') }}
      </button>
      <button 
        class="tab-btn" 
        :class="{ active: activeTab === 'lte' }"
        @click="activeTab = 'lte'"
      >
        {{ t('network.tabEthernet') }}
      </button>
      <button 
        v-if="config.net_select !== '2'"
        class="tab-btn" 
        :class="{ active: activeTab === 'ltecat' }"
        @click="activeTab = 'ltecat'"
      >
        {{ t('network.tabLte') }}
      </button>
    </div>

    <!-- 网络优先选择部分 -->
    <form v-if="activeTab === 'ethernet'">
      <legend>{{ t('network.prioritySelect') }}</legend>
      <div class="form-section">
        <div class="form-group">
          <label>{{ t('network.networkPriority') }}:</label>
          <select v-model="config.net_select">
            <option value="0">{{ t('network.ethernetFirst') }}</option>
            <option value="1">{{ t('network.cellularFirst') }}</option>
            <option value="2">{{ t('network.ethernetOnly') }}</option>
          </select>
        </div>
        <div class="form-group">
          <label>{{ t('network.probePeriod') }}:</label>
          <input v-model="config.probe_period" type="text" placeholder="-" />
        </div>
        <div class="form-group">
          <label>{{ t('network.probeServer1') }}:</label>
          <input v-model="config.probe_server1" type="text" placeholder="-" />
        </div>
        <div class="form-group">
          <label>{{ t('network.probeServer2') }}:</label>
          <input v-model="config.probe_server2" type="text" placeholder="-" />
        </div>
      </div>
    </form>

    <!-- 以太网配置部分 -->
    <form v-if="activeTab === 'lte'" style="margin-top: 20px;">
      <legend>{{ t('network.ethernet') }}</legend>
      <div class="form-section">
        <div class="form-group">
          <label>{{ t('network.workMode') }}:</label>
          <select v-model="config.eth_mode">
            <option value="0">{{ t('network.staticMode') }}</option>
            <option value="1">{{ t('network.dhcpMode') }}</option>
          </select>
        </div>
        <div class="form-group">
          <label>{{ t('network.dnsMode') }}:</label>
          <select v-model="config.eth_dns_mode">
            <option value="0">{{ t('network.manualDns') }}</option>
            <option value="1">{{ t('network.autoDns') }}</option>
          </select>
        </div>
        <div v-if="config.eth_mode === '0'" class="form-group">
          <label>{{ t('network.lanIp') }}:</label>
          <input v-model="config.eth_ip" type="text" placeholder="" />
        </div>
        <div v-if="config.eth_mode === '0'" class="form-group">
          <label>{{ t('network.subnetMask') }}:</label>
          <input v-model="config.eth_netmask" type="text" placeholder="" />
        </div>
        <div v-if="config.eth_mode === '0'" class="form-group">
          <label>{{ t('network.gatewayAddress') }}:</label>
          <input v-model="config.eth_gw" type="text" placeholder="" />
        </div>
        <div class="form-group">
          <label>{{ t('network.primaryDns') }}:</label>
          <input v-model="config.eth_dns" type="text" placeholder="" :disabled="config.eth_dns_mode === '1'" />
        </div>
        <div class="form-group">
          <label>{{ t('network.backupDns') }}:</label>
          <input v-model="config.eth_sdns" type="text" placeholder="" :disabled="config.eth_dns_mode === '1'" />
        </div>
      </div>
    </form>

    <!-- LTE/CAT1 配置部分 -->
    <form v-if="activeTab === 'ltecat' && config.net_select !== '2'" style="margin-top: 20px;">
      <legend>{{ t('network.tabLte') }}</legend>
      <div class="form-section">
        <div class="form-group">
          <label>{{ t('network.simSwitch') }}:</label>
          <select v-model="config.lte_sim">
            <option value="0">{{ t('network.externalSimFirst') }}</option>
            <option value="1">{{ t('network.internalSimOnly') }}</option>
            <option value="2">{{ t('network.externalSimOnly') }}</option>
            <option value="3">{{ t('network.dualSimBackup') }}</option>
          </select>
        </div>
        <div class="form-group">
          <label>{{ t('network.apnName') }}:</label>
          <input v-model="config.lte_apn" type="text" placeholder="" />
        </div>
        <div class="form-group">
          <label>{{ t('network.username') }}:</label>
          <input v-model="config.lte_user" type="text" placeholder="" />
        </div>
        <div class="form-group">
          <label>{{ t('network.password') }}:</label>
          <input v-model="config.lte_pwd" type="password" placeholder="" />
        </div>
        <div class="form-group">
          <label>{{ t('network.authMethod') }}:</label>
          <select v-model="config.lte_auth">
            <option value="0">NONE</option>
            <option value="1">PAP</option>
            <option value="2">CHAP</option>
          </select>
        </div>
        <div class="form-group">
          <label>{{ t('network.dnsMode') }}:</label>
          <select v-model="config.lte_dns_mode">
            <option value="0">{{ t('network.manualDns') }}</option>
            <option value="1">{{ t('network.autoDns') }}</option>
          </select>
        </div>
        <div class="form-group">
          <label>{{ t('network.primaryDns') }}:</label>
          <input v-model="config.lte_dns" type="text" placeholder="" :disabled="config.lte_dns_mode === '1'" />
        </div>
        <div class="form-group">
          <label>{{ t('network.backupDns') }}:</label>
          <input v-model="config.lte_sdns" type="text" placeholder="" :disabled="config.lte_dns_mode === '1'" />
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
          <p>{{ t('network.restartRequired') }}</p>
          <div class="modal-actions">
            <button class="btn-restart" @click="handleRestart">{{ t('system.restartNow') }}</button>
            <button class="btn-continue" @click="handleContinue">{{ t('network.continueConfig') }}</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'
import { fetchNetworkConfigData, fetchNetworkData, fetchStatusData } from '../api/mockData'
import { updateConfig, restartDevice } from '../api/services'
import { useI18n } from '../i18n/useI18n.js'

// 使用 i18n
const { t } = useI18n()

// 响应式数据
const loading = ref(true)
const error = ref(null)
const activeTab = ref('ethernet')
const showRestartModal = ref(false)

// 配置对象
const config = ref({
  // 网络优先级
  net_select: '',
  probe_period: '',
  probe_server1: '',
  probe_server2: '',
  // 以太网
  eth_mode: '',
  eth_dns_mode: '',
  eth_ip: '',
  eth_netmask: '',
  eth_gw: '',
  eth_dns: '',
  eth_sdns: '',
  // LTE/CAT1
  lte_sim: '',
  lte_apn: '',
  lte_user: '',
  lte_pwd: '',
  lte_auth: '',
  lte_dns_mode: '',
  lte_dns: '',
  lte_sdns: ''
})

// 加载所有数据
const loadData = async () => {
  try {
    loading.value = true
    error.value = null
    
    const [status, networkFlex, netConfig] = await Promise.all([
      fetchStatusData(),
      fetchNetworkData(),
      fetchNetworkConfigData()
    ])
    
    console.log('=== 网络配置页面数据加载 ===')
    
    if (netConfig) {
      Object.assign(config.value, {
        net_select: String(netConfig.net_select),
        probe_period: String(netConfig.keepalive_period),
        probe_server1: netConfig.keepalive_addr[0],
        probe_server2: netConfig.keepalive_addr[1],
        eth_mode: String(netConfig.eth0.ip_mode),
        eth_dns_mode: String(netConfig.eth0.dns_mode),
        eth_ip: netConfig.eth0.sip,
        eth_netmask: netConfig.eth0.mip,
        eth_gw: netConfig.eth0.gip,
        eth_dns: netConfig.eth0.dns_ip[0],
        eth_sdns: netConfig.eth0.dns_ip[1],
        lte_sim: String(netConfig.cell.sim_switch),
        lte_apn: netConfig.cell.apn.addr || '',
        lte_user: netConfig.cell.apn.user || '',
        lte_pwd: netConfig.cell.apn.pswd || '',
        lte_auth: String(netConfig.cell.apn.auth),
        lte_dns_mode: String(netConfig.cell.dns_mode),
        lte_dns: netConfig.cell.dns_ip[0],
        lte_sdns: netConfig.cell.dns_ip[1]
      })
    }
    
    /*
    if (networkFlex) {
      if (networkFlex.eth) {
        Object.assign(config.value, {
          eth_ip: networkFlex.eth.ip || config.value.eth_ip,
          eth_netmask: networkFlex.eth.netmask || config.value.eth_netmask,
          eth_dns: networkFlex.eth.dns || config.value.eth_dns,
          eth_sdns: networkFlex.eth.sdns || config.value.eth_sdns
        })
      }
      
      if (networkFlex.lte) {
        Object.assign(config.value, {
          lte_dns: networkFlex.lte.lte_dns || config.value.lte_dns,
          lte_sdns: networkFlex.lte.lte_sdns || config.value.lte_sdns
        })
      }
    }
    */
    
    console.log('最终配置对象:', config.value)
    
  } catch (err) {
    error.value = t('common.loadError') + ': ' + err.message
    console.error('配置加载错误:', err)
  } finally {
    loading.value = false
  }
}

// 保存配置
const saveConfig = async () => {
  try {
    const params = []
    const c = config.value
    
    // 网络优先级参数
    params.push(`n_net_select=${c.net_select}`)
    params.push(`n_keepalive_period=${c.probe_period}`)
    params.push(`s_keepalive_addr[0]=${c.probe_server1}`)
    params.push(`s_keepalive_addr[1]=${c.probe_server2}`)
    
    // 以太网参数
    params.push(`n_eth0.ip_mode=${c.eth_mode}`)
    params.push(`s_eth0.sip=${c.eth_ip}`)
    params.push(`s_eth0.gip=${c.eth_gw}`)
    params.push(`s_eth0.mip=${c.eth_netmask}`)
    params.push(`n_eth0.dns_mode=${c.eth_dns_mode}`)
    params.push(`s_eth0.dns_ip[0]=${c.eth_dns}`)
    params.push(`s_eth0.dns_ip[1]=${c.eth_sdns}`)
    
    // LTE/CAT1 参数
    params.push(`n_cell.sim_switch=${c.lte_sim}`)
    params.push(`s_cell.apn.addr=${c.lte_apn}`)
    params.push(`s_cell.apn.user=${c.lte_user}`)
    params.push(`s_cell.apn.pswd=${c.lte_pwd}`)
    params.push(`n_cell.apn.auth=${c.lte_auth}`)
    params.push(`n_cell.dns_mode=${c.lte_dns_mode}`)
    params.push(`s_cell.dns_ip[0]=${c.lte_dns}`)
    params.push(`s_cell.dns_ip[1]=${c.lte_sdns}`)
    
    const queryString = params.join('&')
    console.log('Saving network config:', queryString)
    
    await updateConfig('network', queryString)
    showRestartModal.value = true
    
  } catch (err) {
    alert(t('common.saveFailed') + ': ' + err.message)
    console.error(err)
  }
}

const handleRestart = async () => {
  try {
    await restartDevice()
    alert(t('system.restartSuccess'))
    showRestartModal.value = false
  } catch (err) {
    alert(t('system.restartFailed') + ': ' + err.message)
  }
}

const handleContinue = () => {
  showRestartModal.value = false
}

// 监听网络优先级变化
watch(() => config.value.net_select, (newVal) => {
  if (newVal === '2' && activeTab.value === 'ltecat') {
    activeTab.value = 'lte'
  }
})

onMounted(() => {
  loadData()
})

onUnmounted(() => {
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

.form-group input:disabled,
.form-group select:disabled {
  background-color: #f5f5f5;
  color: #999;
  cursor: not-allowed;
}

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

.loading {
  text-align: center;
  padding: 40px 20px;
  color: #666;
}

.error {
  background-color: #ffebee;
  border: 1px solid #ffcdd2;
  color: #c62828;
  padding: 12px 15px;
  border-radius: 4px;
  margin-bottom: 20px;
}

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
