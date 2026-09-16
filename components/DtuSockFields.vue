<template>
  <div v-if="sock">
    <div class="form-group">
      <label>{{ t('socket.enable') }}:</label>
      <select v-model.number="sock.enable">
        <option :value="0">{{ t('common.disable') }}</option>
        <option :value="1">{{ t('common.enable') }}</option>
      </select>
    </div>

    <template v-if="sock.enable === 1">
      <div class="form-group">
        <label>{{ t('socket.workMode') }}:</label>
        <select v-model.number="sock.mode">
          <option :value="0">{{ t('socket.tcpClient') }}</option>
          <option :value="1">{{ t('socket.tcpServer') }}</option>
          <option :value="2">{{ t('socket.udpClient') }}</option>
          <option :value="3">{{ t('socket.httpClient') }}</option>
        </select>
      </div>

      <template v-if="sock.mode === 0">
        <div class="form-group">
          <label>{{ t('socket.serverAddress') }}:</label>
          <input v-model="sock.tcpc.server_ip" type="text" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.localPort') }}:</label>
          <input v-model.number="sock.tcpc.local_port" type="number" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.remotePort') }}:</label>
          <input v-model.number="sock.tcpc.server_port" type="number" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.reconnectInterval') }}:</label>
          <input v-model.number="sock.tcpc.reconn_interval" type="number" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.sslEncrypt') }}:</label>
          <select v-model.number="sock.tcpc.ssl_mode">
            <option :value="0">{{ t('common.disable') }}</option>
            <option :value="1">TLS1.2</option>
          </select>
        </div>
        <div class="form-group">
          <label>{{ t('socket.registerPacket') }}:</label>
          <select v-model.number="sock.tcpc.regp_en">
            <option :value="0">{{ t('common.disable') }}</option>
            <option :value="1">{{ t('common.enable') }}</option>
          </select>
        </div>
        <div class="form-group" v-if="sock.tcpc.regp_en === 1">
          <label>{{ t('socket.customContent') }}:</label>
          <input v-model="sock.tcpc.regp_ctx" type="text" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.heartbeat') }}:</label>
          <select v-model.number="sock.tcpc.hrtp_en">
            <option :value="0">{{ t('common.disable') }}</option>
            <option :value="1">{{ t('common.enable') }}</option>
          </select>
        </div>
        <template v-if="sock.tcpc.hrtp_en === 1">
          <div class="form-group">
            <label>{{ t('socket.heartbeatInterval') }}:</label>
            <input v-model.number="sock.tcpc.hrtp_tim" type="number" />
          </div>
          <div class="form-group">
            <label>{{ t('socket.heartbeatCustomContent') }}:</label>
            <input v-model="sock.tcpc.hrtp_ctx" type="text" />
          </div>
        </template>
      </template>

      <template v-if="sock.mode === 1">
        <div class="form-group">
          <label>{{ t('socket.localPort') }}:</label>
          <input v-model.number="sock.tcps.local_port" type="number" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.maxConnections') }}:</label>
          <input v-model.number="sock.tcps.conn_max_num" type="number" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.overflowHandle') }}:</label>
          <select v-model.number="sock.tcps.timeout_handling">
            <option :value="0">KEEP</option>
            <option :value="1">KICK</option>
          </select>
        </div>
      </template>

      <template v-if="sock.mode === 2">
        <div class="form-group">
          <label>{{ t('socket.serverAddress') }}:</label>
          <input v-model="sock.udpc.server_ip" type="text" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.localPort') }}:</label>
          <input v-model.number="sock.udpc.local_port" type="number" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.remotePort') }}:</label>
          <input v-model.number="sock.udpc.server_port" type="number" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.shortConnect') }}:</label>
          <select v-model.number="sock.udpc.short_en">
            <option :value="0">{{ t('common.disable') }}</option>
            <option :value="1">{{ t('common.enable') }}</option>
          </select>
        </div>
        <div class="form-group" v-if="sock.udpc.short_en === 1">
          <label>{{ t('socket.shortTimeout') }}:</label>
          <input v-model.number="sock.udpc.short_timeout" type="number" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.keepalive') }}:</label>
          <input v-model.number="sock.udpc.keepalive" type="number" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.sockTimeout') }}:</label>
          <input v-model.number="sock.udpc.sock_timeout" type="number" />
        </div>
      </template>

      <template v-if="sock.mode === 3">
        <div class="form-group">
          <label>{{ t('socket.httpMethod') }}:</label>
          <select v-model.number="sock.httpc.mode">
            <option :value="0">GET</option>
            <option :value="1">POST</option>
          </select>
        </div>
        <div class="form-group">
          <label>{{ t('socket.serverAddress') }}:</label>
          <input v-model="sock.httpc.server_ip" type="text" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.remotePort') }}:</label>
          <input v-model.number="sock.httpc.server_port" type="number" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.path') }}:</label>
          <input v-model="sock.httpc.url" type="text" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.httpHeader') }}:</label>
          <input v-model="sock.httpc.header" type="text" />
        </div>
        <div class="form-group">
          <label>{{ t('socket.cutHeader') }}:</label>
          <select v-model.number="sock.httpc.cut_header">
            <option :value="0">{{ t('common.disable') }}</option>
            <option :value="1">{{ t('common.enable') }}</option>
          </select>
        </div>
        <div class="form-group">
          <label>{{ t('socket.respTimeout') }}:</label>
          <input v-model.number="sock.httpc.resp_timeout" type="number" />
        </div>
      </template>
    </template>
  </div>
</template>

<script setup>
import { useI18n } from '../i18n/useI18n.js'

defineProps({
  sock: { type: Object, required: true }
})

const { t } = useI18n()
</script>

<style scoped>
.form-group { display: flex; align-items: flex-start; margin-bottom: 15px; gap: 20px; }
.form-group label { font-weight: 600; width: 160px; text-align: right; flex-shrink: 0; margin-top: 8px; }
.form-group input, .form-group select { width: 100%; max-width: 320px; padding: 8px 12px; border: 1px solid #ddd; border-radius: 4px; font-size: 13px; }
</style>
