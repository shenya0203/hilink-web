<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading">{{ t('common.loading') }}</div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

    <!-- 边缘计算标题 -->
    <div class="description-box">
      <div class="desc-title">{{ t('edge.title') }}</div>
      <div class="desc-content">{{ t('edge.description') }}</div>
    </div>

    <!-- 标签页选择 -->
    <div class="tabs">
      <button 
        v-for="(tab, index) in visibleTabs"
        :key="index"
        class="tab-btn" 
        :class="{ active: activeTab === tab.originalIndex }"
        @click="activeTab = tab.originalIndex"
      >
        {{ tab.name }}
      </button>
    </div>

    <!-- Tab 1: 网关使能 -->
    <div v-if="activeTab === 0" class="tab-content">
      <div class="form-section">
        <div class="form-group">
          <label>{{ t('edge.gatewayEnable') }}:</label>
          <select v-model.number="edgeConfig.all_en">
            <option :value="0">{{ t('edge.close') }}</option>
            <option :value="1">{{ t('edge.open') }}</option>
          </select>
        </div>
      </div>
      
      <div class="button-group">
        <button class="btn-save" @click="saveCurrentPage">{{ t('edge.saveCurrentPage') }}</button>
        <button v-if="edgeConfig.all_en === 1" class="btn-next" @click="nextTab">{{ t('edge.nextStep') }}</button>
      </div>
    </div>

    <!-- Tab 2: 数据采集 -->
    <div v-if="activeTab === 1" class="tab-content">
      <!-- 点表导入区域 -->
      <div class="import-section">
        <span class="label">{{ t('edge.pointImport') }}</span>
        <button class="btn-outline" @click="triggerFileSelect">{{ t('edge.selectFile') }}</button>
        <button class="btn-outline" @click="importCsv" :disabled="!selectedCsvFile">{{ t('edge.import') }}</button>
        <button class="btn-outline" @click="showExportModal">{{ t('edge.export') }}</button>
        <span class="file-hint">{{ t('edge.pleaseSelectFile') }}</span>
        <input type="file" ref="csvFileInput" @change="handleCsvSelect" accept=".csv" style="display:none" />
      </div>
      
      <div class="import-tips">
        <span class="tip-warning">{{ t('edge.importTip') }}</span>
        <br/>
        <span class="tip-info">{{ t('edge.pointsAdded') }}:{{ totalPoints }}</span>
        <span class="tip-info" style="margin-left: 20px;">{{ t('edge.pointsRemaining') }}:{{ 1000 - totalPoints }}</span>
      </div>

      <!-- 从机和数据点表格区域 -->
      <div class="table-container">
        <!-- 左侧从机表格 -->
        <div class="table-wrapper slave-table">
          <table>
            <thead>
              <tr>
                <th>{{ t('edge.slaveNumber') }}</th>
                <th>{{ t('edge.slaveName') }}</th>
                <th>{{ t('edge.slaveSource') }}</th>
                <th>{{ t('edge.slaveAddress') }}</th>
                <th>{{ t('edge.operation') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr 
                v-for="(slave, index) in slaveList" 
                :key="slave.id"
                :class="{ selected: selectedSlaveIndex === index }"
                @click="selectSlave(index)"
              >
                <td>{{ index + 1 }}</td>
                <td class="name-cell">{{ slave.name }}</td>
                <td>{{ getSlaveSource(slave) }}</td>
                <td>{{ slave.slaveAddress || t('edge.empty') }}</td>
                <td class="action-cell">
                  <template v-if="!slave.isSystem">
                    <button class="btn-small" @click.stop="editSlave(index)">{{ t('edge.edit') }}</button>
                    <button class="btn-small btn-danger" @click.stop="deleteSlave(index)">{{ t('edge.delete') }}</button>
                  </template>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- 右侧数据点表格 -->
        <div class="table-wrapper point-table">
          <table>
            <thead>
              <tr>
                <th>{{ t('edge.pointNumber') }}</th>
                <th>{{ t('edge.pointName') }}</th>
                <th>{{ t('edge.register') }}</th>
                <th>{{ t('edge.dataType') }}</th>
                <th>{{ t('edge.value') }}</th>
                <th>{{ t('edge.operation') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr 
                v-for="(point, index) in currentSlavePoints" 
                :key="point.id"
                :class="{ selected: selectedPointIndex === index }"
                @click="selectPoint(index)"
              >
                <td>{{ index + 1 }}</td>
                <td>{{ point.name }}</td>
                <td>{{ point.registerDisplay || '-' }}</td>
                <td>{{ point.dataType }}</td>
                <td>{{ point.value !== undefined ? point.value : '-' }}</td>
                <td class="action-cell">
                  <template v-if="!currentSlave?.isSystem">
                    <button class="btn-small" @click.stop="editPoint(index)">{{ t('edge.edit') }}</button>
                    <button v-if="!point.isDefault" class="btn-small btn-danger" @click.stop="deletePoint(index)">{{ t('edge.delete') }}</button>
                  </template>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- 按钮组 -->
      <div class="button-group">
        <button class="btn-action" @click="showAddSlaveModal">{{ t('edge.addSlave') }}</button>
        <button class="btn-action" @click="showAddPointModal" :disabled="!currentSlave || currentSlave.isSystem">{{ t('edge.addDataPoint') }}</button>
        <button class="btn-save" @click="saveCurrentPage">{{ t('edge.saveCurrentPage') }}</button>
        <button class="btn-next" @click="nextTab">{{ t('edge.nextStep') }}</button>
      </div>
    </div>

    <!-- Tab 3: 数据上报 -->
    <div v-if="activeTab === 2" class="tab-content">
      <!-- 上报分组导入区域 -->
      <div class="import-section">
        <span class="label">{{ t('edge.reportGroupImport') }}</span>
        <button class="btn-outline" @click="triggerReportFileSelect">{{ t('edge.selectFile') }}</button>
        <button class="btn-outline" @click="importReportJson" :disabled="!reportJsonFile">{{ t('edge.import') }}</button>
        <button class="btn-outline" @click="exportReportJson">{{ t('edge.export') }}</button>
        <span class="file-hint">{{ reportJsonFileName || t('edge.pleaseSelectJsonFile') }}</span>
        <input type="file" ref="reportJsonInput" @change="handleReportFileSelect" accept=".json" style="display:none" />
      </div>

      <div class="table-container">
        <div class="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>{{ t('edge.groupNumber') }}</th>
                <th>{{ t('edge.name') }}</th>
                <th>{{ t('edge.channelSelection') }}</th>
                <th>{{ t('edge.periodicReport') }}</th>
                <th>{{ t('edge.scheduledReport') }}</th>
                <th>{{ t('edge.changeReport') }}</th>
                <th>{{ t('edge.operation') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(group, index) in reportGroups" :key="group.id">
                <td>{{ index + 1 }}</td>
                <td>{{ group.name }}</td>
                <td>{{ group.channel }}</td>
                <td>{{ group.periodic ? t('edge.open') : t('edge.close') }}</td>
                <td>{{ group.scheduled ? t('edge.open') : t('edge.close') }}</td>
                <td>{{ t('edge.wholeGroupReport') }}</td>
                <td class="action-cell">
                  <button class="btn-small" @click="editReportGroup(index)">{{ t('edge.edit') }}</button>
                  <button class="btn-small btn-danger" @click="deleteReportGroup(index)">{{ t('edge.delete') }}</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      
      <div class="button-group">
        <button class="btn-action" @click="showAddReportGroupModal">{{ t('edge.addGroup') }}</button>
        <button class="btn-save" @click="saveCurrentPage">{{ t('edge.saveCurrentPage') }}</button>
        <button class="btn-next" @click="nextTab">{{ t('edge.nextStep') }}</button>
      </div>
    </div>

    <!-- Tab 4: 协议转换 -->
    <div v-if="activeTab === 3" class="tab-content">
      <!-- 协议转换点表导入区域 -->
      <div class="import-section">
        <span class="label">{{ t('edge.pointImport') }}</span>
        <button class="btn-outline" @click="triggerProtocolFileSelect">{{ t('edge.selectFile') }}</button>
        <button class="btn-outline" @click="importProtocolCsv" :disabled="!protocolCsvFile">{{ t('edge.import') }}</button>
        <button class="btn-outline" @click="exportProtocolCsv">{{ t('edge.export') }}</button>
        <span class="file-hint">{{ protocolCsvFile ? protocolCsvFile.name : t('edge.pleaseSelectFile') }}</span>
        <input type="file" ref="protocolCsvFileInput" @change="handleProtocolCsvSelect" accept=".csv" style="display:none" />
      </div>

      <div class="form-section">
        <div class="form-group">
          <label>{{ t('edge.enable') }}:</label>
          <select v-model.number="protocolConversionConfig.enable">
            <option :value="0">{{ t('edge.close') }}</option>
            <option :value="1">{{ t('edge.open') }}</option>
          </select>
        </div>

        <template v-if="protocolConversionConfig.enable === 1">
          <div class="form-group">
            <label>{{ t('edge.protocolType') }}:</label>
            <select v-model.number="protocolConversionConfig.protocol">
              <option :value="0">JSON</option>
              <option :value="1">ModBus TCP</option>
            </select>
          </div>

          <template v-if="protocolConversionConfig.protocol === 1">
             <div class="form-group">
               <label>{{ t('edge.stationAddress') }}:</label>
               <input v-model.number="protocolConversionConfig.stationAddress" type="number" />
             </div>
             <div class="form-group">
               <label>{{ t('edge.intByteOrder') }}:</label>
               <select v-model="protocolConversionConfig.intByteOrder">
                 <option value="ABCD">ABCD</option>
                 <option value="CDAB">CDAB</option>
                 <option value="BADC">BADC</option>
                 <option value="DCBA">DCBA</option>
               </select>
             </div>
             <div class="form-group">
               <label>{{ t('edge.floatByteOrder') }}:</label>
               <select v-model="protocolConversionConfig.floatByteOrder">
                 <option value="ABCD">ABCD</option>
                 <option value="CDAB">CDAB</option>
                 <option value="BADC">BADC</option>
                 <option value="DCBA">DCBA</option>
               </select>
             </div>
          </template>

          <div class="form-group">
            <label>{{ t('edge.channelSelection') }}:</label>
            <select v-model="protocolConversionConfig.channel">
              <option value="MQTT1">MQTT1</option>
              <option value="MQTT2">MQTT2</option>
              <option value="SOCKA">SOCKA</option>
              <option value="SOCKB">SOCKB</option>
            </select>
          </div>

          <template v-if="protocolConversionConfig.channel.startsWith('MQTT')">
            <div class="form-group" style="align-items: flex-start;">
              <label style="margin-top: 5px;">{{ t('edge.subTopic') }}:</label>
              <div style="flex: 1; display: flex; flex-direction: column;">
                <input 
                  v-model="protocolConversionConfig.subTopic" 
                  type="text" 
                  :style="{ color: protocolSubTopicError ? 'red' : '', borderColor: protocolSubTopicError ? 'red' : '' }"
                />
                <span v-if="protocolSubTopicError" style="color: red; font-size: 12px; margin-top: 4px;">{{ protocolSubTopicError }}</span>
              </div>
            </div>
            <div class="form-group">
              <label>{{ t('edge.subQos') }}:</label>
              <select v-model="protocolConversionConfig.subQos">
                <option value="QOS0">QOS0</option>
                <option value="QOS1">QOS1</option>
                <option value="QOS2">QOS2</option>
              </select>
            </div>
            <div class="form-group" style="align-items: flex-start;">
              <label style="margin-top: 5px;">{{ t('edge.pubTopic') }}:</label>
              <div style="flex: 1; display: flex; flex-direction: column;">
                <input 
                  v-model="protocolConversionConfig.pubTopic" 
                  type="text" 
                  :style="{ color: protocolPubTopicError ? 'red' : '', borderColor: protocolPubTopicError ? 'red' : '' }"
                />
                <span v-if="protocolPubTopicError" style="color: red; font-size: 12px; margin-top: 4px;">{{ protocolPubTopicError }}</span>
              </div>
            </div>
            <div class="form-group">
              <label>{{ t('edge.pubQos') }}:</label>
              <select v-model="protocolConversionConfig.pubQos">
                <option value="QOS0">QOS0</option>
                <option value="QOS1">QOS1</option>
                <option value="QOS2">QOS2</option>
              </select>
            </div>
            <div class="form-group">
              <label>{{ t('edge.retainMessage') }}:</label>
              <input type="checkbox" v-model="protocolConversionConfig.retain" />
            </div>
          </template>
        </template>
      </div>

      <!-- Protocol Conversion Table (Only for Modbus TCP) -->
      <div v-if="protocolConversionConfig.enable === 1 && protocolConversionConfig.protocol === 1" style="padding: 0 15px; margin-top: 15px;">
        <div class="table-header-bar" style="background-color: #e67e22; color: white; padding: 10px; font-weight: bold; text-align: center;">
          {{ t('edge.protocolConversion') }}
        </div>
        <div class="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>{{ t('edge.seq') }}</th>
                <th>{{ t('edge.pointName') }}</th>
                <th>{{ t('edge.pointSource') }}</th>
                <th>{{ t('edge.dataType') }}</th>
                <th>{{ t('edge.mappingAddress') }}</th>
                <th>{{ t('edge.rwStatus') }}</th>
                <th>{{ t('edge.operation') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(point, index) in mappingPoints" :key="point.id">
                <td>{{ index + 1 }}</td>
                <td>{{ point.pointName }}</td>
                <td>{{ point.source }}</td>
                <td>{{ point.dataType }}</td>
                <td>{{ point.mappingAddress }}</td>
                <td>{{ point.rwStatus }}</td>
                <td class="action-cell">
                  <button class="btn-small" @click="editMapping(index)">{{ t('edge.edit') }}</button>
                  <button class="btn-small btn-danger" @click="deleteMapping(index)">{{ t('edge.delete') }}</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="button-group">
        <button v-if="protocolConversionConfig.enable === 1 && protocolConversionConfig.protocol === 1" class="btn-action" @click="showAddMappingModal">{{ t('edge.addMappingPoint') }}</button>
        <button 
          class="btn-save" 
          @click="saveCurrentPage"
          :disabled="hasProtocolConversionErrors"
          :style="{ backgroundColor: hasProtocolConversionErrors ? '#ccc' : '', cursor: hasProtocolConversionErrors ? 'not-allowed' : 'pointer', opacity: hasProtocolConversionErrors ? 0.6 : 1 }"
        >
          {{ t('edge.saveCurrentPage') }}
        </button>
      </div>
    </div>

    <!-- 添加分组对话框 -->
    <div v-if="showReportGroupModal" class="modal-overlay" @click.self="closeReportGroupModal">
      <div class="modal" style="max-width: 600px;">
        <h3>{{ isEditingReportGroup ? t('edge.editGroup') : t('edge.addGroup') }}</h3>
        <div class="modal-form">
          <div class="form-group">
            <label>{{ t('edge.name') }}:</label>
            <div style="flex: 1; display: flex; flex-direction: column;">
              <input 
                v-model="reportGroupForm.name" 
                type="text" 
                :style="{ color: reportGroupNameError ? 'red' : '', borderColor: reportGroupNameError ? 'red' : '' }"
              />
              <span v-if="reportGroupNameError" style="color: red; font-size: 12px; margin-top: 4px;">{{ reportGroupNameError }}</span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('edge.channelSelection') }}:</label>
            <select v-model="reportGroupForm.channel">
              <option v-for="channel in availableChannels" :key="channel" :value="channel">
                {{ channel }}
              </option>
            </select>
          </div>
          <template v-if="['MQTT1', 'MQTT2'].includes(reportGroupForm.channel)">
            <div class="form-group" style="align-items: flex-start;">
              <label style="margin-top: 5px;">{{ t('edge.reportTopic') }}:</label>
              <div style="flex: 1; display: flex; flex-direction: column;">
                <input 
                  v-model="reportGroupForm.topic" 
                  type="text" 
                  :style="{ color: reportTopicError ? 'red' : '', borderColor: reportTopicError ? 'red' : '' }"
                />
                <span v-if="reportTopicError" style="color: red; font-size: 12px; margin-top: 4px;">{{ reportTopicError }}</span>
              </div>
            </div>
            <div class="form-group">
              <label>QOS:</label>
              <select v-model="reportGroupForm.qos">
                <option value="QOS0">QOS0</option>
                <option value="QOS1">QOS1</option>
                <option value="QOS2">QOS2</option>
              </select>
            </div>
            <div class="form-group">
              <label>{{ t('edge.messageRetain') }}:</label>
              <input type="checkbox" v-model="reportGroupForm.retain" />
            </div>
          </template>
          

          <div class="form-group">
            <label>{{ t('edge.periodicReport') }}:</label>
            <input type="checkbox" v-model="reportGroupForm.periodic" />
          </div>
          <div class="form-group" v-if="reportGroupForm.periodic" style="align-items: flex-start;">
            <label style="margin-top: 5px;">{{ t('edge.reportPeriod') }}:</label>
            <div style="flex: 1; display: flex; flex-direction: column;">
              <div class="input-with-unit">
                <input 
                  v-model.number="reportGroupForm.periodicInterval" 
                  type="number"
                  :style="{ color: reportPeriodError ? 'red' : '', borderColor: reportPeriodError ? 'red' : '' }"
                />
                <span class="unit">s</span>
              </div>
              <span v-if="reportPeriodError" style="color: red; font-size: 12px; margin-top: 4px;">{{ reportPeriodError }}</span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('edge.scheduledReport') }}:</label>
            <input type="checkbox" v-model="reportGroupForm.scheduled" />
          </div>
          <div class="form-group" v-if="reportGroupForm.scheduled">
            <label>{{ t('edge.reportTime') }}:</label>
            <select v-model.number="reportGroupForm.scheduledType">
              <option :value="1">{{ t('edge.wholeHour') }}</option>
              <option :value="2">{{ t('edge.wholeQuarter') }}</option>
              <option :value="3">{{ t('edge.wholeMinute') }}</option>
              <option :value="4">{{ t('edge.fixedTime') }}</option>
            </select>
          </div>
          <div class="form-group" v-if="reportGroupForm.scheduled && reportGroupForm.scheduledType === 4">
            <label>{{ t('edge.timeSelection') }}:</label>
            <div class="time-input-container">
              <input 
                v-model="timeParts.h" 
                type="text" 
                class="time-input"
                @input="validateTimeInput('h')"
                @blur="formatTimeBlur('h')"
              />
              <span class="time-separator">:</span>
              <input 
                v-model="timeParts.m" 
                type="text" 
                class="time-input"
                @input="validateTimeInput('m')"
                @blur="formatTimeBlur('m')"
              />
              <span class="time-separator">:</span>
              <input 
                v-model="timeParts.s" 
                type="text" 
                class="time-input"
                @input="validateTimeInput('s')"
                @blur="formatTimeBlur('s')"
              />
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('edge.reportDataFormat') }}:</label>
            <select v-model="reportGroupForm.format">
              <option value="Original">{{ t('edge.originalType') }}</option>
              <option value="String">{{ t('edge.stringType') }}</option>
            </select>
          </div>
          <div class="form-group">
            <label>{{ t('edge.errorFill') }}:</label>
            <input type="checkbox" v-model="reportGroupForm.errorFill" />
          </div>
          <div class="form-group" v-if="reportGroupForm.errorFill">
            <label>{{ t('edge.errorMessage') }}:</label>
            <input v-model="reportGroupForm.errorMsg" type="text" placeholder="error" />
          </div>
          
          <div class="form-group" v-if="reportGroupForm.channel === 'Cloud'">
             <label>{{ t('edge.selectedPoints') }}:</label>
             <div style="flex: 1; display: flex; flex-direction: column; gap: 5px;">
               <textarea 
                 v-model="reportGroupForm.selectedPointsText" 
                 rows="5" 
                 disabled 
                 style="width: 100%; padding: 5px; background-color: #f5f5f5; resize: none; cursor: default; color: #666;"
               ></textarea>
             </div>
          </div>
          <div class="form-group" style="align-items: flex-start;" v-if="reportGroupForm.channel !== 'Cloud'">
            <label style="margin-top: 5px;">{{ t('edge.reportTemplate') }}:</label>
            <div style="flex: 1; display: flex; flex-direction: column;">
              <textarea v-model="reportGroupForm.template" rows="10" style="width: 100%; padding: 5px; border: 1px solid #ddd; border-radius: 2px; font-family: monospace;"></textarea>
              <span v-if="isJsonError" style="color: red; font-size: 12px; margin-top: 5px;">Json格式错误</span>
            </div>
          </div>
        </div>
        <div class="modal-buttons">
          <button 
            class="btn-save" 
            @click="saveReportGroup"
            :disabled="hasReportGroupFormErrors"
            :style="{ backgroundColor: hasReportGroupFormErrors ? '#ccc' : '', cursor: hasReportGroupFormErrors ? 'not-allowed' : 'pointer', opacity: hasReportGroupFormErrors ? 0.6 : 1 }"
          >
            {{ t('edge.save') }}
          </button>
          <button class="btn-cancel" @click="closeReportGroupModal">{{ t('edge.cancel') }}</button>
          <button v-if="reportGroupForm.channel === 'Cloud'" class="btn-save" @click="openCloudPointModal">{{ t('edge.configPoints') }}</button>
        </div>
      </div>
    </div>

    <!-- 保存成功对话框 -->
    <div v-if="showSuccessModal" class="modal-overlay">
      <div class="modal" style="min-width: 300px; text-align: center;">
        <h3 style="border: none; margin-bottom: 10px;">{{ t('edge.saveSuccess') }}</h3>
        <div class="modal-buttons">
          <button class="btn-save" @click="handleRestart">{{ t('system.restart') }}</button>
          <button class="btn-next" @click="handleContinue">{{ t('edge.continueConfig') }}</button>
        </div>
      </div>
    </div>

    <!-- 解析结果对话框 -->
    <div v-if="showParseResultModal" class="modal-overlay" @click.self="closeParseResultModal">
      <div class="modal" style="min-width: 300px; text-align: center;">
        <div style="margin-bottom: 20px; font-size: 16px; font-weight: bold;">
          <span v-if="parseSuccess">🌐 {{ ipAddress }}</span>
        </div>
        
        <div v-if="parseSuccess" style="margin-bottom: 20px;">
          {{ t('edge.parseSuccess') }}
        </div>
        <div v-else style="text-align: left; margin-bottom: 20px;">
          <div>{{ t('edge.errorReason') }}:</div>
          <div>{{ parseErrorMsg }}</div>
        </div>
        
        <div class="modal-buttons" style="justify-content: center;">
          <button class="btn-save" @click="closeParseResultModal">{{ t('common.confirm') }}</button>
        </div>
      </div>
    </div>

    <!-- 编辑映射点位对话框 -->
    <div v-if="showEditMappingModal" class="modal-overlay" @click.self="closeEditMappingModal">
      <div class="modal" style="max-width: 400px;">
        <h3>{{ t('edge.edit') }}</h3>
        <div class="modal-form">
           <div class="form-group">
             <label style="width: 80px;">{{ t('edge.pointName') }}</label>
             <span>{{ editingMappingPoint.pointName }}</span>
           </div>
           <div class="form-group">
             <label style="width: 80px;">{{ t('edge.register') }}</label>
             <div style="display: flex; gap: 5px; align-items: center;">
               <select v-model="editingMappingPoint.regType" style="width: 60px; text-align: center;">
                 <option value="0">0</option>
                 <option value="1">1</option>
                 <option value="3">3</option>
                 <option value="4">4</option>
               </select>
               <span>、</span>
               <input v-model.number="editingMappingPoint.regAddr" type="number" style="width: 100px;" />
             </div>
           </div>
           <div class="form-group">
              <label style="width: 80px;"></label>
              <span style="color: red;">{{ computedEditingAddress }}</span>
           </div>
        </div>
        <div class="modal-buttons">
          <button class="btn-save" @click="saveEditedMapping">{{ t('edge.save') }}</button>
          <button class="btn-cancel" @click="closeEditMappingModal">{{ t('edge.cancel') }}</button>
        </div>
      </div>
    </div>

    <!-- 添加从机对话框 -->
    <div v-if="showSlaveModal" class="modal-overlay" @click.self="closeSlaveModal">
      <div class="modal">
        <h3>{{ isEditingSlave ? t('edge.editSlaveTitle') : t('edge.addSlaveTitle') }}</h3>
        <div class="modal-form">
          <div class="form-group" style="align-items: flex-start;">
            <label style="margin-top: 5px;">{{ t('edge.name') }}:</label>
            <div style="flex: 1; display: flex; flex-direction: column;">
              <input 
                v-model="slaveForm.name" 
                type="text" 
                placeholder="Device1" 
                :style="{ color: slaveNameError ? 'red' : '', borderColor: slaveNameError ? 'red' : '' }"
              />
              <span v-if="slaveNameError" style="color: red; font-size: 12px; margin-top: 4px;">{{ slaveNameError }}</span>
            </div>
          </div>
          <div class="form-group" style="align-items: flex-start;">
            <label style="margin-top: 5px;">{{ t('edge.detail') }}:</label>
            <div style="flex: 1; display: flex; flex-direction: column;">
              <input 
                v-model="slaveForm.detail" 
                type="text" 
                :style="{ color: slaveDetailError ? 'red' : '', borderColor: slaveDetailError ? 'red' : '' }"
              />
              <span v-if="slaveDetailError" style="color: red; font-size: 12px; margin-top: 4px;">{{ slaveDetailError }}</span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('edge.protocolType') }}:</label>
            <select v-model.number="slaveForm.protocol" :disabled="isEditingSlave">
              <option :value="0">{{ t('edge.modbusRtu') }}</option>
              <option :value="1">{{ t('edge.modbusTcp') }}</option>
            </select>
          </div>
          
          <!-- Modbus TCP 选项 -->
          <template v-if="slaveForm.protocol === 1">
            <div class="form-group" style="align-items: flex-start;">
              <label style="margin-top: 5px;">{{ t('edge.remoteAddress') }}:</label>
              <div style="flex: 1; display: flex; flex-direction: column;">
                <input 
                  v-model="slaveForm.remoteAddress" 
                  type="text" 
                  placeholder="192.168.0.21" 
                  :style="{ color: slaveRemoteAddressError ? 'red' : '', borderColor: slaveRemoteAddressError ? 'red' : '' }"
                />
                <span v-if="slaveRemoteAddressError" style="color: red; font-size: 12px; margin-top: 4px;">{{ slaveRemoteAddressError }}</span>
              </div>
            </div>
            <div class="form-group" style="align-items: flex-start;">
              <label style="margin-top: 5px;">{{ t('edge.remotePort') }}:</label>
              <div style="flex: 1; display: flex; flex-direction: column;">
                <input 
                  v-model.number="slaveForm.remotePort" 
                  type="number" 
                  placeholder="2100" 
                  :style="{ color: slaveRemotePortError ? 'red' : '', borderColor: slaveRemotePortError ? 'red' : '' }"
                />
                <span v-if="slaveRemotePortError" style="color: red; font-size: 12px; margin-top: 4px;">{{ slaveRemotePortError }}</span>
              </div>
            </div>
          </template>
          
          <!-- Modbus RTU 选项 -->
          <template v-if="slaveForm.protocol === 0">
            <div class="form-group">
              <label>{{ t('edge.serialConfig') }}:</label>
              <select v-model.number="slaveForm.serialPort">
                <option :value="1">{{ t('edge.serial1') }}</option>
                <option :value="2">{{ t('edge.serial2') }}</option>
              </select>
            </div>
          </template>
          
          <div class="form-group" style="align-items: flex-start;">
            <label style="margin-top: 5px;">{{ t('edge.slaveAddress') }}:</label>
            <div style="flex: 1; display: flex; flex-direction: column;">
              <input 
                v-model.number="slaveForm.slaveAddress" 
                type="number" 
                placeholder="1" 
                :style="{ color: slaveAddressError ? 'red' : '', borderColor: slaveAddressError ? 'red' : '' }"
              />
              <span v-if="slaveAddressError" style="color: red; font-size: 12px; margin-top: 4px;">{{ slaveAddressError }}</span>
            </div>
          </div>
          <div class="form-group" style="align-items: flex-start;">
            <label style="margin-top: 5px;">{{ t('edge.pollInterval') }}:</label>
            <div style="flex: 1; display: flex; flex-direction: column;">
              <div class="input-with-unit">
                <input 
                  v-model.number="slaveForm.pollInterval" 
                  type="number" 
                  placeholder="100" 
                  :style="{ color: slavePollIntervalError ? 'red' : '', borderColor: slavePollIntervalError ? 'red' : '' }"
                />
                <span class="unit">ms</span>
              </div>
              <span v-if="slavePollIntervalError" style="color: red; font-size: 12px; margin-top: 4px;">{{ slavePollIntervalError }}</span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('edge.mergeCollect') }}:</label>
            <input type="checkbox" v-model="slaveForm.mergeCollect" />
          </div>
        </div>
        <div class="modal-buttons">
          <button 
            class="btn-save" 
            @click="saveSlave"
            :disabled="hasSlaveFormErrors"
            :style="{ backgroundColor: hasSlaveFormErrors ? '#ccc' : '', cursor: hasSlaveFormErrors ? 'not-allowed' : 'pointer', opacity: hasSlaveFormErrors ? 0.6 : 1 }"
          >
            {{ t('edge.save') }}
          </button>
          <button class="btn-cancel" @click="closeSlaveModal">{{ t('edge.cancel') }}</button>
        </div>
      </div>
    </div>

    <!-- 添加数据点对话框 -->
    <div v-if="showPointModal" class="modal-overlay" @click.self="closePointModal">
      <div class="modal">
        <h3>{{ isEditingPoint ? t('edge.editPointTitle') : t('edge.addPointTitle') }}</h3>
        <div class="modal-form">
          <div class="form-group" style="align-items: flex-start;">
            <label style="margin-top: 5px;">{{ t('edge.name') }}:</label>
            <div style="flex: 1; display: flex; flex-direction: column;">
              <input 
                v-model="pointForm.name" 
                type="text" 
                placeholder="node0101" 
                :disabled="pointForm.isDefault" 
                :style="{ color: pointNameError ? 'red' : '', borderColor: pointNameError ? 'red' : '' }"
              />
              <span v-if="pointNameError" style="color: red; font-size: 12px; margin-top: 4px;">{{ pointNameError }}</span>
            </div>
          </div>
          <div class="form-group" v-if="!pointForm.isDefault" style="align-items: flex-start;">
            <label style="margin-top: 5px;">{{ t('edge.detail') }}:</label>
            <div style="flex: 1; display: flex; flex-direction: column;">
              <input 
                v-model="pointForm.detail" 
                type="text" 
                :style="{ color: pointDetailError ? 'red' : '', borderColor: pointDetailError ? 'red' : '' }"
              />
              <span v-if="pointDetailError" style="color: red; font-size: 12px; margin-top: 4px;">{{ pointDetailError }}</span>
            </div>
          </div>
          <div class="form-group" v-if="!pointForm.isDefault" style="align-items: flex-start;">
            <label style="margin-top: 5px;">{{ t('edge.registerType') }}:</label>
            <div style="flex: 1; display: flex; flex-direction: column;">
              <div style="display: flex; align-items: center;">
                <div class="register-input">
                  <select v-model.number="pointForm.registerType">
                    <option :value="0">0</option>
                    <option :value="1">1</option>
                    <option :value="3">3</option>
                    <option :value="4">4</option>
                  </select>
                  <input 
                    v-model.number="pointForm.registerAddress" 
                    type="number" 
                    placeholder="1" 
                    :style="{ color: (pointRegisterError || pointRegisterAddressError) ? 'red' : '', borderColor: (pointRegisterError || pointRegisterAddressError) ? 'red' : '' }"
                  />
                  <input 
                    v-if="pointForm.registerType === 4 && pointForm.dataType === 'Bit'"
                    v-model.number="pointForm.bitIndex" 
                    type="number" 
                    min="0" 
                    max="15" 
                    placeholder="0" 
                    style="width: 60px; flex: none;"
                  />
                </div>
                <span class="register-display">{{ computedRegisterAddress }}</span>
              </div>
              <span v-if="pointRegisterError" style="color: red; font-size: 12px; margin-top: 4px;">{{ pointRegisterError }}</span>
              <span v-if="pointRegisterAddressError && !pointRegisterError" style="color: red; font-size: 12px; margin-top: 4px;">{{ pointRegisterAddressError }}</span>
            </div>
          </div>
          <div class="form-group">
            <label>{{ t('edge.dataType') }}:</label>
            <select v-model="pointForm.dataType" :disabled="pointForm.isDefault">
              <option v-for="type in availableDataTypes" :key="type" :value="type">{{ type }}</option>
            </select>
          </div>
          <div class="form-group" v-if="!pointForm.isDefault">
            <label>{{ t('edge.decimalPlaces') }}:</label>
            <select v-model.number="pointForm.decimalPlaces">
              <option v-for="n in 7" :key="n-1" :value="n-1">{{ n - 1 }}</option>
            </select>
          </div>
          <div class="form-group" v-if="!pointForm.isDefault">
            <label>{{ t('edge.timeout') }}:</label>
            <div class="input-with-unit">
              <input v-model.number="pointForm.timeout" type="number" placeholder="200" />
              <span class="unit">ms</span>
            </div>
          </div>
          <div class="form-group" v-if="!pointForm.isDefault">
            <label>{{ t('edge.collectFormula') }}:</label>
            <input v-model="pointForm.collectFormula" type="text" />
          </div>
          <div class="form-group" v-if="!pointForm.isDefault">
            <label>{{ t('edge.controlFormula') }}:</label>
            <input v-model="pointForm.controlFormula" type="text" />
          </div>
          <div class="form-group" v-if="!pointForm.isDefault">
            <label>{{ t('edge.reportOnChange') }}:</label>
            <input type="checkbox" v-model="pointForm.reportOnChange" />
          </div>
          <div class="form-group" v-if="!pointForm.isDefault && pointForm.reportOnChange" style="align-items: flex-start;">
            <label style="margin-top: 5px;">{{ t('edge.changeRange') }}:</label>
            <div style="flex: 1; display: flex; flex-direction: column;">
              <input 
                v-model.number="pointForm.changeRange" 
                type="number" 
                placeholder="2" 
                :style="{ color: pointChangeRangeError ? 'red' : '', borderColor: pointChangeRangeError ? 'red' : '' }"
              />
              <span v-if="pointChangeRangeError" style="color: red; font-size: 12px; margin-top: 4px;">{{ pointChangeRangeError }}</span>
            </div>
          </div>
        </div>
        <div class="modal-buttons">
          <button 
            class="btn-save" 
            @click="savePoint"
            :disabled="hasPointFormErrors"
            :style="{ backgroundColor: hasPointFormErrors ? '#ccc' : '', cursor: hasPointFormErrors ? 'not-allowed' : 'pointer', opacity: hasPointFormErrors ? 0.6 : 1 }"
          >
            {{ t('edge.save') }}
          </button>
          <button class="btn-cancel" @click="closePointModal">{{ t('edge.cancel') }}</button>
        </div>
      </div>
    </div>

    <!-- 添加映射点位对话框 (Add Mapping Modal) -->
    <div v-if="showMappingModal" class="modal-overlay" @click.self="closeMappingModal">
      <div class="modal" style="max-width: 800px;">
        <h3>{{ t('edge.add') }}</h3>
        <div class="modal-form">
          <div class="form-group">
             <label>{{ t('edge.mappingStartAddress') }}:</label>
             <div class="input-with-unit" style="display: flex; gap: 10px;">
                <select v-model="mappingForm.startAddressType" style="width: 80px;">
                  <option value="0X">0X</option>
                  <option value="1X">1X</option>
                  <option value="3X">3X</option>
                  <option value="4X">4X</option>
                </select>
                <input v-model.number="mappingForm.startAddressValue" type="number" placeholder="1" style="width: 100px;" />
             </div>
             <label style="width: auto; margin-left: 20px;">{{ t('edge.pointSelection') }}:</label>
             <button class="btn-outline" @click="openPointSelectionModal">{{ t('edge.addPoint') }}</button>
          </div>
          
          <!-- Selected Points Table in Modal -->
          <div class="table-wrapper" style="max-height: 300px; overflow-y: auto; margin-top: 10px;">
             <table>
               <thead>
                 <tr>
                   <th>{{ t('edge.seq') }}</th>
                   <th>{{ t('edge.pointName') }}</th>
                   <th>{{ t('edge.slaveNameFull') }}</th>
                   <th>{{ t('edge.mappingAddress') }}</th>
                   <th>{{ t('edge.dataType') }}</th>
                   <th>{{ t('edge.rwStatus') }}</th>
                 </tr>
               </thead>
               <tbody>
                 <tr v-for="(p, index) in mappingForm.points" :key="index">
                   <td>{{ index + 1 }}</td>
                   <td>{{ p.name }}</td>
                   <td>{{ p.slaveName }}</td>
                   <td>{{ getCalculatedAddress(index) }}</td>
                   <td>{{ p.dataType }}</td>
                   <td>读写</td>
                 </tr>
               </tbody>
             </table>
          </div>
        </div>
        <div class="modal-buttons">
          <button class="btn-save" @click="saveMapping">{{ t('edge.confirm') }}</button>
          <button class="btn-cancel" @click="closeMappingModal">{{ t('edge.cancel') }}</button>
        </div>
      </div>
    </div>

    <!-- 点位选择对话框 (Point Selection Modal) -->
    <div v-if="showPointSelectionModal" class="modal-overlay" @click.self="closePointSelectionModal">
      <div class="modal" style="max-width: 700px;">
        <h3>{{ t('edge.pointSelection') }}</h3>
        <div class="modal-form">
           <div class="form-group">
             <label>{{ t('edge.slaveSelection') }}:</label>
             <select v-model="selectedMappingSlaveId">
               <option v-for="slave in availableMappingSlaves" :key="slave.id" :value="slave.id">
                 {{ slave.name }}
               </option>
             </select>
             <input v-model="mappingSearchQuery" type="text" :placeholder="t('edge.search')" style="margin-left: 10px;" />
             <button class="btn-outline">{{ t('edge.query') }}</button>
           </div>
           
           <div class="table-wrapper" style="max-height: 400px; overflow-y: auto;">
             <table>
               <thead>
                 <tr>
                   <th style="width: 50px;">
                     <input type="checkbox" :checked="isAllSelected" @change="toggleSelectAll" />
                   </th>
                   <th>{{ t('edge.pointName') }}</th>
                   <th>{{ t('edge.dataType') }}</th>
                   <th>{{ t('edge.rwStatus') }}</th>
                 </tr>
               </thead>
               <tbody>
                 <tr v-for="point in filteredSelectionPoints" :key="point.id">
                   <td>
                     <input type="checkbox" :checked="isPointSelected(point)" @change="togglePointSelection(point)" />
                   </td>
                   <td>{{ point.name }}</td>
                   <td>{{ point.dataType }}</td>
                   <td>{{ point.registerDisplay === 'State' ? '只读' : '读写' }}</td>
                 </tr>
               </tbody>
             </table>
           </div>
        </div>
        <div class="modal-buttons">
          <button class="btn-save" @click="confirmPointSelection">{{ t('edge.confirm') }}</button>
          <button class="btn-cancel" @click="closePointSelectionModal">{{ t('edge.cancel') }}</button>
        </div>
      </div>
    </div>
    <!-- Cloud Point Configuration Modal -->
    <div v-if="showCloudPointModal" class="modal-overlay" @click.self="closeCloudPointModal">
      <div class="modal" style="max-width: 700px;">
        <h3>{{ t('edge.configPoints') }}</h3>
        <div class="modal-form">
           <div class="form-group">
             <label>{{ t('edge.slaveSelection') }}:</label>
             <select v-model="cloudPointForm.slaveId">
               <option v-for="slave in availableCloudSlaves" :key="slave.id" :value="slave.id">
                 {{ slave.name }}
               </option>
             </select>
             <input v-model="cloudPointForm.searchQuery" type="text" :placeholder="t('edge.search')" style="margin-left: 10px;" />
             <button class="btn-outline">{{ t('edge.query') }}</button>
           </div>
           
           <div class="table-wrapper" style="max-height: 400px; overflow-y: auto;">
             <table>
               <thead>
                 <tr>
                   <th style="width: 50px;">
                     <!-- Optional: Select All for current view -->
                   </th>
                   <th>{{ t('edge.pointName') }}</th>
                   <th>{{ t('edge.dataType') }}</th>
                 </tr>
               </thead>
               <tbody>
                 <tr v-for="point in cloudPointList" :key="point.id">
                   <td>
                     <input type="checkbox" :checked="isCloudPointSelected(point)" @change="toggleCloudPointSelection(point)" />
                   </td>
                   <td>{{ point.name }}</td>
                   <td>{{ point.dataType }}</td>
                 </tr>
               </tbody>
             </table>
           </div>
        </div>
        <div class="modal-buttons">
          <button class="btn-save" @click="saveCloudPoints">{{ t('edge.save') }}</button>
          <button class="btn-cancel" @click="closeCloudPointModal">{{ t('edge.cancel') }}</button>
        </div>
      </div>
    </div>
    <!-- Export Options Modal -->
    <div v-if="showExportOptionsModal" class="modal-overlay" @click.self="showExportOptionsModal = false">
      <div class="modal" style="max-width: 400px; text-align: center;">
        <h3 style="border: none; margin-bottom: 20px;">{{ t('edge.exportOptions') || '导出选项' }}</h3>
        <div class="modal-buttons" style="justify-content: center; gap: 20px;">
          <button class="btn-save" @click="exportToCloud">到Cloud</button>
          <button class="btn-save" @click="exportToDevice">到设备</button>
          <button class="btn-cancel" @click="showExportOptionsModal = false">取消</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch, onUnmounted } from 'vue'
