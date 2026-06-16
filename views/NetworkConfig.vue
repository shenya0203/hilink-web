<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading-container">
      <div class="loading-wrapper">
        <div class="loading-spinner"></div>
        <div class="loading-text">{{ t('common.loading') }}</div>
      </div>
    </div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error-container">
      <div class="error-content">
        <div class="error-icon">
          <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"></circle>
            <line x1="12" y1="8" x2="12" y2="12"></line>
            <line x1="12" y1="16" x2="12.01" y2="16"></line>
          </svg>
        </div>
        <div class="error-message">{{ error }}</div>
        <button class="btn-reload" @click="loadData">
          {{ t('common.retry') || '重试' }}
        </button>
      </div>
    </div>

    <div v-if="!loading && !error">
      <!-- 网络配置标题 -->
      <form>
        <legend>{{ t('network.title') }}</legend>
        <div class="config-subtitle">{{ t('network.description') }}</div>
      </form>
    </div>

    <div v-if="!loading && !error">
      <!-- 顶级标签页选择 -->
    <div class="main-tabs">
      <button
        class="main-tab-btn"
        :class="{ active: activeMainTab === 'wan', 'has-error': hasMainTabError('wan') }"
        @click="activeMainTab = 'wan'"
      >
        {{ t('network.wanSettings') }}
      </button>
      <button
        class="main-tab-btn"
        :class="{ active: activeMainTab === 'lan', 'has-error': hasMainTabError('lan') }"
        @click="activeMainTab = 'lan'"
      >
        {{ t('network.lanSettings') }}
      </button>
    </div>

    <!-- WAN 设置标签页 -->
    <div v-if="activeMainTab === 'wan'" class="sub-tabs">
      <button
        class="tab-btn"
        :class="{ active: activeTab === 'ethernet', 'has-error': hasTabError('ethernet') }"
        @click="activeTab = 'ethernet'"
      >
        {{ t('network.tabPriority') }}
      </button>
      <button
        class="tab-btn"
        :class="{ active: activeTab === 'lte', 'has-error': hasTabError('lte') }"
        @click="activeTab = 'lte'"
      >
        {{ t('network.tabEthernet') }}
      </button>
      <button
        class="tab-btn"
        :class="{ active: activeTab === 'wifi', 'has-error': hasTabError('wifi') }"
        @click="activeTab = 'wifi'"
      >
        {{ t('network.tabWifi') }}
      </button>
      <button
          v-if="config.net_select !== '2'"
          class="tab-btn" 
          :class="{ active: activeTab === 'ltecat', 'has-error': hasTabError('ltecat') }"
          @click="activeTab = 'ltecat'"
        >
          {{ t('network.tabLte') }}
        </button>
      </div>

      <!-- 网络优先选择部分 -->
    <form v-if="activeMainTab === 'wan' && activeTab === 'ethernet'">
      <legend>{{ t('network.prioritySelect') }}</legend>
      <div class="form-section">
        <div class="form-group">
          <label>{{ t('network.networkPriority') }}:</label>
          <select v-model="config.net_select">
            <option value="0">{{ t('network.ethernetWifiFirst') }}</option>
            <option value="1">{{ t('network.cellularFirst') }}</option>
            <option value="2">{{ t('network.ethernetOnly') }}</option>
          </select>
        </div>
        <div v-if="config.net_select === '0'" class="form-group">
          <div class="priority-description">
            {{ t('network.ethernetWifiFirstDesc') }}
          </div>
          </div>
          <div class="form-group">
            <label>{{ t('network.probePeriod') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model="config.probe_period" 
                type="text" 
                placeholder="-" 
                :class="{ 'input-error': getFieldError('probe_period') }"
              />
              <span v-if="getFieldError('probe_period')" class="field-error-text">
                {{ getFieldError('probe_period') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('network.probeServer1') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model="config.probe_server1" 
                type="text" 
                :class="{ 'input-error': getFieldError('probe_server1') }"
              />
              <span v-if="getFieldError('probe_server1')" class="field-error-text">
                {{ getFieldError('probe_server1') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('network.probeServer2') }}:</label>
            <div class="input-wrapper">
              <input 
                v-model="config.probe_server2" 
                type="text" 
                :class="{ 'input-error': getFieldError('probe_server2') }"
              />
              <span v-if="getFieldError('probe_server2')" class="field-error-text">
                {{ getFieldError('probe_server2') }}
              </span>
            </div>
          </div>
        </div>
      </form>

    <!-- 以太网配置部分 -->
    <form v-if="activeMainTab === 'wan' && activeTab === 'lte'" style="margin-top: 20px;">
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
          <label>{{ t('network.wanIp') }}:</label>
          <div class="input-wrapper">
            <input 
              v-model="config.eth_ip" 
              type="text" 
              placeholder="" 
              :class="{ 'input-error': getFieldError('eth_ip') }"
            />
            <span v-if="getFieldError('eth_ip')" class="field-error-text">
              {{ getFieldError('eth_ip') }}
            </span>
          </div>
        </div>
        <div v-if="config.eth_mode === '0'" class="form-group">
          <label>{{ t('network.subnetMask') }}:</label>
          <div class="input-wrapper">
            <input 
              v-model="config.eth_netmask" 
              type="text" 
              placeholder="" 
              :class="{ 'input-error': getFieldError('eth_netmask') }"
            />
            <span v-if="getFieldError('eth_netmask')" class="field-error-text">
              {{ getFieldError('eth_netmask') }}
            </span>
          </div>
        </div>
        <div v-if="config.eth_mode === '0'" class="form-group">
          <label>{{ t('network.gatewayAddress') }}:</label>
          <div class="input-wrapper">
            <input 
              v-model="config.eth_gw" 
              type="text" 
              placeholder="" 
              :class="{ 'input-error': getFieldError('eth_gw') }"
            />
            <span v-if="getFieldError('eth_gw')" class="field-error-text">
              {{ getFieldError('eth_gw') }}
            </span>
          </div>
        </div>
        <div class="form-group">
          <label>{{ t('network.primaryDns') }}:</label>
          <div class="input-wrapper">
            <input 
              v-model="config.eth_dns" 
              type="text" 
              placeholder="" 
              :disabled="config.eth_dns_mode === '1'" 
              :class="{ 'input-error': getFieldError('eth_dns') }"
            />
            <span v-if="getFieldError('eth_dns')" class="field-error-text">
              {{ getFieldError('eth_dns') }}
            </span>
          </div>
        </div>
        <div class="form-group">
          <label>{{ t('network.backupDns') }}:</label>
          <div class="input-wrapper">
            <input 
              v-model="config.eth_sdns" 
              type="text" 
              placeholder="" 
              :disabled="config.eth_dns_mode === '1'" 
              :class="{ 'input-error': getFieldError('eth_sdns') }"
            />
            <span v-if="getFieldError('eth_sdns')" class="field-error-text">
              {{ getFieldError('eth_sdns') }}
            </span>
          </div>
        </div>
      </div>
    </form>

    <!-- LTE/CAT1 配置部分 -->
    <form v-if="activeMainTab === 'wan' && activeTab === 'ltecat' && config.net_select !== '2'" style="margin-top: 20px;">
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
          <div class="input-wrapper">
            <input 
              v-model="config.lte_apn" 
              type="text" 
              placeholder="" 
              :class="{ 'input-error': getFieldError('lte_apn') }"
            />
            <span v-if="getFieldError('lte_apn')" class="field-error-text">
              {{ getFieldError('lte_apn') }}
            </span>
          </div>
        </div>
        <div class="form-group">
          <label>{{ t('network.username') }}:</label>
          <div class="input-wrapper">
            <input 
              v-model="config.lte_user" 
              type="text" 
              placeholder="" 
              :class="{ 'input-error': getFieldError('lte_user') }"
            />
            <span v-if="getFieldError('lte_user')" class="field-error-text">
              {{ getFieldError('lte_user') }}
            </span>
          </div>
        </div>
        <div class="form-group">
          <label>{{ t('network.password') }}:</label>
          <div class="input-wrapper">
            <input 
              v-model="config.lte_pwd" 
              type="password" 
              placeholder="" 
              :class="{ 'input-error': getFieldError('lte_pwd') }"
            />
            <span v-if="getFieldError('lte_pwd')" class="field-error-text">
              {{ getFieldError('lte_pwd') }}
            </span>
          </div>
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
          <div class="input-wrapper">
            <input 
              v-model="config.lte_dns" 
              type="text" 
              placeholder="" 
              :disabled="config.lte_dns_mode === '1'" 
              :class="{ 'input-error': getFieldError('lte_dns') }"
            />
            <span v-if="getFieldError('lte_dns')" class="field-error-text">
              {{ getFieldError('lte_dns') }}
            </span>
          </div>
        </div>
        <div class="form-group">
          <label>{{ t('network.backupDns') }}:</label>
          <div class="input-wrapper">
            <input 
              v-model="config.lte_sdns" 
              type="text" 
              placeholder="" 
              :disabled="config.lte_dns_mode === '1'" 
              :class="{ 'input-error': getFieldError('lte_sdns') }"
            />
            <span v-if="getFieldError('lte_sdns')" class="field-error-text">
              {{ getFieldError('lte_sdns') }}
            </span>
          </div>
        </div>
        
        <div class="form-group">
          <label>{{ t('network.internalForwardDisable') }}:</label>
          <select v-model="config.internal_forward_disable">
            <option value="0">{{ t('network.internalForwardAllow') }}</option>
            <option value="1">{{ t('network.internalForwardDisallow') }}</option>
          </select>
        </div>
        <div class="form-group">
          <label>{{ t('network.externalForwardDisable') }}:</label>
          <select v-model="config.external_forward_disable">
            <option value="0">{{ t('network.externalForwardAllow') }}</option>
            <option value="1">{{ t('network.externalForwardDisallow') }}</option>
          </select>
        </div>
      </div>
    </form>

    <!-- WiFi 配置部分 -->
    <form v-if="activeMainTab === 'wan' && activeTab === 'wifi'" style="margin-top: 20px;">
      <legend>{{ t('network.wifi') }}</legend>
      <div class="form-section">
        <div class="form-group">
          <label>{{ t('network.wifiStaEnable') }}:</label>
          <select v-model="config.n_wifi.enable">
            <option value="0">{{ t('common.disable') }}</option>
            <option value="1">{{ t('common.enable') }}</option>
          </select>
        </div>
        <div class="form-group">
          <label>{{ t('network.wifiSsid') }}:</label>
          <div class="input-wrapper">
            <input
              v-model="config.s_wifi.ssid"
              type="text"
              placeholder=""
              :class="{ 'input-error': getFieldError('wifi_ssid') }"
              :disabled="config.n_wifi.enable !== '1'"
            />
            <button
              type="button"
              class="scan-btn"
              :disabled="config.n_wifi.enable !== '1'"
              @click="handleScan"
            >
              扫描WiFi
            </button>
            <span v-if="getFieldError('wifi_ssid')" class="field-error-text">
              {{ getFieldError('wifi_ssid') }}
            </span>
            <span v-if="config.n_wifi.enable === '1' && showHiddenSsidHint" class="field-hint-text">
              {{ t('network.hiddenSsidHint') }}
            </span>
          </div>
        </div>
        <div class="form-group">
          <label>{{ t('network.wifiPassword') }}:</label>
          <div class="input-wrapper">
            <input
              v-model="config.s_wifi.password"
              type="password"
              placeholder=""
              :class="{ 'input-error': getFieldError('wifi_password') }"
              :disabled="config.n_wifi.enable !== '1'"
            />
            <span v-if="getFieldError('wifi_password')" class="field-error-text">
              {{ getFieldError('wifi_password') }}
            </span>
          </div>
        </div>
        <div class="form-group">
          <label>{{ t('network.wifiEncryption') }}:</label>
          <select v-model="config.n_wifi.encryption" :disabled="config.n_wifi.enable !== '1'">
            <option value="0">NONE</option>
            <option value="1">WPA2</option>
            <option value="2">WPA3</option>
          </select>
        </div>
      </div>
      <div class="form-section">
        <div class="form-group">
          <label>{{ t('network.workMode') }}:</label>
          <select v-model="config.wifi_ip_mode" :disabled="config.n_wifi.enable !== '1'">
            <option value="0">{{ t('network.staticMode') }}</option>
            <option value="1">{{ t('network.dhcpMode') }}</option>
          </select>
        </div>
        <div class="form-group">
          <label>{{ t('network.dnsMode') }}:</label>
          <select v-model="config.wifi_dns_mode" :disabled="config.n_wifi.enable !== '1'">
            <option value="0">{{ t('network.manualDns') }}</option>
            <option value="1">{{ t('network.autoDns') }}</option>
          </select>
        </div>
        <div v-if="config.wifi_ip_mode === '0'" class="form-group">
          <label>{{ t('network.wanIp') }}:</label>
          <div class="input-wrapper">
            <input
              v-model="config.wifi_ip"
              type="text"
              placeholder=""
              :disabled="config.n_wifi.enable !== '1'"
              :class="{ 'input-error': getFieldError('wifi_ip') }"
            />
            <span v-if="getFieldError('wifi_ip')" class="field-error-text">
              {{ getFieldError('wifi_ip') }}
            </span>
          </div>
        </div>
        <div v-if="config.wifi_ip_mode === '0'" class="form-group">
          <label>{{ t('network.subnetMask') }}:</label>
          <div class="input-wrapper">
            <input
              v-model="config.wifi_netmask"
              type="text"
              placeholder=""
              :disabled="config.n_wifi.enable !== '1'"
              :class="{ 'input-error': getFieldError('wifi_netmask') }"
            />
            <span v-if="getFieldError('wifi_netmask')" class="field-error-text">
              {{ getFieldError('wifi_netmask') }}
            </span>
          </div>
        </div>
        <div v-if="config.wifi_ip_mode === '0'" class="form-group">
          <label>{{ t('network.gatewayAddress') }}:</label>
          <div class="input-wrapper">
            <input
              v-model="config.wifi_gw"
              type="text"
              placeholder=""
              :disabled="config.n_wifi.enable !== '1'"
              :class="{ 'input-error': getFieldError('wifi_gw') }"
            />
            <span v-if="getFieldError('wifi_gw')" class="field-error-text">
              {{ getFieldError('wifi_gw') }}
            </span>
          </div>
        </div>
        <div v-if="config.wifi_dns_mode === '0'" class="form-group">
          <label>{{ t('network.primaryDns') }}:</label>
          <div class="input-wrapper">
            <input
              v-model="config.wifi_dns"
              type="text"
              placeholder=""
              :disabled="config.n_wifi.enable !== '1'"
              :class="{ 'input-error': getFieldError('wifi_dns') }"
            />
            <span v-if="getFieldError('wifi_dns')" class="field-error-text">
              {{ getFieldError('wifi_dns') }}
            </span>
          </div>
        </div>
        <div v-if="config.wifi_dns_mode === '0'" class="form-group">
          <label>{{ t('network.backupDns') }}:</label>
          <div class="input-wrapper">
            <input
              v-model="config.wifi_sdns"
              type="text"
              placeholder=""
              :disabled="config.n_wifi.enable !== '1'"
              :class="{ 'input-error': getFieldError('wifi_sdns') }"
            />
            <span v-if="getFieldError('wifi_sdns')" class="field-error-text">
              {{ getFieldError('wifi_sdns') }}
            </span>
          </div>
        </div>
      </div>
    </form>

    <!-- WiFi扫描弹窗 -->
    <div v-if="wifiScanModal.show" class="modal-overlay">
      <div class="modal wifi-scan-modal">
        <div class="modal-header wifi-scan-header">
          <h3>{{ t('network.wifiScan') }}</h3>
          <button type="button" class="close-btn" @click="closeWifiScanModal">&times;</button>
        </div>
        <div class="modal-body">
          <div v-if="wifiScanModal.loading" class="scan-loading">
            <div class="loading-spinner"></div>
            <p>{{ t('network.wifiScanning') }}</p>
          </div>
          <div v-else-if="wifiScanModal.networks && wifiScanModal.networks.length > 0" class="scan-results">
            <table class="wifi-table">
              <thead>
                <tr>
                  <th>{{ t('network.wifiSsid') }}</th>
                  <th>{{ t('network.wifiBssid') }}</th>
                  <th>{{ t('network.wifiSignalStrength') }}</th>
                  <th>{{ t('network.wifiEncryption') }}</th>
                  <th>{{ t('common.action') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="network in wifiScanModal.networks" :key="network.bssid">
                  <td :class="{ 'hidden-ssid-label': !network.ssid }">
                    {{ network.ssid || t('network.hiddenSsid') }}
                  </td>
                  <td>{{ network.bssid }}</td>
                  <td>{{ network.signal }}</td>
                  <td>
                    <span v-if="network.security === 0">NONE</span>
                    <span v-else-if="network.security === 1">WPA2</span>
                    <span v-else-if="network.security === 2">WPA3</span>
                  </td>
                  <td>
                    <button type="button" class="select-btn" @click="selectWifi(network)">{{ t('common.select') }}</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div v-else class="scan-empty">
            <p>{{ t('network.noWifiFound') }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- LAN 设置部分 -->
    <div v-if="activeMainTab === 'lan'" style="margin-top: 20px;">
      <!-- 接口配置 -->
      <form>
        <legend>{{ t('network.lanInterface') }}</legend>
        <div class="form-section">
          <div class="form-group">
            <label>{{ t('network.lanIp') }}:</label>
            <div class="input-wrapper">
              <input
                v-model="config.s_lan.ip"
                type="text"
                :class="{ 'input-error': getFieldError('lan_ip') }"
              />
              <span v-if="getFieldError('lan_ip')" class="field-error-text">
                {{ getFieldError('lan_ip') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('network.lanNetmask') }}:</label>
            <div class="input-wrapper">
              <input
                v-model="config.s_lan.netmask"
                type="text"
                :class="{ 'input-error': getFieldError('lan_netmask') }"
              />
              <span v-if="getFieldError('lan_netmask')" class="field-error-text">
                {{ getFieldError('lan_netmask') }}
              </span>
            </div>
          </div>
        </div>
      </form>

      <!-- DHCP Server 配置 -->
      <form style="margin-top: 20px;">
        <legend>{{ t('network.dhcpServer') }}</legend>
        <div class="form-section">
          <div class="form-group">
            <label>{{ t('network.dhcpEnable') }}:</label>
            <select v-model="config.n_lan.dhcp_enable">
              <option value="0">{{ t('common.disable') }}</option>
              <option value="1">{{ t('common.enable') }}</option>
            </select>
          </div>
          <div class="form-group">
            <label>{{ t('network.dhcpStart') }}:</label>
            <div class="input-wrapper">
              <input
                v-model="config.s_lan.dhcp_start"
                type="text"
                :class="{ 'input-error': getFieldError('dhcp_start') }"
                :disabled="config.n_lan.dhcp_enable !== '1'"
              />
              <span v-if="getFieldError('dhcp_start')" class="field-error-text">
                {{ getFieldError('dhcp_start') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('network.dhcpEnd') }}:</label>
            <div class="input-wrapper">
              <input
                v-model="config.s_lan.dhcp_end"
                type="text"
                :class="{ 'input-error': getFieldError('dhcp_end') }"
                :disabled="config.n_lan.dhcp_enable !== '1'"
              />
              <span v-if="getFieldError('dhcp_end')" class="field-error-text">
                {{ getFieldError('dhcp_end') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('network.dhcpLease') }}:</label>
            <div class="input-wrapper">
              <input
                v-model="config.n_lan.dhcp_lease"
                type="number"
                :class="{ 'input-error': getFieldError('dhcp_lease') }"
                :disabled="config.n_lan.dhcp_enable !== '1'"
              />
              <span v-if="getFieldError('dhcp_lease')" class="field-error-text">
                {{ getFieldError('dhcp_lease') }}
              </span>
            </div>
          </div>
        </div>
      </form>

      <!-- Wi-Fi AP (热点) 配置 -->
      <form style="margin-top: 20px;">
        <legend>{{ t('network.wifiApConfig') }}</legend>
        <div class="form-section">
          <div class="form-group">
            <label>{{ t('network.apEnable') }}:</label>
            <select v-model="config.n_ap.enable">
              <option value="0">{{ t('common.disable') }}</option>
              <option value="1">{{ t('common.enable') }}</option>
            </select>
          </div>
          <div class="form-group">
            <label>{{ t('network.apSsid') }}:</label>
            <div class="input-wrapper">
              <input
                v-model="config.s_ap.ssid"
                type="text"
                placeholder=""
                :class="{ 'input-error': getFieldError('ap_ssid') }"
                :disabled="config.n_ap.enable !== '1'"
              />
              <span v-if="getFieldError('ap_ssid')" class="field-error-text">
                {{ getFieldError('ap_ssid') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('network.apEncryption') }}:</label>
            <select v-model="config.n_ap.encryption" :disabled="config.n_ap.enable !== '1'">
              <option value="0">OPEN</option>
              <option value="1">WPA2-PSK</option>
              <option value="2">WPA/WPA2-PSK</option>
            </select>
          </div>
          <div class="form-group">
            <label>{{ t('network.apPassword') }}:</label>
            <div class="input-wrapper">
              <div class="password-group">
                <input
                  v-model="config.s_ap.password"
                  :type="showApPassword ? 'text' : 'password'"
                  placeholder=""
                  :class="{ 'input-error': getFieldError('ap_password') }"
                  :disabled="config.n_ap.enable !== '1' || config.n_ap.encryption === '0'"
                  style="padding-right: 35px;"
                />
                <span 
                  class="toggle-icon" 
                  @click="showApPassword = !showApPassword"
                  v-if="config.n_ap.enable === '1' && config.n_ap.encryption !== '0'"
                >
                  <svg v-if="showApPassword" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
                    <circle cx="12" cy="12" r="3"></circle>
                  </svg>
                  <svg v-else xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path>
                    <line x1="1" y1="1" x2="23" y2="23"></line>
                  </svg>
                </span>
              </div>
              <span v-if="getFieldError('ap_password')" class="field-error-text">
                {{ getFieldError('ap_password') }}
              </span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('network.apChannel') }}:</label>
            <select v-model="config.n_ap.channel" :disabled="config.n_ap.enable !== '1'">
              <option value="0">{{ t('network.auto') }}</option>
              <option value="1">1</option>
              <option value="2">2</option>
              <option value="3">3</option>
              <option value="4">4</option>
              <option value="5">5</option>
              <option value="6">6</option>
              <option value="7">7</option>
              <option value="8">8</option>
              <option value="9">9</option>
              <option value="10">10</option>
              <option value="11">11</option>
              <option value="12">12</option>
              <option value="13">13</option>
            </select>
          </div>
          <div class="form-group">
            <label>{{ t('network.apHidden') }}:</label>
            <select v-model="config.n_ap.hidden" :disabled="config.n_ap.enable !== '1'">
              <option value="0">{{ t('network.apSsidVisible') }}</option>
              <option value="1">{{ t('network.apSsidHidden') }}</option>
            </select>
          </div>
        </div>
      </form>
    </div>

      <!-- 应用保存按钮 -->
      <div class="button-group">
        <button class="btn-save" @click="saveConfig" :disabled="!isConfigValid" :class="{ 'btn-disabled': !isConfigValid }">{{ t('common.save') }}</button>
      </div>
    </div>

    <!-- 重启确认弹窗 -->
    <div v-if="showRestartModal" class="modal-overlay">
      <div class="modal">
        <div class="modal-header">
          <h3>{{ t('common.saveSuccess') }}</h3>
        </div>
        <div class="modal-body">
          <p v-if="!isLanIpChanged">{{ t('network.restartRequired') }}</p>
          <p v-else class="warning-text">{{ t('network.lanIpChangedRestart', { newIp: config.s_lan.ip }) }}</p>
          <div class="modal-actions">
            <button class="btn-restart" @click="handleRestart">{{ t('system.restartNow') }}</button>
            <button class="btn-continue" @click="handleContinue">{{ t('network.continueConfig') }}</button>
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
import { ref, onMounted, onUnmounted, watch, computed } from 'vue'
import { fetchNetworkConfigData, fetchNetworkLanConfigData, fetchNetworkData, fetchStatusData } from '../api/mockData'
import { updateConfig, restartDevice } from '../api/services'
import { useI18n } from '../i18n/useI18n.js'
import {
  isValidIP,
  isValidSubnetMask,
  isIpInSubnet,
  isValidStringSafe,
  isValidProbePeriod,
  isValidServerAddress,
  isSameSubnet
} from '../utils/validation.js'
import { useServiceControl } from '../composables/useServiceControl.js'

// 使用 i18n
const { t } = useI18n()
const { isServiceRestarting, restartService } = useServiceControl()

// 响应式数据
const loading = ref(true)
const error = ref(null)
const activeMainTab = ref('wan')
const activeTab = ref('ethernet')
const showRestartModal = ref(false)
const showApPassword = ref(false)
const originalLanIp = ref('')

// WiFi扫描相关
const wifiScanModal = ref({
  show: false,
  loading: false,
  networks: []
})
const scanInterval = ref(null)
const scanAttempts = ref(0)
const showHiddenSsidHint = ref(false)
const retryTimer = ref(null) // 用于自动重试的定时器

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
  // WiFi
  n_wifi: {
    enable: '',
    encryption: ''
  },
  s_wifi: {
    ssid: '',
    password: ''
  },
  wifi_ip_mode: '1',
  wifi_ip: '',
  wifi_netmask: '',
  wifi_gw: '',
  wifi_dns_mode: '1',
  wifi_dns: '',
  wifi_sdns: '',
  // LTE/CAT1
  lte_sim: '',
  lte_apn: '',
  lte_user: '',
  lte_pwd: '',
  lte_auth: '',
  lte_dns_mode: '',
  lte_dns: '',
  lte_sdns: '',
  internal_forward_disable: '1',
  external_forward_disable: '0',
  // LAN
  s_lan: {
    ip: '',
    netmask: '',
    dhcp_start: '',
    dhcp_end: ''
  },
  n_lan: {
    dhcp_enable: '',
    dhcp_lease: ''
  },
  // AP (热点)
  n_ap: {
    enable: '',
    encryption: '',
    channel: '',
    hidden: ''
  },
  s_ap: {
    ssid: '',
    password: ''
  }
})

// 验证逻辑
const networkErrors = computed(() => {
  const errors = {}
  
  // 1. 网络优先级验证
  if (!isValidProbePeriod(config.value.probe_period)) {
    errors['probe_period'] = t('network.invalidProbePeriod') || 'Invalid Probe Period (5-600s)'
  }
  if (!isValidServerAddress(config.value.probe_server1)) {
    errors['probe_server1'] = t('network.invalidServerAddress') || 'Invalid Server Address'
  }
  if (config.value.probe_server2 && !isValidServerAddress(config.value.probe_server2)) {
    errors['probe_server2'] = t('network.invalidServerAddress') || 'Invalid Server Address'
  }

  // 2. 以太网验证
  if (config.value.eth_mode === '0') { // 静态IP模式
    if (!isValidIP(config.value.eth_ip)) {
      errors['eth_ip'] = t('network.invalidIP') || 'Invalid IP'
    }
    if (!isValidSubnetMask(config.value.eth_netmask)) {
      errors['eth_netmask'] = t('network.invalidSubnetMask') || 'Invalid Subnet Mask'
    }
    if (!isValidIP(config.value.eth_gw)) {
      errors['eth_gw'] = t('network.invalidGateway') || 'Invalid Gateway'
    }
    
    // 关联验证：IP和网关是否在同一子网
    if (isValidIP(config.value.eth_ip) && isValidSubnetMask(config.value.eth_netmask) && isValidIP(config.value.eth_gw)) {
      if (!isIpInSubnet(config.value.eth_gw, config.value.eth_ip, config.value.eth_netmask)) {
        errors['eth_gw'] = t('network.gatewayNotInSubnet') || 'Gateway not in subnet'
      }
    }
  }

  if (config.value.eth_dns_mode === '0') { // 手动DNS
    if (config.value.eth_dns && !isValidIP(config.value.eth_dns)) {
      errors['eth_dns'] = t('network.invalidIP') || 'Invalid DNS IP'
    }
    if (config.value.eth_sdns && !isValidIP(config.value.eth_sdns)) {
      errors['eth_sdns'] = t('network.invalidIP') || 'Invalid DNS IP'
    }
  }

  // 3. WiFi 验证
  if (config.value.n_wifi.enable === '1') {
    if (!config.value.s_wifi.ssid || config.value.s_wifi.ssid.trim() === '') {
      errors['wifi_ssid'] = t('network.invalidStringSafe') || 'SSID is required'
    } else if (!isValidStringSafe(config.value.s_wifi.ssid, 1, 32)) {
      errors['wifi_ssid'] = t('network.invalidStringSafe') || 'Invalid SSID (1-32 chars, no special chars)'
    }

    if (config.value.n_wifi.encryption !== '0' && (!config.value.s_wifi.password || config.value.s_wifi.password.trim() === '')) {
      errors['wifi_password'] = t('network.invalidStringSafe') || 'Password is required for encrypted connection'
    } else if (config.value.s_wifi.password && !isValidStringSafe(config.value.s_wifi.password, 8, 64)) {
      errors['wifi_password'] = t('network.invalidStringSafe') || 'Invalid Password (8-64 chars, no special chars)'
    }

    if (config.value.wifi_ip_mode === '0') {
      if (!isValidIP(config.value.wifi_ip)) {
        errors['wifi_ip'] = t('network.invalidIP') || 'Invalid IP'
      }
      if (!isValidSubnetMask(config.value.wifi_netmask)) {
        errors['wifi_netmask'] = t('network.invalidSubnetMask') || 'Invalid Subnet Mask'
      }
      if (!isValidIP(config.value.wifi_gw)) {
        errors['wifi_gw'] = t('network.invalidGateway') || 'Invalid Gateway'
      }

      if (isValidIP(config.value.wifi_ip) && isValidSubnetMask(config.value.wifi_netmask) && isValidIP(config.value.wifi_gw)) {
        if (!isIpInSubnet(config.value.wifi_gw, config.value.wifi_ip, config.value.wifi_netmask)) {
          errors['wifi_gw'] = t('network.gatewayNotInSubnet') || 'Gateway not in subnet'
        }
      }
    }

    if (config.value.wifi_dns_mode === '0') {
      if (config.value.wifi_dns && !isValidIP(config.value.wifi_dns)) {
        errors['wifi_dns'] = t('network.invalidIP') || 'Invalid DNS IP'
      }
      if (config.value.wifi_sdns && !isValidIP(config.value.wifi_sdns)) {
        errors['wifi_sdns'] = t('network.invalidIP') || 'Invalid DNS IP'
      }
    }
  }

  // 4. LTE/CAT1 验证
  if (config.value.lte_apn && !isValidStringSafe(config.value.lte_apn, 4, 16)) {
    errors['lte_apn'] = t('network.invalidStringSafe') || 'Invalid APN (4-16 chars, no special chars)'
  }
  if (config.value.lte_user && !isValidStringSafe(config.value.lte_user, 0, 32)) {
    errors['lte_user'] = t('network.invalidStringSafe') || 'Invalid Username (0-32 chars, no special chars)'
  }
  if (config.value.lte_pwd && !isValidStringSafe(config.value.lte_pwd, 0, 32)) {
    errors['lte_pwd'] = t('network.invalidStringSafe') || 'Invalid Password (0-32 chars, no special chars)'
  }

  if (config.value.lte_dns_mode === '0') { // 手动DNS
    if (config.value.lte_dns && !isValidIP(config.value.lte_dns)) {
      errors['lte_dns'] = t('network.invalidIP') || 'Invalid DNS IP'
    }
    if (config.value.lte_sdns && !isValidIP(config.value.lte_sdns)) {
      errors['lte_sdns'] = t('network.invalidIP') || 'Invalid DNS IP'
    }
  }

  // 5. LAN 验证
  if (!isValidIP(config.value.s_lan.ip)) {
    errors['lan_ip'] = t('network.invalidIP') || 'Invalid LAN IP'
  }
  if (!isValidSubnetMask(config.value.s_lan.netmask)) {
    errors['lan_netmask'] = t('network.invalidSubnetMask') || 'Invalid LAN Subnet Mask'
  }

  // DHCP 验证
  if (config.value.n_lan.dhcp_enable === '1') {
    if (!isValidIP(config.value.s_lan.dhcp_start)) {
      errors['dhcp_start'] = t('network.invalidIP') || 'Invalid DHCP Start IP'
    }
    if (!isValidIP(config.value.s_lan.dhcp_end)) {
      errors['dhcp_end'] = t('network.invalidIP') || 'Invalid DHCP End IP'
    }
    if (!config.value.n_lan.dhcp_lease || config.value.n_lan.dhcp_lease < 1 || config.value.n_lan.dhcp_lease > 8760) {
      errors['dhcp_lease'] = 'Lease time must be between 1-8760 hours'
    }

    // DHCP 范围验证：起始IP和结束IP必须在LAN网段内
    if (isValidIP(config.value.s_lan.ip) && isValidSubnetMask(config.value.s_lan.netmask) &&
        isValidIP(config.value.s_lan.dhcp_start) && isValidIP(config.value.s_lan.dhcp_end)) {
      if (!isIpInSubnet(config.value.s_lan.dhcp_start, config.value.s_lan.ip, config.value.s_lan.netmask)) {
        errors['dhcp_start'] = 'DHCP Start IP not in LAN subnet'
      }
      if (!isIpInSubnet(config.value.s_lan.dhcp_end, config.value.s_lan.ip, config.value.s_lan.netmask)) {
        errors['dhcp_end'] = 'DHCP End IP not in LAN subnet'
      }
      if (isValidIP(config.value.s_lan.dhcp_start) && isValidIP(config.value.s_lan.dhcp_end)) {
        const startParts = config.value.s_lan.dhcp_start.split('.').map(Number);
        const endParts = config.value.s_lan.dhcp_end.split('.').map(Number);
        const startNum = (startParts[0] << 24) + (startParts[1] << 16) + (startParts[2] << 8) + startParts[3];
        const endNum = (endParts[0] << 24) + (endParts[1] << 16) + (endParts[2] << 8) + endParts[3];
        if (startNum >= endNum) {
          errors['dhcp_end'] = 'DHCP End IP must be greater than Start IP'
        }
      }
    }
  }

  // 6. AP 验证
  if (config.value.n_ap.enable === '1') {
    if (!config.value.s_ap.ssid || config.value.s_ap.ssid.trim() === '') {
      errors['ap_ssid'] = t('network.apSsidRequired') || 'SSID is required'
    } else if (!isValidStringSafe(config.value.s_ap.ssid, 1, 32)) {
      errors['ap_ssid'] = t('network.apSsidInvalid') || 'Invalid SSID (1-32 characters)'
    }

    if (config.value.n_ap.encryption !== '0') { // 非OPEN模式
      if (!config.value.s_ap.password || config.value.s_ap.password.trim() === '') {
        errors['ap_password'] = t('network.apPasswordRequired') || 'Password is required for encrypted hotspot'
      } else if (!isValidStringSafe(config.value.s_ap.password, 8, 63)) {
        errors['ap_password'] = t('network.apPasswordInvalid') || 'Invalid password (8-63 characters)'
      }
    }
  }

  // 7. WAN/LAN 网段冲突校验
  if (config.value.eth_mode === '0' && // WAN为静态IP模式
      isValidIP(config.value.eth_ip) && isValidSubnetMask(config.value.eth_netmask) &&
      isValidIP(config.value.s_lan.ip) && isValidSubnetMask(config.value.s_lan.netmask)) {
    if (isSameSubnet(config.value.eth_ip, config.value.s_lan.ip, config.value.eth_netmask)) {
      errors['subnet_conflict'] = t('network.subnetConflict') || 'LAN IP subnet cannot conflict with WAN IP subnet'
    }
  }

  if (config.value.eth_mode === '0' && config.value.wifi_ip_mode === '0' &&
      isValidIP(config.value.eth_ip) && isValidSubnetMask(config.value.eth_netmask) &&
      isValidIP(config.value.wifi_ip) && isValidSubnetMask(config.value.wifi_netmask)) {
    if (isSameSubnet(config.value.wifi_ip, config.value.eth_ip, config.value.wifi_netmask) ||
        isSameSubnet(config.value.wifi_ip, config.value.eth_ip, config.value.eth_netmask)) {
      errors['subnet_conflict'] = t('network.subnetConflict') || 'LAN IP subnet cannot conflict with WAN IP subnet'
    }
  }

  return errors
})

const isConfigValid = computed(() => {
  return Object.keys(networkErrors.value).length === 0
})

const isLanIpChanged = computed(() => {
  return config.value.s_lan.ip !== originalLanIp.value
})

const getFieldError = (field) => {
  return networkErrors.value[field]
}

const hasTabError = (tabName) => {
  const errors = networkErrors.value
  if (tabName === 'ethernet') {
    return errors.probe_period || errors.probe_server1 || errors.probe_server2
  }
  if (tabName === 'lte') {
    return errors.eth_ip || errors.eth_netmask || errors.eth_gw || errors.eth_dns || errors.eth_sdns
  }
  if (tabName === 'wifi') {
    return errors.wifi_ssid || errors.wifi_password || errors.wifi_ip || errors.wifi_netmask || errors.wifi_gw || errors.wifi_dns || errors.wifi_sdns || errors.subnet_conflict
  }
  if (tabName === 'ltecat') {
    return errors.lte_apn || errors.lte_user || errors.lte_pwd || errors.lte_dns || errors.lte_sdns
  }
  return false
}

const hasMainTabError = (mainTabName) => {
  const errors = networkErrors.value
  if (mainTabName === 'wan') {
    return errors.probe_period || errors.probe_server1 || errors.probe_server2 ||
           errors.eth_ip || errors.eth_netmask || errors.eth_gw || errors.eth_dns || errors.eth_sdns ||
           errors.wifi_ssid || errors.wifi_password || errors.wifi_ip || errors.wifi_netmask || errors.wifi_gw || errors.wifi_dns || errors.wifi_sdns ||
           errors.lte_apn || errors.lte_user || errors.lte_pwd || errors.lte_dns || errors.lte_sdns ||
           errors.subnet_conflict
  }
  if (mainTabName === 'lan') {
    return errors.lan_ip || errors.lan_netmask || errors.dhcp_start || errors.dhcp_end || errors.dhcp_lease ||
           errors.ap_ssid || errors.ap_password
  }
  return false
}

// 加载所有数据
const loadData = async () => {
  try {
    // 确保重试时仍处于加载状态且无错误提示
    loading.value = true
    error.value = null

    // 清理可能存在的旧定时器
    if (retryTimer.value) {
      clearTimeout(retryTimer.value)
      retryTimer.value = null
    }

    const [status, networkFlex, netConfig, lanConfig] = await Promise.all([
      fetchStatusData(),
      fetchNetworkData(),
      fetchNetworkConfigData(),
      fetchNetworkLanConfigData()
    ])
    
    // 如果任何一个接口获取失败 (返回 null)，则记录警告并延迟重试
    if (status === null || networkFlex === null || netConfig === null || lanConfig === null) {
      const failedApis = []
      if (status === null) failedApis.push('status')
      if (networkFlex === null) failedApis.push('networkFlex')
      if (netConfig === null) failedApis.push('netConfig')
      if (lanConfig === null) failedApis.push('lanConfig')
      
      console.warn(`[NetworkConfig] 以下接口获取失败: ${failedApis.join(', ')}。2秒后将自动发起重试...`)
      
      // 保持转圈状态，2秒后重试
      retryTimer.value = setTimeout(loadData, 2000)
      return
    }
    
    // 能运行到这里说明全部接口成功
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
      // WiFi (使用数据或默认值)
      n_wifi: {
        enable: String(netConfig.n_wifi?.enable ?? 0),
        encryption: String(netConfig.n_wifi?.encryption ?? 1)
      },
      s_wifi: {
        ssid: netConfig.s_wifi?.ssid ?? '',
        password: netConfig.s_wifi?.password ?? ''
      },
      wifi_ip_mode: String(netConfig.n_wifi?.ip_mode ?? 1),
      wifi_ip: netConfig.s_wifi?.ip ?? '',
      wifi_netmask: netConfig.s_wifi?.netmask ?? '',
      wifi_gw: netConfig.s_wifi?.gw ?? '',
      wifi_dns_mode: String(netConfig.n_wifi?.dns_mode ?? 1),
      wifi_dns: netConfig.s_wifi?.dns_ip?.[0] ?? '',
      wifi_sdns: netConfig.s_wifi?.dns_ip?.[1] ?? '',
      lte_sim: String(netConfig.cell.sim_switch),
      lte_apn: netConfig.cell.apn.addr || '',
      lte_user: netConfig.cell.apn.user || '',
      lte_pwd: netConfig.cell.apn.pswd || '',
      lte_auth: String(netConfig.cell.apn.auth),
      lte_dns_mode: String(netConfig.cell.dns_mode),
      lte_dns: netConfig.cell.dns_ip[0],
      lte_sdns: netConfig.cell.dns_ip[1],
      internal_forward_disable: String(netConfig.cell.internal_forward_disable ?? 1),
      external_forward_disable: String(netConfig.cell.external_forward_disable ?? 0)
    })

    // 执行到这里 netConfig 和 lanConfig 肯定都不为 null
    config.value.s_lan = {
      ip: lanConfig.s_lan?.ip || '',
      netmask: lanConfig.s_lan?.netmask || '',
      dhcp_start: lanConfig.s_lan?.dhcp_start || '',
      dhcp_end: lanConfig.s_lan?.dhcp_end || ''
    }
    config.value.n_lan = {
      dhcp_enable: lanConfig.n_lan?.dhcp_enable !== undefined ? String(lanConfig.n_lan.dhcp_enable) : '',
      dhcp_lease: lanConfig.n_lan?.dhcp_lease !== undefined ? String(lanConfig.n_lan.dhcp_lease) : ''
    }

    config.value.n_ap = {
      enable: String(lanConfig.n_ap?.enable ?? 0),
      encryption: String(lanConfig.n_ap?.encryption ?? 1),
      channel: String(lanConfig.n_ap?.channel ?? 0),
      hidden: String(lanConfig.n_ap?.hidden ?? 0)
    }
    config.value.s_ap = {
      ssid: lanConfig.s_ap?.ssid ?? '',
      password: lanConfig.s_ap?.password ?? ''
    }

    // 保存原始LAN IP用于检测变化
    originalLanIp.value = config.value.s_lan.ip

    // 全部成功后，关闭转圈
    loading.value = false
    
  } catch (err) {
    console.error('[NetworkConfig] 加载处理过程中抛出异常，准备重试:', err)
    // 如果发生 JS 运行异常，同样进行等待重试
    retryTimer.value = setTimeout(loadData, 2000)
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

    // WiFi 参数
    params.push(`n_wifi.enable=${c.n_wifi.enable}`)
    params.push(`s_wifi.ssid=${c.s_wifi.ssid}`)
    params.push(`s_wifi.password=${c.s_wifi.password}`)
    params.push(`n_wifi.encryption=${c.n_wifi.encryption}`)
    params.push(`n_wifi.ip_mode=${c.wifi_ip_mode}`)
    params.push(`s_wifi.ip=${c.wifi_ip}`)
    params.push(`s_wifi.netmask=${c.wifi_netmask}`)
    params.push(`s_wifi.gw=${c.wifi_gw}`)
    params.push(`n_wifi.dns_mode=${c.wifi_dns_mode}`)
    params.push(`s_wifi.dns_ip[0]=${c.wifi_dns}`)
    params.push(`s_wifi.dns_ip[1]=${c.wifi_sdns}`)

    // LTE/CAT1 参数
    params.push(`n_cell.sim_switch=${c.lte_sim}`)
    params.push(`s_cell.apn.addr=${c.lte_apn}`)
    params.push(`s_cell.apn.user=${c.lte_user}`)
    params.push(`s_cell.apn.pswd=${c.lte_pwd}`)
    params.push(`n_cell.apn.auth=${c.lte_auth}`)
    params.push(`n_cell.dns_mode=${c.lte_dns_mode}`)
    params.push(`s_cell.dns_ip[0]=${c.lte_dns}`)
    params.push(`s_cell.dns_ip[1]=${c.lte_sdns}`)
    params.push(`n_cell.internal_forward_disable=${c.internal_forward_disable}`)
    params.push(`n_cell.external_forward_disable=${c.external_forward_disable}`)

    // LAN 参数
    params.push(`s_lan.ip=${c.s_lan.ip}`)
    params.push(`s_lan.netmask=${c.s_lan.netmask}`)
    params.push(`n_lan.dhcp_enable=${c.n_lan.dhcp_enable}`)
    params.push(`s_lan.dhcp_start=${c.s_lan.dhcp_start}`)
    params.push(`s_lan.dhcp_end=${c.s_lan.dhcp_end}`)
    params.push(`n_lan.dhcp_lease=${c.n_lan.dhcp_lease}`)

    // AP 参数
    params.push(`n_ap.enable=${c.n_ap.enable}`)
    params.push(`s_ap.ssid=${c.s_ap.ssid}`)
    params.push(`s_ap.password=${c.s_ap.password}`)
    params.push(`n_ap.encryption=${c.n_ap.encryption}`)
    params.push(`n_ap.channel=${c.n_ap.channel}`)
    params.push(`n_ap.hidden=${c.n_ap.hidden}`)

    const queryString = params.join('&')
    //console.log('Saving network config:', queryString)
    
    await updateConfig('network', queryString)
    showRestartModal.value = true
    
  } catch (err) {
    alert(t('common.saveFailed') + ': ' + err.message)
    console.error(err)
  }
}

const handleRestart = async () => {
  showRestartModal.value = false
  await restartService()
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

// 监听主标签页变化
watch(() => activeMainTab.value, (newVal) => {
  if (newVal === 'wan' && activeTab.value !== 'ethernet' && activeTab.value !== 'lte' && activeTab.value !== 'wifi' && activeTab.value !== 'ltecat') {
    activeTab.value = 'ethernet'
  }
  // 切换主标签页时关闭WiFi扫描弹窗
  closeWifiScanModal()
})

// 监听子标签页变化
watch(() => activeTab.value, () => {
  // 切换子标签页时关闭WiFi扫描弹窗
  closeWifiScanModal()
})

// WiFi扫描方法
const handleScan = async () => {
  try {
    wifiScanModal.value.show = true
    wifiScanModal.value.loading = true
    wifiScanModal.value.networks = []
    scanAttempts.value = 0

    // 发起扫描
    const startResponse = await fetch('/action_wifi.cgi?act=start')
    const startResult = await startResponse.json()

    if (!startResult.result) {
      throw new Error('Failed to start WiFi scan')
    }

    // 开始轮询检查结果
    scanInterval.value = setInterval(async () => {
      try {
        scanAttempts.value++
        const checkResponse = await fetch('/action_wifi.cgi?act=check')
        const checkResult = await checkResponse.json()

        if (checkResult.result) {
          if (checkResult.status === 'done') {
            // 扫描完成
            wifiScanModal.value.loading = false
            wifiScanModal.value.networks = checkResult.data || []
            clearInterval(scanInterval.value)
          } else if (checkResult.status === 'scanning') {
            // 仍在扫描，继续等待
            wifiScanModal.value.loading = true
          }
        } else {
          // 扫描失败
          wifiScanModal.value.loading = false
          clearInterval(scanInterval.value)
          throw new Error(checkResult.msg || 'Scan failed')
        }

        // 超时检查 (6次 * 1000ms = 6秒)
        if (scanAttempts.value >= 6) {
          wifiScanModal.value.loading = false
          clearInterval(scanInterval.value)
          throw new Error('Scan timeout')
        }
      } catch (err) {
        console.error('Scan check error:', err)
        wifiScanModal.value.loading = false
        clearInterval(scanInterval.value)
      }
    }, 1000)
  } catch (err) {
    console.error('Scan start error:', err)
    wifiScanModal.value.loading = false
    wifiScanModal.value.show = false
  }
}

const selectWifi = (network) => {
  // 填入SSID
  config.value.s_wifi.ssid = network.ssid

  // 根据安全类型设置加密方式
  config.value.n_wifi.encryption = network.security.toString()

  // 清空密码
  config.value.s_wifi.password = ''

  // 只要SSID为空，即视为选择了隐藏SSID的AP
  showHiddenSsidHint.value = !network.ssid

  // 关闭弹窗
  closeWifiScanModal()
}

const closeWifiScanModal = () => {
  wifiScanModal.value.show = false
  wifiScanModal.value.loading = false
  wifiScanModal.value.networks = []
  if (scanInterval.value) {
    clearInterval(scanInterval.value)
    scanInterval.value = null
  }
  scanAttempts.value = 0
}

onMounted(() => {
  loadData()
})

onUnmounted(() => {
  if (retryTimer.value) {
    clearTimeout(retryTimer.value)
    retryTimer.value = null
  }
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

.main-tabs {
  display: flex;
  gap: 20px;
  margin: 20px 0;
  border-bottom: 2px solid #e8e8e8;
  padding-bottom: 10px;
  width: 100%;
}

.main-tab-btn {
  padding: 12px 25px;
  background-color: #f5f5f5;
  color: #666;
  border: none;
  cursor: pointer;
  border-radius: 6px 6px 0 0;
  font-size: 14px;
  font-weight: 600;
  transition: all 0.2s;
}

.main-tab-btn:hover {
  background-color: #e0e0e0;
}

.main-tab-btn.active {
  background-color: #0066cc;
  color: white;
}

.main-tab-btn.has-error {
  background-color: #ffebee;
  color: #d32f2f;
}

.main-tab-btn.active.has-error {
  background-color: #c62828;
  color: white;
}

.sub-tabs {
  display: flex;
  gap: 10px;
  margin: 15px 0;
  border-bottom: 1px solid #e8e8e8;
  width: 100%;
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

.tab-btn.has-error {
  background-color: #d32f2f;
}

.tab-btn.active.has-error {
  background-color: #c62828;
}

.form-section {
  padding: 25px 30px;
  background-color: white;
}

form {
  background-color: white;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
  margin: 0 0 25px 0;
  overflow: hidden;
  width: 100%;
}

legend {
  font-size: 16px;
  font-weight: 600;
  color: white;
  background-color: #0066cc;
  padding: 12px 20px;
  width: 100%;
  margin: 0;
  border: none;
  display: block;
}

.form-group {
  display: flex;
  align-items: flex-start;
  margin-bottom: 15px;
  gap: 20px;
}

.form-group label {
  font-weight: 600;
  width: 150px;
  text-align: right;
  flex-shrink: 0;
  margin-top: 8px;
}

.form-group input,
.form-group select {
  width: 100%;
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

.field-hint-text {
  color: #ff8800;
  font-size: 11px;
  margin-top: 4px;
  font-weight: 500;
  line-height: 1.2;
}

.hidden-ssid-label {
  color: #888;
  font-style: italic;
}

.priority-description {
  color: #666;
  font-size: 12px;
  font-style: italic;
  margin-top: 8px;
  padding: 8px 12px;
  background-color: #f9f9f9;
  border-radius: 4px;
  border-left: 3px solid #0066cc;
}

.warning-text {
  color: #d32f2f;
  font-weight: 600;
  font-size: 14px;
  line-height: 1.4;
  margin-bottom: 15px;
  padding: 10px 15px;
  background-color: #ffebee;
  border-radius: 4px;
  border-left: 4px solid #d32f2f;
}

.button-group {
  display: flex;
  justify-content: center;
  padding: 20px 0;
  margin: 10px 0 0 0;
  width: 100%;
  background-color: #f9f9f9;
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

.btn-disabled {
  background-color: #ccc !important;
  cursor: not-allowed;
}

.loading-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 400px;
  width: 100%;
}

.loading-wrapper {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 15px;
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 4px solid #f3f3f3;
  border-top: 4px solid #0066cc;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

.loading-text {
  color: #666;
  font-size: 14px;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.loading {
  text-align: center;
  padding: 40px 20px;
  color: #666;
}

.error-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 400px;
  width: 100%;
}

.error-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 15px;
  background-color: #fff;
  padding: 30px;
  border-radius: 8px;
  box-shadow: 0 2px 12px rgba(0,0,0,0.08);
  border: 1px solid #ffcdd2;
}

.error-icon {
  color: #d32f2f;
}

.error-message {
  color: #d32f2f;
  font-size: 14px;
  font-weight: 500;
  text-align: center;
}

.btn-reload {
  padding: 8px 25px;
  background-color: #d32f2f;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 13px;
  transition: background-color 0.2s;
}

.btn-reload:hover {
  background-color: #b71c1c;
}

.error {
  background-color: #ffebee;
  border: 1px solid #ffcdd2;
  color: #c62828;
  padding: 12px 15px;
  border-radius: 4px;
  margin-bottom: 20px;
}

/* WiFi扫描相关样式 */
.scan-btn {
  width: 100%;
  padding: 10px 12px;
  background-color: #0066cc;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 600;
  margin-top: 10px;
  transition: all 0.2s;
  box-shadow: 0 2px 4px rgba(0, 102, 204, 0.2);
}

.scan-btn:hover:not(:disabled) {
  background-color: #0052a3;
  box-shadow: 0 4px 8px rgba(0, 102, 204, 0.3);
}

.scan-btn:disabled {
  background-color: #ccc;
  cursor: not-allowed;
}

.wifi-scan-modal {
  /* 基础宽度定义，覆盖 .modal 的默认 400px */
  max-width: 800px;
  width: 90%;
  min-width: 600px;
  
  /* 圆角和阴影优化 */
  border-radius: 12px !important;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2) !important;
  
  /* 确保溢出内容正确处理（如标题栏圆角） */
  overflow: hidden;
}

/* WiFi 扫描弹窗头部样式 */
.wifi-scan-header {
  background-color: #0066cc !important;
  color: white !important;
  border-bottom: 1px solid #0052a3;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 15px !important; /* 减小内边距，解决“太宽”问题 */
}

.wifi-scan-header h3 {
  color: white !important;
  margin: 0;
  font-size: 16px;
}

.wifi-scan-header .close-btn {
  background: none;
  border: none;
  color: white !important;
  font-size: 20px; /* 稍微减小字体 */
  cursor: pointer;
  line-height: 1;
  opacity: 0.8;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px; /* 减小按钮尺寸以匹配紧凑型标题栏 */
  height: 32px;
  border-radius: 4px;
  transition: all 0.2s;
  margin-right: -5px; /* 向右微调位置 */
}

.wifi-scan-header .close-btn:hover {
  background-color: rgba(255, 255, 255, 0.2);
  opacity: 1;
}

.scan-loading {
  text-align: center;
  padding: 40px 20px;
}

.loading-spinner {
  border: 4px solid #f3f3f3;
  border-top: 4px solid #0066cc;
  border-radius: 50%;
  width: 40px;
  height: 40px;
  animation: spin 1s linear infinite;
  margin: 0 auto 15px;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.scan-results {
  max-height: 400px;
  overflow-y: auto;
}

.wifi-table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 10px;
  font-size: 14px;
}

.wifi-table th,
.wifi-table td {
  padding: 12px 15px;
  text-align: left;
  border-bottom: 1px solid #e0e0e0;
  line-height: 1.4;
}

.wifi-table th {
  background-color: #f5f5f5;
  font-weight: 600;
  color: #333;
}

.wifi-table tr:hover {
  background-color: #f9f9f9;
}

.select-btn {
  padding: 6px 16px;
  background-color: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 13px;
  font-weight: 500;
  transition: all 0.2s ease;
  box-shadow: 0 2px 4px rgba(0, 123, 255, 0.2);
}

.select-btn:hover {
  background-color: #0056b3;
  transform: translateY(-1px);
  box-shadow: 0 4px 8px rgba(0, 123, 255, 0.3);
}

.select-btn:active {
  transform: translateY(0);
}

.scan-empty {
  text-align: center;
  padding: 40px 20px;
  color: #666;
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
.password-group {
  position: relative;
  width: 100%;
}

.toggle-icon {
  position: absolute;
  right: 10px;
  top: 50%;
  transform: translateY(-50%);
  cursor: pointer;
  color: #888;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10;
}

.toggle-icon:hover {
  color: #0066cc;
}
</style>
