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
 * 验证 TCP Server 最大连接数
 * 规则：整数，范围 1 ~ 32
 */
export const isValidMaxConnections = (num) => {
    if (num === '' || num === null || num === undefined) return false;
    const n = Number(num);
    return Number.isInteger(n) && n >= 1 && n <= 32;
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
 * 验证超时时间
 * 规则：整数，范围 200 ~ 10000 (ms)
 * @param {number|string} timeout 超时时间
 */
export const isValidTimeout = (timeout) => {
    if (timeout === '' || timeout === null || timeout === undefined) return false;
    const t = Number(timeout);
    return Number.isInteger(t) && t >= 200 && t <= 10000;
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
    return Number.isInteger(a) && a >= 1 && a <= 65536;
};

/**
 * 验证变化范围
 * 规则：0-100，最多支持3位小数
 * @param {number|string} range 变化范围
 */
export const isValidChangeRange = (range) => {
    if (range === '' || range === null || range === undefined) return false;
    
    // 1. 数值范围校验
    const r = Number(range);
    if (isNaN(r) || r < 0 || r > 100) return false;
    
    // 2. 精度格式校验 (基于原始字符串)
    const str = String(range).trim().toLowerCase();
    
    // 如果包含科学计数法 (如 1e-7 或 1e3)
    if (str.includes('e')) {
        const multiplied = r * 1000;
        return Math.abs(multiplied - Math.round(multiplied)) < 1e-9;
    }

    // 普通小数点格式校验
    if (str.includes('.')) {
        const parts = str.split('.');
        if (parts.length === 2 && parts[1].length > 3) {
            return false;
        }
    }
    return true;
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

/**
 * 验证 MQTT 主题 (发布端，如遗嘱主题)
 * 规则：
 * 1. 必填，长度 1-200 字节
 * 2. 禁止空层级 (例如 //)
 * 3. 仅限可见 ASCII 字符 (0x21-0x7E)，且禁止空格
 * 4. 禁止使用通配符 (#, +) 和系统保留前缀 ($)
 * 5. 层级限制在 7 层以内
 */
export const isValidMqttTopic = (topic) => {
    if (!topic) return false;

    // 1. 长度校验 (ASCII 字符下字符码点范围即为字节数)
    if (topic.length < 1 || topic.length > 200) return false;

    // 2. 仅限可见 ASCII 字符 (0x21-0x7E)，排除 MQTT 特殊字符
    // 排除 # (0x23), + (0x2B), $ (0x24)
    // 允许 !, ", %, &, ', (, ), *, ,, -, ., /, 0-9, :, ;, <, =, >, ?, @, A-Z, [, \, ], ^, _, `, a-z, {, |, }, ~
    const validCharsRegex = /^[\x21\x22\x25-\x2A\x2C-\x7E]+$/;
    if (!validCharsRegex.test(topic)) return false;

    // 3. 禁止以 $ 开头 (系统保留，虽然上面正则已拦截，此处做二次防护)
    if (topic.startsWith('$')) return false;

    // 4. 禁止空层级 //
    if (topic.includes('//')) return false;

    // 5. 层级限制 (建议 7 层以内)
    const levels = topic.split('/');
    if (levels.length > 7) return false;

    return true;
};

/**
 * 验证自定义内容 (注册包/心跳包)
 * 规则：长度 1-128 字节，仅支持 'a'-'z', 'A'-'Z', '0'-'9', '-', '.', '@'
 */
export const isValidCustomContent = (content) => {
    if (!content) return false;
    // 如果不是字符串，转成字符串以防万一
    const str = String(content);
    if (str.length < 1 || str.length > 128) return false;
    const reg = /^[a-zA-Z0-9\-\.\@]+$/;
    return reg.test(str);
};

/**
 * 检查两个IP是否在同一个网段内
 * @param {string} ip1 第一个IP地址
 * @param {string} ip2 第二个IP地址
 * @param {string} mask 子网掩码
 * @returns {boolean} 如果在同一网段返回true，否则返回false
 */
export const isSameSubnet = (ip1, ip2, mask) => {
    if (!isValidIPv4Format(ip1) || !isValidIPv4Format(ip2) || !isValidSubnetMask(mask)) {
        return false;
    }

    const ip1Parts = ip1.split('.').map(Number);
    const ip2Parts = ip2.split('.').map(Number);
    const maskParts = mask.split('.').map(Number);

    for (let i = 0; i < 4; i++) {
        if ((ip1Parts[i] & maskParts[i]) !== (ip2Parts[i] & maskParts[i])) {
            return false;
        }
    }
    return true;
};
/**
 * 验证计算公式
 * 规则：
 * 1. 允许为空
 * 2. 必须以 = 开头
 * 3. 允许字符：0-9, ., +, -, *, /, %, (, ), %s, 空格
 * 4. 禁止其他字母，禁止科学计数法 (e/E)
 * 5. 括号必须匹配
 */
export const isValidFormula = (formula) => {
    if (formula === undefined || formula === null || formula === '') return true;
    
    // 1. 基础规则：必须以 = 开头，禁止空格
    if (!formula.startsWith('=')) return false;
    if (formula.includes(' ')) return false;

    const expr = formula.substring(1);
    if (expr.length === 0) return false;

    // 2. 检查除 %s 以外的字母
    const noVarExpr = expr.replace(/%s/g, '1'); // 将 %s 替换为数字 1 方便后续语法检查
    if (/[a-zA-Z]/.test(noVarExpr.replace(/[0-9]/g, ''))) return false;

    // 3. 检查合法字符集
    const validCharRegex = /^[\d\.\+\-\*\/\%\(\)]+$/;
    if (!validCharRegex.test(noVarExpr)) return false;

    // 4. 除0及取模0检查
    if (expr.includes('/0') || expr.includes('%0')) return false;

    // 5. 结构检查 (基于已替换变量的 noVarExpr)
    const operators = ['+', '-', '*', '/', '%'];
    const binaryOperators = ['+', '*', '/', '%'];

    if (binaryOperators.includes(noVarExpr[0])) return false;
    if (operators.includes(noVarExpr[noVarExpr.length - 1])) return false;

    let balance = 0;
    for (let i = 0; i < noVarExpr.length; i++) {
        const char = noVarExpr[i];
        const nextChar = noVarExpr[i + 1];

        if (char === '(') balance++;
        if (char === ')') balance--;
        if (balance < 0) return false;

        if (operators.includes(char)) {
            if (nextChar && operators.includes(nextChar)) return false;
            if (nextChar === ')') return false;
        }

        if (char === '(') {
            if (nextChar && binaryOperators.includes(nextChar)) return false;
            if (nextChar === ')') return false;
        }
    }

    return balance === 0;
};