import apiClient from '../api/services'
import { useI18n } from '../i18n/useI18n.js'
import { 
  isValidIP, 
  isValidDetailInfo, 
  isValidModbusPort, 
  isValidPollInterval, 
  isValidSlaveAddress, 
  isValidRegisterAddress, 
  isValidChangeRange, 
  isValidReportPeriod, 
  isValidTopic 
} from '../utils/validation.js'

// 使用 i18n
const { t } = useI18n()

// 响应式数据
const loading = ref(true)
const error = ref(null)
const activeTab = ref(0)

// 标签页配置
const tabList = ref([
  { name: t('edge.tabGatewayEnable') },
  { name: t('edge.tabDataCollection') },
  { name: t('edge.tabDataReport') },
  { name: t('edge.tabProtocolConvert') }
])

// 边缘计算配置
const edgeConfig = ref({
  all_en: 1,
  refresh_frequency: 100,
  calc_period: 100,
  poll_interval: 100
})

// 边缘计算相关数据
const edgeFileContent = ref('')
const edgeReport = ref({ group: [] })
const edgeAccess = ref({ group: [] })
const edgeLinkCtrl = ref({ group: [] })

// 协议转换配置
const protocolConversionConfig = ref({
  enable: 0,
  protocol: 0, // 0: JSON, 1: Modbus TCP
  channel: 'MQTT1',
  subTopic: '/SubTopic',
  subQos: 'QOS0',
  pubTopic: '/PubTopic',
  pubQos: 'QOS0',
  retain: false,
  stationAddress: 1,
  intByteOrder: 'ABCD',
  floatByteOrder: 'ABCD'
})

