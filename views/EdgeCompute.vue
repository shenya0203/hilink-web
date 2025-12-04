<template>
  <div>
    <!-- 加载状态 -->
    <div v-if="loading" class="loading">加载中...</div>
    
    <!-- 错误提示 -->
    <div v-if="error" class="error">{{ error }}</div>

    <!-- 边缘计算标题 -->
    <div class="description-box">
      <div class="desc-title">边缘计算</div>
      <div class="desc-content">边缘计算网关</div>
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
          <label>网关使能:</label>
          <select v-model.number="edgeConfig.all_en">
            <option :value="0">关闭</option>
            <option :value="1">开启</option>
          </select>
        </div>
      </div>
      
      <div class="button-group">
        <button class="btn-save" @click="saveCurrentPage">保存当前页</button>
        <button v-if="edgeConfig.all_en === 1" class="btn-next" @click="nextTab">下一步</button>
      </div>
    </div>

    <!-- Tab 2: 数据采集 -->
    <div v-if="activeTab === 1" class="tab-content">
      <!-- 点表导入区域 -->
      <div class="import-section">
        <span class="label">点表导入</span>
        <button class="btn-outline" @click="triggerFileSelect">选择文件</button>
        <button class="btn-outline" @click="importCsv" :disabled="!selectedCsvFile">导入</button>
        <button class="btn-outline" @click="exportCsv">导出</button>
        <span class="file-hint">请选择文件(.csv)</span>
        <input type="file" ref="csvFileInput" @change="handleCsvSelect" accept=".csv" style="display:none" />
      </div>
      
      <div class="import-tips">
        <span class="tip-warning">(连续导入的文件名称一致时，需要shift+f5刷新后导入)</span>
        <br/>
        <span class="tip-info">已添加点位数量:{{ totalPoints }}</span>
        <span class="tip-info" style="margin-left: 20px;">还可添加点位:{{ 1000 - totalPoints }}</span>
      </div>

      <!-- 从机和数据点表格区域 -->
      <div class="table-container">
        <!-- 左侧从机表格 -->
        <div class="table-wrapper slave-table">
          <table>
            <thead>
              <tr>
                <th>序号</th>
                <th>名称</th>
                <th>点位来源</th>
                <th>从机地址</th>
                <th>操作</th>
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
                <td>{{ slave.slaveAddress || '空' }}</td>
                <td class="action-cell">
                  <template v-if="!slave.isSystem">
                    <button class="btn-small" @click.stop="editSlave(index)">编辑</button>
                    <button class="btn-small btn-danger" @click.stop="deleteSlave(index)">删除</button>
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
                <th>序号</th>
                <th>名称</th>
                <th>寄存器</th>
                <th>数值类型</th>
                <th>值</th>
                <th>操作</th>
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
                    <button class="btn-small" @click.stop="editPoint(index)">编辑</button>
                    <button class="btn-small btn-danger" @click.stop="deletePoint(index)">删除</button>
                  </template>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- 按钮组 -->
      <div class="button-group">
        <button class="btn-action" @click="showAddSlaveModal">添加从机</button>
        <button class="btn-action" @click="showAddPointModal" :disabled="!currentSlave || currentSlave.isSystem">添加数据点</button>
        <button class="btn-save" @click="saveCurrentPage">保存当前页</button>
        <button class="btn-next" @click="nextTab">下一步</button>
      </div>
    </div>

    <!-- Tab 3: 数据上报 -->
    <div v-if="activeTab === 2" class="tab-content">
      <div class="placeholder">
        <h3>数据上报配置</h3>
        <p>功能开发中...</p>
      </div>
      <div class="button-group">
        <button class="btn-save" @click="saveCurrentPage">保存当前页</button>
        <button class="btn-next" @click="nextTab">下一步</button>
      </div>
    </div>

    <!-- Tab 4: 协议转换 -->
    <div v-if="activeTab === 3" class="tab-content">
      <div class="placeholder">
        <h3>协议转换配置</h3>
        <p>功能开发中...</p>
      </div>
      <div class="button-group">
        <button class="btn-save" @click="saveCurrentPage">保存当前页</button>
      </div>
    </div>

    <!-- 添加从机对话框 -->
    <div v-if="showSlaveModal" class="modal-overlay" @click.self="closeSlaveModal">
      <div class="modal">
        <h3>{{ isEditingSlave ? '编辑从机' : '添加从机' }}</h3>
        <div class="modal-form">
          <div class="form-group">
            <label>名称:</label>
            <input v-model="slaveForm.name" type="text" placeholder="Device1" />
          </div>
          <div class="form-group">
            <label>详细信息:</label>
            <input v-model="slaveForm.detail" type="text" />
          </div>
          <div class="form-group">
            <label>协议类型:</label>
            <select v-model.number="slaveForm.protocol">
              <option :value="0">Modbus RTU</option>
              <option :value="1">Modbus TCP</option>
            </select>
          </div>
          
          <!-- Modbus TCP 选项 -->
          <template v-if="slaveForm.protocol === 1">
            <div class="form-group">
              <label>远程服务器地址:</label>
              <input v-model="slaveForm.remoteAddress" type="text" placeholder="192.168.0.21" />
            </div>
            <div class="form-group">
              <label>远程端口号:</label>
              <input v-model.number="slaveForm.remotePort" type="number" placeholder="2100" />
            </div>
          </template>
          
          <!-- Modbus RTU 选项 -->
          <template v-if="slaveForm.protocol === 0">
            <div class="form-group">
              <label>串口配置:</label>
              <select v-model.number="slaveForm.serialPort">
                <option :value="1">串口1</option>
                <option :value="2">串口2</option>
              </select>
            </div>
          </template>
          
          <div class="form-group">
            <label>从机地址:</label>
            <input v-model.number="slaveForm.slaveAddress" type="number" placeholder="1" />
          </div>
          <div class="form-group">
            <label>轮询间隔:</label>
            <div class="input-with-unit">
              <input v-model.number="slaveForm.pollInterval" type="number" placeholder="100" />
              <span class="unit">ms</span>
            </div>
          </div>
          <div class="form-group">
            <label>合并采集:</label>
            <input type="checkbox" v-model="slaveForm.mergeCollect" />
          </div>
        </div>
        <div class="modal-buttons">
          <button class="btn-save" @click="saveSlave">保存</button>
          <button class="btn-cancel" @click="closeSlaveModal">取消</button>
        </div>
      </div>
    </div>

    <!-- 添加数据点对话框 -->
    <div v-if="showPointModal" class="modal-overlay" @click.self="closePointModal">
      <div class="modal">
        <h3>{{ isEditingPoint ? '编辑数据点' : '添加数据点' }}</h3>
        <div class="modal-form">
          <div class="form-group">
            <label>名称:</label>
            <input v-model="pointForm.name" type="text" placeholder="node0101" />
          </div>
          <div class="form-group">
            <label>详细信息:</label>
            <input v-model="pointForm.detail" type="text" />
          </div>
          <div class="form-group">
            <label>寄存器:</label>
            <div class="register-input">
              <select v-model.number="pointForm.registerType">
                <option :value="0">0</option>
                <option :value="1">1</option>
                <option :value="3">3</option>
                <option :value="4">4</option>
              </select>
              <input v-model.number="pointForm.registerAddress" type="number" placeholder="1" />
            </div>
            <span class="register-display">{{ computedRegisterAddress }}</span>
          </div>
          <div class="form-group">
            <label>数值类型:</label>
            <select v-model="pointForm.dataType">
              <option v-for="type in availableDataTypes" :key="type" :value="type">{{ type }}</option>
            </select>
          </div>
          <div class="form-group">
            <label>小数位数:</label>
            <select v-model.number="pointForm.decimalPlaces">
              <option v-for="n in 7" :key="n-1" :value="n-1">{{ n - 1 }}</option>
            </select>
          </div>
          <div class="form-group">
            <label>超时时间:</label>
            <div class="input-with-unit">
              <input v-model.number="pointForm.timeout" type="number" placeholder="200" />
              <span class="unit">ms</span>
            </div>
          </div>
          <div class="form-group">
            <label>采集公式:</label>
            <input v-model="pointForm.collectFormula" type="text" />
          </div>
          <div class="form-group">
            <label>控制公式:</label>
            <input v-model="pointForm.controlFormula" type="text" />
          </div>
          <div class="form-group">
            <label>变化上报:</label>
            <input type="checkbox" v-model="pointForm.reportOnChange" />
          </div>
        </div>
        <div class="modal-buttons">
          <button class="btn-save" @click="savePoint">保存</button>
          <button class="btn-cancel" @click="closePointModal">取消</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import apiClient from '../api/services'

