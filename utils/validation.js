
/**
 * 验证 IPv4 地址
 * 规则：符合 IPv4 格式，且不能是广播地址 255.255.255.255
 */
export const isValidIP = (ip) => {
    if (!ip) return false;
    const reg = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
    if (!reg.test(ip)) return false;

    const parts = ip.split('.');
    for (let i = 0; i < 4; i++) {
        const num = parseInt(parts[i], 10);
        if (num < 0 || num > 255) return false;
    }

    // 广播地址拦截 (255.255.255.255)
    if (ip === '255.255.255.255') return false;

    return true;
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
 */
export const isValidServerAddress = (addr) => {
    if (!addr) return false;
    // 尝试判断是否为 IP 格式 (简单的数字.数字...)
    // 这里用一个简单的正则来区分是像IP还是像域名
    // 如果全是数字和点，且看起来像IP结构，就走IP验证
    const isIpFormat = /^[\d.]+$/.test(addr) && addr.split('.').length === 4;

    if (isIpFormat) {
        return isValidIP(addr);
    } else {
        return isValidDomain(addr);
    }
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