// 协议转换验证错误状态
const protocolSubTopicError = ref('')
const protocolPubTopicError = ref('')

// 协议转换验证状态计算属性
const hasProtocolConversionErrors = computed(() => {
  if (protocolConversionConfig.value.enable !== 1) return false
  if (!protocolConversionConfig.value.channel.startsWith('MQTT')) return false
  return !!protocolSubTopicError.value || !!protocolPubTopicError.value
})

// 验证协议转换主题
const validateProtocolTopics = () => {
  if (protocolConversionConfig.value.enable === 1 && 
      protocolConversionConfig.value.channel.startsWith('MQTT')) {
    if (!isValidTopic(protocolConversionConfig.value.subTopic)) {
      protocolSubTopicError.value = t('edge.invalidSubTopic')
    } else {
      protocolSubTopicError.value = ''
    }
    
    if (!isValidTopic(protocolConversionConfig.value.pubTopic)) {
      protocolPubTopicError.value = t('edge.invalidPubTopic')
    } else {
      protocolPubTopicError.value = ''
    }
  } else {
    protocolSubTopicError.value = ''
    protocolPubTopicError.value = ''
  }
}

// 监听协议转换配置变化
watch(() => protocolConversionConfig.value.subTopic, () => {
  if (protocolConversionConfig.value.enable === 1 && 
      protocolConversionConfig.value.channel.startsWith('MQTT')) {
    if (!isValidTopic(protocolConversionConfig.value.subTopic)) {
      protocolSubTopicError.value = t('edge.invalidSubTopic')
    } else {
      protocolSubTopicError.value = ''
    }
  }
})

watch(() => protocolConversionConfig.value.pubTopic, () => {
  if (protocolConversionConfig.value.enable === 1 && 
      protocolConversionConfig.value.channel.startsWith('MQTT')) {
    if (!isValidTopic(protocolConversionConfig.value.pubTopic)) {
      protocolPubTopicError.value = t('edge.invalidPubTopic')
    } else {
      protocolPubTopicError.value = ''
    }
  }
})

watch(() => protocolConversionConfig.value.enable, () => {
  validateProtocolTopics()
})

watch(() => protocolConversionConfig.value.channel, () => {
  validateProtocolTopics()
})

const mappingPoints = ref([])
const showMappingModal = ref(false)
const showPointSelectionModal = ref(false)
const mappingForm = ref({
  startAddressType: '4X',
  startAddressValue: 1,
  points: []
})
const selectedMappingSlaveId = ref('')
const mappingSearchQuery = ref('')
const tempSelectedPoints = ref([]) // Points selected in the selection modal

const showEditMappingModal = ref(false)
const editingMappingPoint = ref({
  index: -1,
  pointName: '',
  regType: '0',
  regAddr: 1
})

const computedEditingAddress = computed(() => {
   return editingMappingPoint.value.regType + String(editingMappingPoint.value.regAddr).padStart(5, '0')
})

// 数据上报相关数据
const allChannels = ['MQTT1', 'MQTT2', 'SOCKA', 'SOCKB', 'Cloud']
const reportGroups = ref([])

const availableChannels = computed(() => {
  const usedChannels = reportGroups.value
    .filter((g, index) => {
      // If editing, exclude the current group being edited
      if (isEditingReportGroup.value && index === editingReportGroupIndex.value) {
        return false
      }
      return true
    })
    .map(g => g.channel)
    
  return allChannels.filter(c => !usedChannels.includes(c))
})
const showReportGroupModal = ref(false)
const isEditingReportGroup = ref(false)
const editingReportGroupIndex = ref(-1)
const showSuccessModal = ref(false)

const reportGroupForm = ref({
  name: '',
  channel: 'MQTT1',
  topic: '',
  qos: 'QOS0',
  retain: false,
  periodic: true,
  periodicInterval: 5,
  scheduled: false,
  scheduledType: 1,
  scheduledTime: '00:00:00',
  format: 'Original',
  errorFill: false,
  errorMsg: '',
  template: '',
  selectedPointsText: '' // New field for Cloud points display
})

