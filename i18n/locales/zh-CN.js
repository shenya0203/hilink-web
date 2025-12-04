/**
 * 中文语言包
 */
export default {
    // 公共
    common: {
        loading: '加载中...',
        save: '应用&保存',
        apply: '应用',
        cancel: '取消',
        confirm: '确认',
        close: '关闭',
        open: '开启',
        enable: '开启',
        disable: '关闭',
        on: '开',
        off: '关',
        yes: '是',
        no: '否',
        success: '成功',
        error: '错误',
        warning: '警告',
        info: '信息',
        upload: '上传',
        download: '下载',
        export: '导出',
        import: '导入',
        selectFile: '选择文件',
        selectedFile: '已选文件',
        connected: '已连接',
        disconnected: '未连接',
        unknown: '未知',
        none: '无',
        loadError: '加载数据失败',
        saveSuccess: '保存成功',
        saveFailed: '保存失败',
        uploadSuccess: '上传成功',
        uploadFailed: '上传失败'
    },

    // 顶部导航栏
    navbar: {
        title: '工业路由网关',
        subtitle: 'Web 配置管理系统'
    },

    // 侧边栏菜单
    menu: {
        status: '当前状态',
        network: '网络',
        port: '端口',
        uart: '串口',
        comm: '通信',
        socket: 'Socket',
        mqtt: 'MQTT',
        usrCld: 'USR_CLD',
        gateway: '网关',
        edgeCompute: '边缘计算',
        system: '系统设置'
    },

    // 当前状态页面
    status: {
        // 系统信息
        system: '系统',
        deviceName: '设备名称',
        productModel: '产品型号',
        firmwareVersion: '固件版本',
        productType: '产品类型',
        runtime: '运行时间',
        os: '操作系统',
        mac: 'MAC',
        sn: 'SN',
        systemTime: '系统时间',
        currentNetwork: '当前运行网络',

        // 以太网
        ethernet: '以太网',
        connectionStatus: '连接状态',
        networkType: '网络类型',
        localIP: '本地IP',
        pluggedIn: '已接入',
        unplugged: '未接入',

        // 蜂窝网络
        cellular: '蜂窝网络',
        activeSim: '联网SIM',
        imei: 'IMEI',
        iccid: 'ICCID',
        cimi: 'CIMI',
        signalValue: '信号值',
        signalStrength: '信号强度',
        gatewayAddress: '网关地址',

        // 信号强度描述
        signalNone: '无信号',
        signalVeryWeak: '极弱',
        signalWeak: '弱',
        signalFair: '一般',
        signalGood: '良好',
        signalExcellent: '优秀',
        signalStrong: '极强',

        // TCP 连接状态
        tcpStatus: 'TCP 连接状态',
        socket1Status: 'socket1 连接状态',
        socket1Flag: 'socket1 连接标识',
        socket2Status: 'socket2 连接状态',
        socket2Flag: 'socket2 连接标识',

        // MQTT 连接状态
        mqttStatus: 'MQTT 连接状态',
        mqtt1Status: 'MQTT1 连接状态',
        mqtt1Flag: 'MQTT1 连接标识',
        mqtt2Status: 'MQTT2 连接状态',
        mqtt2Flag: 'MQTT2 连接标识',

        // Cloud 连接状态
        cloudStatus: 'Cloud 连接状态',
        cloudConnectionStatus: 'Cloud 连接状态',
        cloudConnectionFlag: 'Cloud 连接标识'
    },

    // 串口配置页面
    uart: {
        title: '串口配置',
        description: '设置串口工作参数',
        portName: '串口',
        baudRate: '波特率',
        dataBits: '数据位',
        stopBits: '停止位',
        parity: '校验位',
        flowControl: '流控',
        parityNone: '无校验',
        parityOdd: '奇校验',
        parityEven: '偶校验',
        flowNone: '无',
        flowHardware: '硬件',
        flowSoftware: '软件',
        restartRequired: '设置串口参数需要重启设备才能生效。',
        continueConfig: '继续配置'
    },

    // Socket配置页面
    socket: {
        title: 'Socket 通信链路',
        description: 'Socket通信通道的详细参数配置',
        enable: 'Socket使能',
        workMode: '工作模式',
        serverAddress: '服务器地址',
        serverPort: '服务器端口',
        remotePort: '远程端口号',
        localPort: '本地端口号',
        keepalive: 'Keepalive',
        reconnectInterval: '重连间隔',
        offlineCache: '断网缓存',
        sslEncrypt: 'SSL加密',
        authMethod: '认证方式',
        noAuth: '不认证证书',
        serverAuth: '认证服务器',
        mutualAuth: '双向认证',
        serverCert: '服务器根证书上传',
        clientCert: '客户端证书上传',
        clientKey: '客户端私钥上传',
        registerPacket: '注册包使能',
        registerSendMode: '注册包发送方式',
        registerContent: '注册包发送内容',
        customContent: '自定义内容',
        onConnect: '建立连接时',
        onSend: '发送数据时',
        both: '都发送',
        custom: '自定义',
        heartbeat: '心跳包使能',
        heartbeatInterval: '心跳包时间(秒)',
        heartbeatContent: '心跳包发送内容',
        tcpClient: 'TCP Client',
        tcpServer: 'TCP Server',
        udpClient: 'UDP Client',
        udpServer: 'UDP Server',
        maxConnections: 'TCP Server最大连接数',
        overflowHandle: '超出连接数量',
        config: '配置',
        path: '路径',
        restartRequired: 'Socket配置需要重启设备才能生效。',
        continueConfig: '继续配置'
    },

    // MQTT配置页面
    mqtt: {
        title: 'MQTT通信链路',
        enable: 'MQTT使能',
        protocol: 'MQTT协议',
        clientId: '客户ID',
        serverAddress: '服务器地址',
        remotePort: '远程端口号',
        keepalive: 'Keepalive',
        reconnectInterval: '重连间隔时间',
        cleanSession: '清理会话',
        connectionAuth: '连接验证',
        username: '用户名',
        password: '密码',
        will: '遗嘱',
        willTopic: '遗嘱Topic',
        willMessage: '遗嘱消息',
        willQos: '遗嘱QoS',
        willRetain: '遗嘱保留',
        retain: '保留',
        noRetain: '不保留',
        offlineCache: '断网缓存',
        sslEncrypt: 'SSL加密',
        authMethod: '认证方式',
        noAuth: '不认证证书',
        serverAuth: '认证服务器证书',
        mutualAuth: '双向认证',
        serverCert: '服务器根证书上传',
        clientCert: '客户端证书上传',
        clientKey: '客户端私钥上传'
    },

    // 云平台配置页面
    cloud: {
        title: '海凌科云',
        description: '海凌科云通信链路',
        enable: 'Cloud使能',
        deviceId: '设备ID',
        password: '设备密码',
        serverAddress: '服务器地址',
        serverPort: '服务器端口'
    },

    // 边缘计算页面
    edge: {
        title: '边缘计算配置',
        description: '配置边缘计算规则和脚本',
        scriptUpload: '脚本上传',
        scriptList: '脚本列表',
        scriptName: '脚本名称',
        actions: '操作',
        run: '运行',
        stop: '停止',
        delete: '删除',
        edit: '编辑'
    },

    // 系统设置页面
    system: {
        title: '系统设置',
        description: '设置系统参数',

        // 标签页
        tabParams: '参数设置',
        tabTime: '系统时间',
        tabDevice: '设备管理',
        tabTfCard: 'TF卡管理',

        // 参数设置
        hostName: '主机名称',
        username: '用户名',
        password: '密码',
        webPort: '网页端口号',
        exportParams: '参数导出',
        importParams: '参数导入',

        // 系统时间
        timezone: '时区',
        ntpEnable: 'NTP 使能',
        ntpServer: 'NTP服务器地址',
        ntpServer2: 'NTP服务器地址 2',
        ntpServer3: 'NTP服务器地址 3',
        ntpServer4: 'NTP服务器地址 4',
        currentTime: '当前时间',
        sync: '同步',
        timeSettings: '时间设置',
        setTime: '时间设置',

        // 设备管理
        firmwareUpgrade: '固件升级',
        selectFirmware: '选择文件',
        flashFirmware: '刷写固件',
        factoryReset: '恢复出厂',
        restart: '重新启动',
        restartNow: '立即重启',
        scheduledRestart: '定时重启',
        timeSelect: '时间选择',

        // TF卡管理
        spaceUsed: '已用空间/总空间',
        tfStatus: 'TF卡 状态',
        inserted: '已插入',
        notInserted: '未插入',
        formatTf: 'TF卡格式化',
        format: '格式化',

        // 确认对话框
        confirmUpgrade: '确定要升级固件吗？升级过程中请勿断电或关闭页面。',
        confirmFactoryReset: '确定要恢复出厂设置吗？所有配置将被清除！',
        confirmRestart: '确定要重启设备吗？',
        confirmFormat: '确定要格式化TF卡吗？所有数据将被清除！',

        // 操作结果
        exportSuccess: '参数导出成功',
        exportFailed: '参数导出失败',
        importSuccess: '参数导入成功',
        importFailed: '参数导入失败',
        configFormatError: '配置文件格式错误',
        syncSuccess: '时间同步成功',
        syncFailed: '时间同步失败',
        timeSetSuccess: '时间设置成功',
        timeSetFailed: '时间设置失败',
        upgradeSuccess: '固件上传成功，设备即将重启进行升级...',
        upgradeFailed: '固件升级失败',
        factoryResetSuccess: '恢复出厂设置成功，设备即将重启...',
        factoryResetFailed: '恢复出厂失败',
        restartSuccess: '设备即将重启...',
        restartFailed: '重启设备失败',
        formatSuccess: 'TF卡格式化成功',
        formatFailed: 'TF卡格式化失败',
        saveParamsSuccess: '参数配置保存成功',
        saveTimeSuccess: '时间配置保存成功',
        saveDeviceSuccess: '设备配置保存成功'
    },

    // 网络配置页面
    network: {
        title: '网络配置',
        description: '配置网络参数',
        // 标签页
        tabPriority: '网络优先',
        tabEthernet: '以太网',
        tabLte: 'LTE/CAT1',
        // 网络优先
        prioritySelect: '网络优先选择',
        networkPriority: '网络优先',
        ethernetFirst: '以太网优先',
        cellularFirst: '蜂窝网络优先',
        ethernetOnly: '仅以太网',
        probePeriod: '探测周期',
        probeServer1: '探测服务器地址1',
        probeServer2: '探测服务器地址2',
        // 以太网
        ethernet: '以太网',
        workMode: '工作模式',
        staticMode: '静态设置',
        dhcpMode: 'DHCP',
        dnsMode: 'DNS获取方式',
        manualDns: '手动设置',
        autoDns: '自动获取',
        lanIp: 'LAN IP',
        subnetMask: '子网掩码',
        gatewayAddress: '网关地址',
        primaryDns: '首选DNS地址',
        backupDns: '备用DNS地址',
        // LTE/CAT1
        simSwitch: 'SIM卡切换',
        externalSimFirst: '外置SIM优先',
        internalSimOnly: '仅内置SIM',
        externalSimOnly: '仅外置SIM',
        dualSimBackup: '双卡备份',
        apnName: 'APN名称',
        username: '用户名',
        password: '密码',
        authMethod: '鉴权方式',
        // 弹窗
        restartRequired: '网络配置需要重启设备才能生效。',
        continueConfig: '继续配置'
    },

    // 页脚
    footer: {
        copyright: 'Copyright © USR IOT'
    }
}