// 响应式数据
const loading = ref(true)
const error = ref(null)
const activeTab = ref(0)

// 标签页配置
const tabList = ref([
  { name: '网关使能' },
  { name: '数据采集' },
  { name: '数据上报' },
  { name: '协议转换' }
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

// CSV文件选择
const csvFileInput = ref(null)
const selectedCsvFile = ref(null)

// 系统默认数据点
const systemPoints = [
  { id: 'sys_local_time', name: 'sys_local_time', dataType: '字符串', value: null },
  { id: 'sys_timestamp', name: 'sys_timestamp', dataType: '字符串', value: null },
  { id: 'sys_timestamp_ms', name: 'sys_timestamp_ms', dataType: '字符串', value: null },
  { id: 'sys_mac', name: 'sys_mac', dataType: '字符串', value: 0 },
  { id: 'sys_imei', name: 'sys_imei', dataType: '字符串', value: null },
  { id: 'sys_sn', name: 'sys_sn', dataType: '字符串', value: null },
  { id: 'sys_iccid', name: 'sys_iccid', dataType: '字符串', value: null },
  { id: 'sys_ver', name: 'sys_ver', dataType: '字符串', value: null },
  { id: 'sys_csq', name: 'sys_csq', dataType: '字符串', value: null },
  { id: 'sys_utc_time', name: 'sys_utc_time', dataType: '字符串', value: null },
  { id: 'sys_model', name: 'sys_model', dataType: '字符串', value: null }
]

// 从机列表
const slaveList = ref([
  {
    id: 'system',
    name: 'System_Sla..System',
    isSystem: true,
    slaveAddress: '',
    points: [...systemPoints]
  }
])

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
  reportOnChange: false
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

// 计算属性：生成寄存器地址显示
const computedRegisterAddress = computed(() => {
  const type = pointForm.value.registerType
  const addr = pointForm.value.registerAddress || 0
  // 格式：寄存器类型 + 5位地址
  return String(type) + String(addr).padStart(5, '0')
})

// 监听寄存器类型变化，重置数据类型
watch(() => pointForm.value.registerType, (newType) => {
  const types = availableDataTypes.value
  if (!types.includes(pointForm.value.dataType)) {
    pointForm.value.dataType = types[0]
  }
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
    alert('请先选择文件')
    return
  }
  
  try {
    const formData = new FormData()
    formData.append('file', selectedCsvFile.value)
    
    await apiClient.post('/upload/edge', formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    
    alert('导入成功')
    selectedCsvFile.value = null
    await loadData()
  } catch (err) {
    console.error('导入失败:', err)
    alert('导入失败: ' + (err.response?.data?.msg || err.message))
  }
}

// 导出CSV
const exportCsv = async () => {
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
    alert('导出失败: ' + (err.response?.data?.msg || err.message))
  }
}

// 从机对话框操作
const showAddSlaveModal = () => {
  isEditingSlave.value = false
  editingSlaveIndex.value = -1
  slaveForm.value = {
    name: `Device${slaveList.value.length}`,
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
}

const editSlave = (index) => {
  const slave = slaveList.value[index]
  if (slave.isSystem) return
  
  isEditingSlave.value = true
  editingSlaveIndex.value = index
  slaveForm.value = { ...slave }
  showSlaveModal.value = true
}

const closeSlaveModal = () => {
  showSlaveModal.value = false
}

const saveSlave = () => {
  if (!slaveForm.value.name) {
    alert('请输入从机名称')
    return
  }
  
  const newSlave = {
    id: isEditingSlave.value ? slaveList.value[editingSlaveIndex.value].id : `slave_${Date.now()}`,
    ...slaveForm.value,
    isSystem: false,
    points: isEditingSlave.value ? slaveList.value[editingSlaveIndex.value].points : []
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
  
  if (confirm(`确定要删除从机 "${slave.name}" 吗？`)) {
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
  pointForm.value = {
    name: `${currentSlave.value.name}_st.State`,
    detail: '',
    registerType: 0,
    registerAddress: 1,
    dataType: 'Bool',
    decimalPlaces: 3,
    timeout: 200,
    collectFormula: '',
    controlFormula: '',
    reportOnChange: false
  }
  showPointModal.value = true
}

const editPoint = (index) => {
  if (!currentSlave.value || currentSlave.value.isSystem) return
  
  const point = currentSlave.value.points[index]
  isEditingPoint.value = true
  editingPointIndex.value = index
  pointForm.value = { ...point }
  showPointModal.value = true
}

const closePointModal = () => {
  showPointModal.value = false
}

const savePoint = () => {
  if (!pointForm.value.name) {
    alert('请输入数据点名称')
    return
  }
  
  const newPoint = {
    id: isEditingPoint.value ? currentSlave.value.points[editingPointIndex.value].id : `point_${Date.now()}`,
    ...pointForm.value,
    registerDisplay: computedRegisterAddress.value,
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
  if (confirm(`确定要删除数据点 "${point.name}" 吗？`)) {
    currentSlave.value.points.splice(index, 1)
  }
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
    }
    
    alert('保存成功')
  } catch (err) {
    console.error('保存失败:', err)
    alert('保存失败: ' + (err.response?.data?.msg || err.message))
  }
}

// 生成CSV内容
const generateCsvContent = () => {
  let csv = 'V,V1.0,N7X0,;\n'
  
  slaveList.value.forEach(slave => {
    if (slave.isSystem) return
    
    // 从机行格式: SC,name,slaveAddress,protocol,serialPort/tcp,pollInterval,mergeCollect,0,remoteAddress:remotePort,detail,;
    const proto = slave.protocol === 1 ? 2 : 1
    const addr = slave.protocol === 1 ? `${slave.remoteAddress}:${slave.remotePort}` : `串口${slave.serialPort}`
    csv += `SC,${slave.name},${slave.slaveAddress},${proto},${slave.serialPort || 1},${slave.pollInterval},${slave.mergeCollect ? 1 : 0},0,${addr},${slave.detail || slave.name},;\n`
    
    // 数据点行格式 (如果需要)
    slave.points.forEach(point => {
      csv += `C,${point.name},${slave.name},${point.registerType}${String(point.registerAddress).padStart(5, '0')}\n`
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
        slaveAddress: parseInt(parts[2]) || 1,
        protocol: parts[3] === '2' ? 1 : 0,
        serialPort: parseInt(parts[4]) || 1,
        pollInterval: parseInt(parts[5]) || 100,
        mergeCollect: parts[6] === '1',
        isSystem: false,
        points: []
      }
      
      // 解析地址
      if (parts[8] && parts[8].includes(':')) {
        const [addr, port] = parts[8].split(':')
        currentSlave.remoteAddress = addr
        currentSlave.remotePort = parseInt(port) || 2100
      }
      
      currentSlave.detail = parts[9] || ''
      newSlaves.push(currentSlave)
    } else if (parts[0] === 'C' && currentSlave) {
      // 数据点定义
      const registerStr = parts[3] || '000001'
      currentSlave.points.push({
        id: `point_${Date.now()}_${Math.random()}`,
        name: parts[1],
        registerType: parseInt(registerStr[0]) || 0,
        registerAddress: parseInt(registerStr.substring(1)) || 1,
        registerDisplay: registerStr,
        dataType: 'Bool',
        value: null
      })
    }
  })
  
  return newSlaves
}

// 加载数据
const loadData = async () => {
  try {
    loading.value = true
    error.value = null
    
    // 并行获取所有数据
    const [edgeRes, edgeFileRes, edgeReportRes, edgeAccessRes, edgeLinkCtrlRes] = await Promise.all([
      apiClient.get('/download_nv.cgi', { params: { name: 'edge' } }),
      apiClient.get('/download_file.cgi', { params: { name: 'edge' } }),
      apiClient.get('/download_nv.cgi', { params: { name: 'edge_report' } }),
      apiClient.get('/download_nv.cgi', { params: { name: 'edge_access' } }),
      apiClient.get('/download_nv.cgi', { params: { name: 'edge_link_ctrl' } })
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
    edgeAccess.value = edgeAccessRes.data || { group: [] }
    edgeLinkCtrl.value = edgeLinkCtrlRes.data || { group: [] }
    
    // 解析CSV文件内容
    if (edgeFileContent.value) {
      const parsedSlaves = parseCsvContent(edgeFileContent.value)
      if (parsedSlaves.length > 0) {
        // 保留系统从机，添加解析的从机
        const systemSlave = slaveList.value[0]
        slaveList.value = [systemSlave, ...parsedSlaves]
      }
    }
    
  } catch (err) {
    error.value = '加载配置失败: ' + err.message
    console.error('配置加载错误:', err)
  } finally {
    loading.value = false
  }
}

// 组件挂载时加载数据
onMounted(() => {
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
  font-size: 12px;
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
  max-width: 500px;
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
  max-width: 250px;
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