const isJsonError = ref(false)
const reportGroupNameError = ref('')

// Cloud Point Configuration
const showCloudPointModal = ref(false)
const cloudPointForm = ref({
  slaveId: '',
  searchQuery: '',
  selectedPoints: [] // Array of strings "SlaveName-PointName"
})

const availableCloudSlaves = computed(() => {
  return slaveList.value.filter(s => !s.isSystem)
})

const cloudPointList = computed(() => {
  if (!cloudPointForm.value.slaveId) return []
  const slave = slaveList.value.find(s => s.id === cloudPointForm.value.slaveId)
  if (!slave) return []
  
  let points = slave.points
  if (cloudPointForm.value.searchQuery) {
    const q = cloudPointForm.value.searchQuery.toLowerCase()
    points = points.filter(p => p.name.toLowerCase().includes(q))
  }
  return points
})

const openCloudPointModal = () => {
  // Initialize with current selection
  const currentText = reportGroupForm.value.selectedPointsText || ''
  const currentSelection = currentText ? currentText.split('\n').filter(s => s.trim()) : []
  
  const firstSlave = availableCloudSlaves.value.length > 0 ? availableCloudSlaves.value[0].id : ''
  
  cloudPointForm.value = {
    slaveId: firstSlave,
    searchQuery: '',
    selectedPoints: [...currentSelection]
  }
  showCloudPointModal.value = true
}

const closeCloudPointModal = () => {
  showCloudPointModal.value = false
}

const isCloudPointSelected = (point) => {
  const slave = slaveList.value.find(s => s.id === cloudPointForm.value.slaveId)
  if (!slave) return false
  const key = `${slave.name}-${point.name}`
  return cloudPointForm.value.selectedPoints.includes(key)
}

const toggleCloudPointSelection = (point) => {
  const slave = slaveList.value.find(s => s.id === cloudPointForm.value.slaveId)
  if (!slave) return
  const key = `${slave.name}-${point.name}`
  const idx = cloudPointForm.value.selectedPoints.indexOf(key)
  if (idx >= 0) {
    cloudPointForm.value.selectedPoints.splice(idx, 1)
  } else {
    cloudPointForm.value.selectedPoints.push(key)
  }
}

const saveCloudPoints = () => {
  reportGroupForm.value.selectedPointsText = cloudPointForm.value.selectedPoints.join('\n')
  closeCloudPointModal()
}

// Time selection parts
const timeParts = ref({ h: '00', m: '00', s: '00' })

// Watch for changes in scheduledTime to update parts
watch(() => reportGroupForm.value.scheduledTime, (newVal) => {
  if (!newVal) return
  const parts = newVal.split(':')
  if (parts.length >= 2) {
    timeParts.value.h = parts[0] || '00'
    timeParts.value.m = parts[1] || '00'
    timeParts.value.s = parts[2] || '00'
  }
}, { immediate: true })

// Watch for changes in template to validate JSON
watch(() => reportGroupForm.value.template, (newVal) => {
  if (!newVal) {
    isJsonError.value = false
    return
  }
  try {
    JSON.parse(newVal)
    isJsonError.value = false
  } catch (e) {
    isJsonError.value = true
  }
})

const validateTimeInput = (type) => {
  let val = timeParts.value[type]
  // Remove non-digits
  val = val.replace(/\D/g, '')
  
  // Limit length to 2
  if (val.length > 2) val = val.slice(0, 2)
  
  const intVal = parseInt(val || '0')
  
  if (type === 'h') {
    if (intVal > 23) val = '23'
  } else {
    // m or s
    if (intVal > 59) val = '59'
  }
  
  timeParts.value[type] = val
  updateScheduledTime()
}

const formatTimeBlur = (type) => {
  let val = timeParts.value[type]
  if (!val) val = '00'
  val = val.padStart(2, '0')
  timeParts.value[type] = val
  updateScheduledTime()
}

const updateScheduledTime = () => {
  reportGroupForm.value.scheduledTime = `${timeParts.value.h}:${timeParts.value.m}:${timeParts.value.s}`
}

// JSON导入导出
const reportJsonInput = ref(null)
const reportJsonFile = ref(null)
const reportJsonFileName = ref('')
const showParseResultModal = ref(false)
const parseSuccess = ref(false)
const parseErrorMsg = ref('')
const ipAddress = ref(window.location.hostname)

// CSV文件选择
const csvFileInput = ref(null)
const selectedCsvFile = ref(null)
const showExportOptionsModal = ref(false)

// 协议转换CSV文件选择
const protocolCsvFileInput = ref(null)
const protocolCsvFile = ref(null)

// 系统默认数据点
const systemPoints = computed(() => [
  { id: 'sys_local_time', name: 'sys_local_time', dataType: t('edge.dataTypeString'), value: null },
  { id: 'sys_timestamp', name: 'sys_timestamp', dataType: t('edge.dataTypeString'), value: null },
  { id: 'sys_timestamp_ms', name: 'sys_timestamp_ms', dataType: t('edge.dataTypeString'), value: null },
  { id: 'sys_mac', name: 'sys_mac', dataType: t('edge.dataTypeString'), value: 0 },
  { id: 'sys_imei', name: 'sys_imei', dataType: t('edge.dataTypeString'), value: null },
  { id: 'sys_sn', name: 'sys_sn', dataType: t('edge.dataTypeString'), value: null },
  { id: 'sys_iccid', name: 'sys_iccid', dataType: t('edge.dataTypeString'), value: null },
  { id: 'sys_ver', name: 'sys_ver', dataType: t('edge.dataTypeString'), value: null },
  { id: 'sys_csq', name: 'sys_csq', dataType: t('edge.dataTypeString'), value: null },
  { id: 'sys_utc_time', name: 'sys_utc_time', dataType: t('edge.dataTypeString'), value: null },
  { id: 'sys_model', name: 'sys_model', dataType: t('edge.dataTypeString'), value: null }
])

// 从机列表
const slaveList = ref([
  {
    id: 'system',
    name: 'System_Sla..System',
    isSystem: true,
    slaveAddress: '',
    points: [] // 初始化为空数组，后续填充
  }
])

// 实时数据轮询
const pollTimer = ref(null)

const fetchEdgeValues = async () => {
  if (activeTab.value !== 1) return // Only for Data Collection tab (index 1)
  
  try {
    const res = await apiClient.get('/download_flex.cgi', { params: { name: 'edge_values' } })
    // ubus_adapter returns the data directly if successful, or wrapped?
    // entry.lua: response = ubus_adapter.get_edge_values()
    // ubus_adapter: return result.data (which is the table)
    // So res.data should be the table directly, or wrapped in standard response?
    // entry.lua uses send_json(response).
    // So if ubus_adapter returns { "Device1": ... }, then res.data is that object.
    // But wait, ubus_adapter.get_edge_values returns result.data.
    // Let's check ubus_daemon.lua again.
    // reply(req, { result = true, data = values })
    // So ubus_call returns { result = true, data = values }.
    // ubus_adapter returns result.data (values).
    // So entry.lua sends values.
    // So res.data is values.
    
    if (res.data) {
      updatePointsValue(res.data)
    }
  } catch (e) {
    console.error("Failed to fetch edge values", e)
  }
}

const updatePointsValue = (data) => {
  // data format: { "Device1": { "node0101": 12.5 }, ... }
  slaveList.value.forEach(slave => {
    const deviceData = data[slave.name]
    if (deviceData && slave.points) {
      slave.points.forEach(point => {
        if (deviceData[point.name] !== undefined) {
          point.value = deviceData[point.name]
        }
      })
    }
  })
}

const startPolling = () => {
  stopPolling()
  fetchEdgeValues()
  pollTimer.value = setInterval(fetchEdgeValues, 5000)
}

const stopPolling = () => {
  if (pollTimer.value) {
    clearInterval(pollTimer.value)
    pollTimer.value = null
  }
}

// Watch activeTab
watch(activeTab, (newTab) => {
  // activeTab is index in visibleTabs? No, originalIndex.
  // In template: activeTab = tab.originalIndex.
  // Tab 2: Data Collection is index 1.
  if (newTab === 1) {
    startPolling()
  } else {
    stopPolling()
  }
})

onMounted(() => {
  if (activeTab.value === 1) {
    startPolling()
  }
})

onUnmounted(() => {
  stopPolling()
})

// 选中的从机和数据点索引
const selectedSlaveIndex = ref(0)
const selectedPointIndex = ref(0)

// 对话框状态
const showSlaveModal = ref(false)
const showPointModal = ref(false)
const isEditingSlave = ref(false)
const isEditingPoint = ref(false)
const editingSlaveIndex = ref(-1)
const editingPointIndex = ref(-1)

// 从机表单
const slaveForm = ref({
  name: '',
  detail: '',
  protocol: 1, // 0: Modbus RTU, 1: Modbus TCP
  remoteAddress: '192.168.0.21',
  remotePort: 2100,
  serialPort: 1,
  slaveAddress: 1,
  pollInterval: 100,
  mergeCollect: false
})

// 数据点表单
const pointForm = ref({
  name: '',
  detail: '',
  registerType: 0,
  registerAddress: 1,
  dataType: 'Bool',
  decimalPlaces: 3,
  timeout: 200,
  collectFormula: '',
  controlFormula: '',
  reportOnChange: false,
  changeRange: 2
})

// 计算属性：可见的标签页（网关使能关闭时只显示网关使能标签）
const visibleTabs = computed(() => {
  if (edgeConfig.value.all_en === 0) {
    return [{ name: tabList.value[0].name, originalIndex: 0 }]
  }
  return tabList.value.map((tab, index) => ({ name: tab.name, originalIndex: index }))
})

// 计算属性：当前选中的从机
const currentSlave = computed(() => {
  return slaveList.value[selectedSlaveIndex.value] || null
})

// 计算属性：当前从机的数据点
const currentSlavePoints = computed(() => {
  return currentSlave.value?.points || []
})

// 计算属性：总数据点数量
const totalPoints = computed(() => {
  return slaveList.value.reduce((total, slave) => {
    if (slave.isSystem) return total
    return total + (slave.points?.length || 0)
  }, 0)
})

// 计算属性：根据寄存器类型显示可用的数据类型
const availableDataTypes = computed(() => {
  const regType = pointForm.value.registerType
  if (regType === 0 || regType === 1) {
    return ['Bool']
  } else if (regType === 3) {
    return [
      'Unsigned', 
      'Signed', 
      '32 Bit Unsigned (AB CD)', 
      '32 Bit Unsigned (CD AB)',
      '32 Bit Signed (AB CD)', 
      '32 Bit Signed (CD AB)',
      '32 Bit Float(AB CD)', 
      '32 Bit Float(CD AB)'
    ]
  } else if (regType === 4) {
    return [
      'Unsigned', 
      'Signed', 
      '32 Bit Unsigned (AB CD)', 
      '32 Bit Unsigned (CD AB)',
      '32 Bit Signed (AB CD)', 
      '32 Bit Signed (CD AB)',
      '32 Bit Float(AB CD)', 
      '32 Bit Float(CD AB)',
      'Bit'
    ]
  }
  return ['Bool']
})

// 计算属性：数据点名称校验
// 数据点名称校验
const pointNameError = ref('')

const validatePointName = () => {
  const name = pointForm.value.name
  
  // Layer 1: Format Validation
  const regex = /^[a-zA-Z0-9_]{1,20}$/
  if (!name || !regex.test(name)) {
    pointNameError.value = "(1-20字节 支持'a'-'z'/'A'-'Z'/'0'-'9'和'_')"
    return
  }
  
  if (!currentSlave.value) return
  
  // Layer 2: Duplicate Validation
  const duplicate = currentSlave.value.points.some((point, index) => {
    if (isEditingPoint.value && index === editingPointIndex.value) return false
    return point.name === name
  })
  
  if (duplicate) {
    pointNameError.value = "(名称重复！)"
    return
  }
  
  pointNameError.value = ''
}

watch(() => pointForm.value.name, () => {
  if (showPointModal.value) {
    validatePointName()
  }
})

// 数据点表单其他字段验证错误状态
const pointDetailError = ref('')
const pointRegisterAddressError = ref('')
const pointChangeRangeError = ref('')

// 数据点表单验证状态计算属性
const hasPointFormErrors = computed(() => {
  return !!pointNameError.value || 
    !!pointRegisterError.value ||
    !!pointDetailError.value || 
    !!pointRegisterAddressError.value || 
    !!pointChangeRangeError.value
})

// 监听数据点表单字段变化
watch(() => pointForm.value.detail, () => {
  if (showPointModal.value) {
    if (!isValidDetailInfo(pointForm.value.detail)) {
      pointDetailError.value = t('edge.invalidDetailInfo')
    } else {
      pointDetailError.value = ''
    }
  }
})

watch(() => pointForm.value.registerAddress, () => {
  if (showPointModal.value) {
    if (!isValidRegisterAddress(pointForm.value.registerAddress)) {
      pointRegisterAddressError.value = t('edge.invalidRegisterAddress')
    } else {
      pointRegisterAddressError.value = ''
    }
  }
})

watch(() => pointForm.value.changeRange, () => {
  if (showPointModal.value && pointForm.value.reportOnChange) {
    if (!isValidChangeRange(pointForm.value.changeRange)) {
      pointChangeRangeError.value = t('edge.invalidChangeRange')
    } else {
      pointChangeRangeError.value = ''
    }
  }
})

watch(() => pointForm.value.reportOnChange, () => {
  if (showPointModal.value) {
    if (pointForm.value.reportOnChange) {
      if (!isValidChangeRange(pointForm.value.changeRange)) {
        pointChangeRangeError.value = t('edge.invalidChangeRange')
      } else {
        pointChangeRangeError.value = ''
      }
    } else {
      pointChangeRangeError.value = ''
    }
  }
})

// 获取下一个可用寄存器地址
const getNextRegisterAddress = (type) => {
  if (!currentSlave.value) return 1
  
  // Filter points by register type
  const points = currentSlave.value.points.filter(p => p.registerType === type)
  
  if (points.length === 0) return 1
  
  // Find max address
  const maxAddr = Math.max(...points.map(p => p.registerAddress || 0))
  
  let nextAddr = maxAddr + 1
  if (nextAddr > 65535) {
     return null
  }
  return nextAddr
}

// 计算属性：寄存器地址重复校验
const pointRegisterError = computed(() => {
  if (!currentSlave.value) return null
  const type = pointForm.value.registerType
  const addr = pointForm.value.registerAddress
  
  if (addr === null || addr === undefined || addr === '') return null
  
  const duplicate = currentSlave.value.points.some((point, index) => {
    if (isEditingPoint.value && index === editingPointIndex.value) return false
    return point.registerType === type && point.registerAddress === addr
  })
  
  return duplicate ? t('edge.addressExists') : null
})

// 计算属性：从机名称校验
// 从机名称校验
const slaveNameError = ref('')

const validateSlaveName = () => {
  const name = slaveForm.value.name
  
  // Layer 1: Format Validation
  const regex = /^[a-zA-Z0-9_]{1,20}$/
  if (!name || !regex.test(name)) {
    slaveNameError.value = "(1-20字节 支持'a'-'z'/'A'-'Z'/'0'-'9'和'_')"
    return
  }
  
  // Layer 2: Duplicate Validation
  const duplicate = slaveList.value.some((slave, index) => {
    if (isEditingSlave.value && index === editingSlaveIndex.value) return false
    return slave.name === name
  })
  
  if (duplicate) {
    slaveNameError.value = "(名称重复！)"
    return
  }
  
  slaveNameError.value = ''
}

watch(() => slaveForm.value.name, () => {
  if (showSlaveModal.value) {
    validateSlaveName()
  }
})

