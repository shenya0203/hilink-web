/**
 * 基础 IPv4 格式验证 (仅验证格式和数值范围 0-255)
 */
const isValidIPv4Format = (ip) => {
    if (!ip) return false;
    const reg = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
    if (!reg.test(ip)) return false;

    const parts = ip.split('.');
    for (let i = 0; i < 4; i++) {
        const num = parseInt(parts[i], 10);
        if (num < 0 || num > 255) return false;
    }
    return true;
};

/**
 * 验证 IPv4 主机地址
 * 规则：
 * 1. 符合 IPv4 格式
 * 2. 不能是 0.x.x.x
 * 3. 不能是 127.x.x.x (回环)
 * 4. 不能是 224.0.0.0 - 255.255.255.255 (组播 + 保留/广播)
 */
export const isValidIP = (ip) => {
    if (!isValidIPv4Format(ip)) return false;

    const parts = ip.split('.');
    const firstByte = parseInt(parts[0], 10);

    // 0.x.x.x
    if (firstByte === 0) return false;

    // 127.x.x.x
    if (firstByte === 127) return false;

    // 224+ (组播 Class D: 224-239, 保留 Class E: 240-255)
    if (firstByte >= 224) return false;

    return true;
};

/**
 * 验证子网掩码
 */
export const isValidSubnetMask = (mask) => {
    if (!isValidIPv4Format(mask)) return false;

    const parts = mask.split('.').map(Number);
    // 将掩码转换为32位整数
    let maskInt = 0;
    for (let i = 0; i < 4; i++) {
        maskInt = (maskInt << 8) + parts[i];
    }
    // 掩码必须是连续的1后面跟连续的0
    // 取反后加1，结果应该是2的幂次
    const inverted = ~maskInt;
    return (inverted & (inverted + 1)) === 0;
};

/**
 * 验证 IP 是否在子网内
 * @param {string} ip 待验证IP
 * @param {string} baseIp 基准IP (如 LAN IP)
 * @param {string} mask 子网掩码
 */
export const isIpInSubnet = (ip, baseIp, mask) => {
    // IP 和 BaseIP 应该是合法的 Host IP (或者至少是合法的格式)
    // Mask 必须是合法的掩码
    if (!isValidIPv4Format(ip) || !isValidIPv4Format(baseIp) || !isValidSubnetMask(mask)) return false;

    const ipParts = ip.split('.').map(Number);
    const baseParts = baseIp.split('.').map(Number);
    const maskParts = mask.split('.').map(Number);

    for (let i = 0; i < 4; i++) {
        if ((ipParts[i] & maskParts[i]) !== (baseParts[i] & maskParts[i])) {
            return false;
        }
    }
    return true;
};

/**
 * 验证 APN/用户名/密码 (允许大部分字符，排除特定特殊字符如空格、括号)
 * @param {string} str 字符串
 * @param {number} minLen 最小长度
 * @param {number} maxLen 最大长度
 */
export const isValidStringSafe = (str, minLen, maxLen) => {
    if (str === undefined || str === null) return true; // 允许为空由必填逻辑控制
    if (str.length === 0) return minLen === 0;
    if (str.length < minLen || str.length > maxLen) return false;

    // 禁止空格和括号 () [] {}
    const forbidden = /[\s\(\)\[\]\{\}]/;
    return !forbidden.test(str);
};

/**
 * 验证探测周期
 * 规则：整数，范围 5 ~ 600 秒
 */
export const isValidProbePeriod = (period) => {
    if (period === '' || period === null || period === undefined) return false;
    const p = Number(period);
    return Number.isInteger(p) && p >= 5 && p <= 600;
};

/**
 * 验证域名
 * 规则：长度不能超过 64 字节，支持字母、数字、点、横线
 */
export const isValidDomain = (domain) => {
    if (!domain) return false;
    if (domain.length > 64) return false;
    // 简单的域名字符验证
    const reg = /^[a-zA-Z0-9.-]+$/;
    return reg.test(domain);
};

/**
 * 验证服务器地址 (自动识别 IP 或域名)
 * 规则：
 * 1. 如果只包含数字和点，必须是合法的 IPv4 地址
 * 2. 否则按域名规则验证
 */
export const isValidServerAddress = (addr) => {
    if (!addr) return false;

    // 如果只包含数字和点，强制走 IP 验证
    // 这样可以防止像 223.5.322222222 这样的畸形 IP 被误判为域名
    if (/^[0-9.]+$/.test(addr)) {
        return isValidIP(addr);
    }

    return isValidDomain(addr);
};