// 从机表单其他字段验证错误状态
const slaveDetailError = ref('')
const slaveRemoteAddressError = ref('')
const slaveRemotePortError = ref('')
const slavePollIntervalError = ref('')
const slaveAddressError = ref('')

// 从机表单验证函数
const validateSlaveForm = () => {
  // 验证详细信息
  if (!isValidDetailInfo(slaveForm.value.detail)) {
    slaveDetailError.value = t('edge.invalidDetailInfo')
  } else {
    slaveDetailError.value = ''
  }
  
  // 验证服务器地址 (仅 Modbus TCP)
  if (slaveForm.value.protocol === 1) {
    if (!isValidIP(slaveForm.value.remoteAddress)) {
      slaveRemoteAddressError.value = t('edge.invalidServerAddress')
    } else {
      slaveRemoteAddressError.value = ''
    }
    
    // 验证端口
    if (!isValidModbusPort(slaveForm.value.remotePort)) {
      slaveRemotePortError.value = t('edge.invalidModbusPort')
    } else {
      slaveRemotePortError.value = ''
    }
  } else {
    slaveRemoteAddressError.value = ''
    slaveRemotePortError.value = ''
  }
  
  // 验证轮询间隔
  if (!isValidPollInterval(slaveForm.value.pollInterval)) {
    slavePollIntervalError.value = t('edge.invalidPollInterval')
  } else {
    slavePollIntervalError.value = ''
  }
  
  // 验证从机地址
  if (!isValidSlaveAddress(slaveForm.value.slaveAddress)) {
    slaveAddressError.value = t('edge.invalidSlaveAddress')
  } else {
    slaveAddressError.value = ''
  }
}

// 从机表单验证状态计算属性
const hasSlaveFormErrors = computed(() => {
  return !!slaveNameError.value || 
    !!slaveDetailError.value || 
    !!slaveRemoteAddressError.value || 
    !!slaveRemotePortError.value || 
    !!slavePollIntervalError.value || 
    !!slaveAddressError.value
})

// 监听从机表单字段变化
watch(() => slaveForm.value.detail, () => {
  if (showSlaveModal.value) {
    if (!isValidDetailInfo(slaveForm.value.detail)) {
      slaveDetailError.value = t('edge.invalidDetailInfo')
    } else {
      slaveDetailError.value = ''
    }
  }
})

watch(() => slaveForm.value.remoteAddress, () => {
  if (showSlaveModal.value && slaveForm.value.protocol === 1) {
    if (!isValidIP(slaveForm.value.remoteAddress)) {
      slaveRemoteAddressError.value = t('edge.invalidServerAddress')
    } else {
      slaveRemoteAddressError.value = ''
    }
  }
})

watch(() => slaveForm.value.remotePort, () => {
  if (showSlaveModal.value && slaveForm.value.protocol === 1) {
    if (!isValidModbusPort(slaveForm.value.remotePort)) {
      slaveRemotePortError.value = t('edge.invalidModbusPort')
    } else {
      slaveRemotePortError.value = ''
    }
  }
})

watch(() => slaveForm.value.pollInterval, () => {
  if (showSlaveModal.value) {
    if (!isValidPollInterval(slaveForm.value.pollInterval)) {
      slavePollIntervalError.value = t('edge.invalidPollInterval')
    } else {
      slavePollIntervalError.value = ''
    }
  }
})

watch(() => slaveForm.value.slaveAddress, () => {
  if (showSlaveModal.value) {
    if (!isValidSlaveAddress(slaveForm.value.slaveAddress)) {
      slaveAddressError.value = t('edge.invalidSlaveAddress')
    } else {
      slaveAddressError.value = ''
    }
  }
})

watch(() => slaveForm.value.protocol, () => {
  if (showSlaveModal.value) {
    // 重新验证协议相关字段
    if (slaveForm.value.protocol === 1) {
      if (!isValidIP(slaveForm.value.remoteAddress)) {
        slaveRemoteAddressError.value = t('edge.invalidServerAddress')
      } else {
        slaveRemoteAddressError.value = ''
      }
      if (!isValidModbusPort(slaveForm.value.remotePort)) {
        slaveRemotePortError.value = t('edge.invalidModbusPort')
      } else {
        slaveRemotePortError.value = ''
      }
    } else {
      slaveRemoteAddressError.value = ''
      slaveRemotePortError.value = ''
    }
  }
})

// 计算属性：生成寄存器地址显示
const computedRegisterAddress = computed(() => {
  const type = pointForm.value.registerType
  const addr = pointForm.value.registerAddress || 0
  // 格式：寄存器类型 + 5位地址
  let str = String(type) + String(addr).padStart(5, '0')
  
  if (type === 4 && pointForm.value.dataType === 'Bit') {
    str += `.${pointForm.value.bitIndex || 0}`
  }
  
  return str
})

// 监听寄存器类型变化，重置数据类型
watch(() => pointForm.value.registerType, (newType) => {
  const types = availableDataTypes.value
  if (!types.includes(pointForm.value.dataType)) {
    pointForm.value.dataType = types[0]
  }
  
  // 自动填充地址（仅在添加模式下）
  if (!isEditingPoint.value) {
    pointForm.value.registerAddress = getNextRegisterAddress(newType)
  }
})

// 监听位索引变化，限制范围 0-15
watch(() => pointForm.value.bitIndex, (newVal) => {
  if (newVal === undefined || newVal === null || newVal === '') return
  if (newVal < 0) pointForm.value.bitIndex = 0
  if (newVal > 15) pointForm.value.bitIndex = 15
})

// 获取从机来源显示
const getSlaveSource = (slave) => {
  if (slave.isSystem) return 'System'
  if (slave.protocol === 1) {
    return `${slave.remoteAddress}:${slave.remotePort}`
  }
  return `串口${slave.serialPort}`
}

// 选择从机
const selectSlave = (index) => {
  selectedSlaveIndex.value = index
  selectedPointIndex.value = 0
}

// 选择数据点
const selectPoint = (index) => {
  selectedPointIndex.value = index
}

// 数据上报管理
const showAddReportGroupModal = () => {
  isEditingReportGroup.value = false
  editingReportGroupIndex.value = -1
  
  let counter = reportGroups.value.length + 1
  let defaultName = `Report${counter}`
  while (reportGroups.value.some(g => g.name === defaultName)) {
    counter++
    defaultName = `Report${counter}`
  }

  // Calculate default channel
  const usedChannels = reportGroups.value.map(g => g.channel)
  const freeChannels = allChannels.filter(c => !usedChannels.includes(c))
  const defaultChannel = freeChannels.length > 0 ? freeChannels[0] : ''

  reportGroupForm.value = {
    name: defaultName,
    channel: defaultChannel,
    topic: '/UploadTopic',
    qos: 'QOS0',
    retain: false,
    periodic: true,
    periodicInterval: 5,
    scheduled: false,
    scheduledType: 1,
    scheduledTime: '00:00:00',
    format: 'Original',
    errorFill: false,
    errorMsg: '',
    errorMsg: '',
    template: '{\n  "device01": {\n    "node0101": "node0101",\n    "node0102": "node0102"\n  },\n  "time": "sys_local_time"\n}',
    selectedPointsText: ''
  }
  showReportGroupModal.value = true
  isJsonError.value = false
  reportGroupNameError.value = ''
}

const editReportGroup = (index) => {
  isEditingReportGroup.value = true
  editingReportGroupIndex.value = index
  reportGroupForm.value = { ...reportGroups.value[index] }
  showReportGroupModal.value = true
  reportGroupNameError.value = ''
  // Validate initial value
  try {
    if (reportGroupForm.value.template) {
      JSON.parse(reportGroupForm.value.template)
      isJsonError.value = false
    }
  } catch (e) {
    isJsonError.value = true
  }
}

const deleteReportGroup = (index) => {
  reportGroups.value.splice(index, 1)
}

const closeReportGroupModal = () => {
  showReportGroupModal.value = false
}

const validateReportGroupName = () => {
  const name = reportGroupForm.value.name
  
  // Layer 1: Format Validation
  const regex = /^[a-zA-Z0-9_]{1,20}$/
  if (!name || !regex.test(name)) {
    // If empty, it also fails this regex (length 1-20)
    // But if we want to be specific about "entering content", usually empty is handled by "Required".
    // However, the regex requires 1 char minimum.
    // If the user clears the input, we should probably show the format error or a required error.
    // Given the prompt's specific error message for the regex failure:
    reportGroupNameError.value = "(1-20字节 支持'a'-'z'/'A'-'Z'/'0'-'9'和'_')"
    return
  }
  
  // Layer 2: Duplicate Validation
  const duplicate = reportGroups.value.some((g, i) => {
    if (isEditingReportGroup.value && i === editingReportGroupIndex.value) return false
    return g.name === name
  })
  
  if (duplicate) {
    reportGroupNameError.value = "(名称重复！)"
    return
  }
  
  reportGroupNameError.value = ''
}

watch(() => reportGroupForm.value.name, () => {
  if (showReportGroupModal.value) {
    validateReportGroupName()
  }
})

// 上报分组表单其他字段验证错误状态
const reportPeriodError = ref('')
const reportTopicError = ref('')

// 上报分组表单验证状态计算属性
const hasReportGroupFormErrors = computed(() => {
  return !!reportGroupNameError.value || 
    !!reportPeriodError.value || 
    !!reportTopicError.value ||
    isJsonError.value
})

// 监听上报分组表单字段变化
watch(() => reportGroupForm.value.periodicInterval, () => {
  if (showReportGroupModal.value && reportGroupForm.value.periodic) {
    if (!isValidReportPeriod(reportGroupForm.value.periodicInterval)) {
      reportPeriodError.value = t('edge.invalidReportPeriod')
    } else {
      reportPeriodError.value = ''
    }
  }
})

watch(() => reportGroupForm.value.periodic, () => {
  if (showReportGroupModal.value) {
    if (reportGroupForm.value.periodic) {
      if (!isValidReportPeriod(reportGroupForm.value.periodicInterval)) {
        reportPeriodError.value = t('edge.invalidReportPeriod')
      } else {
        reportPeriodError.value = ''
      }
    } else {
      reportPeriodError.value = ''
    }
  }
})

watch(() => reportGroupForm.value.topic, () => {
  if (showReportGroupModal.value && ['MQTT1', 'MQTT2'].includes(reportGroupForm.value.channel)) {
    if (!isValidTopic(reportGroupForm.value.topic)) {
      reportTopicError.value = t('edge.invalidTopic')
    } else {
      reportTopicError.value = ''
    }
  }
})

watch(() => reportGroupForm.value.channel, () => {
  if (showReportGroupModal.value) {
    if (['MQTT1', 'MQTT2'].includes(reportGroupForm.value.channel)) {
      if (!isValidTopic(reportGroupForm.value.topic)) {
        reportTopicError.value = t('edge.invalidTopic')
      } else {
        reportTopicError.value = ''
      }
    } else {
      reportTopicError.value = ''
    }
  }
})

const saveReportGroup = () => {
  if (!reportGroupForm.value.name) {
    alert(t('edge.pleaseInputPointName')) // Reuse
    return
  }
  
  validateReportGroupName()
  
  if (reportGroupNameError.value) {
    return
  }
  
  const newGroup = {
    id: isEditingReportGroup.value ? reportGroups.value[editingReportGroupIndex.value].id : `group_${Date.now()}`,
    ...reportGroupForm.value
  }
  
  if (isEditingReportGroup.value) {
    reportGroups.value[editingReportGroupIndex.value] = newGroup
  } else {
    reportGroups.value.push(newGroup)
  }
  
  closeReportGroupModal()
}

const saveReportData = async () => {
  // 1. Save Group Config (group.json)
  const groupConfig = {
    group: reportGroups.value.map(g => {
      const isCloud = g.channel === 'Cloud'
      
      // Construct ucld_node for Cloud
      let ucldNode = []
      if (isCloud && g.selectedPointsText) {
        const lines = g.selectedPointsText.split('\n').filter(l => l.trim())
        const map = {}
        lines.forEach(line => {
          const parts = line.split('-')
          if (parts.length >= 2) {
            const slaveName = parts[0]
            const nodeName = parts.slice(1).join('-') // In case node name has hyphen
            if (!map[slaveName]) map[slaveName] = []
            map[slaveName].push(nodeName)
          }
        })
        ucldNode = Object.keys(map).map(slaveName => ({
          slave_name: slaveName,
          node_list: map[slaveName]
        }))
      }

      return {
        name: g.name,
        link: g.channel,
        topic: g.topic, // Keep value even if hidden
        qos: g.qos === 'QOS0' ? 0 : (g.qos === 'QOS1' ? 1 : 2), // Keep value
        retention: g.retain ? 1 : 0, // Keep value
        cond: {
          period: g.periodic ? g.periodicInterval : 0,
          timed: {
            type: g.scheduled ? g.scheduledType : 0,
            hh: g.scheduled && g.scheduledType === 4 ? parseInt(g.scheduledTime.split(':')[0]) || 0 : 0,
            mm: g.scheduled && g.scheduledType === 4 ? parseInt(g.scheduledTime.split(':')[1]) || 0 : 0
          }
        },
        data_report_type: g.format === 'Original' ? 0 : 1,
        change_report_type: 0,
        err_enable: g.errorFill ? 1 : 0,
        err_info: g.errorMsg,
        tmpl_file: isCloud ? "" : `/template/${g.name}.json`,
        fkey_md5: "00000000000000000000000000000000",
        ucld_node: ucldNode
        // tmpl_cont excluded for save
      }
    })
  }
  
  // Request 1: POST /upload/nv1
  await apiClient.post('/upload/nv1', JSON.stringify(groupConfig), {
    headers: { 'Content-Type': 'application/json' }
  })
  
  // Request 2: POST /upload/nv2 (Only if nv1 succeeds)
  // Payload: name="c", filename="edge_report", content=JSON string
  const formDataNv2 = new FormData()
  // Create a blob from the JSON string
  const jsonBlob = new Blob([JSON.stringify(groupConfig)], { type: 'application/octet-stream' })
  formDataNv2.append('c', jsonBlob, 'edge_report')
  
  await apiClient.post('/upload/nv2', formDataNv2, {
    headers: { 'Content-Type': 'multipart/form-data' }
  })

  // 3. Save Templates (report_template.json) - Only for non-Cloud groups or if needed
  // Format: GroupName:{...}\nGroupName:{...}
  let templateContent = ''
  reportGroups.value.forEach((g) => {
    if (g.channel !== 'Cloud') {
       templateContent += `${g.name}:${g.template}\n`
    }
  })
  
  if (templateContent) {
    const formData = new FormData()
    formData.append('c', new Blob([templateContent]), 'report')
    
    await apiClient.post('/upload/template', formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
  }
}

const handleRestart = async () => {
  try {
    await apiClient.get('/action_restart.cgi')
    alert(t('system.restartSuccess'))
  } catch (err) {
    console.error(err)
    alert(t('system.restartFailed'))
  }
  showSuccessModal.value = false
}

const handleContinue = () => {
  showSuccessModal.value = false
  nextTab()
}

// 文件选择处理
const triggerFileSelect = () => {
  csvFileInput.value?.click()
}

const handleCsvSelect = (event) => {
  const files = event.target.files
  if (files && files.length > 0) {
    selectedCsvFile.value = files[0]
    console.log('选择了CSV文件:', files[0].name)
  }
}

// 导入CSV
const importCsv = async () => {
  if (!selectedCsvFile.value) {
    alert(t('edge.pleaseSelectFileFirst'))
    return
  }
  
  try {
    const formData = new FormData()
    formData.append('file', selectedCsvFile.value)
    
    await apiClient.post('/upload/edge', formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    
    alert(t('edge.importSuccess'))
    selectedCsvFile.value = null
    await loadData()
  } catch (err) {
    console.error('导入失败:', err)
    alert(t('edge.importFailed') + ': ' + (err.response?.data?.msg || err.message))
  }
}

// 导出选项对话框
const showExportModal = () => {
  showExportOptionsModal.value = true
}

// 导出到设备 (原导出CSV)
const exportToDevice = async () => {
  showExportOptionsModal.value = false
  try {
    const response = await apiClient.get('/download_file.cgi', {
      params: { name: 'edge' },
      responseType: 'text'
    })
    
    const blob = new Blob([response.data], { type: 'text/csv' })
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'edge_points.csv'
    a.click()
    window.URL.revokeObjectURL(url)
  } catch (err) {
    console.error('导出失败:', err)
    alert(t('edge.exportFailed') + ': ' + (err.response?.data?.msg || err.message))
  }
}

// 导出到Cloud
const exportToCloud = () => {
  try {
    // 获取当前点表的CSV内容
    const csvContent = generateCsvContent()

    // Base64 encode (handling UTF-8)
    const base64Str = btoa(unescape(encodeURIComponent(csvContent)))
    
    const blob = new Blob([base64Str], { type: 'text/plain' })
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'point_table.cloud'
    a.click()
    window.URL.revokeObjectURL(url)
    
    showExportOptionsModal.value = false
  } catch (err) {
    console.error('Export to Cloud failed:', err)
    alert(t('edge.exportFailed') + ': ' + err.message)
  }
}

// 从机对话框操作
const showAddSlaveModal = () => {
  isEditingSlave.value = false
  editingSlaveIndex.value = -1
  
  // Generate unique default name
  let counter = 1
  let defaultName = `Device${counter}`
  while (slaveList.value.some(s => s.name === defaultName)) {
    counter++
    defaultName = `Device${counter}`
  }

  slaveForm.value = {
    name: defaultName,
    detail: '',
    protocol: 1,
    remoteAddress: '192.168.0.21',
    remotePort: 2100,
    serialPort: 1,
    slaveAddress: 1,
    pollInterval: 100,
    mergeCollect: false
  }
  showSlaveModal.value = true
  slaveNameError.value = ''
}

const editSlave = (index) => {
  const slave = slaveList.value[index]
  if (slave.isSystem) return
  
  isEditingSlave.value = true
  editingSlaveIndex.value = index
  slaveForm.value = { ...slave }
  showSlaveModal.value = true
  slaveNameError.value = ''
}

const closeSlaveModal = () => {
  showSlaveModal.value = false
}

const saveSlave = () => {
  if (!slaveForm.value.name) {
    alert(t('edge.pleaseInputSlaveName'))
    return
  }
  
  validateSlaveName()
  
  if (slaveNameError.value) {
    return
  }
  
  const newSlave = {
    id: isEditingSlave.value ? slaveList.value[editingSlaveIndex.value].id : `slave_${Date.now()}`,
    ...slaveForm.value,
    isSystem: false,
    points: isEditingSlave.value ? slaveList.value[editingSlaveIndex.value].points : [
      {
        id: `point_${Date.now()}`,
        name: `${slaveForm.value.name}_state`,
        dataType: 'Bool',
        registerType: 0,
        registerAddress: 0,
        registerDisplay: 'State',
        value: null,
        isDefault: true
      }
    ]
  }
  
  if (isEditingSlave.value) {
    slaveList.value[editingSlaveIndex.value] = newSlave
  } else {
    slaveList.value.push(newSlave)
    selectedSlaveIndex.value = slaveList.value.length - 1
  }
  
  closeSlaveModal()
}

const deleteSlave = (index) => {
  const slave = slaveList.value[index]
  if (slave.isSystem) return
  
  if (confirm(`${t('edge.confirmDeleteSlave')} "${slave.name}" 吗？`)) {
    slaveList.value.splice(index, 1)
    if (selectedSlaveIndex.value >= slaveList.value.length) {
      selectedSlaveIndex.value = slaveList.value.length - 1
    }
  }
}

// 数据点对话框操作
const showAddPointModal = () => {
  if (!currentSlave.value || currentSlave.value.isSystem) return
  
  isEditingPoint.value = false
  editingPointIndex.value = -1
  // Calculate default name
  // 1. Slave Index (slaveList[0] is System, so selectedSlaveIndex is the 1-based index for CSV devices)
  const slaveIdxStr = String(selectedSlaveIndex.value).padStart(2, '0')
  
  // 2. Point Index (ignoring default points like State)
  const existingUserPoints = currentSlave.value.points.filter(p => !p.isDefault).length
  let counter = existingUserPoints + 1
  let pointIdxStr = String(counter).padStart(2, '0')
  let defaultName = `node${slaveIdxStr}${pointIdxStr}`
  
  // Ensure uniqueness
  while (currentSlave.value.points.some(p => p.name === defaultName)) {
    counter++
    pointIdxStr = String(counter).padStart(2, '0')
    defaultName = `node${slaveIdxStr}${pointIdxStr}`
  }

  pointForm.value = {
    name: defaultName,
    detail: '',
    registerType: 0,
    registerAddress: getNextRegisterAddress(0),
    bitIndex: 0,
    dataType: 'Bool',
    decimalPlaces: 3,
    timeout: 200,
    collectFormula: '',
    controlFormula: '',
    reportOnChange: false,
    changeRange: 2
  }
  showPointModal.value = true
  pointNameError.value = ''
}

const editPoint = (index) => {
  if (!currentSlave.value || currentSlave.value.isSystem) return
  
  const point = currentSlave.value.points[index]
  isEditingPoint.value = true
  editingPointIndex.value = index
  pointForm.value = { bitIndex: 0, changeRange: 2, ...point }
  showPointModal.value = true
  pointNameError.value = ''
}

const closePointModal = () => {
  showPointModal.value = false
}

const savePoint = () => {
  if (!pointForm.value.name) {
    alert(t('edge.pleaseInputPointName'))
    return
  }
  
  validatePointName()
  
  if (pointNameError.value || pointRegisterError.value) {
    return
  }
  
  const newPoint = {
    id: isEditingPoint.value ? currentSlave.value.points[editingPointIndex.value].id : `point_${Date.now()}`,
    ...pointForm.value,
    registerDisplay: pointForm.value.isDefault ? pointForm.value.registerDisplay : computedRegisterAddress.value,
    value: null
  }
  
  if (isEditingPoint.value) {
    currentSlave.value.points[editingPointIndex.value] = newPoint
  } else {
    currentSlave.value.points.push(newPoint)
  }
  
  closePointModal()
}

const deletePoint = (index) => {
  if (!currentSlave.value || currentSlave.value.isSystem) return
  
  const point = currentSlave.value.points[index]
  if (confirm(`${t('edge.confirmDeletePoint')} "${point.name}" 吗？`)) {
    currentSlave.value.points.splice(index, 1)
  }
}

// JSON文件选择处理
const triggerReportFileSelect = () => {
  reportJsonInput.value?.click()
}

const handleReportFileSelect = (event) => {
  const files = event.target.files
  if (files && files.length > 0) {
    reportJsonFile.value = files[0]
    reportJsonFileName.value = files[0].name
  }
}

// 导出JSON
const exportReportJson = () => {
  try {
    const data = {
      group: reportGroups.value.map(g => {
        const isCloud = g.channel === 'Cloud'
        return {
          name: g.name,
          link: g.channel,
          topic: g.topic,
          qos: g.qos === 'QOS0' ? 0 : (g.qos === 'QOS1' ? 1 : 2),
          retention: g.retain ? 1 : 0,
          cond: {
            period: g.periodic ? g.periodicInterval : 0,
            timed: {
              type: g.scheduled ? g.scheduledType : 0,
              hh: 0,
              mm: 0
            }
          },
          data_report_type: g.format === 'Original' ? 0 : 1,
          change_report_type: 0,
          err_enable: g.errorFill ? 1 : 0,
          err_info: g.errorMsg,
          tmpl_file: "",
          fkey_md5: "00000000000000000000000000000000",
          ucld_node: [],
          tmpl_cont: g.template ? JSON.parse(g.template) : {}
        }
      })
    }
    
    const jsonStr = JSON.stringify(data, null, 2)
    const blob = new Blob([jsonStr], { type: 'application/json' })
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'edge_report.json'
    a.click()
    window.URL.revokeObjectURL(url)
  } catch (err) {
    console.error('导出失败:', err)
    alert(t('edge.exportFailed') + ': ' + err.message)
  }
}

// 导入JSON
const importReportJson = () => {
  if (!reportJsonFile.value) return
  
  const reader = new FileReader()
  reader.onload = (e) => {
    try {
      const jsonStr = e.target.result
      const data = JSON.parse(jsonStr)
      
      if (data && Array.isArray(data.group)) {
        reportGroups.value = data.group.map((g, i) => {
          // Map new fields back to frontend fields
          const qosVal = g.qos === 1 ? 'QOS1' : (g.qos === 2 ? 'QOS2' : 'QOS0')
          const periodic = g.cond && g.cond.period > 0
          const periodicInterval = g.cond ? g.cond.period : 5
          const scheduled = g.cond && g.cond.timed && g.cond.timed.type > 0
          const scheduledType = (g.cond && g.cond.timed && g.cond.timed.type > 0) ? g.cond.timed.type : 1
          const hh = g.cond && g.cond.timed ? g.cond.timed.hh || 0 : 0
          const mm = g.cond && g.cond.timed ? g.cond.timed.mm || 0 : 0
          const scheduledTime = `${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}:00`
          
          return {
            id: `group_${Date.now()}_${i}`,
            name: g.name || `Report${i+1}`,
            channel: g.link || g.channel || 'MQTT1',
            topic: g.topic || '',
            qos: qosVal,
            retain: g.retention === 1 || g.retain === 1,
            periodic: periodic,
            periodicInterval: periodicInterval,
            scheduled: scheduled,
            scheduledType: scheduledType,
            scheduledTime: scheduledTime,
            format: (g.data_report_type === 0 || g.format === 'Original') ? 'Original' : 'JSON',
            errorFill: g.err_enable === 1 || g.errorFill === 1,
            errorMsg: g.err_info || g.errorMsg || '',
            template: g.tmpl_cont ? JSON.stringify(g.tmpl_cont, null, 2) : (g.template || ''),
            selectedPointsText: (g.ucld_node && Array.isArray(g.ucld_node)) 
              ? g.ucld_node.flatMap(node => node.node_list.map(n => `${node.slave_name}-${n}`)).join('\n') 
              : ''
          }
        })
        
        parseSuccess.value = true
        parseErrorMsg.value = ''
      } else {
        throw new Error('Invalid JSON format: missing "group" array')
      }
    } catch (err) {
      console.error('解析失败:', err)
      parseSuccess.value = false
      parseErrorMsg.value = err.message
    } finally {
      showParseResultModal.value = true
      // Reset file input
      reportJsonFile.value = null
      reportJsonFileName.value = ''
      if (reportJsonInput.value) reportJsonInput.value.value = ''
    }
  }
  reader.readAsText(reportJsonFile.value)
}

const closeParseResultModal = () => {
  showParseResultModal.value = false
}

// 下一页
const nextTab = () => {
  if (activeTab.value < tabList.value.length - 1) {
    activeTab.value++
  }
}

// 保存当前页
const saveCurrentPage = async () => {
  try {
    if (activeTab.value === 0) {
      // 保存网关使能配置
      await apiClient.get('/update_nv.cgi', {
        params: {
          file: 'edge',
          'n_all_en': edgeConfig.value.all_en
        }
      })
    } else if (activeTab.value === 1) {
      // 保存数据采集配置 - 生成CSV并上传
      const csvContent = generateCsvContent()
      const blob = new Blob([csvContent], { type: 'text/csv' })
      const formData = new FormData()
      formData.append('file', blob, 'edge.csv')
      
      await apiClient.post('/upload/edge', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      })
      showSuccessModal.value = true
      return
    } else if (activeTab.value === 2) {
      // 保存数据上报配置
      await saveReportData()
      showSuccessModal.value = true
      showSuccessModal.value = true
      return
    } else if (activeTab.value === 3) {
      // 保存协议转换配置
      // 1. GET Request to update NVRAM
      const params = {
        file: 'edge_access',
        'n_group[0].enable': protocolConversionConfig.value.enable,
        'n_group[0].proto': protocolConversionConfig.value.protocol,
        's_group[0].up.link': protocolConversionConfig.value.channel,
        's_group[0].down.link': protocolConversionConfig.value.channel,
      }

      if (protocolConversionConfig.value.channel.startsWith('MQTT')) {
        params['s_group[0].up.topic'] = protocolConversionConfig.value.pubTopic
        params['n_group[0].up.qos'] = protocolConversionConfig.value.pubQos === 'QOS1' ? 1 : (protocolConversionConfig.value.pubQos === 'QOS2' ? 2 : 0)
        params['n_group[0].up.retention'] = protocolConversionConfig.value.retain ? 1 : 0
        params['s_group[0].down.topic'] = protocolConversionConfig.value.subTopic
        params['n_group[0].down.qos'] = protocolConversionConfig.value.subQos === 'QOS1' ? 1 : (protocolConversionConfig.value.subQos === 'QOS2' ? 2 : 0)
      }

      await apiClient.get('/update_nv.cgi', { params })

      // 2. POST Request to upload CSV
      const csvContent = generateConversionCsv()
      const blob = new Blob([csvContent], { type: 'application/octet-stream' }) // User specified octet-stream
      const formData = new FormData()
      formData.append('c', blob, 'conver_csv')
      
      await apiClient.post('/upload/conver_csv', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      })
      showSuccessModal.value = true
      return
    }
    
    alert(t('edge.saveSuccess'))
  } catch (err) {
    console.error('保存失败:', err)
    alert(t('edge.saveFailed') + ': ' + (err.response?.data?.msg || err.message))
  }
}

// 数据类型映射
const dataTypeMap = {
  'Bit': 1,
  'Unsigned': 4,
  'Signed': 5,
  '32 Bit Unsigned (AB CD)': 6,
  '32 Bit Unsigned (CD AB)': 7,
  '32 Bit Signed (AB CD)': 8,
  '32 Bit Signed (CD AB)': 9,
  '32 Bit Float (AB CD)': 10,
  '32 Bit Float (CD AB)': 11,
  'Bool': 18
}

const getDataTypeName = (code) => {
  return Object.keys(dataTypeMap).find(key => dataTypeMap[key] === code) || 'Bool'
}

// 生成CSV内容
const generateCsvContent = () => {
  let csv = 'V,V1.0,N7X0,;\n'
  
  slaveList.value.forEach(slave => {
    if (slave.isSystem) return
    
    // 从机行格式: SC,name,detail,protocol,slaveAddress,pollInterval,0,mergeCollect,remoteAddress:remotePort,deviceName,;
    const proto = slave.protocol === 1 ? 2 : 1
    const addr = slave.protocol === 1 ? `${slave.remoteAddress}:${slave.remotePort}` : ''
    const devName = slave.protocol === 1 ? slave.name : `UART${slave.serialPort || 1}`
    
    csv += `SC,${slave.name},${slave.detail || ''},${proto},${slave.slaveAddress},${slave.pollInterval},0,${slave.mergeCollect ? 1 : 0},${addr},${devName},;\n`
    
    // 数据点行格式
    // C, SlaveName, PointName, Detail, Type, Decimal, 0,0,0,0,0, CollectFormula, Register, 0,0,0, Timeout, Report, 0, ControlFormula, ;
    slave.points.forEach(point => {
      if (point.registerDisplay === 'State') {
        // 特殊 State 点位格式
        csv += `C,${slave.name},${point.name},,18,0,0,0,0,0,0,,State,0,0,0,0,0,0,,;\n`
      } else {
        const typeCode = dataTypeMap[point.dataType] || 18
        const report = point.reportOnChange ? 1 : 0
        
        let registerStr = String(point.registerType) + String(point.registerAddress).padStart(5, '0')
        let bitIndex = 0
        
        if (point.registerType === 4 && point.dataType === 'Bit') {
          bitIndex = point.bitIndex || 0
        } else {
          // For other types, ensure we use the clean register string without dot
          // (though point.registerDisplay might be clean for them, this is safer)
          registerStr = String(point.registerType) + String(point.registerAddress).padStart(5, '0')
        }

        csv += `C,${slave.name},${point.name},${point.detail || ''},${typeCode},${point.decimalPlaces || 0},0,0,0,0,0,${point.collectFormula || ''},${registerStr},${bitIndex},0,0,${point.timeout || 200},${report},${point.changeRange || 2},${point.controlFormula || ''},;\n`
      }
    })
  })
  
  return csv
}