/**
 * 验证端口
 * 规则：整数，范围 1024 ~ 65534
 * @param {number|string} port 端口号
 * @param {boolean} allowZero 是否允许为0 (0通常表示随机端口)
 */
export const isValidPort = (port, allowZero = false) => {
    // 允许字符串或数字输入
    if (port === '' || port === null || port === undefined) return false;
    const p = Number(port);

    if (allowZero && p === 0) return true;

    return Number.isInteger(p) && p >= 1024 && p <= 65534;
};

/**
 * 验证重连间隔
 * 规则：整数，范围 5 ~ 60 秒
 */
export const isValidReconnectInterval = (interval) => {
    if (interval === '' || interval === null || interval === undefined) return false;
    const i = Number(interval);
    return Number.isInteger(i) && i >= 5 && i <= 60;
};

/**
 * 验证 MQTT Client ID
 * 规则：允许字母、数字、下划线、横线，长度限制在 16 字节以内
 */
export const isValidClientId = (id) => {
    if (!id) return true; // 如果允许为空，则返回 true。如果不允许为空，需修改此处。假设必填则在组件层判断非空。
    // 这里主要验证格式和长度
    if (id.length > 16) return false;
    const reg = /^[a-zA-Z0-9_-]+$/;
    return reg.test(id);
};

/**
 * 验证详细信息 (Detail Info)
 * 规则：长度 0-16 字节，禁止空格和括号等特殊字符
 * @param {string} str 详细信息字符串
 */
export const isValidDetailInfo = (str) => {
    if (str === undefined || str === null || str === '') return true; // 允许为空
    if (str.length > 16) return false;
    // 禁止空格和括号 () [] {}
    const forbidden = /[\s\(\)\[\]\{\}]/;
    return !forbidden.test(str);
};

/**
 * 验证 Modbus TCP 端口号
 * 规则：整数，范围 1 ~ 65534
 * @param {number|string} port 端口号
 */
export const isValidModbusPort = (port) => {
    if (port === '' || port === null || port === undefined) return false;
    const p = Number(port);
    return Number.isInteger(p) && p >= 1 && p <= 65534;
};

/**
 * 验证轮询间隔
 * 规则：整数，范围 200 ~ 5000 (ms)
 * @param {number|string} interval 轮询间隔
 */
export const isValidPollInterval = (interval) => {
    if (interval === '' || interval === null || interval === undefined) return false;
    const i = Number(interval);
    return Number.isInteger(i) && i >= 200 && i <= 5000;
};

/**
 * 验证从机地址
 * 规则：整数，范围 1 ~ 247
 * @param {number|string} address 从机地址
 */
export const isValidSlaveAddress = (address) => {
    if (address === '' || address === null || address === undefined) return false;
    const a = Number(address);
    return Number.isInteger(a) && a >= 1 && a <= 247;
};

/**
 * 验证寄存器地址
 * 规则：整数，范围 1 ~ 65535
 * @param {number|string} address 寄存器地址
 */
export const isValidRegisterAddress = (address) => {
    if (address === '' || address === null || address === undefined) return false;
    const a = Number(address);
    return Number.isInteger(a) && a >= 1 && a <= 65535;
};

/**
 * 验证变化范围
 * 规则：正整数 (大于 0)
 * @param {number|string} range 变化范围
 */
export const isValidChangeRange = (range) => {
    if (range === '' || range === null || range === undefined) return false;
    const r = Number(range);
    return Number.isInteger(r) && r > 0;
};

/**
 * 验证上报周期
 * 规则：整数，范围 5 ~ 86400 (秒)
 * @param {number|string} period 上报周期
 */
export const isValidReportPeriod = (period) => {
    if (period === '' || period === null || period === undefined) return false;
    const p = Number(period);
    return Number.isInteger(p) && p >= 5 && p <= 86400;
};

/**
 * 验证主题 (订阅/发布主题)
 * 规则：字符串，长度 1-32 字节，禁止空格和括号等特殊字符
 * @param {string} topic 主题字符串
 */
export const isValidTopic = (topic) => {
    if (!topic) return false; // 必填
    if (topic.length < 1 || topic.length > 32) return false;
    // 禁止空格和括号 () [] {}
    const forbidden = /[\s\(\)\[\]\{\}]/;
    return !forbidden.test(topic);
};