// 解析CSV内容
const parseCsvContent = (content) => {
  const lines = content.split('\n').filter(line => line.trim())
  const newSlaves = []
  let currentSlave = null
  
  lines.forEach(line => {
    const parts = line.split(',')
    
    if (parts[0] === 'SC') {
      // 从机定义
      currentSlave = {
        id: `slave_${Date.now()}_${Math.random()}`,
        name: parts[1],
        detail: parts[2] || '',
        protocol: parts[3] === '2' ? 1 : 0,
        slaveAddress: parseInt(parts[4]) || 1,
        pollInterval: parseInt(parts[5]) || 100,
        mergeCollect: parts[7] === '1',
        isSystem: false,
        points: []
      }
      
      // 解析地址和串口
      if (currentSlave.protocol === 1) {
        // TCP
        if (parts[8] && parts[8].includes(':')) {
          const [addr, port] = parts[8].split(':')
          currentSlave.remoteAddress = addr
          currentSlave.remotePort = parseInt(port) || 2100
        }
      } else {
        // RTU - 解析 DeviceName (UART1/UART2)
        const devName = parts[9] || ''
        if (devName.toUpperCase().includes('UART2')) {
          currentSlave.serialPort = 2
        } else {
          currentSlave.serialPort = 1
        }
      }
      
      newSlaves.push(currentSlave)
    } else if (parts[0] === 'C' && currentSlave) {
      // 数据点定义
      // 索引映射:
      // 1: SlaveName, 2: PointName, 3: Detail, 4: Type, 5: Decimal, 
      // 11: CollectFormula, 12: Register, 16: Timeout, 17: Report, 19: ControlFormula
      
      const registerStr = parts[12]
      
      // 检查是否为特殊的 State 点位
      if (registerStr === 'State') {
        currentSlave.points.push({
          id: `point_${Date.now()}_${Math.random()}`,
          name: parts[2],
          registerType: 0,
          registerAddress: 0,
          registerDisplay: 'State',
          dataType: 'Bool',
          value: null,
          isDefault: true
        })
      } else {
        const regType = parseInt(registerStr[0]) || 0

        const regAddr = parseInt(registerStr.substring(1)) || 1
        
        let bitIdx = parseInt(parts[13]) || 0
        
        // Reconstruct display string
        let displayStr = registerStr
        if (regType === 4 && getDataTypeName(parseInt(parts[4])) === 'Bit') {
           displayStr += `.${bitIdx}`
        }
        
        currentSlave.points.push({
          id: `point_${Date.now()}_${Math.random()}`,
          name: parts[2],
          detail: parts[3] || '',
          registerType: regType,
          registerAddress: regAddr,
          bitIndex: bitIdx,
          registerDisplay: displayStr,
          dataType: getDataTypeName(parseInt(parts[4])),
          decimalPlaces: parseInt(parts[5]) || 0,
          collectFormula: parts[11] || '',
          timeout: parseInt(parts[16]) || 200,
          reportOnChange: parts[17] === '1',
          changeRange: parseInt(parts[18]) || 2,
          controlFormula: parts[19] || '',
          value: null,
          isDefault: false
        })
      }
    }
  })
  
  return newSlaves
}

// 协议转换CSV文件选择处理
const triggerProtocolFileSelect = () => {
  protocolCsvFileInput.value?.click()
}

const handleProtocolCsvSelect = (event) => {
  const files = event.target.files
  if (files && files.length > 0) {
    protocolCsvFile.value = files[0]
  }
}

// 导出协议转换CSV
const exportProtocolCsv = () => {
  try {
    const cfg = protocolConversionConfig.value
    // V Line
    let csv = 'V,V1.0,N7X0\n'
    
    // S Line
    // Map Byte Orders
    const intMap = { 'ABCD': 6, 'CDAB': 7, 'BADC': 8, 'DCBA': 9 }
    const floatMap = { 'ABCD': 10, 'CDAB': 11, 'BADC': 12, 'DCBA': 13 }
    const intCode = intMap[cfg.intByteOrder] || 6
    const floatCode = floatMap[cfg.floatByteOrder] || 10
    const protoName = cfg.protocol === 0 ? 'JSON' : 'ModBusTCP'
    
    csv += `S,${cfg.stationAddress},${intCode},${floatCode},${protoName}\n`
    
    // J Line
    // J,0,Enable,group1,Protocol,Channel,PubTopic,PubQos,Retain,Channel,SubTopic,SubQos
    const pubQosMap = { 'QOS0': 0, 'QOS1': 1, 'QOS2': 2 }
    const subQosMap = { 'QOS0': 0, 'QOS1': 1, 'QOS2': 2 }
    const pubQos = pubQosMap[cfg.pubQos] || 0
    const subQos = subQosMap[cfg.subQos] || 0
    const retain = cfg.retain ? 1 : 0
    
    csv += `J,0,${cfg.enable},group1,${cfg.protocol},${cfg.channel},${cfg.pubTopic},${pubQos},${retain},${cfg.channel},${cfg.subTopic},${subQos}\n`
    
    // C Lines
    mappingPoints.value.forEach(p => {
      const typeCode = dataTypeMap[p.dataType] || 18
      csv += `C,${p.pointName},${p.slaveName},${typeCode},${p.mappingAddress}\n`
    })
    
    // Download
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'protocol_conversion.csv'
    a.click()
    window.URL.revokeObjectURL(url)
    
  } catch (err) {
    console.error('Export failed:', err)
    alert(t('edge.exportFailed') + ': ' + err.message)
  }
}

// 导入协议转换CSV
const importProtocolCsv = () => {
  if (!protocolCsvFile.value) return
  
  const reader = new FileReader()
  reader.onload = (e) => {
    try {
      const content = e.target.result
      const lines = content.split('\n').filter(line => line.trim())
      
      // Check V Line
      if (!lines[0].startsWith('V,V1.0')) {
        // Optional warning
        console.warn('Version mismatch or missing V line')
      }
      
      const newMappingPoints = []
      
      lines.forEach(line => {
        const parts = line.split(',').map(p => p.trim())
        const type = parts[0]
        
        if (type === 'S') {
           // S, StationAddr, IntByteOrder, FloatByteOrder, Protocol
           if (parts.length >= 5) {
             protocolConversionConfig.value.stationAddress = parseInt(parts[1]) || 1
             
             // Map codes back to ABCD...
             const intCode = parseInt(parts[2])
             const floatCode = parseInt(parts[3])
             const proto = parts[4]
             
             const intMapRev = { 6: 'ABCD', 7: 'CDAB', 8: 'BADC', 9: 'DCBA' }
             const floatMapRev = { 10: 'ABCD', 11: 'CDAB', 12: 'BADC', 13: 'DCBA' }
             
             if (intMapRev[intCode]) protocolConversionConfig.value.intByteOrder = intMapRev[intCode]
             if (floatMapRev[floatCode]) protocolConversionConfig.value.floatByteOrder = floatMapRev[floatCode]
             
             protocolConversionConfig.value.protocol = proto === 'JSON' ? 0 : 1
           }
        } else if (type === 'J') {
           // J,0,Enable,group1,Protocol,Channel,PubTopic,PubQos,Retain,Channel,SubTopic,SubQos
           if (parts.length >= 12) {
             protocolConversionConfig.value.enable = parseInt(parts[2]) || 0
             // parts[3] group1
             // parts[4] protocol
             protocolConversionConfig.value.channel = parts[5]
             protocolConversionConfig.value.pubTopic = parts[6]
             
             const pubQos = parseInt(parts[7])
             protocolConversionConfig.value.pubQos = pubQos === 1 ? 'QOS1' : (pubQos === 2 ? 'QOS2' : 'QOS0')
             
             protocolConversionConfig.value.retain = parts[8] === '1'
             
             // parts[9] channel
             protocolConversionConfig.value.subTopic = parts[10]
             
             const subQos = parseInt(parts[11])
             protocolConversionConfig.value.subQos = subQos === 1 ? 'QOS1' : (subQos === 2 ? 'QOS2' : 'QOS0')
           }
        } else if (type === 'C') {
           // C,PointName,SlaveName,DataType,MappingAddr
           if (parts.length >= 5) {
             const pointName = parts[1]
             const slaveName = parts[2]
             const typeCode = parseInt(parts[3])
             const mapAddr = parts[4].replace(/'/g, '') // Remove quotes if any
             
             // Reconstruct point object
             const slave = slaveList.value.find(s => s.name === slaveName)
             let point = null
             if (slave) {
               point = slave.points.find(p => p.name === pointName)
             }
             
             newMappingPoints.push({
               id: `map_${Date.now()}_${Math.random()}`,
               pointName: pointName,
               slaveName: slaveName,
               dataType: getDataTypeName(typeCode),
               mappingAddress: mapAddr,
               rwStatus: point ? (point.registerDisplay === 'State' ? '只读' : '读写') : '未知',
               source: slave ? getSlaveSource(slave) : '未知'
             })
           }
        }
      })
      
      mappingPoints.value = newMappingPoints
      alert(t('edge.importSuccess'))
      protocolCsvFile.value = null
      // Reset file input
      if (protocolCsvFileInput.value) protocolCsvFileInput.value.value = ''
      
    } catch (err) {
      console.error('Import failed:', err)
      alert(t('edge.importFailed') + ': ' + err.message)
    }
  }
  reader.readAsText(protocolCsvFile.value)
}

// 生成协议转换CSV内容 (Used for Save)
const generateConversionCsv = () => {
  // Use the same logic as exportProtocolCsv but return string
  const cfg = protocolConversionConfig.value
  let csv = 'V,V1.0,N7X0\n'
  
  const intMap = { 'ABCD': 6, 'CDAB': 7, 'BADC': 8, 'DCBA': 9 }
  const floatMap = { 'ABCD': 10, 'CDAB': 11, 'BADC': 12, 'DCBA': 13 }
  const intCode = intMap[cfg.intByteOrder] || 6
  const floatCode = floatMap[cfg.floatByteOrder] || 10
  const protoName = cfg.protocol === 0 ? 'JSON' : 'ModBusTCP'
  
  csv += `S,${cfg.stationAddress},${intCode},${floatCode},${protoName}\n`
  
  const pubQosMap = { 'QOS0': 0, 'QOS1': 1, 'QOS2': 2 }
  const subQosMap = { 'QOS0': 0, 'QOS1': 1, 'QOS2': 2 }
  const pubQos = pubQosMap[cfg.pubQos] || 0
  const subQos = subQosMap[cfg.subQos] || 0
  const retain = cfg.retain ? 1 : 0
  
  csv += `J,0,${cfg.enable},group1,${cfg.protocol},${cfg.channel},${cfg.pubTopic},${pubQos},${retain},${cfg.channel},${cfg.subTopic},${subQos}\n`
  
  mappingPoints.value.forEach(p => {
    const typeCode = dataTypeMap[p.dataType] || 18
    csv += `C,${p.pointName},${p.slaveName},${typeCode},${p.mappingAddress}\n`
  })
  
  return csv
}

// 协议转换 - 映射点位管理
const showAddMappingModal = () => {
  mappingForm.value = {
    startAddressType: '4X',
    startAddressValue: 1,
    points: [] // Will store selected points temporarily
  }
  tempSelectedPoints.value = []
  showMappingModal.value = true
}

const closeMappingModal = () => {
  showMappingModal.value = false
}

const deleteMapping = (index) => {
  mappingPoints.value.splice(index, 1)
}

const openPointSelectionModal = () => {
  selectedMappingSlaveId.value = ''
  mappingSearchQuery.value = ''
  tempSelectedPoints.value = []
  showPointSelectionModal.value = true
}

const closePointSelectionModal = () => {
  showPointSelectionModal.value = false
}

const availableMappingSlaves = computed(() => {
  return slaveList.value.filter(s => !s.isSystem)
})

// Filtered points for selection modal
const filteredSelectionPoints = computed(() => {
  if (!selectedMappingSlaveId.value) return []
  const slave = slaveList.value.find(s => s.id === selectedMappingSlaveId.value)
  if (!slave) return []
  
  // Exclude default points except 'State'
  let points = slave.points.filter(p => !p.isDefault || p.registerDisplay === 'State')
  
  if (mappingSearchQuery.value) {
    const q = mappingSearchQuery.value.toLowerCase()
    points = points.filter(p => p.name.toLowerCase().includes(q))
  }
  return points
})

const togglePointSelection = (point) => {
  const idx = tempSelectedPoints.value.findIndex(p => p.id === point.id)
  if (idx >= 0) {
    tempSelectedPoints.value.splice(idx, 1)
  } else {
    tempSelectedPoints.value.push(point)
  }
}

const isPointSelected = (point) => {
  return tempSelectedPoints.value.some(p => p.id === point.id)
}

const isAllSelected = computed(() => {
  if (filteredSelectionPoints.value.length === 0) return false
  return filteredSelectionPoints.value.every(p => isPointSelected(p))
})

const toggleSelectAll = () => {
  if (isAllSelected.value) {
    // Deselect all visible
    filteredSelectionPoints.value.forEach(p => {
      const idx = tempSelectedPoints.value.findIndex(tp => tp.id === p.id)
      if (idx >= 0) tempSelectedPoints.value.splice(idx, 1)
    })
  } else {
    // Select all visible
    filteredSelectionPoints.value.forEach(p => {
      if (!isPointSelected(p)) {
        tempSelectedPoints.value.push(p)
      }
    })
  }
}

const confirmPointSelection = () => {
  // Add selected points to mappingForm.points (or directly to table in Add Modal)
  // The Add Modal needs to show the selected points.
  // We'll just store them in mappingForm.points
  // We need to store slave info too
  const slave = slaveList.value.find(s => s.id === selectedMappingSlaveId.value)
  
  tempSelectedPoints.value.forEach(p => {
     // Check if already added to avoid duplicates in the current batch?
     // Or just allow it.
     mappingForm.value.points.push({
       ...p,
       slaveName: slave.name,
       slaveSource: getSlaveSource(slave)
     })
  })
  
  closePointSelectionModal()
}

const saveMapping = () => {
  // Calculate mapping addresses and add to main list
  let currentAddr = parseInt(mappingForm.value.startAddressValue) || 1
  const typePrefix = mappingForm.value.startAddressType.substring(0, 1) // '4' from '4X'
  
  mappingForm.value.points.forEach(p => {
    // Determine size
    let size = 1
    if (p.dataType.includes('32 Bit') || p.dataType === 'Float') size = 2
    
    // Construct full address
    const fullAddr = typePrefix + String(currentAddr).padStart(5, '0')
    
    mappingPoints.value.push({
      id: `map_${Date.now()}_${Math.random()}`,
      pointName: p.name,
      slaveName: p.slaveName,
      dataType: p.dataType,
      mappingAddress: fullAddr,
      rwStatus: p.registerDisplay === 'State' ? '只读' : '读写',
      source: p.slaveName
    })
    
    currentAddr += size
  })
  
  closeMappingModal()
}

const getCalculatedAddress = (index) => {
  let currentAddr = parseInt(mappingForm.value.startAddressValue) || 1
  const typePrefix = mappingForm.value.startAddressType.substring(0, 1)

  for (let i = 0; i < index; i++) {
    const p = mappingForm.value.points[i]
    let size = 1
    if (p.dataType.includes('32 Bit') || p.dataType === 'Float') size = 2
    currentAddr += size
  }
  
  return typePrefix + String(currentAddr).padStart(5, '0')
}

const editMapping = (index) => {
  const point = mappingPoints.value[index]
  const addrStr = point.mappingAddress
  // Assuming format like "400001"
  const type = addrStr.substring(0, 1)
  const addr = parseInt(addrStr.substring(1))
  
  editingMappingPoint.value = {
    index: index,
    pointName: point.pointName,
    regType: type,
    regAddr: addr
  }
  showEditMappingModal.value = true
}

const closeEditMappingModal = () => {
  showEditMappingModal.value = false
}

const saveEditedMapping = () => {
  const idx = editingMappingPoint.value.index
  if (idx >= 0 && idx < mappingPoints.value.length) {
    mappingPoints.value[idx].mappingAddress = computedEditingAddress.value
  }
  closeEditMappingModal()
}

// 加载数据
const loadData = async () => {
  try {
    loading.value = true
    error.value = null
    
    // 并行获取所有数据
    const [edgeRes, edgeFileRes, edgeReportRes, edgeAccessRes, edgeLinkCtrlRes, edgeProtoAccessRes] = await Promise.all([
      apiClient.get('/download_nv.cgi', { params: { name: 'edge' } }),
      apiClient.get('/download_file.cgi', { params: { name: 'edge' } }),
      apiClient.get('/download_nv.cgi', { params: { name: 'edge_report' } }),
      apiClient.get('/download_nv.cgi', { params: { name: 'edge_access' } }),
      apiClient.get('/download_nv.cgi', { params: { name: 'edge_link_ctrl' } }),
      apiClient.get('/download_file.cgi', { params: { name: 'edge_proto_access' } })
    ])
    
    console.log('=== 边缘计算页面数据加载 ===')
    console.log('Edge Config:', edgeRes.data)
    console.log('Edge File:', edgeFileRes.data)
    console.log('Edge Report:', edgeReportRes.data)
    console.log('Edge Access:', edgeAccessRes.data)
    console.log('Edge Link Ctrl:', edgeLinkCtrlRes.data)
    
    // 更新配置
    if (edgeRes.data) {
      edgeConfig.value = { ...edgeConfig.value, ...edgeRes.data }
    }
    
    edgeFileContent.value = edgeFileRes.data || ''
    edgeReport.value = edgeReportRes.data || { group: [] }
    
    // Initialize reportGroups from loaded data
    if (edgeReport.value.group && Array.isArray(edgeReport.value.group)) {
      // 1. Collect template names
      const templateNames = []
      edgeReport.value.group.forEach(g => {
        if (g.tmpl_file) {
           const match = g.tmpl_file.match(/\/([^/]+)\.json$/)
           if (match && match[1]) {
             templateNames.push(match[1])
           }
        }
      })
      
      // 2. Fetch templates if any
      let templatesData = {}
      if (templateNames.length > 0) {
        try {
           // Construct params manually to ensure name=template&name=Report1 format
           // Axios paramsSerializer can be used, or just URLSearchParams
           const params = new URLSearchParams()
           params.append('name', 'template')
           templateNames.forEach(n => params.append('name', n))
           
           const tmplRes = await apiClient.get('/download_multi_file.cgi', { params })
           templatesData = tmplRes.data || {}
        } catch (e) {
           console.error('Failed to load templates:', e)
        }
      }

      reportGroups.value = edgeReport.value.group.map((g, i) => {
        // Map backend fields to frontend fields
        const qosVal = g.qos === 1 ? 'QOS1' : (g.qos === 2 ? 'QOS2' : 'QOS0')
        const periodic = g.cond && g.cond.period > 0
        const periodicInterval = g.cond ? g.cond.period : 5
        const scheduled = g.cond && g.cond.timed && g.cond.timed.type > 0
        const scheduledType = (g.cond && g.cond.timed && g.cond.timed.type > 0) ? g.cond.timed.type : 1
        const hh = g.cond && g.cond.timed ? g.cond.timed.hh || 0 : 0
        const mm = g.cond && g.cond.timed ? g.cond.timed.mm || 0 : 0
        const scheduledTime = `${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}:00`
        
        // Resolve template content
        let tmplContent = g.template || '' // Fallback if backend still sends it (it shouldn't)
        if (g.tmpl_file) {
           const match = g.tmpl_file.match(/\/([^/]+)\.json$/)
           if (match && match[1] && templatesData[match[1]]) {
              tmplContent = JSON.stringify(templatesData[match[1]], null, 2)
           }
        }

        return {
          id: `group_${i}`,
          name: g.name || `Report${i+1}`,
          channel: g.link || g.channel || 'MQTT1',
          topic: g.topic || '',
          qos: qosVal,
          retain: g.retention === 1 || g.retain === 1,
          periodic: periodic,
          periodicInterval: periodicInterval,
          scheduled: scheduled,
          scheduledType: scheduledType,
          scheduledTime: scheduledTime,
          format: (g.data_report_type === 0 || g.format === 'Original') ? 'Original' : 'JSON',
          errorFill: g.err_enable === 1 || g.errorFill === 1,
          errorMsg: g.err_info || g.errorMsg || '',
          template: g.tmpl_cont ? JSON.stringify(g.tmpl_cont, null, 2) : tmplContent,
          selectedPointsText: (g.ucld_node && Array.isArray(g.ucld_node)) 
              ? g.ucld_node.flatMap(node => node.node_list.map(n => `${node.slave_name}-${n}`)).join('\n') 
              : ''
        }
      })
    } else {
      reportGroups.value = []
    }
    edgeAccess.value = edgeAccessRes.data || { group: [] }
    edgeLinkCtrl.value = edgeLinkCtrlRes.data || { group: [] }
    const edgeProtoAccessContent = edgeProtoAccessRes?.data || ''

    // Update Protocol Conversion Config
    if (edgeAccess.value.group && edgeAccess.value.group[0]) {
      const g = edgeAccess.value.group[0]
      protocolConversionConfig.value = {
        enable: g.enable || 0,
        protocol: g.proto || 0,
        channel: g.up?.link || 'MQTT1',
        subTopic: g.down?.topic || '/SubTopic',
        subQos: g.down?.qos === 1 ? 'QOS1' : (g.down?.qos === 2 ? 'QOS2' : 'QOS0'),
        pubTopic: g.up?.topic || '/PubTopic',
        pubQos: g.up?.qos === 1 ? 'QOS1' : (g.up?.qos === 2 ? 'QOS2' : 'QOS0'),
        retain: g.up?.retention === 1,
        stationAddress: 1, // Default, not in NVRAM? Or need to find where it is stored.
        intByteOrder: 'ABCD',
        floatByteOrder: 'ABCD'
      }
    }

    // Parse Protocol Conversion CSV
    // Format: V,V1.0,N7X0
    // S,StationAddr,IntCode,FloatCode,Protocol
    // J,0,Enable,group1,Protocol,Channel,PubTopic,PubQos,Retain,Channel,SubTopic,SubQos
    // C,PointName,SlaveName,DataType,MappingAddr
    // 解析CSV文件内容
    if (edgeFileContent.value) {
      const parsedSlaves = parseCsvContent(edgeFileContent.value)
      if (parsedSlaves.length > 0) {
        // 保留系统从机，添加解析的从机
        const systemSlave = slaveList.value[0]
        slaveList.value = [systemSlave, ...parsedSlaves]
      }
    }

    if (edgeProtoAccessContent) {
       const lines = edgeProtoAccessContent.split('\n').filter(line => line.trim())
       mappingPoints.value = []
       lines.forEach(line => {
         const parts = line.split(',').map(p => p.trim())
         const type = parts[0]
         
         if (type === 'S') {
            if (parts.length >= 5) {
               protocolConversionConfig.value.stationAddress = parseInt(parts[1]) || 1
               
               const intCode = parseInt(parts[2])
               const floatCode = parseInt(parts[3])
               const proto = parts[4]
               
               const intMapRev = { 6: 'ABCD', 7: 'CDAB', 8: 'BADC', 9: 'DCBA' }
               const floatMapRev = { 10: 'ABCD', 11: 'CDAB', 12: 'BADC', 13: 'DCBA' }
               
               if (intMapRev[intCode]) protocolConversionConfig.value.intByteOrder = intMapRev[intCode]
               if (floatMapRev[floatCode]) protocolConversionConfig.value.floatByteOrder = floatMapRev[floatCode]
               
               // Optional: Sync protocol from CSV if needed, but usually NVRAM is master
               // protocolConversionConfig.value.protocol = proto === 'JSON' ? 0 : 1
            }
         } else if (type === 'J') {
            if (parts.length >= 12) {
               protocolConversionConfig.value.enable = parseInt(parts[2]) || 0
               protocolConversionConfig.value.channel = parts[5]
               protocolConversionConfig.value.pubTopic = parts[6]
               
               const pubQos = parseInt(parts[7])
               protocolConversionConfig.value.pubQos = pubQos === 1 ? 'QOS1' : (pubQos === 2 ? 'QOS2' : 'QOS0')
               
               protocolConversionConfig.value.retain = parts[8] === '1'
               
               protocolConversionConfig.value.subTopic = parts[10]
               
               const subQos = parseInt(parts[11])
               protocolConversionConfig.value.subQos = subQos === 1 ? 'QOS1' : (subQos === 2 ? 'QOS2' : 'QOS0')
            }
         } else if (type === 'C') {
            // C,PointName,SlaveName,DataType,MappingAddr
            if (parts.length >= 5) {
               const pointName = parts[1]
               const slaveName = parts[2]
               const typeCode = parseInt(parts[3])
               const mapAddr = parts[4].replace(/'/g, '')
               
               const slave = slaveList.value.find(s => s.name === slaveName)
               let point = null
               if (slave) {
                  point = slave.points.find(p => p.name === pointName)
               }
               
               mappingPoints.value.push({
                  id: `map_${Date.now()}_${Math.random()}`,
                  pointName: pointName,
                  slaveName: slaveName,
                  dataType: getDataTypeName(typeCode),
                  mappingAddress: mapAddr,
                  rwStatus: point ? (point.registerDisplay === 'State' ? '只读' : '读写') : '未知',
                  dataType: getDataTypeName(typeCode),
                  mappingAddress: mapAddr,
                  rwStatus: point ? (point.registerDisplay === 'State' ? '只读' : '读写') : '未知',
                  source: slaveName
               })
            }
         }
       })
    }
    
  } catch (err) {
    error.value = t('common.loadError') + ': ' + err.message
    console.error('配置加载错误:', err)
  } finally {
    loading.value = false
  }
}

// 组件挂载时加载数据
onMounted(() => {
  // 初始化系统从机的数据点
  if (slaveList.value[0] && slaveList.value[0].isSystem) {
    slaveList.value[0].points = [...systemPoints.value]
  }
  
  loadData()
})
</script>

<style scoped>
.description-box {
  background-color: #0066cc; /* Blue background like Uart */
  color: white;
  padding: 10px 15px;
  margin-bottom: 0;
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

.tab-content {
  padding: 20px 0;
}

/* 表单样式 */
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
  width: 120px;
  text-align: right;
  flex-shrink: 0;
  font-size: 13px;
}

.form-group input[type="text"],
.form-group input[type="number"],
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

/* 导入区域 */
.import-section {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 15px;
  background-color: #fff;
  border-bottom: 1px solid #ddd;
}

.import-section .label {
  font-weight: 600;
  margin-right: 10px;
}

.btn-outline {
  padding: 6px 16px;
  background-color: #fff;
  color: #333;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
  font-size: 13px;
}

.btn-outline:hover {
  background-color: #f5f5f5;
}

.btn-outline:disabled {
  background-color: #f5f5f5;
  color: #999;
  cursor: not-allowed;
}

.file-hint {
  color: #999;
  font-size: 12px;
}

.import-tips {
  padding: 10px 15px;
  background-color: #fff;
}

.tip-warning {
  color: #ff8800;
}

.time-input-container {
  display: flex;
  align-items: center;
}

.time-input {
  width: 40px !important;
  text-align: center;
  padding: 6px 4px;
  flex: none !important;
}

.time-separator {
  margin: 0 5px;
  font-weight: bold;
}


.tip-info {
  color: #0066cc;
  font-size: 12px;
}

/* 表格区域 */
.table-container {
  display: flex;
  gap: 20px;
  padding: 0 15px;
  margin-top: 15px;
}

.table-wrapper {
  flex: 1;
  border: 1px solid #ddd;
  max-height: 400px;
  overflow: auto;
}

.slave-table {
  flex: 0.6;
}

.point-table {
  flex: 0.7;
}

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
}

th, td {
  padding: 8px 10px;
  text-align: left;
  border-bottom: 1px solid #ddd;
}

th {
  background-color: #f5f5f5;
  font-weight: 600;
  position: sticky;
  top: 0;
}

tr:hover {
  background-color: #f9f9f9;
}

tr.selected {
  background-color: #0066cc;
  color: white;
}

tr.selected:hover {
  background-color: #0055aa;
}

.name-cell {
  max-width: 120px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.action-cell {
  white-space: nowrap;
}

.btn-small {
  padding: 2px 8px;
  margin-right: 4px;
  background-color: #f5f5f5;
  border: 1px solid #ddd;
  border-radius: 2px;
  cursor: pointer;
  font-size: 11px;
}

.btn-small:hover {
  background-color: #e5e5e5;
}

.btn-small.btn-danger {
  background-color: #ffebee;
  border-color: #ffcdd2;
  color: #c62828;
}

.btn-small.btn-danger:hover {
  background-color: #ffcdd2;
}

/* 按钮组 */
.button-group {
  display: flex;
  justify-content: center;
  padding: 20px;
  gap: 10px;
  background-color: #f9f9f9;
  margin-top: 20px;
}

.btn-save, .btn-next, .btn-action {
  padding: 8px 30px;
  background-color: #0066cc;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 600;
}

.btn-save:hover, .btn-next:hover, .btn-action:hover {
  background-color: #0052a3;
}

.btn-action {
  background-color: #0066cc;
}

.btn-action:disabled {
  background-color: #ccc;
  cursor: not-allowed;
}

/* 模态框 */
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
  padding: 20px 30px;
  min-width: 400px;
  max-width: 600px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
}

.modal h3 {
  margin: 0 0 20px 0;
  padding-bottom: 10px;
  border-bottom: 1px solid #ddd;
  color: #333;
}

.modal-form {
  padding: 10px 0;
}

.modal-form .form-group {
  margin-bottom: 12px;
}

.modal-form .form-group label {
  width: 100px;
}

.modal-form .form-group input[type="text"],
.modal-form .form-group input[type="number"],
.modal-form .form-group select {
  max-width: 250px;
}

.input-with-unit {
  display: flex;
  align-items: center;
  gap: 5px;
  flex: 1;
  max-width: 250px;
}

.input-with-unit input {
  flex: 1;
  max-width: none !important;
}

.input-with-unit .unit {
  color: #666;
  font-size: 12px;
}

.register-input {
  display: flex;
  gap: 5px;
  flex: 1;
  max-width: 340px;
}

.register-input select {
  width: 60px !important;
  flex: none !important;
}

.register-input input {
  flex: 1;
}

.register-display {
  color: #ff8800;
  font-size: 12px;
  margin-left: 10px;
}

.modal-buttons {
  display: flex;
  justify-content: center;
  gap: 10px;
  margin-top: 20px;
  padding-top: 15px;
  border-top: 1px solid #ddd;
}

.btn-cancel {
  padding: 8px 30px;
  background-color: #666;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 14px;
  font-weight: 600;
}

.btn-cancel:hover {
  background-color: #555;
}

/* 占位符 */
.placeholder {
  padding: 60px 20px;
  text-align: center;
  background-color: white;
  color: #666;
}

.placeholder h3 {
  margin: 0 0 10px 0;
  color: #333;
}

/* 加载和错误 */
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
