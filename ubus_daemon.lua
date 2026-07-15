#!/usr/bin/env lua
-- ==========================================================
-- Hilink Ubus Daemon
-- 后端ubus服务进程，提供设备配置的读取和设置接口
-- ==========================================================

local ubus                = require "ubus"
local uloop               = require "uloop"
local cjson               = require "cjson"
local shm                 = require "shm_reader"

-- ==========================================================
-- WiFi扫描全局配置
-- ==========================================================
local WIFI_IFACE          = "wlan0"               -- 扫描接口
local SCAN_TIMEOUT        = 8                     -- 超时时间(秒)
local SCAN_RESULT_FILE    = "/tmp/wifi_scan.txt"  -- 结果临时文件
local SCAN_LOCK_FILE      = "/tmp/wifi_scan.lock" -- 锁文件

-- ==========================================================
-- LED 指示灯配置与状态
-- ==========================================================
local LED_PATH            = "/sys/class/leds/system:net:info/brightness"
local LED_MODE_OFF        = 0
local LED_MODE_ON         = 1
local LED_MODE_BLINK      = 2

local current_led_mode    = LED_MODE_OFF
local led_mgmt_timer      = nil -- 单一LED管理定时器
local led_work_tick       = 0   -- 工作指示灯滴答计数 (每4拍=1s翻转一次)
local led_blink_tick      = 0   -- 网络指示灯闪烁相位 (0-15)
local led_work_state      = 1   -- 工作指示灯当前状态 (1=亮)
local sn                  = nil

-- Data Collection Config
--local WIFI_STA_IFACE = "wlan0"
--local WIFI_AP_IFACE = "wlan0-1"
local NETWORK_STA_LOGICAL = "wwan"

-- ==========================================================
-- 配置数据存储 (实际应用中应该从文件或数据库读取)
-- ==========================================================

product_name              = "HLK-IR01"

-- 1. 状态数据
local status_data         = {
    systime = os.time(),
    runtime = 0,
    cloud_sta = 0,
    socketa_sta = 0,
    socketb_sta = 0,
    mqtt1_sta = 0,
    mqtt2_sta = 0,
    soft_ver = "V1.0.46",
    os = "Openwrt",
    mac = "",
    sn = "03300225101400005387",
    user_sn = "",
    product_type = "HLK-IR01 4G"
}

-- 2. 网络状态数据
local network_status      = {
    netdev = "None", --当前使用网络 EtherNet/LET/WIFI/No
    eth = {
        link_sta = 0,
        ip_mode = 0,
        ip = "",
        dns = "",
        sdns = "",
        netmask = ""
    },
    lte = {
        ver = "",
        iccid = "",
        iccid_0 = "",
        imsi_0 = "",
        imei = "",
        csq = 99,
        mode = "4G",
        oper = 1,
        sim = 1,
        cimi = "",
        lte_sta = "DisConnect",
        lte_ip = "",
        lte_netmask = "",
        lte_dns = "",
        lte_sdns = "",
        use_sim = 0,
        internal_forward_disable = 1,
        external_forward_disable = 0
    }
}

-- 3. 网络配置数据
local network_config      = {
    net_select = 0,
    keepalive_period = 10,
    keepalive_addr = { "223.5.5.5", "8.8.8.8" },
    eth0 = {
        ip_mode = 0,
        sip = "",
        gip = "",
        mip = "",
        dns_mode = 0,
        dns_ip = { "", "" }
    },
    cell = {
        sim_switch = 2,
        apn = { addr = "", user = "", pswd = "", auth = 0 },
        dns_mode = 1,
        dns_ip = { "", "" }
    }
}

-- 4. 杂项配置
local misc_config         = {
    web_lang = 2,
    host_name = "",
    websock_port = 6432,
    websocket_point = 9,
    web_port = 80,
    web_user = "admin",
    web_psw = "admin",
    cache_buf = 0,
    reset_time = 0,
    telnet_en = 0,
    telnet_port = 22,
    ntp_sync_en = 1,
    ntp_url = {
    },
    ntp_utc = 8,
    f485_en = 0,
    f485_t = 10,
    port_max = 2,
    port_view = 0,
    timing_reset = {
        enable = 0,
        hh = 0,
        mm = 0,
        ss = 0
    }
}

-- UCI 配置文件操作封装
local uci_lib             = require("uci")

-- UCI Helper
-- UCI Helper
local function get_uci(key)
    local cursor = uci_lib.cursor()
    local config, section, option = string.match(key, "([^%.]+)%.([^%.]+)%.([^%.]+)")
    if config and section and option then
        return cursor:get(config, section, option)
    end
    return nil
end

local mac = nil

-- 配置缓存标志
local uart_config_loaded = false
local comm_tunnel_config_loaded = false

local function get_runtime()
    local f = io.open("/proc/uptime", "r")
    if f then
        local content = f:read("*l")
        f:close()
        local uptime = string.match(content, "^([%d%.]+)")
        local uptime_val = tonumber(uptime)
        if uptime_val then
            return math.floor(uptime_val)
        end
    end
    return 0
end

-- 边缘计算点位配置缓存
local edge_point_configs = {}
local edge_proto_access_csv = ""

local function log_info(msg)
    local f = io.popen("logger", "w")
    if f then
        f:write(string.format("[INFO] %s", tostring(msg)))
        f:close()
    end
end

local function log_error(msg)
    local f = io.popen("logger", "w")
    if f then
        f:write(string.format("[ERROR] %s", tostring(msg)))
        f:close()
    end
end

local function deep_copy(obj)
    if type(obj) ~= 'table' then return obj end
    local res = {}
    for k, v in pairs(obj) do res[deep_copy(k)] = deep_copy(v) end
    return res
end

local function get_system_mac()
    -- 如果已经获取过，直接返回缓存值
    if mac then return mac end

    local f = io.open("/dev/mtd2", "rb")
    if f then
        -- 移动指针到 0x4 (根据你的原始代码)
        f:seek("set", 0x4)

        -- 读取 6 字节二进制数据
        local content = f:read(6)
        f:close()

        if content and #content == 6 then
            -- 1. 将二进制流解包为 6 个独立的数字
            local b1, b2, b3, b4, b5, b6 = string.byte(content, 1, 6)

            -- 2. 格式化为标准 MAC 地址 (大写十六进制，不足两位自动补0)
            -- 你的错误结果 E4::3:8... 看起来像是把 38 变成了 3:8，
            -- 使用 %02X 可以强制保证每个字节占两位，中间用单冒号连接。
            mac = string.format("%02X:%02X:%02X:%02X:%02X:%02X", b1, b2, b3, b4, b5, b6)
        end
    end

    return mac
end

local function get_system_sn()
    if sn then return sn end
    local handle = io.popen("cloud_app -g 2>&1", "r")

    if not handle then
        return nil
    end

    local result = handle:read("*a")
    print("get_system_sn result: " .. result)
    handle:close()

    if result then
        -- 提取 DeviceName 字段
        local device_name = result:match("DeviceName:%s*(%S+)")
        if device_name then
            sn = device_name
            return device_name
        end
    end

    return nil
end

local function get_product_type()
    return "HLK-IR01 4G"
end


local function check_is_online(iface_name)
    if iface_name == "lte" then
        --判断网络配置是否是eth_only,这个配置在
        local net_select = get_uci("mwan3.globals.net_select") or 0
        if net_select == 2 or net_select == "2" then
            return false
        end
    end

    local path = "/var/run/mwan3/iface_state/" .. iface_name
    local f = io.open(path, "r")

    -- 1. 如果文件不存在，直接视为离线 (mwan3 未启动或接口未接管)
    if not f then return false end

    local content = f:read("*a")
    f:close()

    -- 2. 判断内容是否包含 "online"
    if content and string.find(content, "online") then
        return true
    end

    return false
end

local function get_current_run_net()
    -- 内部辅助函数：读取接口状态
    -- 返回 true 表示在线，false 表示离线

    -- 内部辅助函数：获取 UCI 策略配置
    local function get_uci_policy()
        -- 使用 -q 防止报错
        local handle = io.popen("uci -q get mwan3.default_rule.use_policy", "r")
        if not handle then return nil end

        local result = handle:read("*a")
        handle:close()

        if result then
            -- 去除首尾的换行符和空格
            return string.gsub(result, "^%s*(.-)%s*$", "%1")
        end
        return nil
    end

    -- --- 主逻辑开始 ---

    -- 1. 获取接口物理状态
    local wan_online = check_is_online("wan")
    local lte_online = check_is_online("lte")
    local wifi_online = check_is_online("wwan")

    --查看mwan3的配置中的globals中的 net_select 配置

    -- 2. 互斥判断：只有一个接口在线的情况
    if (wan_online or wifi_online) and not lte_online then
        return "EtherNet"
    elseif not (wan_online or wifi_online) and lte_online then
        return "LTE"
    elseif not (wan_online or wifi_online) and not lte_online then
        return "None" -- 全部离线
    end

    -- 3. 冲突判断：两个接口都在线
    -- 此时需要读取 UCI 配置来决定谁是主路由
    local policy = get_uci_policy()

    if policy then
        -- 3.1 明确匹配 LTE 优先策略
        if policy == "policy_cell_pri" then
            return "LTE"
        end

        -- 3.2 模糊匹配（增强健壮性，防止策略名微调）
        if string.find(policy, "cell") or string.find(policy, "lte") then
            return "LTE"
        end

        -- 3.3 明确匹配 EtherNet 优先策略 (如 policy_eth_pri)
        if string.find(policy, "eth") or string.find(policy, "wan") or string.find(policy, "wwan") then
            return "EtherNet"
        end
    end

    -- 4. 默认兜底
    -- 如果两个都在线，且无法识别策略（或策略为 balanced），
    -- 通常默认认为有线网络（EtherNet）优先级更高。
    return "EtherNet"
end

-- ==========================================================
-- LED 硬件控制与闪烁逻辑
-- ==========================================================

local function set_led_brightness(val)
    local f = io.open(LED_PATH, "w")
    if f then
        f:write(tostring(val))
        f:close()
    end
end

-- 统一LED管理定时器回调：每250ms执行一次，同时管理工作指示灯和网络指示灯
local function led_mgmt_cb()
    -- 工作指示灯：每4拍(1s)翻转一次
    led_work_tick = led_work_tick + 1
    if led_work_tick >= 4 then
        led_work_tick = 0
        led_work_state = 1 - led_work_state
        os.execute(string.format("echo %d > /sys/class/leds/system:work:status/brightness", led_work_state))
        --喂狗心跳 暂时放这 后面需要根据 业务心跳 来去处理
        os.execute("echo 1 > /sys/kernel/hlk_watchdog/heartbeat")
    end

    -- 网络指示灯闪烁
    if current_led_mode == LED_MODE_BLINK then
        local phase = led_blink_tick
        if phase < 8 then
            -- 闪烁阶段：每拍翻转一次
            if phase % 2 == 0 then
                set_led_brightness(1)
            else
                set_led_brightness(0)
            end
        else
            -- 暂停阶段：保持熄灭
            if phase == 8 then
                set_led_brightness(0)
            end
        end
        led_blink_tick = (led_blink_tick + 1) % 16
    end

    led_mgmt_timer:set(250)
end

-- 根据网络状态更新 LED 模式（无定时器操作，只改变模式变量和立即设置亮度）
local function update_net_led_logic()
    local handle = io.popen("uci -q get mwan3.default_rule.use_policy", "r")
    local policy = nil
    if handle then
        local res = handle:read("*a")
        handle:close()
        if res then policy = string.gsub(res, "^%s*(.-)%s*$", "%1") end
    end

    local wan_online = check_is_online("wan")
    local wifi_online = check_is_online("wwan")
    local lte_online = check_is_online("lte")
    local new_mode = LED_MODE_OFF

    if policy == "policy_lte_pri" then
        if lte_online then
            new_mode = LED_MODE_BLINK
        elseif wan_online or wifi_online then
            new_mode = LED_MODE_ON
        end
    else
        if wan_online or wifi_online then
            new_mode = LED_MODE_ON
        elseif lte_online then
            new_mode = LED_MODE_BLINK
        end
    end

    if new_mode == current_led_mode then return end
    current_led_mode = new_mode

    if current_led_mode == LED_MODE_OFF then
        set_led_brightness(0)
    elseif current_led_mode == LED_MODE_ON then
        set_led_brightness(1)
    elseif current_led_mode == LED_MODE_BLINK then
        set_led_brightness(1)
        led_blink_tick = 0
    end
end


local function read_file_content(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

-- precision-aware rounding
local function math_round(val, precision)
    local multiplier = 10 ^ (precision or 0)
    if val >= 0 then
        -- 正数：+0.5 后向下取整
        return math.floor(val * multiplier + 0.5) / multiplier
    else
        -- 负数：-0.5 后向上取整 (保证对称性)
        return math.ceil(val * multiplier - 0.5) / multiplier
    end
end

-- 格式化边缘计算点位值（支持截断和补位）
local function format_edge_value(val, data_type, precision)
    --log_info("format_edge_value: " .. val .. ", " .. data_type .. ", " .. precision)
    if not val then return "0" end
    local n = 10 ^ precision
    local num_val = tonumber(val) or 0

    -- 1:Bit, 4:Unsigned, 5:Signed, 18:Bool 等整数类
    -- 预处理：如果是整数类，先取整
    --if data_type == 1 or data_type == 4 or data_type == 5 or data_type == 6 or data_type == 7 or data_type == 8 or data_type == 9  or data_type == 18 then
    --    num_val = math.floor(num_val)
    --else
    num_val = math_round(val, precision)
    -- 移除手动截断逻辑，保留浮点原始精度，以便后续 string.format 执行标准的四舍五入
    --end

    -- 强制格式化为指定精度字符串（自动补0）
    local fmt = "%." .. precision .. "f"
    local ret_val = string.format(fmt, num_val)
    --log_info("format_edge_value: " .. ret_val)
    return ret_val
end

-- 加载协议转换配置 CSV 到内存缓存
local function load_edge_point_configs()
    local path = "/etc/config/device/points.csv"
    local content = read_file_content(path)
    if not content then
        log_info("No points.csv file found or empty at " .. path)
        edge_proto_access_csv = ""
        edge_point_configs = {}
        return
    end

    edge_proto_access_csv = content
    edge_point_configs = {}

    -- 解析 CSV 格式 (C 行)
    for line in string.gmatch(content, "[^\r\n]+") do
        -- 去掉末尾分号
        line = string.gsub(line, ";%s*$", "")
        if line ~= "" then
            local fields = {}
            for field in string.gmatch(line .. ",", "([^,]*),") do
                table.insert(fields, field)
            end

            -- 索引 0: 标识 (C)
            -- 索引 2: 数据点名称 (CSV 的第三个字段) -> 与 SHM 的 key 对应
            -- 索引 4: 数据类型
            -- 索引 5: 小数位数
            --log_info("fields: " .. cjson.encode(fields))
            if fields[1] == "C" then
                local key = fields[3]
                local data_type = tonumber(fields[5])
                local precision = tonumber(fields[6])
                if key and data_type and precision then
                    edge_point_configs[key] = {
                        data_type = data_type,
                        precision = precision
                    }
                end
                --log_info("Loaded edge point config: key=" .. key .. ", type=" .. data_type .. ", precision=" .. precision)
            end
        end
    end
    log_info("Loaded edge point configs for " ..
        (function()
            local c = 0
            for _ in pairs(edge_point_configs) do c = c + 1 end
            return c
        end)() .. " points")
end

local function base64_encode_file(path)
    -- Check if file exists first
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    f:close()

    local cmd = string.format("openssl base64 -A -in %s", path)
    local handle = io.popen(cmd, "r")
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()

    return result
end

local function write_file_content(path, content)
    local file = io.open(path, "w")
    if not file then return false end
    file:write(content)
    file:close()
    return true
end

-- UCI Helper for Timezone
local function timezone_to_utc_num(tz_str)
    -- 1. 处理 nil 或空字符串，默认为 0 (UTC)
    if not tz_str or tz_str == "" then
        return 0
    end

    -- 2. 尝试匹配 POSIX 格式中的 "符号" 和 "偏移量数字"
    -- 匹配逻辑：
    -- ([%+%-]?)  -> 捕获可选的 + 或 - 号 (sign)
    -- (%d+)      -> 捕获后面的数字 (offset)
    local sign, offset_str = string.match(tz_str, "([%+%-]?)(%d+)")

    -- 3. 特殊情况处理：如果字符串里没有数字 (例如 "UTC", "GMT", "Z")
    -- 你的原代码在这里会失败，因为 regex 匹配不到内容，offset 为 nil
    if not offset_str then
        return 0
    end

    local offset = tonumber(offset_str)

    -- 4. 符号转换 (关键：POSIX 符号与日常习惯相反)
    if sign == "-" then
        -- POSIX 的 "-" 代表“东区” (East of Greenwich)
        -- 比如 CST-8，代表比 UTC 快 8 小时
        -- 转换结果应为正数: 8
        return -offset
    else
        -- POSIX 的 "+" 或 "无符号" 代表“西区” (West of Greenwich)
        -- 比如 EST5 (无符号) 或 UTC+5
        -- 转换结果应为负数: -5
        return offset
    end
end

local function utc_num_to_timezone(num)
    num = tonumber(num) or 0

    -- POSIX 标准：东区（+）用负号，西区（-）用正号
    -- 格式建议使用 <+/-偏移量>反向偏移量，这是最标准且兼容性最好的写法
    if num > 0 then
        -- 例如：UTC+8 -> <+08>-8
        return string.format("<+%02d>-%d", num, num)
    elseif num < 0 then
        -- 例如：UTC-5 -> <-05>5
        local abs_num = math.abs(num)
        return string.format("<-%02d>%d", abs_num, abs_num)
    else
        -- 零时区
        return "UTC0"
    end
end

local function load_system_config_from_uci()
    local cursor = uci_lib.cursor()
    local system_conf = {
        hostname = product_name,
        timezone = "UTC-8",
        ntp_enable = 1,
        ntp_servers = {}
    }

    cursor:foreach("system", "system", function(section)
        system_conf.hostname = section.hostname or product_name
        system_conf.timezone = section.timezone or "UTC-8"
    end)

    cursor:foreach("system", "timeserver", function(section)
        system_conf.ntp_enable = tonumber(section.enabled) or 1
        if section.server then
            if type(section.server) == "table" then
                system_conf.ntp_servers = section.server
            elseif type(section.server) == "string" then
                table.insert(system_conf.ntp_servers, section.server)
            end
        end
    end)
    --log_info("system_config: " .. cjson.encode(system_conf))

    return system_conf
end

local function load_nginx_config_from_uci()
    -- Assuming nginx config is stored in /etc/config/nginx
    -- config main global
    --     option uci_port '80'
    --     option uci_user 'admin'
    --     option uci_pass 'admin'

    local cursor = uci_lib.cursor()
    local nginx_conf = {}

    -- Try to read from nginx uci if exists, otherwise fallback or use misc_config defaults
    -- Note: Standard nginx uci might not have user/pass in cleartext.
    -- We will assume a custom section 'global' or similar for this device.

    local section = cursor:get_all("nginx", "global")

    if section then
        --log_info("Found nginx global section")

        -- 更新配置，如果uci里有值就用uci的，否则保持默认
        if section.uci_port then nginx_conf.port = tonumber(section.uci_port) end
        if section.uci_user then nginx_conf.user = section.uci_user end
        if section.uci_pass then nginx_conf.pass = section.uci_pass end

        --log_info("uci_port: " .. (section.uci_port or "nil"))
        --log_info("uci_user: " .. (section.uci_user or "nil"))
    else
        log_info("Nginx global section not found!")
    end

    --log_info("nginx config :" .. cjson.encode(nginx_conf))

    return nginx_conf
end

local function set_nginx_config(port, user, pass)
    local cursor = uci_lib.cursor()
    -- Ensure section exists
    cursor:set("nginx", "global", "global")

    if port then cursor:set("nginx", "global", "uci_port", tostring(port)) end
    if user then cursor:set("nginx", "global", "uci_user", user) end
    if pass then cursor:set("nginx", "global", "uci_pass", pass) end

    cursor:commit("nginx")
    os.execute("touch /tmp/nginx_commit")

    -- Also update real nginx config file if needed, or trigger reload
    -- os.execute("/etc/init.d/nginx reload")
    return true
end

local function set_system_config(hostname, timezone_num)
    local cursor = uci_lib.cursor()
    local tz_val = utc_num_to_timezone(timezone_num)

    cursor:foreach("system", "system", function(section)
        cursor:set("system", section[".name"], "hostname", hostname)
        cursor:set("system", section[".name"], "timezone", tz_val)
    end)

    cursor:commit("system")
    os.execute("touch /tmp/misc_commit")
    -- 核心步骤：让系统根据新的 timezone 重新生成 /etc/TZ 文件
    os.execute("/etc/init.d/system restart")
    return true
end

local function set_ntp_config(enabled, server_list)
    local cursor = uci_lib.cursor()

    -- 设置 NTP 开关
    cursor:set("system", "ntp", "enabled", enabled)

    -- 设置 Server 列表
    -- 既然前端保证合法性，后端直接覆盖即可
    if server_list and #server_list > 0 then
        cursor:set("system", "ntp", "server", server_list)
    else
        -- 如果传来的列表全是空的（且前端允许这样做），则删除 server 配置
        -- 这样 /etc/config/system 里就不会有 "list server" 这一行
        cursor:delete("system", "ntp", "server")
    end
    cursor:commit("system")
    os.execute("touch /tmp/misc_commit")
end

-- ==========================================================
-- hlk_system 配置文件初始化（存储设备固定参数）
-- ==========================================================
local hlk_system_retry_timer = nil
local HLK_SYSTEM_RETRY_INTERVAL = 3000 -- 3秒

local function validate_imei(imei)
    if not imei or imei == "" then return false end
    return string.match(imei, "^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") ~= nil
end

local function validate_iccid(iccid)
    if not iccid or iccid == "" then return false end
    return string.match(iccid, "^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d?") ~= nil
        and (#iccid == 19 or #iccid == 20)
end

local function validate_imsi(imsi)
    if not imsi or imsi == "" then return false end
    return string.match(imsi, "^%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d$") ~= nil
end


local function init_hlk_system_check_cb()
    local modem_info_str = read_file_content("/tmp/modem_info.json")
    if not modem_info_str then
        log_info("hlk_system: modem_info.json not ready, retrying...")
        hlk_system_retry_timer:set(HLK_SYSTEM_RETRY_INTERVAL)
        return
    end

    local ok, info = pcall(cjson.decode, modem_info_str)
    if not ok then
        log_info("hlk_system: modem_info.json parse failed, err=" .. tostring(info) .. ", retrying...")
        hlk_system_retry_timer:set(HLK_SYSTEM_RETRY_INTERVAL)
        return
    end

    local imei    = info.imei or ""
    local iccid   = info.iccid or ""
    local imsi    = info.imsi or ""

    local mac     = get_system_mac() or ""
    local sn      = get_system_sn() or ""
    local ver     = status_data.soft_ver or ""

    local v_imei  = validate_imei(imei)
    local v_iccid = validate_iccid(iccid)
    local v_imsi  = validate_imsi(imsi)

    if not v_imei or not v_iccid or not v_imsi or
        mac == "" or sn == "" or ver == "" then
        log_info("hlk_system: data incomplete, retrying...")
        hlk_system_retry_timer:set(HLK_SYSTEM_RETRY_INTERVAL)
        return
    end


    local uci_dir = "/etc/config"
    local uci_file = uci_dir .. "/hlk_system"

    -- 检查文件是否存在，不存在则创建
    local f = io.open(uci_file, "r")
    if not f then
        log_info("hlk_system: /etc/config/hlk_system not found, creating...")
        local new_f = io.open(uci_file, "w")
        if new_f then
            new_f:write("config hlk_system 'global'\n")
            new_f:close()
            log_info("hlk_system: created /etc/config/hlk_system")
        else
            log_error("hlk_system: failed to create " .. uci_file)
            hlk_system_retry_timer:set(HLK_SYSTEM_RETRY_INTERVAL)
            return
        end
    else
        f:close()
        log_info("hlk_system: /etc/config/hlk_system already exists")
    end

    local cursor = uci_lib.cursor()
    cursor:set("hlk_system", "global", "hlk_system")
    cursor:set("hlk_system", "global", "imei", imei)
    cursor:set("hlk_system", "global", "iccid", iccid)
    cursor:set("hlk_system", "global", "imsi", imsi)
    cursor:set("hlk_system", "global", "mac", mac)
    cursor:set("hlk_system", "global", "sn", sn)
    cursor:set("hlk_system", "global", "soft_ver", ver)

    log_info("hlk_system: UCI set done, committing...")
    cursor:commit("hlk_system")
    os.execute("sync")
    log_info("hlk_system: commit + sync done, reading back...")

    local r_cursor = uci_lib.cursor()
    local r_imei   = r_cursor:get("hlk_system", "global", "imei") or ""
    local r_iccid  = r_cursor:get("hlk_system", "global", "iccid") or ""
    local r_imsi   = r_cursor:get("hlk_system", "global", "imsi") or ""
    local r_mac    = r_cursor:get("hlk_system", "global", "mac") or ""
    local r_sn     = r_cursor:get("hlk_system", "global", "sn") or ""
    local r_ver    = r_cursor:get("hlk_system", "global", "soft_ver") or ""

    log_info("hlk_system: READ BACK imei=[" .. r_imei .. "] (expect [" .. imei .. "]) match=" .. tostring(r_imei == imei))
    log_info("hlk_system: READ BACK iccid=[" ..
        r_iccid .. "] (expect [" .. iccid .. "]) match=" .. tostring(r_iccid == iccid))
    log_info("hlk_system: READ BACK imsi=[" .. r_imsi .. "] (expect [" .. imsi .. "]) match=" .. tostring(r_imsi == imsi))
    log_info("hlk_system: READ BACK mac=[" .. r_mac .. "] (expect [" .. mac .. "]) match=" .. tostring(r_mac == mac))
    log_info("hlk_system: READ BACK sn=[" .. r_sn .. "] (expect [" .. sn .. "]) match=" .. tostring(r_sn == sn))
    log_info("hlk_system: READ BACK ver=[" .. r_ver .. "] (expect [" .. ver .. "]) match=" .. tostring(r_ver == ver))

    if r_imei == imei and r_iccid == iccid and r_imsi == imsi and
        r_mac == mac and r_sn == sn and r_ver == ver then
        log_info("hlk_system: ===== WRITE SUCCESS =====")
    else
        log_error("hlk_system: ===== VERIFY FAILED, will retry =====")
        hlk_system_retry_timer:set(HLK_SYSTEM_RETRY_INTERVAL)
        return
    end

    if hlk_system_retry_timer then
        hlk_system_retry_timer:cancel()
        hlk_system_retry_timer = nil
    end
    log_info("hlk_system: ===== init_hlk_system_check_cb END =====")
end

local function init_hlk_system()
    local f = io.open("/etc/config/hlk_system", "r")
    if f then
        f:close()
        log_info("hlk_system: file exists, checking params...")

        -- 读取已存储的参数
        local cursor    = uci_lib.cursor()
        local old_imei  = cursor:get("hlk_system", "global", "imei") or ""
        local old_iccid = cursor:get("hlk_system", "global", "iccid") or ""
        local old_imsi  = cursor:get("hlk_system", "global", "imsi") or ""
        local old_mac   = cursor:get("hlk_system", "global", "mac") or ""
        local old_sn    = cursor:get("hlk_system", "global", "sn") or ""
        local old_ver   = cursor:get("hlk_system", "global", "soft_ver") or ""

        log_info("hlk_system: stored imei=[" .. old_imei .. "] iccid=[" .. old_iccid ..
            "] imsi=[" .. old_imsi .. "] mac=[" .. old_mac ..
            "] sn=[" .. old_sn .. "] ver=[" .. old_ver .. "]")

        -- 检查参数是否完整
        if old_imei == "" or old_iccid == "" or old_imsi == "" or
            old_mac == "" or old_sn == "" or old_ver == "" then
            log_info("hlk_system: params incomplete, start timer to fill")
            hlk_system_retry_timer = uloop.timer(init_hlk_system_check_cb)
            hlk_system_retry_timer:set(HLK_SYSTEM_RETRY_INTERVAL)
            return
        end

        -- 检查版本号是否变化（固件升级）
        local cur_ver = status_data.soft_ver or ""
        log_info("hlk_system: stored_ver=[" .. old_ver .. "] cur_ver=[" .. cur_ver .. "]")

        if cur_ver ~= "" and cur_ver ~= old_ver then
            log_info("hlk_system: version changed [" .. old_ver .. "] -> [" .. cur_ver .. "], updating")
            cursor:set("hlk_system", "global", "soft_ver", cur_ver)
            cursor:commit("hlk_system")
            os.execute("sync")

            -- 验证
            local r_cursor = uci_lib.cursor()
            local r_ver = r_cursor:get("hlk_system", "global", "soft_ver") or ""
            if r_ver == cur_ver then
                log_info("hlk_system: version update success")
            else
                log_error("hlk_system: version update failed, expect [" .. cur_ver .. "] got [" .. r_ver .. "]")
            end
        else
            log_info("hlk_system: version unchanged, no update needed")
        end

        log_info("hlk_system: ===== init_hlk_system END (all good) =====")
        return
    end

    log_info("hlk_system: file not found, starting timer to wait for modem data")
    hlk_system_retry_timer = uloop.timer(init_hlk_system_check_cb)
    hlk_system_retry_timer:set(HLK_SYSTEM_RETRY_INTERVAL)
end

-- 从UCI读取串口配置到内存
local function load_uart_config_from_uci()
    local cursor = uci_lib.cursor()
    local config = { UART = {} }

    cursor:foreach("uart", "uart", function(section)
        local uart_item = {
            enable = tonumber(section.enable) or 0,
            name = section.name or section[".name"],
            work_mode = tonumber(section.work_mode) or 0,
            baud_rate = tonumber(section.baud_rate) or 9600,
            data_bit = tonumber(section.data_bit) or 8,
            stop_bit = tonumber(section.stop_bit) or 1,
            parity = tonumber(section.parity) or 0,
            pack_len = tonumber(section.pack_len) or 1460,
            pack_time = tonumber(section.pack_time) or 0,
            func = tonumber(section.func) or 1,
            select = tonumber(section.select) or 0,
            device = section.device or ""
        }
        table.insert(config.UART, uart_item)
    end)

    return config
end

-- 保存串口配置到UCI
local function save_uart_config_to_uci(config)
    local cursor = uci_lib.cursor()

    -- 先删除所有现有的uart section
    cursor:foreach("uart", "uart", function(section)
        cursor:delete("uart", section[".name"])
    end)

    -- 写入新的配置
    for i, uart_item in ipairs(config.UART) do
        local section_name = uart_item.name or ("Uart" .. i)
        cursor:set("uart", section_name, "uart")
        cursor:set("uart", section_name, "enable", tostring(uart_item.enable or 0))
        cursor:set("uart", section_name, "name", uart_item.name or section_name)
        cursor:set("uart", section_name, "work_mode", tostring(uart_item.work_mode or 0))
        cursor:set("uart", section_name, "baud_rate", tostring(uart_item.baud_rate or 9600))
        cursor:set("uart", section_name, "data_bit", tostring(uart_item.data_bit or 8))
        cursor:set("uart", section_name, "stop_bit", tostring(uart_item.stop_bit or 1))
        cursor:set("uart", section_name, "parity", tostring(uart_item.parity or 0))
        cursor:set("uart", section_name, "pack_len", tostring(uart_item.pack_len or 1460))
        cursor:set("uart", section_name, "pack_time", tostring(uart_item.pack_time or 0))
        cursor:set("uart", section_name, "func", tostring(uart_item.func or 1))
        if uart_item.select then
            cursor:set("uart", section_name, "select", tostring(uart_item.select))
        end
        if uart_item.device then
            cursor:set("uart", section_name, "device", uart_item.device)
        end
    end

    cursor:commit("uart")
    os.execute("touch /tmp/uart_commit")
    return true
end

-- 从UCI读取通讯通道配置到内存
local function load_comm_tunnel_config_from_uci()
    local cursor = uci_lib.cursor()
    local config = {
        SOCK = {},
        MQTT = {},
        CLOUD = nil
    }

    -- 读取SOCK配置
    cursor:foreach("comm_tunnel", "SOCK", function(section)
        local sock_item = {
            enable = tonumber(section.enable) or 0,
            name = section.name or section[".name"],
            mode = tonumber(section.mode) or 0,
            tcpc = {
                server_ip = section.tcpc_server_ip or "",
                local_port = tonumber(section.tcpc_local_port) or 0,
                server_port = tonumber(section.tcpc_server_port) or 8234,
                dns_timeout = tonumber(section.tcpc_dns_timeout) or 30,
                reconn_interval = tonumber(section.tcpc_reconn_interval) or 5,
                ssl_mode = tonumber(section.tcpc_ssl_mode) or 0,
                ssl_verify = tonumber(section.tcpc_ssl_verify) or 0,
                ssl_server_name = section.tcpc_ssl_server_name or "null",
                ssl_client_name = section.tcpc_ssl_client_name or "null",
                ssl_client_key = section.tcpc_ssl_client_key or "null",
                regp_en = tonumber(section.tcpc_regp_en) or 0,
                regp_fmt = tonumber(section.tcpc_regp_fmt) or 0,
                regp_ctx = section.tcpc_regp_ctx or "",
                regp_tim = tonumber(section.tcpc_regp_tim) or 0,
                hrtp_en = tonumber(section.tcpc_hrtp_en) or 0,
                hrtp_fmt = tonumber(section.tcpc_hrtp_fmt) or 0,
                hrtp_ctx = section.tcpc_hrtp_ctx or "",
                hrtp_tim = tonumber(section.tcpc_hrtp_tim) or 60
            },
            tcps = {
                local_port = tonumber(section.tcps_local_port) or 8029,
                conn_max_num = tonumber(section.tcps_conn_max_num) or 4,
                timeout_handling = tonumber(section.tcps_timeout_handling) or 0,
                idle_handling = tonumber(section.tcps_idle_handling) or 0,
                idle_timeout = tonumber(section.tcps_idle_timeout) or 3600
            },
            udpc = {
                server_ip = section.udpc_server_ip or "192.168.20.21",
                local_port = tonumber(section.udpc_local_port) or 0,
                server_port = tonumber(section.udpc_server_port) or 1593,
                dns_timeout = tonumber(section.udpc_dns_timeout) or 30,
                ip_port_verify = tonumber(section.udpc_ip_port_verify) or 0
            },
            httpc = {
                mode = tonumber(section.httpc_mode) or 0,
                url = section.httpc_url or "/1.php?",
                header = section.httpc_header or "Accept:text/html",
                cut_header = tonumber(section.httpc_cut_header) or 1,
                server_ip = section.httpc_server_ip or "test.usr.cn",
                server_port = tonumber(section.httpc_server_port) or 80,
                resp_timeout = tonumber(section.httpc_resp_timeout) or 10,
                local_port = tonumber(section.httpc_local_port) or 0
            }
        }
        table.insert(config.SOCK, sock_item)
    end)

    -- 读取MQTT配置
    cursor:foreach("comm_tunnel", "MQTT", function(section)
        local mqtt_item = {
            enable = tonumber(section.enable) or 0,
            name = section.name or section[".name"],
            mqtt_ver = tonumber(section.mqtt_ver) or 4,
            server_ip = section.server_ip or "",
            server_port = tonumber(section.server_port) or 1883,
            loacl_port = tonumber(section.local_port) or 0,
            keepalive = tonumber(section.keepalive) or 60,
            reconn_space = tonumber(section.reconn_space) or 5,
            clean_session = tonumber(section.clean_session) or 0,
            client_id = section.client_id or "",
            conn_verify = tonumber(section.conn_verify) or 0,
            conn_user_name = section.conn_user_name or "",
            conn_user_password = section.conn_password or "",
            ssl_mode = tonumber(section.ssl_mode) or 0,
            ssl_verify = tonumber(section.ssl_verify) or 0,
            ssl_server_name = section.ssl_server_name or "null",
            ssl_client_name = section.ssl_client_name or "null",
            ssl_client_key = section.ssl_client_key or "null",
            will_flag = tonumber(section.will_flag) or 0,
            will = {
                topic = section.will_topic or "/will",
                msg = section.will_msg or "offline",
                qos = tonumber(section.will_qos) or 0,
                retention = tonumber(section.will_retention) or 0
            }
        }
        table.insert(config.MQTT, mqtt_item)
    end)

    --log_info("GET CLOUD")

    -- 读取CLOUD配置
    cursor:foreach("comm_tunnel", "CLOUD", function(section)
        -- CLOUD配置只有一个，直接赋值而不是插入到数组
        config.CLOUD = {
            enable = tonumber(section.enable) or 0,
            name = section.name or "CLOUD",
            pvt_deploy_enable = tonumber(section.pvt_deploy_enable) or 0,
            server_ip = section.server_ip or "",
            server_port = tonumber(section.server_port) or 1234
        }
    end)

    return config
end

-- 保存通讯通道配置到UCI
local function save_comm_tunnel_config_to_uci(config)
    local cursor = uci_lib.cursor()

    -- 先删除所有现有的SOCK section
    cursor:foreach("comm_tunnel", "SOCK", function(section)
        cursor:delete("comm_tunnel", section[".name"])
    end)

    -- 先删除所有现有的MQTT section
    cursor:foreach("comm_tunnel", "MQTT", function(section)
        cursor:delete("comm_tunnel", section[".name"])
    end)

    -- 先删除所有现有的cloud section
    cursor:foreach("comm_tunnel", "cloud", function(section)
        cursor:delete("comm_tunnel", section[".name"])
    end)

    -- 写入SOCK配置
    for i, sock_item in ipairs(config.SOCK or {}) do
        local section_name = sock_item.name or ("SOCK" .. i)
        cursor:set("comm_tunnel", section_name, "SOCK")
        cursor:set("comm_tunnel", section_name, "enable", tostring(sock_item.enable or 0))
        cursor:set("comm_tunnel", section_name, "name", sock_item.name or section_name)
        cursor:set("comm_tunnel", section_name, "mode", tostring(sock_item.mode or 0))

        -- tcpc 配置
        if sock_item.tcpc then
            cursor:set("comm_tunnel", section_name, "tcpc_server_ip", sock_item.tcpc.server_ip or "")
            cursor:set("comm_tunnel", section_name, "tcpc_local_port", tostring(sock_item.tcpc.local_port or 0))
            cursor:set("comm_tunnel", section_name, "tcpc_server_port", tostring(sock_item.tcpc.server_port or 8234))
            cursor:set("comm_tunnel", section_name, "tcpc_dns_timeout", tostring(sock_item.tcpc.dns_timeout or 30))
            cursor:set("comm_tunnel", section_name, "tcpc_reconn_interval", tostring(sock_item.tcpc.reconn_interval or 5))
            cursor:set("comm_tunnel", section_name, "tcpc_ssl_mode", tostring(sock_item.tcpc.ssl_mode or 0))
            cursor:set("comm_tunnel", section_name, "tcpc_ssl_verify", tostring(sock_item.tcpc.ssl_verify or 0))
            cursor:set("comm_tunnel", section_name, "tcpc_ssl_server_name", sock_item.tcpc.ssl_server_name or "null")
            cursor:set("comm_tunnel", section_name, "tcpc_ssl_client_name", sock_item.tcpc.ssl_client_name or "null")
            cursor:set("comm_tunnel", section_name, "tcpc_ssl_client_key", sock_item.tcpc.ssl_client_key or "null")
            cursor:set("comm_tunnel", section_name, "tcpc_regp_en", tostring(sock_item.tcpc.regp_en or 0))
            cursor:set("comm_tunnel", section_name, "tcpc_regp_fmt", tostring(sock_item.tcpc.regp_fmt or 0))
            cursor:set("comm_tunnel", section_name, "tcpc_regp_ctx", sock_item.tcpc.regp_ctx or "")
            cursor:set("comm_tunnel", section_name, "tcpc_regp_tim", tostring(sock_item.tcpc.regp_tim or 0))
            cursor:set("comm_tunnel", section_name, "tcpc_hrtp_en", tostring(sock_item.tcpc.hrtp_en or 0))
            cursor:set("comm_tunnel", section_name, "tcpc_hrtp_fmt", tostring(sock_item.tcpc.hrtp_fmt or 0))
            cursor:set("comm_tunnel", section_name, "tcpc_hrtp_ctx", sock_item.tcpc.hrtp_ctx or "")
            cursor:set("comm_tunnel", section_name, "tcpc_hrtp_tim", tostring(sock_item.tcpc.hrtp_tim or 60))
        end

        -- tcps 配置
        if sock_item.tcps then
            cursor:set("comm_tunnel", section_name, "tcps_local_port", tostring(sock_item.tcps.local_port or 8029))
            cursor:set("comm_tunnel", section_name, "tcps_conn_max_num", tostring(sock_item.tcps.conn_max_num or 4))
            cursor:set("comm_tunnel", section_name, "tcps_timeout_handling",
                tostring(sock_item.tcps.timeout_handling or 0))
            cursor:set("comm_tunnel", section_name, "tcps_idle_handling", tostring(sock_item.tcps.idle_handling or 0))
            cursor:set("comm_tunnel", section_name, "tcps_idle_timeout", tostring(sock_item.tcps.idle_timeout or 3600))
        end

        -- udpc 配置
        if sock_item.udpc then
            cursor:set("comm_tunnel", section_name, "udpc_server_ip", sock_item.udpc.server_ip or "192.168.20.21")
            cursor:set("comm_tunnel", section_name, "udpc_local_port", tostring(sock_item.udpc.local_port or 0))
            cursor:set("comm_tunnel", section_name, "udpc_server_port", tostring(sock_item.udpc.server_port or 1593))
            cursor:set("comm_tunnel", section_name, "udpc_dns_timeout", tostring(sock_item.udpc.dns_timeout or 30))
            cursor:set("comm_tunnel", section_name, "udpc_ip_port_verify", tostring(sock_item.udpc.ip_port_verify or 0))
        end

        -- httpc 配置
        if sock_item.httpc then
            cursor:set("comm_tunnel", section_name, "httpc_mode", tostring(sock_item.httpc.mode or 0))
            cursor:set("comm_tunnel", section_name, "httpc_url", sock_item.httpc.url or "/1.php?")
            cursor:set("comm_tunnel", section_name, "httpc_header", sock_item.httpc.header or "Accept:text/html")
            cursor:set("comm_tunnel", section_name, "httpc_cut_header", tostring(sock_item.httpc.cut_header or 1))
            cursor:set("comm_tunnel", section_name, "httpc_server_ip", sock_item.httpc.server_ip or "test.usr.cn")
            cursor:set("comm_tunnel", section_name, "httpc_server_port", tostring(sock_item.httpc.server_port or 80))
            cursor:set("comm_tunnel", section_name, "httpc_resp_timeout", tostring(sock_item.httpc.resp_timeout or 10))
            cursor:set("comm_tunnel", section_name, "httpc_local_port", tostring(sock_item.httpc.local_port or 0))
        end
    end

    -- 写入MQTT配置
    for i, mqtt_item in ipairs(config.MQTT or {}) do
        local section_name = mqtt_item.name or ("MQTT" .. i)
        cursor:set("comm_tunnel", section_name, "MQTT")
        cursor:set("comm_tunnel", section_name, "enable", tostring(mqtt_item.enable or 0))
        cursor:set("comm_tunnel", section_name, "name", mqtt_item.name or section_name)
        cursor:set("comm_tunnel", section_name, "mqtt_ver", tostring(mqtt_item.mqtt_ver or 4))
        cursor:set("comm_tunnel", section_name, "server_ip", mqtt_item.server_ip or "")
        cursor:set("comm_tunnel", section_name, "server_port", tostring(mqtt_item.server_port or 1883))
        cursor:set("comm_tunnel", section_name, "local_port", tostring(mqtt_item.loacl_port or 0))
        cursor:set("comm_tunnel", section_name, "keepalive", tostring(mqtt_item.keepalive or 60))
        cursor:set("comm_tunnel", section_name, "reconn_space", tostring(mqtt_item.reconn_space or 5))
        cursor:set("comm_tunnel", section_name, "clean_session", tostring(mqtt_item.clean_session or 0))
        cursor:set("comm_tunnel", section_name, "client_id", mqtt_item.client_id or "")
        cursor:set("comm_tunnel", section_name, "conn_verify", tostring(mqtt_item.conn_verify or 0))
        cursor:set("comm_tunnel", section_name, "conn_user_name", mqtt_item.conn_user_name or "")
        cursor:set("comm_tunnel", section_name, "conn_password", mqtt_item.conn_user_password or "")
        cursor:set("comm_tunnel", section_name, "ssl_mode", tostring(mqtt_item.ssl_mode or 0))
        cursor:set("comm_tunnel", section_name, "ssl_verify", tostring(mqtt_item.ssl_verify or 0))
        cursor:set("comm_tunnel", section_name, "ssl_server_name", mqtt_item.ssl_server_name or "null")
        cursor:set("comm_tunnel", section_name, "ssl_client_name", mqtt_item.ssl_client_name or "null")
        cursor:set("comm_tunnel", section_name, "ssl_client_key", mqtt_item.ssl_client_key or "null")
        cursor:set("comm_tunnel", section_name, "will_flag", tostring(mqtt_item.will_flag or 0))

        -- will 配置
        if mqtt_item.will then
            cursor:set("comm_tunnel", section_name, "will_topic", mqtt_item.will.topic or "/will")
            cursor:set("comm_tunnel", section_name, "will_msg", mqtt_item.will.msg or "offline")
            cursor:set("comm_tunnel", section_name, "will_qos", tostring(mqtt_item.will.qos or 0))
            cursor:set("comm_tunnel", section_name, "will_retention", tostring(mqtt_item.will.retention or 0))
        end
    end

    -- 写入CLOUD配置
    if config.CLOUD then
        local section_name = config.CLOUD.name or "CLOUD"
        cursor:set("comm_tunnel", section_name, "CLOUD")
        cursor:set("comm_tunnel", section_name, "enable", tostring(config.CLOUD.enable or 0))
        cursor:set("comm_tunnel", section_name, "name", config.CLOUD.name or "CLOUD")
        cursor:set("comm_tunnel", section_name, "pvt_deploy_enable", tostring(config.CLOUD.pvt_deploy_enable or 0))
        cursor:set("comm_tunnel", section_name, "server_ip", config.CLOUD.server_ip or "")
        cursor:set("comm_tunnel", section_name, "server_port", tostring(config.CLOUD.server_port or 1234))
    end

    cursor:commit("comm_tunnel")
    os.execute("touch /tmp/comm_commit")
    return true
end



-- 5. 通讯通道配置
--分多个配置
--[[
    /etc/config/comm_tunnel
    config SOCK 'SOCKA'
        option enable '1'                       #socket 使能 0：禁用 1：启用
        option name 'SOCKA'                     #socket 通道名称
        option mode '0'                         #socket 模式 0：TCP client 1: TCP Server 2:UDP client 3 http client
        #以tcpc_开头的参数
        option tcpc_server_ip '192.168.0.201'   #tcp client  连接的服务器IP/域名
        option tcpc_local_port '0'              #tcp client  tcp client本地使用的端口 0表示系统选择 非0表示指定端口
        option tcpc_server_port '8234'          #tcp client  tcp client连接的服务器端口
        option tcpc_dns_timeout '30'            #tcp client  dns超时时间    用在tcpc_server_ip为域名时
        option tcpc_reconn_interval '5'         #tcp client  重连间隔
        option tcpc_ssl_mode '0'                #tcp client  ssl模式 0：不使用ssl 1：使用ssl TLS1.2
        option tcpc_ssl_verify '0'              #tcp client  0：不认证证书 1：认证服务器证书 2：双向认证
        option tcpc_ssl_server_name 'null'      #服务器证书名称 证书存放在指定的目录下/etc/config/tcpc/
        option tcpc_ssl_client_name 'null'      #客户端证书名称
        option tcpc_ssl_client_key 'null'       #客户端证书密钥
        option tcpc_regp_en '0'                 #tcp client  注册包使能 0：禁用 1：启用
        option tcpc_regp_fmt '0'                #tcp client  注册包发送内容：0：MAC 1：IMEI 2：SN 3：自定义
        option tcpc_regp_ctx ''                 #tcp client  注册包自定义内容 当tcpc_regp_fmt为3时有效
        option tcpc_regp_tim '0'                #tcp client  注册包发送方式 0：建立连接时 1: 发送数据时 2: 都发送

        option tcpc_hrtp_en '0'                 #tcp client  心跳包使能 0：禁用 1：启用
        option tcpc_hrtp_fmt '0'                #tcp client  心跳包发送内容： 0：MAC 1:IMEI 2:自定义
        option tcpc_hrtp_ctx ''                 #tcp client  心跳包自定义内容 当tcpc_hrtp_fmt为2时有效
        option tcpc_hrtp_tim '60'               #tcp client  心跳包时间
        #以tcps_开头的参数
        option tcps_local_port '8029'           #tcp server  tcp server本地使用的端口
        option tcps_conn_max_num '4'            #tcp server  tcp server最大连接数
        option tcps_timeout_handling '0'        #tcp server  超出连接数量后的处理 0：KEEP 保持 1：KICK 踢掉
        #以udpc_开头的参数
        option udpc_server_ip '192.168.20.21'   #udp client  udp client连接的服务器IP/域名
        option udpc_local_port '0'              #udp client  udp client本地使用的端口 0表示系统选择 非0表示指定端口
        option udpc_server_port '1593'          #udp client  udp client连接的服务器端口
        option udpc_dns_timeout '30'            #udp client  dns超时时间    用在udpc_server_ip为域名时
        option udpc_ip_port_verify '0'          #udp client  ip端口验证 0：不验证 1：验证
        #以httpc_开头的参数
        option httpc_mode '0'                   #http client  http client模式 0：http 1：https
        option httpc_url '/1.php?'              #http client  http client连接的URL
        option httpc_header 'Accept:text/html'  #http client  http client连接的header
        option httpc_cut_header '1'             #http client  http client连接的cut_header
        option httpc_server_ip 'test.usr.cn'    #http client  http client连接的服务器IP/域名
        option httpc_server_port '80'           #http client  http client连接的服务器端口
        option httpc_resp_timeout '10'          #http client  http client连接的响应超时时间
        option httpc_local_port '0'             #http client  http client本地使用的端口 0表示系统选择 非0表示指定端口
    config SOCK 'SOCKB'
        option enable '1'                       #socket 使能 0：禁用 1：启用
        option name 'SOCKB'                     #socket 通道名称
        option mode '0'                         #socket 模式 0：TCP client 1: TCP Server 2:UDP client 3 http client
        #以tcpc_开头的参数
        option tcpc_server_ip '192.168.0.201'   #tcp client  连接的服务器IP/域名
        option tcpc_local_port '0'              #tcp client  tcp client本地使用的端口 0表示系统选择 非0表示指定端口
        option tcpc_server_port '8234'          #tcp client  tcp client连接的服务器端口
        option tcpc_dns_timeout '30'            #tcp client  dns超时时间    用在tcpc_server_ip为域名时
        option tcpc_reconn_interval '5'         #tcp client  重连间隔
        option tcpc_ssl_mode '0'                #tcp client  ssl模式 0：不使用ssl 1：使用ssl TLS1.2
        option tcpc_ssl_verify '0'              #tcp client  ssl验证 0：不验证 1：验证   不知道干啥的？？
        option tcpc_ssl_server_name 'null'      #服务器证书名称 证书存放在指定的目录下/etc/config/tcpc/
        option tcpc_ssl_client_name 'null'      #客户端证书名称
        option tcpc_ssl_client_key 'null'       #客户端证书密钥
        option tcpc_regp_en '0'                 #tcp client  注册包协议使能 0：禁用 1：启用
        option tcpc_regp_fmt '0'                #tcp client  注册包协议格式 0：不使用 1：使用
        option tcpc_regp_ctx ''                 #tcp client  注册包协议上下文
        option tcpc_regp_tim '0'                #tcp client  注册包协议超时时间
        option tcpc_hrtp_en '0'                 #tcp client  心跳包协议使能 0：禁用 1：启用
        option tcpc_hrtp_fmt '0'                #tcp client  心跳包协议格式 0：不使用 1：使用
        option tcpc_hrtp_ctx ''                 #tcp client  心跳包协议上下文
        option tcpc_hrtp_tim '60'               #tcp client  心跳包协议超时时间
        #以tcps_开头的参数
        option tcps_local_port '8029'           #tcp server  tcp server本地使用的端口
        option tcps_conn_max_num '4'            #tcp server  tcp server最大连接数
        option tcps_timeout_handling '0'        #tcp server  超出连接数量后的处理 0：KEEP 保持 1：KICK 踢掉
        #以udpc_开头的参数
        option udpc_server_ip '192.168.20.21'   #udp client  udp client连接的服务器IP/域名
        option udpc_local_port '0'              #udp client  udp client本地使用的端口 0表示系统选择 非0表示指定端口
        option udpc_server_port '1593'          #udp client  udp client连接的服务器端口
        option udpc_dns_timeout '30'            #udp client  dns超时时间    用在udpc_server_ip为域名时
        option udpc_ip_port_verify '0'          #udp client  ip端口验证 0：不验证 1：验证
        #以httpc_开头的参数
        option httpc_mode '0'                   #http client  http client模式 0：http 1：https
        option httpc_url '/1.php?'              #http client  http client连接的URL
        option httpc_header 'Accept:text/html'  #http client  http client连接的header
        option httpc_cut_header '1'             #http client  http client连接的cut_header
        option httpc_server_ip 'test.usr.cn'    #http client  http client连接的服务器IP/域名
        option httpc_server_port '80'           #http client  http client连接的服务器端口
        option httpc_resp_timeout '10'          #http client  http client连接的响应超时时间
        option httpc_local_port '0'             #http client  http client本地使用的端口 0表示系统选择 非0表示指定端口
    config MQTT 'MQTT1'
        option enable '1'                       #MQTT 使能 0：禁用 1：启用
        option name 'MQTT1'                     #MQTT 通道名称
        option mott_Ver '4'                     #MQTT 协议版本 3：MQTT 3.1 4：MQTT 3.1.1
        option client_id 'test'                 #MQTT 客户端ID
        option server_ip '192.168.0.201'        #MQTT 服务器IP
        option server_port '1883'               #MQTT 服务器端口
        option local_port '0'                   #MQTT 本地端口
        option keepalive '60'                   #MQTT 保持连接时间

        option reconn_space '5'                 #MQTT 重连间隔
        option clean_session '0'                #MQTT 清除会话 0：不清除 1：清除
        option conn_verify '0'                  #MQTT 连接验证 0：不验证 1：验证

        option conn_user_name 'test'            #MQTT 用户名
        option conn_password 'test'             #MQTT 密码
        option will_flag '0'                    #MQTT 遗嘱标志 0：不遗嘱 1：遗嘱
        option will_topic 'test'                #MQTT 遗嘱主题
        option will_msg 'test'                  #MQTT 遗嘱消息
        option will_qos '0'                     #MQTT 遗嘱QoS 0：QoS 0 1：QoS 1 2：QoS 2
        option will_retention '0'               #MQTT 遗嘱保留 0：不保留 1：保留
        option ssl_mode '1'                     #MQTT SSL模式 0：不使用SSL 1：使用SSL
        option ssl_verify '0'                   #MQTT SSL验证 01: 不认证证书 1:认证服务器证书 2:双向认证
        option ssl_server_name 'test'           #MQTT SSL服务器证书文件名称
        option ssl_client_name 'test'           #MQTT SSL客户端证书文件名称
        option ssl_client_key 'test'            #MQTT SSL客户端密钥文件名称
    config MQTT 'MQTT2'
        option enable '0'                       #MQTT 使能 0：禁用 1：启用
        option name 'MQTT2'                     #MQTT 通道名称
        option mott_Ver '4'                     #MQTT 协议版本 3：MQTT 3.1 4：MQTT 3.1.1
        option client_id 'test'                 #MQTT 客户端ID
        option server_ip '192.168.0.202'        #MQTT 服务器IP
        option server_port '1883'               #MQTT 服务器端口
        option local_port '0'                   #MQTT 本地端口
        option keepalive '60'                   #MQTT 保持连接时间

        option reconn_space '5'                 #MQTT 重连间隔
        option clean_session '0'                #MQTT 清除会话 0：不清除 1：清除
        option conn_verify '0'                  #MQTT 连接验证 0：不验证 1：验证

        option conn_user_name 'test'            #MQTT 用户名
        option conn_password 'test'             #MQTT 密码
        option will_flag '0'                    #MQTT 遗嘱标志 0：不遗嘱 1：遗嘱
        option will_topic 'test'                #MQTT 遗嘱主题
        option will_msg 'test'                  #MQTT 遗嘱消息
        option will_qos '0'                     #MQTT 遗嘱QoS 0：QoS 0 1：QoS 1 2：QoS 2
        option will_retention '0'               #MQTT 遗嘱保留 0：不保留 1：保留
        option ssl_mode '0'                     #MQTT SSL模式 0：不使用SSL 1：使用SSL
        option ssl_verify '0'                   #MQTT SSL验证 01: 不认证证书 1:认证服务器证书 2:双向认证
        option ssl_server_name 'test'           #MQTT SSL服务器证书文件名称
        option ssl_client_name 'test'           #MQTT SSL客户端证书文件名称
        option ssl_client_key 'test'            #MQTT SSL客户端密钥文件名称
    config CLOUD 'CLOUD'
        option enable '0'                       #CLOUD 使能 0：禁用 1：启用
        option name 'CLOUD'                     #CLOUD 云的名字
        option pvt_deploy_enable '0'            #CLOUD 私有部署使能 0：禁用 1：启用
        option server_ip '192.168.0.201'        #CLOUD 私有云的IP地址
        option server_port '8234'               #CLOUD 私有云的端口
    }
]] --
local comm_tunnel_config = {
    SOCK = {
        {
            enable = 0,
            name = "SOCKA",
            mode = 0,
            tcpc = {
                server_ip = "",
                dns_timeout = 30,
                reconn_interval = 5,
                server_port = 8234,
                local_port = 0,
                ssl_mode = 0,
                ssl_verify = 0,
                ssl_server_name = "null",
                ssl_client_name = "null",
                ssl_client_key = "null",
                regp_en = 0,
                regp_fmt = 0,
                regp_ctx = "",
                regp_tim = 0,
                hrtp_en = 0,
                hrtp_fmt = 0,
                hrtp_ctx = "",
                hrtp_tim = 60
            },
            tcps = { local_port = 8029, conn_max_num = 4, timeout_handling = 0, idle_handling = 0, idle_timeout = 3600 },
            udpc = { server_ip = "192.168.20.21", dns_timeout = 30, server_port = 1593, local_port = 0, ip_port_verify = 0 },
            httpc = {
                mode = 0,
                url = "/1.php?",
                header = "Accept:text/html",
                cut_header = 1,
                server_ip = "test.usr.cn",
                server_port = 80,
                resp_timeout = 10,
                local_port = 0
            }
        },
        {
            enable = 0,
            name = "SOCKB",
            mode = 0,
            tcpc = {
                server_ip = "",
                dns_timeout = 30,
                reconn_interval = 5,
                server_port = 8234,
                local_port = 0,
                ssl_mode = 0,
                ssl_verify = 0,
                ssl_server_name = "null",
                ssl_client_name = "null",
                ssl_client_key = "null",
                regp_en = 0,
                regp_fmt = 0,
                regp_ctx = "",
                regp_tim = 0,
                hrtp_en = 0,
                hrtp_fmt = 0,
                hrtp_ctx = "",
                hrtp_tim = 60
            },
            tcps = { local_port = 20108, conn_max_num = 4, timeout_handling = 0, idle_handling = 0, idle_timeout = 3600 },
            udpc = { server_ip = "192.168.20.21", dns_timeout = 30, server_port = 1593, local_port = 0, ip_port_verify = 0 },
            httpc = {
                mode = 0,
                url = "/1.php?",
                header = "Accept:text/html",
                cut_header = 1,
                server_ip = "test.usr.cn",
                server_port = 80,
                resp_timeout = 10,
                local_port = 0
            }
        }
    },
    MQTT = {
        {
            enable = 0,
            name = "MQTT1",
            mqtt_ver = 4,
            server_ip = "",
            ssl_mode = 0,
            ssl_verify = 0,
            ssl_server_name = "null",
            ssl_client_name = "null",
            ssl_client_key = "null",
            loacl_port = 0,
            server_port = 1883,
            keepalive = 60,
            reconn_space = 5,
            clean_session = 0,
            client_id = "1234567",
            conn_verify = 0,
            conn_user_name = "",
            conn_user_password = "",
            will_flag = 0,
            will = { topic = "/will", msg = "offline", qos = 0, retention = 0 }
        },
        {
            enable = 0,
            name = "MQTT2",
            mqtt_ver = 4,
            server_ip = "",
            ssl_mode = 0,
            ssl_verify = 0,
            ssl_server_name = "null",
            ssl_client_name = "null",
            ssl_client_key = "null",
            loacl_port = 0,
            server_port = 1883,
            keepalive = 60,
            reconn_space = 5,
            clean_session = 0,
            client_id = "",
            conn_verify = 0,
            conn_user_name = "",
            conn_user_password = "",
            will_flag = 0,
            will = { topic = "/will", msg = "offline", qos = 0, retention = 0 }
        }
    },
    CLOUD = { enable = 0, name = "CLOUD", pvt_deploy_enable = 0, server_ip = "", server_port = 1234 }
}

-- 6. 串口配置
--[[
    /etc/config/uart
    config uart 'Uart1'
        option enable '1'
        option select '0'
        option device '/dev/ttyS0'
        option name 'Uart1'
        option work_mode '2'
        option baud_rate '115200'
        option data_bit '8'
        option stop_bit '1'
        option parity '0'
        option pack_len '1460'
        option pack_time '0'
        option func '1'
    config uart 'Uart2'
        option enable '1'           #串口使能 0 禁用 1 启用
        option select '0'           #意义不明 暂时保留
        option device '/dev/ttyS1'  #物理串口设备
        option name 'Uart2'         #串口通道名称
        option work_mode '1'        #0 网络透传 1:边缘计算模式
        option baud_rate '9600'     #波特率
        option data_bit '8'         #数据位
        option stop_bit '1'         #停止位   1: 1位 2： 2位
        option parity '0'           #校验位   0：无校验 1：奇校验 2：偶校验
        option pack_len '1460'      #串口打包长度， work_mode == 1时 有效
        option pack_time '0'        #串口打包时间， work_mode == 1时 有效
        option func '1'             #功能位 1 表示数据库 0 表示调试口
]] --
local uart_config = {
    UART = {
        { enable = 1, name = "Uart1", work_mode = 2,  baud_rate = 115200, data_bit = 8,     stop_bit = 1, parity = 0,   pack_len = 1460, pack_time = 0,   func = 1 },
        { enable = 1, select = 0,     name = "Uart2", work_mode = 2,      baud_rate = 9600, data_bit = 8, stop_bit = 1, parity = 0,      pack_len = 1460, pack_time = 0 }
    }
}

-- 7. 离线缓存配置
local offline_cache_config = {
    mgt = { rpt_time = 200, queue_type = 0 },
    tunnel = {
        { name = "SOCKA", enable = 0 },
        { name = "SOCKB", enable = 0 },
        { name = "MQTT1", enable = 0 },
        { name = "MQTT2", enable = 0 },
        { name = "CLOUD", enable = 0 }
    }
}

-- 8. TF卡信息
local tf_info = {
    status = 1,
    err = 0,
    total = 16 * 1024 * 1024 * 1024,
    used = 2 * 1024 * 1024 * 1024
}

-- 9. 边缘计算配置
local edge_config = {
    all_en = 1,
    refresh_frequency = 100,
    calc_period = 100,
    poll_interval = 100
}

-- 10. 边缘计算上报配置
local edge_report_config = {
    group = {}
}

-- 11. 边缘计算协议转换配置
local edge_access_config = {
    group = {
        {
            enable = 0,
            name = "my_group1",
            proto = 1,
            up = {
                link = "MQTT1",
                topic = "/PubTopic",
                qos = 0,
                retention = 0
            },
            down = {
                link = "MQTT1",
                topic = "/SubTopic",
                qos = 0
            }
        }
    }
}

-- 12. 边缘计算链路控制配置
local edge_link_ctrl_config = {
    group = {}
}

-- 13. 边缘计算点位数据 (CSV格式)
local edge_points_csv = "V,V1.0,N7X0,;\nSC,Device1,1,2,1,100,0,0,192.168.0.21:2100,Device1,;\n"

-- 14. 协议转换点位数据 (CSV格式)
local edge_proto_access_csv = "S,1,6,10,ModBusTCP\nC,node01,Device1,18,00001"

local function get_communication_enable(tunnel)
    -- 遍历第一层 (SOCK, MQTT, CLOUD)
    for key, data in pairs(comm_tunnel_config) do
        -- 情况1: data 是一个列表/数组 (例如 SOCK, MQTT)
        -- 我们通过判断是否存在索引 [1] 来确定它是不是列表
        if type(data) == "table" and data[1] ~= nil then
            for _, item in ipairs(data) do
                if item.name == tunnel then
                    return item.enable
                end
            end

            -- 情况2: data 是单个对象 (例如 CLOUD)
        elseif type(data) == "table" and data.name == tunnel then
            return data.enable
        end
    end

    -- 未找到
    return 0
end
-- ==========================================================
-- 辅助函数
-- ==========================================================

-- ==========================================================
-- Helper: 获取连接状态 (读取文件)
-- ==========================================================
local function get_communication_status(link)
    -- 假设状态文件存放在 /tmp/ 目录下，请根据实际情况修改
    -- 先判断app是否存在
    -- POSIX 规范检查进程是否存在开销较大，且 procd 有守护机制
    -- 我们选择相信状态文件，或在以后使用 ubus call service list 检查
    --[[
    if link == "CLOUD" then
        local ret = os.execute("pidof cloud_app >/dev/null 2>&1")
        if ret ~= 0 then return 0 end
    elseif link == "MQTT1" or link == "MQTT2" then
        local ret = os.execute("pidof mqtt_app >/dev/null 2>&1")
        if ret ~= 0 then return 0 end
    elseif link == "SOCKA" or link == "SOCKB" then
        local ret = os.execute("pidof socket >/dev/null 2>&1")
        if ret ~= 0 then return 0 end
    end
    ]] --

    local status_dir = "/tmp/"

    local prefix = "socket_" -- 默认为 socket

    -- 根据 link 类型判断文件前缀
    if string.find(link, "MQTT") then
        prefix = "mqtt_"
    elseif link == "CLOUD" then
        prefix = "cloud_"
    end

    -- 拼接完整路径: /tmp/socket_SOCKA_status
    local filename = status_dir .. prefix .. link .. "_status"

    -- 1. 尝试打开文件
    local file = io.open(filename, "r")
    if not file then
        -- 文件不存在，视为未连接
        -- ngx.log(ngx.ERR, "Status file not found: " .. filename)
        return 0
    end

    -- 2. 读取内容
    local content = file:read("*a")
    file:close()

    if not content or content == "" then
        return 0
    end

    --如果进程消失怎么办？？

    -- 3. 解析 JSON (使用 pcall 防止 JSON 格式错误导致崩溃)
    local ok, data = pcall(cjson.decode, content)
    if ok and data then
        -- 确保返回的是数字 0 或 1
        return tonumber(data.connected) or 0
    end

    return 0
end

-- 更新嵌套表的值
local function update_nested_value(tbl, key_path, value)
    local keys = {}
    for k in string.gmatch(key_path, "[^%.%[%]]+") do
        table.insert(keys, k)
    end

    local current = tbl
    for i = 1, #keys - 1 do
        local key = tonumber(keys[i]) or keys[i]
        if current[key] == nil then
            current[key] = {}
        end
        current = current[key]
    end

    local final_key = tonumber(keys[#keys]) or keys[#keys]
    current[final_key] = value
end

-- ==========================================================
-- 配置设置处理函数
-- ==========================================================

local function set_uart_config(args)
    -- 参数格式: {"UART":[{...}, {...}]}
    if args.UART and type(args.UART) == "table" then
        -- 更新内存缓存
        uart_config.UART = args.UART

        -- 保存到UCI配置文件
        local success = save_uart_config_to_uci(uart_config)
        if success then
            log_info("Updated uart config and saved to UCI: " .. cjson.encode(uart_config))
            uart_config_loaded = true
        else
            log_error("Failed to save uart config to UCI")
        end
        return success
    else
        log_error("Invalid uart config format, expected {UART:[...]}")
        return false
    end
end

-- 新增：管理TCP Server防火墙规则
local function manage_firewall_for_tcp_servers(config)
    log_info("Managing firewall rules for TCP servers...")
    local cursor = uci_lib.cursor()
    local changes_made = false

    -- 遍历所有SOCK配置
    for i, sock_item in ipairs(config.SOCK or {}) do
        -- 为每个SOCK通道定义一个唯一的、可预测的防火墙规则名称
        local rule_name = "web_sock_" .. string.lower(sock_item.name or "sock" .. i) .. "_rule"
        log_info("Processing firewall for " .. (sock_item.name or "sock" .. i) .. ", rule name: " .. rule_name)

        -- 1. 无论如何，先尝试删除旧规则，以处理禁用、模式更改或端口更改的情况
        -- 使用 pcall 来安全地处理 uci:get 返回的错误（当规则不存在时）
        local ok, section = pcall(function() return cursor:get_all("firewall", rule_name) end)
        if ok and section then
            log_info("Deleting existing firewall rule: " .. rule_name)
            cursor:delete("firewall", rule_name)
            changes_made = true
        end

        -- 2. 检查当前配置是否为启用的TCP Server模式
        if sock_item.enable == 1 and sock_item.mode == 1 then
            local port = sock_item.tcps.local_port
            if port and port > 0 and port < 65536 then
                log_info("Adding firewall rule for " .. sock_item.name .. " on TCP port " .. port)
                -- 3. 添加新规则
                cursor:set("firewall", rule_name, "rule") -- 创建一个 rule 类型的节
                cursor:set("firewall", rule_name, "name", "Allow-WAN-To-" .. sock_item.name)
                cursor:set("firewall", rule_name, "src", "wan")
                cursor:set("firewall", rule_name, "dest_port", tostring(port))
                cursor:set("firewall", rule_name, "proto", "tcp")
                cursor:set("firewall", rule_name, "target", "ACCEPT")
                changes_made = true
            else
                log_error("Invalid port for " .. sock_item.name .. ": " .. tostring(port) .. ". Firewall rule not added.")
            end
        end
    end

    -- 4. 如果有任何更改，则提交
    if changes_made then
        log_info("Committing firewall changes.")
        cursor:commit("firewall")
        os.execute("touch /tmp/firewall_commit")
    else
        log_info("No firewall changes needed.")
    end
end


local function set_comm_tunnel_config(args)
    log_info("set_comm_tunnel_config: " .. cjson.encode(args))
    for k, v in pairs(args) do
        -- 处理 SOCK 配置
        local prefix, index, key = string.match(k, "([ns])_SOCK%[(%d+)%]%.(.+)")
        if prefix and index and key then
            index = tonumber(index) + 1
            if comm_tunnel_config.SOCK[index] then
                -- 解析嵌套key，如 tcpc.server_ip
                local parts = {}
                for part in string.gmatch(key, "[^%.]+") do
                    table.insert(parts, part)
                end

                local target = comm_tunnel_config.SOCK[index]
                for i = 1, #parts - 1 do
                    if target[parts[i]] then
                        target = target[parts[i]]
                    end
                end
                target[parts[#parts]] = tonumber(v) or v
            end
            --log_info("SOCK[" .. (index - 1) .. "]." .. key .. " = " .. tostring(v))
        end

        -- 处理 MQTT 配置
        prefix, index, key = string.match(k, "([ns])_MQTT%[(%d+)%]%.(.+)")
        if prefix and index and key then
            index = tonumber(index) + 1
            if comm_tunnel_config.MQTT[index] then
                local parts = {}
                for part in string.gmatch(key, "[^%.]+") do
                    table.insert(parts, part)
                end

                local target = comm_tunnel_config.MQTT[index]
                for i = 1, #parts - 1 do
                    if target[parts[i]] then
                        target = target[parts[i]]
                    end
                end
                target[parts[#parts]] = tonumber(v) or v
            end
            --log_info("MQTT[" .. (index - 1) .. "]." .. key .. " = " .. tostring(v))
        end

        -- 处理 CLOUD 配置
        --log_info("cloud_key: " .. k)
        local cloud_key = string.match(k, "[ns]_CLOUD%.(.+)")
        if cloud_key then
            comm_tunnel_config.CLOUD[cloud_key] = tonumber(v) or v
            --log_info("CLOUD." .. cloud_key .. " = " .. tostring(v))
        end
    end

    -- 保存配置到UCI配置文件
    local success = save_comm_tunnel_config_to_uci(comm_tunnel_config)
    if success then
        log_info("Updated comm_tunnel config and saved to UCI: " .. cjson.encode(comm_tunnel_config))
        comm_tunnel_config_loaded = true

        -- 新增：调用防火墙管理函数
        manage_firewall_for_tcp_servers(comm_tunnel_config)
    else
        log_error("Failed to save comm_tunnel config to UCI")
    end

    return success
end

local function set_offline_cache(args)
    for k, v in pairs(args) do
        local index, key = string.match(k, "n_tunnel%[(%d+)%]%.(.+)")
        if index and key then
            index = tonumber(index) + 1
            if offline_cache_config.tunnel[index] then
                offline_cache_config.tunnel[index][key] = tonumber(v) or v
            end
        end

        local mgt_key = string.match(k, "n_mgt%.(.+)")
        if mgt_key then
            offline_cache_config.mgt[mgt_key] = tonumber(v) or v
        end
    end
    return true
end

misc_config = {
    web_lang = 2,
    host_name = "HLK-IR01",
    productModel = "HLK-IR01",
    websock_port = 6432,
    websocket_point = 9,
    web_port = 80, -- 默认值，启动时会被 sync_nginx_settings 覆盖
    web_user = "", -- 默认值
    web_psw = "",  -- 默认值
    cache_buf = 0,
    reset_time = 0,
    telnet_en = 0,
    telnet_port = 22,
    ntp_sync_en = 1,
    ntp_url = {
        "ntp1.aliyun.com",
        "time1.cloud.tencent.com",
        "time.ustc.edu.cn",
        "cn.pool.ntp.org"
    },
    ntp_utc = 8,
    f485_en = 0,
    f485_t = 10,
    port_max = 2,
    port_view = 0,
    timing_reset = {
        enable = 0,
        hh = 0,
        mm = 0,
        ss = 0
    }
}

local function load_timing_reset_config_from_uci()
    local cursor = uci_lib.cursor()
    local enable = cursor:get("system", "auto_reboot", "enable")
    local hh = cursor:get("system", "auto_reboot", "hh")
    local mm = cursor:get("system", "auto_reboot", "mm")
    local ss = cursor:get("system", "auto_reboot", "ss")

    local reset_cfg = {
        enable = enable or 0,
        hh = hh or 0,
        mm = mm or 0,
        ss = ss or 0
    }
    return reset_cfg
end


-- ==========================================================
-- 2. 辅助函数：启动时同步 Nginx 真实配置 (可选，但推荐)
-- ==========================================================
local function sync_nginx_settings()
    --log_info("sync setting")
    -- Load initial config from UCI to memory
    local sys_conf = load_system_config_from_uci()
    local nginx_conf = load_nginx_config_from_uci()
    local timing_reset_conf = load_timing_reset_config_from_uci()
    local loaded_config = load_comm_tunnel_config_from_uci()
    --log_info("loaded comm tunnel config: " .. cjson.encode(loaded_config))
    if loaded_config and (#loaded_config.SOCK > 0 or #loaded_config.MQTT > 0 or loaded_config.CLOUD) then
        comm_tunnel_config = loaded_config
        --log_info("loaded comm tunnel config: " .. comm_tunnel_config.SOCK[1].enable)
        comm_tunnel_config_loaded = true
    end


    if not misc_config then misc_config = {} end

    -- Update misc_config with loaded values
    misc_config.host_name = sys_conf.hostname
    misc_config.ntp_utc = timezone_to_utc_num(sys_conf.timezone)
    misc_config.ntp_sync_en = sys_conf.ntp_enable

    -- Ensure ntp_url is a table of 4 strings
    misc_config.ntp_url = { "", "", "", "" }
    for i, s in ipairs(sys_conf.ntp_servers) do
        if i <= 4 then misc_config.ntp_url[i] = s end
    end

    misc_config.web_port = nginx_conf.port or 80
    misc_config.web_user = nginx_conf.user or "admin"
    misc_config.web_psw = nginx_conf.pass or "admin"
    misc_config.timing_reset = {
        enable = timing_reset_conf.enable,
        hh = timing_reset_conf.hh,
        mm = timing_reset_conf.mm,
        ss = timing_reset_conf.ss
    }

    status_data.os = "Openwrt"
    status_data.mac = get_system_mac()
    status_data.sn = get_system_sn()
    status_data.product_type = get_product_type()
    status_data.netdev = get_current_run_net()

    -- 初始更新一次指示灯状态
    update_net_led_logic()
end

-- ==========================================================
-- 新增辅助函数：设置定时重启任务 (直接操作 crontab)
-- ==========================================================
local function apply_cron_reboot(enable, hh, mm)
    local cron_file = "/etc/crontabs/root"
    local id_tag = "# HLK_AUTO_REBOOT_TASK" -- 唯一标记，用于识别本程序的任务
    local lines = {}
    log_info("apply cron reboot ")

    -- 1. 读取现有的 crontab 内容
    local f = io.open(cron_file, "r")
    if f then
        for line in f:lines() do
            -- 如果这行不包含我们的标记，就保留它（防止覆盖系统或其他程序的任务）
            if not string.find(line, id_tag, 1, true) then
                table.insert(lines, line)
            end
        end
        f:close()
    end

    -- 2. 如果开启了定时重启，添加新任务
    -- Cron 格式: 分 时 日 月 周 命令
    -- 注意: Cron 不支持“秒”，所以我们忽略 UI 传来的秒，或者默认为0
    if tonumber(enable) == 1 then
        hh = tonumber(hh) or 0
        mm = tonumber(mm) or 0
        -- 生成命令: 每天 hh:mm 执行重启
        local cmd = string.format("%d %d * * * /sbin/reboot %s", mm, hh, id_tag)
        table.insert(lines, cmd)
        log_info("Scheduled reboot added: " .. cmd)
    else
        log_info("Scheduled reboot disabled")
    end

    -- 3. 写回文件
    f = io.open(cron_file, "w")
    if f then
        for _, line in ipairs(lines) do
            f:write(line .. "\n")
        end
        f:close()

        -- 4. 重启 cron 服务使配置生效
        os.execute("/etc/init.d/cron restart")
        return true
    else
        log_error("Failed to write to crontab")
        return false
    end
end

-- ==========================================================
-- 新增辅助函数：保存定时配置到 UCI (用于断电保存)
-- ==========================================================
local function save_reboot_config_to_uci(enable, hh, mm, ss)
    log_info("save reboot config to uci")
    local cursor = uci_lib.cursor()
    -- 我们借用 system 配置文件，创建一个名为 'auto_reboot' 的节点
    cursor:set("system", "auto_reboot", "reboot")
    cursor:set("system", "auto_reboot", "enable", tostring(enable))
    cursor:set("system", "auto_reboot", "hh", tostring(hh))
    cursor:set("system", "auto_reboot", "mm", tostring(mm))
    cursor:set("system", "auto_reboot", "ss", tostring(ss))
    cursor:commit("system")
    os.execute("touch /tmp/misc_commit")
end


-- ==========================================================
-- 3. 修改：set_misc_config_values 函数
--    (这个函数在你的代码中被 methods["hilink"]["set_misc_config"] 调用)
-- ==========================================================
function set_misc_config_values(msg)
    log_info("Setting misc config: " .. cjson.encode(msg))

    -- 确保内存配置表已初始化
    if not misc_config then misc_config = {} end

    -- ============================================================
    -- 1. Nginx Config (Web Port, User, Password)
    -- ============================================================
    if msg.n_web_port or msg.s_web_user or msg.s_web_psw then
        local port = msg.n_web_port or misc_config.web_port
        local user = msg.s_web_user or misc_config.web_user
        local pass = msg.s_web_psw or misc_config.web_psw

        -- 只有当参数有实际意义时才调用设置
        set_nginx_config(port, user, pass)

        -- 更新内存缓存
        if msg.n_web_port then misc_config.web_port = port end
        if msg.s_web_user then misc_config.web_user = user end
        if msg.s_web_psw then misc_config.web_psw = pass end
    end

    -- ============================================================
    -- 2. System Config (Hostname, Timezone)
    -- ============================================================
    if msg.s_host_name or msg.n_ntp_utc then
        local hostname = msg.s_host_name or misc_config.host_name
        local utc_val = msg.n_ntp_utc or misc_config.ntp_utc

        set_system_config(hostname, utc_val)

        -- 更新内存缓存
        if msg.s_host_name then misc_config.host_name = hostname end
        if msg.n_ntp_utc then misc_config.ntp_utc = utc_val end
    end

    -- ============================================================
    -- 3. NTP Config (Enable, Server List)
    -- ============================================================
    -- 检测是否有 NTP 相关的参数 (开关 或 具体的URL key)
    local has_ntp_update = false
    if msg.n_ntp_sync_en then has_ntp_update = true end

    -- 检测是否存在 s_ntp_url[x] 格式的参数
    local url_params_exist = false
    for i = 0, 9 do -- 假设最多支持10个，或者按你页面实际数量写 3
        if msg["s_ntp_url[" .. i .. "]"] ~= nil then
            url_params_exist = true
            has_ntp_update = true
            break
        end
    end

    if has_ntp_update then
        local en = msg.n_ntp_sync_en or misc_config.ntp_sync_en
        local new_servers = {}

        if url_params_exist then
            -- A. 前端传来了新的 URL 列表：提取并重组
            for i = 0, 9 do
                local val = msg["s_ntp_url[" .. i .. "]"]
                -- 仅保留非空字符串
                if val and val ~= "" then
                    table.insert(new_servers, val)
                end
            end
        else
            -- B. 前端只改了开关，没传 URL：沿用旧配置
            new_servers = misc_config.ntp_url or {}
        end
        log_info("new_servers: " .. cjson.encode(new_servers))

        -- 写入 UCI
        set_ntp_config(en, new_servers)

        -- 关键：更新内存缓存中的 ntp_url 为标准的数组格式
        -- 这样下次 get 接口返回给前端的就是整洁的 ["a", "b"] 而不是散乱的 key
        misc_config.ntp_sync_en = en
        misc_config.ntp_url = new_servers
    end

    -- ============================================================
    -- 4. Update Other Memory Cache (通用兜底更新)
    -- ============================================================
    log_info("update other memory cache: " .. cjson.encode(msg))
    --{"n_timing_reset.mm":"0","file":"misc","n_timing_reset.hh":"5","n_timing_reset.enable":"1","n_timing_reset.ss":"0"}
    --解析 定时配置参数
    if msg["n_timing_reset.enable"] ~= nil then
        if msg["n_timing_reset.enable"] then misc_config.timing_reset.enable = tonumber(msg["n_timing_reset.enable"]) end
        if msg["n_timing_reset.hh"] then misc_config.timing_reset.hh = tonumber(msg["n_timing_reset.hh"]) end
        if msg["n_timing_reset.mm"] then misc_config.timing_reset.mm = tonumber(msg["n_timing_reset.mm"]) end
        if msg["n_timing_reset.ss"] then misc_config.timing_reset.ss = tonumber(msg["n_timing_reset.ss"]) end
        local en = msg["n_timing_reset.enable"] or 0
        local hh = msg["n_timing_reset.hh"] or 0
        local mm = msg["n_timing_reset.mm"] or 0
        local ss = msg["n_timing_reset.ss"] or 0

        -- B. 保存到 UCI (实现掉电保存)
        save_reboot_config_to_uci(en, hh, mm, ss)

        -- A. 应用到系统 Cron (实现功能)
        apply_cron_reboot(en, hh, mm)
    end


    return true
end

-- 计算 DHCP start 偏移量和 limit
local function calculate_dhcp_range(lan_ip, dhcp_start_ip, dhcp_end_ip)
    -- 解析 LAN IP 的前三段
    local lan_parts = {}
    for part in string.gmatch(lan_ip, "([^%.]+)") do
        table.insert(lan_parts, part)
    end

    if #lan_parts < 4 then
        log_error("Invalid LAN IP format: " .. lan_ip)
        return nil, nil
    end

    -- 解析 DHCP 起始 IP
    local start_parts = {}
    for part in string.gmatch(dhcp_start_ip, "([^%.]+)") do
        table.insert(start_parts, part)
    end

    -- 解析 DHCP 结束 IP
    local end_parts = {}
    for part in string.gmatch(dhcp_end_ip, "([^%.]+)") do
        table.insert(end_parts, part)
    end

    if #start_parts < 4 or #end_parts < 4 then
        log_error("Invalid DHCP IP format: start=" .. dhcp_start_ip .. ", end=" .. dhcp_end_ip)
        return nil, nil
    end

    -- 检查前三段是否匹配 LAN IP
    if lan_parts[1] ~= start_parts[1] or lan_parts[2] ~= start_parts[2] or lan_parts[3] ~= start_parts[3] or
        lan_parts[1] ~= end_parts[1] or lan_parts[2] ~= end_parts[2] or lan_parts[3] ~= end_parts[3] then
        log_error("DHCP IP range must be in the same subnet as LAN IP")
        return nil, nil
    end

    -- 计算 start 偏移量 (相对于 LAN IP 的第四段)
    local start_offset = tonumber(start_parts[4])
    local end_offset = tonumber(end_parts[4])

    if not start_offset or not end_offset then
        log_error("Invalid DHCP IP offset values")
        return nil, nil
    end

    -- 计算 limit (结束IP - 起始IP + 1)
    local limit = end_offset - start_offset + 1

    if limit <= 0 then
        log_error("Invalid DHCP range: start=" .. start_offset .. ", end=" .. end_offset)
        return nil, nil
    end

    log_info("Calculated DHCP range: start=" .. start_offset .. ", limit=" .. limit)
    return start_offset, limit
end

local function set_network_config_values(args)
    local cursor = uci_lib.cursor()
    log_info("Setting network config: " .. cjson.encode(args))

    -- 处理 WAN 参数
    local eth_mode = args["n_eth0.ip_mode"] and tonumber(args["n_eth0.ip_mode"])
    local eth_ip = args["s_eth0.sip"]
    local eth_mask = args["s_eth0.mip"]
    local eth_gw = args["s_eth0.gip"]
    local eth_dns_mode = args["n_eth0.dns_mode"] and tonumber(args["n_eth0.dns_mode"])
    local eth_dns1 = args["s_eth0.dns_ip[0]"]
    local eth_dns2 = args["s_eth0.dns_ip[1]"]

    -- 设置 WAN 接口配置
    if eth_mode ~= nil then
        if eth_mode == 1 then
            cursor:set("network", "wan", "proto", "dhcp")
            log_info("Set network.wan.proto = dhcp")
        else
            cursor:set("network", "wan", "proto", "static")
            log_info("Set network.wan.proto = static")
            if eth_ip then
                cursor:set("network", "wan", "ipaddr", eth_ip)
                log_info("Set network.wan.ipaddr = " .. eth_ip)
            end
            if eth_mask then
                cursor:set("network", "wan", "netmask", eth_mask)
                log_info("Set network.wan.netmask = " .. eth_mask)
            end
            if eth_gw then
                cursor:set("network", "wan", "gateway", eth_gw)
                log_info("Set network.wan.gateway = " .. eth_gw)
            end
        end

        -- 设置 DNS 模式
        if eth_dns_mode ~= nil then
            cursor:set("network", "wan", "peerdns", eth_dns_mode)
            log_info("Set network.wan.peerdns = " .. eth_dns_mode)
        end

        -- 设置 DNS 服务器（仅 static 模式）
        if eth_mode == 0 then
            local dns_list = {}
            if eth_dns1 and eth_dns1 ~= "" then
                table.insert(dns_list, eth_dns1)
            end
            if eth_dns2 and eth_dns2 ~= "" then
                table.insert(dns_list, eth_dns2)
            end
            if #dns_list > 0 then
                cursor:set("network", "wan", "dns", dns_list)
                log_info("Set network.wan.dns = " .. table.concat(dns_list, " "))
            end
        end
    end
    -- Wi-Fi STA 配置
    local wifi_enable = args["n_wifi.enable"]
    local wifi_ssid = args["s_wifi.ssid"]
    local wifi_password = args["s_wifi.password"]
    local wifi_encryption = args["n_wifi.encryption"]
    local wifi_ip_mode = args["n_wifi.ip_mode"] and tonumber(args["n_wifi.ip_mode"])
    local wifi_ip = args["s_wifi.ip"]
    local wifi_netmask = args["s_wifi.netmask"]
    local wifi_gw = args["s_wifi.gw"]
    local wifi_dns_mode = args["n_wifi.dns_mode"] and tonumber(args["n_wifi.dns_mode"])
    local wifi_dns1 = args["s_wifi.dns_ip[0]"]
    local wifi_dns2 = args["s_wifi.dns_ip[1]"]

    if wifi_enable ~= nil or wifi_ssid or wifi_password or wifi_encryption then
        -- 查找已有的 STA 接口（device=radio0, mode=sta）
        local sta_section = nil
        cursor:foreach("wireless", "wifi-iface", function(section)
            if section.device == "radio0" and section.mode == "sta" then
                sta_section = section[".name"]
                return false
            end
        end)

        -- 不存在则创建新的 STA 接口
        if not sta_section then
            sta_section = cursor:add("wireless", "wifi-iface")
            cursor:set("wireless", sta_section, "device", "radio0")
            cursor:set("wireless", sta_section, "mode", "sta")
            log_info("Created new wifi-iface for STA: " .. sta_section)
        end

        -- 设置 STA 参数
        if wifi_ssid then
            cursor:set("wireless", sta_section, "ssid", wifi_ssid)
            log_info("Set wireless." .. sta_section .. ".ssid = " .. wifi_ssid)
        end
        if wifi_password then
            cursor:set("wireless", sta_section, "key", wifi_password)
            log_info("Set wireless." .. sta_section .. ".key = " .. wifi_password)
        end
        if wifi_encryption ~= nil then
            local enc_str = "none"
            local enc_num = tonumber(wifi_encryption)
            if enc_num == 0 then
                enc_str = "none"
            elseif enc_num == 1 then
                enc_str = "psk2"
            elseif enc_num == 2 then
                enc_str = "sae"
            end
            cursor:set("wireless", sta_section, "encryption", enc_str)
            log_info("Set wireless." .. sta_section .. ".encryption = " .. enc_str)
        end

        cursor:set("wireless", sta_section, "network", "wwan")
        log_info("Set wireless." .. sta_section .. ".network = wwan")

        if wifi_enable ~= nil then
            local disabled = (tonumber(wifi_enable) == 1) and "0" or "1"
            cursor:set("wireless", sta_section, "disabled", disabled)
            log_info("Set wireless." .. sta_section .. ".disabled = " .. disabled)
        end

        cursor:commit("wireless")
        os.execute("touch /tmp/wifi_commit")
        log_info("Committed wireless configuration")
    end

    if wifi_ip_mode ~= nil or wifi_ip or wifi_netmask or wifi_gw or wifi_dns_mode ~= nil or wifi_dns1 or wifi_dns2 then
        if wifi_ip_mode ~= nil then
            if wifi_ip_mode == 1 then
                cursor:set("network", "wwan", "proto", "dhcp")
                log_info("Set network.wwan.proto = dhcp")
            else
                cursor:set("network", "wwan", "proto", "static")
                log_info("Set network.wwan.proto = static")
                if wifi_ip then
                    cursor:set("network", "wwan", "ipaddr", wifi_ip)
                    log_info("Set network.wwan.ipaddr = " .. wifi_ip)
                end
                if wifi_netmask then
                    cursor:set("network", "wwan", "netmask", wifi_netmask)
                    log_info("Set network.wwan.netmask = " .. wifi_netmask)
                end
                if wifi_gw then
                    cursor:set("network", "wwan", "gateway", wifi_gw)
                    log_info("Set network.wwan.gateway = " .. wifi_gw)
                end
            end
        end

        if wifi_dns_mode ~= nil then
            cursor:set("network", "wwan", "peerdns", wifi_dns_mode)
            log_info("Set network.wwan.peerdns = " .. wifi_dns_mode)

            cursor:delete("network", "wwan", "dns")
            cursor:delete("network", "wwan", "_dns")

            local dns_list = {}
            if wifi_dns1 and wifi_dns1 ~= "" then
                table.insert(dns_list, wifi_dns1)
            end
            if wifi_dns2 and wifi_dns2 ~= "" then
                table.insert(dns_list, wifi_dns2)
            end

            if #dns_list > 0 then
                if wifi_dns_mode == 1 then
                    cursor:set("network", "wwan", "_dns", dns_list)
                    log_info("Set network.wwan._dns = " .. table.concat(dns_list, " "))
                else
                    cursor:set("network", "wwan", "dns", dns_list)
                    log_info("Set network.wwan.dns = " .. table.concat(dns_list, " "))
                end
            end
        end
    end

    -- 处理 LTE 参数
    local lte_simnum = args["n_cell.sim_switch"] and tonumber(args["n_cell.sim_switch"])
    local lte_apn = args["s_cell.apn.addr"]
    local lte_user = args["s_cell.apn.user"]
    local lte_pswd = args["s_cell.apn.pswd"]
    local lte_auth = args["n_cell.apn.auth"] and tonumber(args["n_cell.apn.auth"])
    local lte_dns_mode = args["n_cell.dns_mode"] and tonumber(args["n_cell.dns_mode"])
    local lte_dns = args["s_cell.dns_ip[0]"]
    local lte_sdns = args["s_cell.dns_ip[1]"]
    local internal_forward_disable = args["n_cell.internal_forward_disable"] and
        tonumber(args["n_cell.internal_forward_disable"])
    local external_forward_disable = args["n_cell.external_forward_disable"] and
        tonumber(args["n_cell.external_forward_disable"])

    if internal_forward_disable ~= nil then
        cursor:set("network", "lte", "internal_forward_disable", internal_forward_disable)
        log_info("Set network.lte.internal_forward_disable = " .. internal_forward_disable)
    end

    if external_forward_disable ~= nil then
        cursor:set("network", "lte", "external_forward_disable", external_forward_disable)
        log_info("Set network.lte.external_forward_disable = " .. external_forward_disable)
    end

    -- 设置 LTE 接口配置
    if lte_simnum ~= nil then
        cursor:set("network", "lte", "modem_simnum", lte_simnum)
        log_info("Set network.lte.modem_simnum = " .. lte_simnum)
    end
    if lte_apn then
        cursor:set("network", "lte", "modem_apn", lte_apn)
        log_info("Set network.lte.modem_apn = " .. lte_apn)
    end
    if lte_user then
        cursor:set("network", "lte", "modem_user", lte_user)
        log_info("Set network.lte.modem_user = " .. lte_user)
    end
    if lte_pswd then
        cursor:set("network", "lte", "modem_passwd", lte_pswd)
        log_info("Set network.lte.modem_passwd = " .. lte_pswd)
    end
    if lte_auth ~= nil then
        cursor:set("network", "lte", "modem_auth", lte_auth)
        log_info("Set network.lte.modem_auth = " .. lte_auth)
    end

    -- 处理 LTE LAN 转发控制
    -- local lte_allow_forward = args["n_cell.allow_lan_forward"]
    -- if lte_allow_forward ~= nil then
    --     cursor:set("network", "lte", "allow_lan_forward", tostring(lte_allow_forward))
    --     log_info("Set network.lte.allow_lan_forward = " .. lte_allow_forward)
    -- end

    -- 设置 LTE DNS
    if lte_dns_mode ~= nil then
        cursor:set("network", "lte", "peerdns", lte_dns_mode)
        log_info("Set network.lte.peerdns = " .. lte_dns_mode)

        cursor:delete("network", "lte", "dns")
        cursor:delete("network", "lte", "_dns")

        if lte_dns_mode == 1 then
            -- 自动获取 DNS
            local dns_list = {}
            if lte_dns and lte_dns ~= "" then
                table.insert(dns_list, lte_dns)
            end
            if lte_sdns and lte_sdns ~= "" then
                table.insert(dns_list, lte_sdns)
            end
            if #dns_list > 0 then
                cursor:set("network", "lte", "_dns", dns_list)
                log_info("Set network.lte._dns = " .. table.concat(dns_list, " "))
            end
        else
            -- 手动 DNS
            local dns_list = {}
            if lte_dns and lte_dns ~= "" then
                table.insert(dns_list, lte_dns)
            end
            if lte_sdns and lte_sdns ~= "" then
                table.insert(dns_list, lte_sdns)
            end
            if #dns_list > 0 then
                cursor:set("network", "lte", "dns", dns_list)
                log_info("Set network.lte.dns = " .. table.concat(dns_list, " "))
            end
        end
    end

    -- 处理 MWAN3 参数
    local net_select = args["n_net_select"] and tonumber(args["n_net_select"])
    local keepalive_period = args["n_keepalive_period"] and tonumber(args["n_keepalive_period"])
    local keepalive_addr1 = args["s_keepalive_addr[0]"]
    local keepalive_addr2 = args["s_keepalive_addr[1]"]

    -- 设置 MWAN3 配置
    if net_select ~= nil then
        cursor:set("mwan3", "globals", "net_select", net_select)
        log_info("Set mwan3.globals.net_select = " .. net_select)
    end
    if keepalive_period ~= nil then
        cursor:set("mwan3", "globals", "keepalive_period", keepalive_period)
        log_info("Set mwan3.globals.keepalive_period = " .. keepalive_period)
    end
    if keepalive_addr1 then
        cursor:set("mwan3", "globals", "keepalive_ip1", keepalive_addr1)
        log_info("Set mwan3.globals.keepalive_ip1 = " .. keepalive_addr1)
    end
    if keepalive_addr2 then
        cursor:set("mwan3", "globals", "keepalive_ip2", keepalive_addr2)
        log_info("Set mwan3.globals.keepalive_ip2 = " .. keepalive_addr2)
    end

    -- 处理 LAN 和 DHCP 参数
    local lan_ip = args["s_lan.ip"]
    local lan_netmask = args["s_lan.netmask"]
    local dhcp_enable = args["n_lan.dhcp_enable"]
    if dhcp_enable ~= nil then
        dhcp_enable = tonumber(dhcp_enable)
    end
    local dhcp_start_ip = args["s_lan.dhcp_start"]
    local dhcp_end_ip = args["s_lan.dhcp_end"]
    local dhcp_lease = args["n_lan.dhcp_lease"]

    -- 设置 LAN 接口配置
    if lan_ip or lan_netmask then
        if lan_ip then
            cursor:set("network", "lan", "ipaddr", lan_ip)
            log_info("Set network.lan.ipaddr = " .. lan_ip)
        end
        if lan_netmask then
            cursor:set("network", "lan", "netmask", lan_netmask)
            log_info("Set network.lan.netmask = " .. lan_netmask)
        end
    end

    -- 设置 DHCP 配置
    if dhcp_enable ~= nil or dhcp_start_ip or dhcp_end_ip or dhcp_lease then
        -- DHCP 开关设置
        if dhcp_enable ~= nil then
            local ignore = (dhcp_enable == 1) and "0" or "1"
            cursor:set("dhcp", "lan", "ignore", ignore)
            log_info("Set dhcp.lan.ignore = " .. ignore)
            os.execute("touch /tmp/dhcp_restart")
        end

        -- DHCP 租期设置
        if dhcp_lease then
            local leasetime = tostring(dhcp_lease) .. "h"
            cursor:set("dhcp", "lan", "leasetime", leasetime)
            log_info("Set dhcp.lan.leasetime = " .. leasetime)
            os.execute("touch /tmp/dhcp_restart")
        end

        -- 计算 DHCP start 和 limit
        if dhcp_start_ip and dhcp_end_ip and lan_ip then
            local start_offset, limit = calculate_dhcp_range(lan_ip, dhcp_start_ip, dhcp_end_ip)
            if start_offset and limit then
                cursor:set("dhcp", "lan", "start", tostring(start_offset))
                cursor:set("dhcp", "lan", "limit", tostring(limit))
                log_info("Set dhcp.lan.start = " .. start_offset .. ", limit = " .. limit)
                os.execute("touch /tmp/dhcp_restart")
            end
        end
    end

    -- 处理 AP 参数
    local ap_enable = args["n_ap.enable"]
    local ap_ssid = args["s_ap.ssid"]
    local ap_password = args["s_ap.password"]
    local ap_encryption = args["n_ap.encryption"]
    local ap_channel = args["n_ap.channel"]
    local ap_hidden = args["n_ap.hidden"]

    if ap_enable ~= nil or ap_ssid or ap_password or ap_encryption or ap_channel or ap_hidden then
        -- 查找现有的AP配置
        local ap_iface_name = nil
        cursor:foreach("wireless", "wifi-iface", function(section)
            if section.mode == "ap" and section.network == "lan" then
                ap_iface_name = section[".name"]
            end
        end)

        -- 如果没有找到AP配置，创建一个新的
        if not ap_iface_name then
            ap_iface_name = cursor:add("wireless", "wifi-iface")
            cursor:set("wireless", ap_iface_name, "mode", "ap")
            cursor:set("wireless", ap_iface_name, "network", "lan")
            log_info("Created new wifi-iface for AP: " .. ap_iface_name)
        end

        -- 设置AP参数
        if ap_ssid then
            cursor:set("wireless", ap_iface_name, "ssid", ap_ssid)
            log_info("Set wireless." .. ap_iface_name .. ".ssid = " .. ap_ssid)
        end

        if ap_password then
            cursor:set("wireless", ap_iface_name, "key", ap_password)
            log_info("Set wireless." .. ap_iface_name .. ".key = " .. ap_password)
        end

        if ap_encryption then
            local enc_str = "none"
            local enc_num = tonumber(ap_encryption)
            if enc_num == 0 then
                enc_str = "none"
            elseif enc_num == 1 then
                enc_str = "psk2"
            elseif enc_num == 2 then
                enc_str = "psk-mixed"
            end
            cursor:set("wireless", ap_iface_name, "encryption", enc_str)
            log_info("Set wireless." .. ap_iface_name .. ".encryption = " .. enc_str)
        end

        if ap_hidden then
            local hidden_val = (ap_hidden == "1") and "1" or "0"
            cursor:set("wireless", ap_iface_name, "hidden", hidden_val)
            log_info("Set wireless." .. ap_iface_name .. ".hidden = " .. hidden_val)
        end

        -- 设置信道（需要找到对应的wifi-device）
        if ap_channel then
            cursor:foreach("wireless", "wifi-device", function(section)
                local device_name = section[".name"]
                cursor:set("wireless", device_name, "channel", ap_channel)
                log_info("Set wireless." .. device_name .. ".channel = " .. ap_channel)
            end)
        end

        -- 设置 AP 启用状态的改写建议
        if ap_enable then
            local disabled = (ap_enable == "1") and "0" or "1"

            -- 1. 确保物理设备总是处于启用状态 (或者至少在有STA或AP启用时把它置为0)
            cursor:foreach("wireless", "wifi-device", function(section)
                cursor:set("wireless", section[".name"], "disabled", "0")
            end)

            -- 2. 仅更改 mode 为 'ap' 的接口的 disabled 状态
            cursor:foreach("wireless", "wifi-iface", function(section)
                if section.mode == "ap" then
                    cursor:set("wireless", section[".name"], "disabled", disabled)
                    log_info("Set wireless AP interface " .. section[".name"] .. " disabled = " .. disabled)
                end
            end)
        end

        cursor:commit("wireless")
        os.execute("touch /tmp/wifi_commit")
        log_info("Committed wireless configuration")
    end

    -- 提交配置
    cursor:commit("network")
    os.execute("touch /tmp/network_commit")
    cursor:commit("mwan3")
    log_info("Committed network and mwan3 configurations")

    if dhcp_enable ~= nil or dhcp_start_ip or dhcp_end_ip or dhcp_lease then
        cursor:commit("dhcp")
        os.execute("touch /tmp/dhcp_restart")
        log_info("Committed dhcp configuration")
    end

    -- 处理其他网络参数（保持原有逻辑）
    for k, v in pairs(args) do
        -- 跳过已经处理的网络参数
        if k ~= "s_lan.ip" and k ~= "s_lan.netmask" and k ~= "n_lan.dhcp_enable" and
            k ~= "s_lan.dhcp_start" and k ~= "s_lan.dhcp_end" and k ~= "n_lan.dhcp_lease" and
            k ~= "n_eth0.ip_mode" and k ~= "s_eth0.sip" and k ~= "s_eth0.mip" and k ~= "s_eth0.gip" and
            k ~= "n_eth0.dns_mode" and k ~= "s_eth0.dns_ip[0]" and k ~= "s_eth0.dns_ip[1]" and
            k ~= "n_cell.sim_switch" and k ~= "s_cell.apn.addr" and k ~= "s_cell.apn.user" and
            k ~= "n_ap.enable" and k ~= "s_ap.ssid" and k ~= "s_ap.password" and
            k ~= "n_ap.encryption" and k ~= "n_ap.channel" and k ~= "n_ap.hidden" and
            k ~= "n_wifi.enable" and k ~= "s_wifi.ssid" and k ~= "s_wifi.password" and
            k ~= "n_wifi.encryption" and k ~= "n_wifi.ip_mode" and k ~= "s_wifi.ip" and
            k ~= "s_wifi.netmask" and k ~= "s_wifi.gw" and k ~= "n_wifi.dns_mode" and
            k ~= "s_wifi.dns_ip[0]" and k ~= "s_wifi.dns_ip[1]" and
            k ~= "s_cell.apn.pswd" and k ~= "n_cell.apn.auth" and k ~= "n_cell.dns_mode" and
            k ~= "s_cell.dns_ip[0]" and k ~= "s_cell.dns_ip[1]" and
            k ~= "n_net_select" and k ~= "n_keepalive_period" and
            k ~= "s_keepalive_addr[0]" and k ~= "s_keepalive_addr[1]" then
            local key = string.match(k, "[ns]_(.+)")
            if key then
                if string.find(key, "%.") then
                    local parts = {}
                    for part in string.gmatch(key, "[^%.]+") do
                        table.insert(parts, part)
                    end

                    local target = network_config
                    for i = 1, #parts - 1 do
                        if target[parts[i]] then
                            target = target[parts[i]]
                        end
                    end
                    target[parts[#parts]] = tonumber(v) or v
                else
                    network_config[key] = tonumber(v) or v
                end
                log_info("network." .. key .. " = " .. tostring(v))
            end
        end
    end
    return true
end

local function set_edge_config_values(args)
    for k, v in pairs(args) do
        if k == "n_all_en" then
            edge_config.all_en = tonumber(v) or 0
        elseif k == "n_refresh_frequency" then
            edge_config.refresh_frequency = tonumber(v) or 100
        elseif k == "n_calc_period" then
            edge_config.calc_period = tonumber(v) or 100
        elseif k == "n_poll_interval" then
            edge_config.poll_interval = tonumber(v) or 100
        end
    end
    -- 将 edge enable 写入 UCI实现持久化
    local cursor = uci_lib.cursor()
    cursor:set("edge", "@edge[0]", "enable", tostring(edge_config.all_en))
    cursor:commit("edge")
    os.execute("touch /tmp/edge_commit")
    log_info("Edge config saved to UCI: all_en=" .. tostring(edge_config.all_en))
    return true
end

local function check_firmware_validity(firmware)
    local fw_path = firmware or "/tmp/firmware.bin"

    -- 1. 检查固件文件是否存在
    local f = io.open(fw_path, "r")
    if not f then
        return false
    end
    f:close()

    -- 2. 检查固件的签名 (使用 sysupgrade -T)
    -- sysupgrade -T 返回 0 表示合法
    local ret = os.execute("sysupgrade -T " .. fw_path .. " >/dev/null 2>&1")
    if ret == 0 then
        return true
    else
        return false
    end
end

-- ==========================================================
-- 初始化 ubus 连接和事件循环
-- ==========================================================

uloop.init()

local conn = ubus.connect()
if not conn then
    log_error("Failed to connect to ubus")
    os.exit(1)
end

-- ==========================================================
-- Helper Functions for WiFi
-- ==========================================================

local function parse_dhcp_leases()
    local leases = {}
    local f = io.open("/tmp/dhcp.leases", "r")
    if not f then return leases end

    for line in f:lines() do
        -- Format: timestamp mac ip hostname mac_id
        local ts, mac, ip, hostname = string.match(line, "(%d+)%s+(%S+)%s+(%S+)%s+(%S+)")
        if mac and ip then
            leases[mac] = {
                ip = ip,
                hostname = (hostname == "*") and "Unknown" or hostname,
                expires = tonumber(ts)
            }
        end
    end
    f:close()
    return leases
end

local function parse_arp_table()
    local arp = {}
    local f = io.open("/proc/net/arp", "r")
    if not f then return arp end

    -- Skip header
    f:read()

    for line in f:lines() do
        -- IP address       HW type     Flags       HW address            Mask     Device
        local ip, mac = string.match(line, "(%d+%.%d+%.%d+%.%d+)%s+%S+%s+%S+%s+(%S+)")
        if ip and mac then
            arp[mac] = ip
        end
    end
    f:close()
    return arp
end

-- 根据模式 (ap 或 sta) 动态解析 iwinfo 输出获取物理接口名称 (增加 30s 缓存)
local wifi_iface_cache = { ap = nil, sta = nil, last_update = 0 }
local function get_wifi_ifname_by_mode(target_type)
    local now = os.time()
    if wifi_iface_cache[target_type] and (now - wifi_iface_cache.last_update < 60) then
        return wifi_iface_cache[target_type]
    end

    local target_mode = (target_type == "ap") and "Master" or "Client"
    local f = io.popen("iwinfo 2>/dev/null")
    if not f then return nil end

    local content = f:read("*a")
    f:close()

    local current_iface = nil
    for line in string.gmatch(content, "[^\n]+") do
        local iface = string.match(line, "^([%w%-%.]+)%s+ESSID:")
        if iface then
            current_iface = iface
        end

        local mode = string.match(line, "Mode: (%a+)")
        if mode and current_iface then
            if mode == target_mode then
                wifi_iface_cache[target_type] = current_iface
                wifi_iface_cache.last_update = now
                return current_iface
            end
        end
    end
    return nil
end

-- ==========================================================
-- 定义 ubus 方法
-- ==========================================================


local function collect_network_status()
    local net_status = {
        netdev = get_current_run_net(),
        eth = {
            link_sta = 0,
            ip_mode = 0,
            ip = "",
            dns = "",
            sdns = "",
            netmask = ""
        },
        lte = {
            ver = "",
            iccid = "",
            imei = "",
            iccid_0 = "",
            imsi_0 = "",
            csq = 0,
            mode = "",
            oper = "",
            sim = 1,
            cimi = "",
            lte_sta = "Disconnected",
            lte_ip = "",
            lte_netmask = "",
            lte_dns = "",
            lte_sdns = "",
            internal_forward_disable = 1,
            external_forward_disable = 0
        },
        wifi_sta = {
            status = "Disconnected",
            ip = "",
            ssid = "",
            signal = 0,
            rate = ""
        },
        wifi_ap = {
            clients = {}
        }
    }

    local cursor = uci_lib.cursor()

    -- 1. ETH IP Mode
    local wan_proto = cursor:get("network", "wan", "proto")
    if wan_proto == "dhcp" then
        net_status.eth.ip_mode = 1
    else
        net_status.eth.ip_mode = 0
    end

    -- 2. Network Params via Ubus (WAN)
    local wan_status = conn:call("network.interface.wan", "status", {})
    if wan_status then
        if wan_status["ipv4-address"] and #wan_status["ipv4-address"] > 0 then
            net_status.eth.ip = wan_status["ipv4-address"][1].address
            local mask = wan_status["ipv4-address"][1].mask
            if type(mask) == "number" then
                local m = math.floor(2 ^ (32) - 2 ^ (32 - mask))
                net_status.eth.netmask = string.format("%d.%d.%d.%d",
                    math.floor(m / 2 ^ 24) % 256,
                    math.floor(m / 2 ^ 16) % 256,
                    math.floor(m / 2 ^ 8) % 256,
                    m % 256)
            else
                net_status.eth.netmask = mask
            end
        end
        if wan_status["dns-server"] then
            net_status.eth.dns = wan_status["dns-server"][1] or ""
            net_status.eth.sdns = wan_status["dns-server"][2] or ""
        end
    end

    -- 3. LTE Info from /tmp/modem_info.json
    --net_status.lte.sim --改为表示sim状态 1 表示ready 其他值暂时表示Not ready
    net_status.lte.sim = "0"
    net_status.lte.lte_sta = "Disconnected"
    net_status.lte.lte_ip = ""

    local modem_info_str = read_file_content("/tmp/modem_info.json")
    local modem_status = read_file_content("/tmp/modem_status.json")

    local use_sim = 0 --默认外置
    if modem_status then
        local ok, status = pcall(cjson.decode, modem_status)
        if ok then
            use_sim = status.sim_source == "external" and 0 or 1
        end
    end

    if modem_info_str then
        --log_info("modem_info_str: " .. modem_info_str)
        local ok, info = pcall(cjson.decode, modem_info_str)

        if ok then
            --log_info("info: " .. cjson.encode(info))
            local is_ready = (info.sim_status == "ready")
            local reg_status = (info.status:find("Registered"))
            net_status.lte.sim = info.sim_status == "ready" and "1" or "0"
            net_status.lte.imei = info.imei
            net_status.lte.use_sim = use_sim


            if info.local_ip ~= "0.0.0.0" then
                net_status.lte.lte_ip = info.local_ip
            end
            net_status.lte.iccid = info.iccid
            net_status.lte.cimi = info.imsi
            net_status.lte.iccid_0 = info.iccid_0
            net_status.lte.imsi_0 = info.imsi_0

            if is_ready then
                net_status.lte.mode = info.network_type
                net_status.lte.oper = info.sim_operator
            else
                net_status.lte.mode = "N/A"
                net_status.lte.oper = "N/A"
                net_status.lte.csq = "N/A"
                if net_status.netdev == "LTE" then
                    net_status.netdev = "None"
                end
            end

            --net_status.lte.lte_sta = info.connection_status

            --log_info("net_status: " .. cjson.encode(net_status))

            if is_ready and info.signal then
                local dbm = tonumber(string.match(info.signal, "([-%d]+)"))
                if dbm then
                    local csq = math.floor((dbm + 113) / 2)
                    if csq < 0 then csq = 0 end
                    if csq > 31 then csq = 31 end
                    net_status.lte.csq = csq
                end
            end
            -- 4. LTE Params via Ubus (Fill gaps)
            if is_ready and reg_status then
                local lte_status = conn:call("network.interface.lte", "status", {})
                if lte_status then
                    if lte_status["ipv4-address"] and #lte_status["ipv4-address"] > 0 then
                        if net_status.lte.lte_ip == "" then
                            net_status.lte.lte_ip = lte_status["ipv4-address"][1].address
                        end
                        local mask = lte_status["ipv4-address"][1].mask
                        if type(mask) == "number" then
                            local m = math.floor(2 ^ (32) - 2 ^ (32 - mask))
                            net_status.lte.lte_netmask = string.format("%d.%d.%d.%d",
                                math.floor(m / 2 ^ 24) % 256,
                                math.floor(m / 2 ^ 16) % 256,
                                math.floor(m / 2 ^ 8) % 256,
                                m % 256)
                        else
                            net_status.lte.lte_netmask = mask
                        end
                    end
                    if lte_status["dns-server"] then
                        net_status.lte.lte_dns = lte_status["dns-server"][1] or ""
                        net_status.lte.lte_sdns = lte_status["dns-server"][2] or ""
                    end
                    local lte_online = check_is_online("lte")
                    if lte_online then
                        net_status.lte.lte_sta = "Connected"
                    end
                end
            else
                if net_status.netdev == "LTE" then
                    net_status.netdev = "None"
                end
            end
        else
            if net_status.netdev == "LTE" then
                net_status.netdev = "None"
            end
        end
    end

    -- 5. SIM Num
    --local sim_num = cursor:get("network", "lte", "modem_simnum")
    --net_status.lte.sim = sim_num or 1

    -- 6. Connection Status via mwan3
    local wan_online = check_is_online("wan")
    if wan_online then
        net_status.eth.link_sta = 1
    end
    --[[
    local f = io.popen("mwan3 status")
    if f then
        local mwan3_out = f:read("*a")
        f:close()
        if mwan3_out then
            if string.find(mwan3_out, "wan is online") then
                net_status.eth.link_sta = 1
            end
            if string.find(mwan3_out, "lte is online") then
                net_status.lte.lte_sta = "Connected"
            end
        end
    end
    ]] --

    -- ==========================================================
    -- WiFi STA Information
    -- ==========================================================
    --获取配置 查看是否开启
    local sta_status = conn:call("network.interface." .. NETWORK_STA_LOGICAL, "status", {})
    if sta_status and sta_status.up then
        net_status.wifi_sta.status = "Connected"
        if sta_status["ipv4-address"] and #sta_status["ipv4-address"] > 0 then
            net_status.wifi_sta.ip = sta_status["ipv4-address"][1].address
        end
    else
        net_status.wifi_sta.status = "Disconnected"
    end

    if net_status.wifi_sta.status == "Connected" then
        -- Get physical info (Signal, Rate)
        local WIFI_STA_IFACE = get_wifi_ifname_by_mode("sta")
        local f = io.popen("iwinfo " .. WIFI_STA_IFACE .. " assolist 2>/dev/null")
        if f then
            local content = f:read("*a")
            f:close()
            if content then
                -- Match signal: "Signal: -65 dBm"
                --local signal = string.match(content, "Signal:%s*([-%d]+)%s*dBm")
                --if signal then
                --    net_status.wifi_sta.signal = tonumber(signal)
                --end
                local signal = string.match(content, "([-%d]+)%s*dBm")
                if signal then
                    net_status.wifi_sta.signal = tonumber(signal)
                end

                -- Match RX/TX Rate: "RX: 72.2 MBit/s", "TX: 72.2 MBit/s"
                -- Or combined output depending on iwinfo version/driver
                -- Trying to capture the whole lines or just the rates
                local rx_rate = string.match(content, "RX:%s*([%d%.]+%s*M?Bit/s)")
                local tx_rate = string.match(content, "TX:%s*([%d%.]+%s*M?Bit/s)")

                if rx_rate and tx_rate then
                    net_status.wifi_sta.rate = "RX: " .. rx_rate .. " / TX: " .. tx_rate
                end
            end
        end
    end

    -- ==========================================================
    -- WiFi AP Client List
    -- ==========================================================
    local dhcp_leases = parse_dhcp_leases()
    local arp_table = parse_arp_table()
    local clients = {}

    local WIFI_AP_IFACE = get_wifi_ifname_by_mode("ap")

    if WIFI_AP_IFACE ~= nil then
        local f_ap = io.popen("iwinfo " .. WIFI_AP_IFACE .. " assolist 2>/dev/null")
        if f_ap then
            local current_mac = nil
            local current_client = {}

            for line in f_ap:lines() do
                -- MAC Address line: "00:11:22:33:44:55  -70 dBm / -90 dBm (SNR 20)  120 ms remaining"
                -- OR simply "00:11:22:33:44:55" at start of line
                local mac = string.match(line, "^(%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)")

                if mac then
                    -- Push previous client if exists
                    if current_mac then
                        table.insert(clients, current_client)
                    end

                    current_mac = mac
                    current_client = {
                        mac = mac,
                        signal = 0,
                        rx_rate = "-",
                        tx_rate = "-"
                    }

                    -- Attempt to parse signal on same line
                    local signal = string.match(line, "([-%d]+)%s*dBm")
                    if signal then current_client.signal = tonumber(signal) end
                elseif current_mac then
                    -- Parse details for current mac
                    -- RX: 6.0 MBit/s -> 6.0 MBit/s
                    local rx = string.match(line, "RX:%s*([%d%.]+%s*M?Bit/s)")
                    if rx then current_client.rx_rate = rx end

                    local tx = string.match(line, "TX:%s*([%d%.]+%s*M?Bit/s)")
                    if tx then current_client.tx_rate = tx end

                    -- Sometimes signal is on a separate line
                    local signal = string.match(line, "Signal:%s*([-%d]+)%s*dBm")
                    if signal then current_client.signal = tonumber(signal) end
                end
            end
            -- Add last client
            if current_mac then
                table.insert(clients, current_client)
            end
            f_ap:close()
        end
    end

    -- Enrich data
    local now = os.time()
    for _, client in ipairs(clients) do
        local mac = client.mac:lower()
        local lease = dhcp_leases[mac]

        if lease then
            client.ip = lease.ip
            client.hostname = lease.hostname
            client.lease_remaining = lease.expires - now
        else
            -- Fallback to ARP
            client.ip = arp_table[mac] or "-"
            client.hostname = "Unknown"
            -- Mark as Static or Unknown
            if client.ip ~= "-" then
                client.lease_remaining = "Static"
            else
                client.lease_remaining = -1
            end
        end

        -- Format rates
        client.rates = "RX: " .. client.rx_rate .. " / TX: " .. client.tx_rate
    end

    net_status.wifi_ap.clients = clients

    --log_info("finally netdev : " .. net_status.netdev)

    return net_status
end

local function reply(req, data)
    conn:reply(req, data or {})
end

local function get_system_slave_data()
    local ts = os.time()
    local local_time = os.date("%Y-%m-%d %H:%M:%S", ts)
    local utc_time = os.date("!%Y-%m-%d %H:%M:%S", ts)
    local ts_ms = tostring(ts) .. "000"

    local mac = get_system_mac() or ""
    local sn = status_data.sn or get_system_sn() or ""
    local ver = status_data.soft_ver or "V1.0.0"
    local model = product_name or "HLK-N7X0"

    local imei = ""
    local iccid = ""
    local iccid_0 = ""
    local imsi_0 = ""
    local csq = 0
    local modem_info_str = read_file_content("/tmp/modem_info.json")
    if modem_info_str then
        local ok, info = pcall(cjson.decode, modem_info_str)
        if ok then
            imei = info.imei or ""
            iccid = info.iccid or ""
            iccid_0 = info.iccid_0 or ""
            imsi_0 = info.imsi_0 or ""

            if info.signal then
                local dbm = tonumber(string.match(info.signal, "([-%d]+)"))
                if dbm then
                    csq = math.floor((dbm + 113) / 2)
                    if csq < 0 then csq = 0 end
                    if csq > 31 then csq = 31 end
                end
            end
        end
    end

    return {
        ["sys_local_time"] = tostring(local_time),
        ["sys_timestamp"] = tostring(ts),
        ["sys_timestamp_ms"] = ts_ms,
        ["sys_mac"] = string.upper(tostring(mac)),
        ["sys_imei"] = tostring(imei),
        ["sys_sn"] = tostring(sn),
        ["sys_iccid"] = tostring(iccid),
        ["sys_ver"] = tostring(ver),
        ["sys_csq"] = tostring(csq),
        ["sys_utc_time"] = tostring(utc_time),
        ["sys_model"] = tostring(model)
    }
end

local function blink_led()
    os.execute("echo timer > /sys/class/leds/system:data:data/trigger")
    os.execute("echo 50 > /sys/class/leds/system:data:data/delay_on")
    os.execute("echo 50 > /sys/class/leds/system:data:data/delay_off")
    os.execute("echo timer > /sys/class/leds/system:net:info/trigger")
    os.execute("echo 50 > /sys/class/leds/system:net:info/delay_on")
    os.execute("echo 50 > /sys/class/leds/system:net:info/delay_off")
    os.execute("echo timer > /sys/class/leds/system:work:status/trigger")
    os.execute("echo 50 > /sys/class/leds/system:work:status/delay_on")
    os.execute("echo 50 > /sys/class/leds/system:work:status/delay_off")
end

local methods = {
    ["hilink"] = {
        -- 获取状态信息
        get_status = {
            function(req, msg)
                local data = deep_copy(status_data)
                data.systime = os.time()
                data.runtime = get_runtime() * 1000
                data.mac = get_system_mac()
                data.socketa_sta = get_communication_status("SOCKA")
                data.socketa_enable = get_communication_enable("SOCKA")
                data.socketb_sta = get_communication_status("SOCKB")
                data.socketb_enable = get_communication_enable("SOCKB")
                data.mqtt1_sta = get_communication_status("MQTT1")
                data.mqtt1_enable = get_communication_enable("MQTT1")
                data.mqtt2_sta = get_communication_status("MQTT2")
                data.mqtt2_enable = get_communication_enable("MQTT2")
                data.cloud_sta = get_communication_status("CLOUD")
                data.cloud_enable = get_communication_enable("CLOUD")
                reply(req, data)
            end,
            {}
        },

        -- 更新网络指示灯状态
        update_net_led = {
            function(req, msg)
                local ok, e = pcall(update_net_led_logic)
                if not ok then
                    log_error("update_net_led_logic failed: " .. tostring(e))
                end
                reply(req, { status = "ok" })
            end,
            {}
        },

        -- 首页综合数据接口：一次请求获取 status 和 network，显著降 CPU
        get_homepage_data = {
            function(req, msg)
                local data = {}
                -- 1. 基础状态 (status)
                local status_copy = deep_copy(status_data)
                status_copy.systime = os.time()
                status_copy.runtime = get_runtime() * 1000
                status_copy.mac = get_system_mac()
                status_copy.socketa_sta = get_communication_status("SOCKA")
                status_copy.socketa_enable = get_communication_enable("SOCKA")
                status_copy.socketb_sta = get_communication_status("SOCKB")
                status_copy.socketb_enable = get_communication_enable("SOCKB")
                status_copy.mqtt1_sta = get_communication_status("MQTT1")
                status_copy.mqtt1_enable = get_communication_enable("MQTT1")
                status_copy.mqtt2_sta = get_communication_status("MQTT2")
                status_copy.mqtt2_enable = get_communication_enable("MQTT2")
                status_copy.cloud_sta = get_communication_status("CLOUD")
                status_copy.cloud_enable = get_communication_enable("CLOUD")

                data.status = status_copy

                -- 2. 网络详细状态 (network)
                data.network = collect_network_status()

                -- 3. 杂项配置 (misc)
                sync_nginx_settings()
                data.misc = deep_copy(misc_config)

                reply(req, data)
            end,
            {}
        },

        -- 获取网络状态
        get_network_status = {
            function(req, msg)
                local data = collect_network_status()
                reply(req, data)
            end,
            {}
        },

        -- 获取网络配置 (LAN + DHCP)
        get_network_config = {
            function(req, msg)
                local cursor = uci_lib.cursor()

                -- 读取 LAN 接口配置
                local lan_ip = ""
                local lan_netmask = ""

                cursor:foreach("network", "interface", function(section)
                    if section[".name"] == "lan" then
                        lan_ip = section.ipaddr or ""
                        lan_netmask = section.netmask or ""
                    end
                end)

                -- 读取 DHCP 配置
                local dhcp_start = 100       -- 默认值
                local dhcp_limit = 150       -- 默认值
                local dhcp_leasetime = "12h" -- 默认值
                local dhcp_ignore = "0"      -- 默认值，表示启用

                cursor:foreach("dhcp", "dhcp", function(section)
                    if section.interface == "lan" then
                        dhcp_start = tonumber(section.start) or 100
                        dhcp_limit = tonumber(section.limit) or 150
                        dhcp_leasetime = section.leasetime or "12h"
                        dhcp_ignore = section.ignore or "0"
                    end
                end)

                -- 计算 DHCP IP 范围
                local dhcp_start_ip = ""
                local dhcp_end_ip = ""

                if lan_ip ~= "" then
                    -- 提取 IP 前三段 (例如 192.168.18.254 -> 192.168.18)
                    local ip_parts = {}
                    for part in string.gmatch(lan_ip, "([^%.]+)") do
                        table.insert(ip_parts, part)
                    end

                    if #ip_parts >= 3 then
                        local base_ip = ip_parts[1] .. "." .. ip_parts[2] .. "." .. ip_parts[3]

                        -- 计算起始 IP
                        dhcp_start_ip = base_ip .. "." .. tostring(dhcp_start)

                        -- 计算结束 IP: start + limit - 1
                        local end_offset = dhcp_start + dhcp_limit - 1
                        dhcp_end_ip = base_ip .. "." .. tostring(end_offset)
                    end
                end

                -- 解析租期 (去掉 'h' 后缀)
                local dhcp_lease = 12 -- 默认值
                if dhcp_leasetime then
                    local num_str = string.match(dhcp_leasetime, "(%d+)")
                    if num_str then
                        dhcp_lease = tonumber(num_str) or 12
                    end
                end

                -- DHCP 开关: ignore='1' 表示关闭，否则开启
                local dhcp_enable = (dhcp_ignore ~= "1") and 1 or 0

                -- 读取 Wi-Fi AP 配置
                local ap_enable = 0
                local ap_ssid = ""
                local ap_password = ""
                local ap_encryption = 1 -- 默认 WPA2-PSK
                local ap_channel = 0    -- 默认自动
                local ap_hidden = 0     -- 默认显示SSID

                cursor:foreach("wireless", "wifi-iface", function(section)
                    if section.mode == "ap" and section.network == "lan" then
                        -- AP 启用状态：如果wifi-device没有disabled，则认为启用
                        local device_disabled = section.disabled or "0"
                        ap_enable = (device_disabled ~= "1") and 1 or 0

                        -- 读取AP配置
                        ap_ssid = section.ssid or ""
                        ap_encryption = section.encryption or "none"

                        -- 转换加密方式为数字
                        if ap_encryption == "none" then
                            ap_encryption = 0 -- OPEN
                        elseif ap_encryption == "psk2" then
                            ap_encryption = 1 -- WPA2-PSK
                        elseif ap_encryption == "psk-mixed" or ap_encryption == "psk2+psk" then
                            ap_encryption = 2 -- WPA/WPA2-PSK
                        else
                            ap_encryption = 1 -- 默认 WPA2-PSK
                        end

                        ap_password = section.key or ""
                        ap_hidden = (section.hidden == "1") and 1 or 0

                        -- 读取信道配置
                        local device_channel = get_uci("wireless." .. section.device .. ".channel")
                        ap_channel = tonumber(device_channel) or 0
                    end
                end)
                -- 返回前端所需的 JSON 结构
                local result = {
                    s_lan = {
                        ip = lan_ip,
                        netmask = lan_netmask,
                        dhcp_start = dhcp_start_ip,
                        dhcp_end = dhcp_end_ip
                    },
                    n_lan = {
                        dhcp_enable = dhcp_enable,
                        dhcp_lease = dhcp_lease
                    },
                    -- AP 配置
                    n_ap = {
                        enable = ap_enable,
                        encryption = ap_encryption,
                        channel = ap_channel,
                        hidden = ap_hidden
                    },
                    s_ap = {
                        ssid = ap_ssid,
                        password = ap_password
                    }
                }

                reply(req, result)
            end,
            {}
        },

        -- 获取网络配置 (WAN/LTE - 从ubus_adapter迁移)
        get_network_config_wan = {
            function(req, msg)
                -- Read WAN config from UCI
                local wan_proto = get_uci("network.wan.proto")
                local wan_ip = get_uci("network.wan.ipaddr") or ""
                local wan_netmask = get_uci("network.wan.netmask") or ""
                local wan_gateway = get_uci("network.wan.gateway") or ""
                local wan_dns_enable = get_uci("network.wan.peerdns") or 1 --0 手动设置 1 自动获取

                local lte_dns_enable = get_uci("network.lte.peerdns") or 1 --0 手动设置 1 自动获取
                local lte_device = get_uci("network.lte.modem_device") or ""
                local lte_apn = get_uci("network.lte.modem_apn") or ""
                local lte_user = get_uci("network.lte.modem_user") or ""
                local lte_pswd = get_uci("network.lte.modem_passwd") or ""
                local lte_auth = get_uci("network.lte.modem_auth") or 0
                local lte_simnum = get_uci("network.lte.modem_simnum") or 0
                local internal_forward_disable = get_uci("network.lte.internal_forward_disable") or 1
                local external_forward_disable = get_uci("network.lte.external_forward_disable") or 0
                --local lte_allow_lan_forward = get_uci("network.lte.allow_lan_forward") or 1

                -- Read DNS
                local wan_dns = {}
                local f = io.popen("uci get network.wan.dns 2>/dev/null")
                if f then
                    for line in f:lines() do
                        for dns in string.gmatch(line, "%S+") do
                            table.insert(wan_dns, dns)
                        end
                    end
                    f:close()
                end

                local lte_dns = {}
                local f = nil
                if lte_dns_enable == 0 then
                    f = io.popen("uci get network.lte.dns 2>/dev/null")
                else
                    f = io.popen("uci get network.lte._dns 2>/dev/null")
                end
                if f then
                    for line in f:lines() do
                        for dns in string.gmatch(line, "%S+") do
                            table.insert(lte_dns, dns)
                        end
                    end
                    f:close()
                end

                local ip_mode = 0
                if wan_proto == "dhcp" then
                    ip_mode = 1
                end

                local track_ip1 = get_uci("mwan3.globals.keepalive_ip1") or "223.5.5.5"
                local track_ip2 = get_uci("mwan3.globals.keepalive_ip2") or "223.6.6.6"
                local track_period = get_uci("mwan3.globals.keepalive_period") or 10
                local net_select = get_uci("mwan3.globals.net_select") or 0

                -- Read WiFi STA configuration
                local wifi_enable = 0
                local wifi_encryption = "0"
                local wifi_ssid = ""
                local wifi_password = ""
                local wwan_proto = get_uci("network.wwan.proto")
                local wwan_ip = get_uci("network.wwan.ipaddr") or ""
                local wwan_netmask = get_uci("network.wwan.netmask") or ""
                local wwan_gateway = get_uci("network.wwan.gateway") or ""
                local wwan_dns_enable = get_uci("network.wwan.peerdns") or 1 --0 手动设置 1 自动获取



                -- Get UCI cursor for wireless config
                local uci_cursor = require("uci").cursor()
                uci_cursor:foreach("wireless", "wifi-iface", function(section)
                    if section.mode == "sta" then
                        wifi_enable = section.disabled == "0" and 1 or 0
                        wifi_ssid = section.ssid or ""
                        wifi_password = section.key or ""

                        -- Map encryption to frontend format
                        local enc = section.encryption or "none"
                        if enc == "none" then
                            wifi_encryption = "0"
                        elseif enc == "psk2" then
                            wifi_encryption = "1" -- WPA2
                        elseif enc == "sae" then
                            wifi_encryption = "2" -- WPA3
                        else
                            wifi_encryption = "0" -- default to none
                        end
                    end
                end)

                local wwan_dns = {}
                local f = nil

                if wwan_dns_enable == 0 or wwan_dns_enable == "0" then
                    f = io.popen("uci get network.wwan.dns 2>/dev/null")
                else
                    f = io.popen("uci get network.wwan._dns 2>/dev/null")
                end
                if f then
                    for line in f:lines() do
                        for dns in string.gmatch(line, "%S+") do
                            table.insert(wwan_dns, dns)
                        end
                    end
                    f:close()
                end

                local wifi_ip_mode = 0
                if wwan_proto == "dhcp" then
                    wifi_ip_mode = 1
                end

                reply(req, {
                    net_select = net_select,
                    keepalive_period = track_period,
                    keepalive_addr = { track_ip1, track_ip2 },
                    eth0 = {
                        ip_mode = ip_mode,
                        sip = wan_ip,
                        gip = wan_gateway,
                        mip = wan_netmask,
                        dns_mode = wan_dns_enable,
                        dns_ip = { wan_dns[1] or "", wan_dns[2] or "" }
                    },
                    cell = {
                        sim_switch = lte_simnum,
                        apn = { addr = lte_apn, user = lte_user, pswd = lte_pswd, auth = lte_auth },
                        dns_mode = lte_dns_enable,
                        dns_ip = { lte_dns[1] or "", lte_dns[2] or "" },
                        --allow_lan_forward = tonumber(lte_allow_lan_forward) or 0,
                        internal_forward_disable = tonumber(internal_forward_disable) or 1,
                        external_forward_disable = tonumber(external_forward_disable) or 0
                    },
                    n_wifi = {
                        enable = wifi_enable,
                        encryption = wifi_encryption,
                        ip_mode = wifi_ip_mode,
                        dns_mode = wwan_dns_enable
                    },
                    s_wifi = {
                        ssid = wifi_ssid,
                        password = wifi_password,
                        ip = wwan_ip,
                        netmask = wwan_netmask,
                        gw = wwan_gateway,
                        dns_ip = { wwan_dns[1] or "", wwan_dns[2] or "" }
                    }
                })
            end,
            {}
        },

        -- 设置网络配置 (兼容旧接口)
        set_network_config = {
            function(req, msg)
                local res = set_network_config_values(msg)
                reply(req, { result = res })
            end,
            {}
        },

        -- 设置网络配置 (新接口)
        set_network_config_values = {
            function(req, msg)
                local res = set_network_config_values(msg)
                reply(req, { result = res })
            end,
            {}
        },

        -- 获取杂项配置
        -- 获取杂项配置
        get_misc_config = {
            function(req, msg)
                -- Refresh from UCI to ensure we have latest values (e.g. if changed by other means)
                --log_info("get misc config")
                sync_nginx_settings()
                reply(req, deep_copy(misc_config))
            end,
            {}
        },

        -- 设置杂项配置
        set_misc_config = {
            function(req, msg)
                local res = set_misc_config_values(msg)
                reply(req, { result = res })
            end,
            {}
        },

        -- 获取通讯通道配置
        get_comm_tunnel_config = {
            function(req, msg)
                -- 如果内存缓存为空，则从UCI配置文件读取
                if not comm_tunnel_config_loaded then
                    local loaded_config = load_comm_tunnel_config_from_uci()
                    if loaded_config and (#loaded_config.SOCK > 0 or #loaded_config.MQTT > 0 or loaded_config.CLOUD) then
                        comm_tunnel_config = loaded_config
                        comm_tunnel_config_loaded = true
                        log_info("Loaded comm_tunnel config from UCI: " .. cjson.encode(comm_tunnel_config))
                    else
                        log_info("Using default comm_tunnel config (UCI empty or not found)")
                        comm_tunnel_config_loaded = true
                    end
                else
                    log_info("Using cached comm_tunnel config")
                end
                reply(req, deep_copy(comm_tunnel_config))
            end,
            {}
        },

        -- 设置通讯通道配置
        set_comm_tunnel_config = {
            function(req, msg)
                local res = set_comm_tunnel_config(msg)
                reply(req, { result = res })
            end,
            {}
        },

        -- 获取串口配置
        get_uart_config = {
            function(req, msg)
                -- 如果内存缓存为空，则从UCI配置文件读取
                if not uart_config_loaded then
                    local loaded_config = load_uart_config_from_uci()
                    if loaded_config and #loaded_config.UART > 0 then
                        uart_config = loaded_config
                        uart_config_loaded = true
                        log_info("Loaded uart config from UCI: " .. cjson.encode(uart_config))
                    else
                        log_info("Using default uart config (UCI empty or not found)")
                        uart_config_loaded = true -- 标记已尝试加载，避免重复尝试
                    end
                else
                    log_info("Using cached uart config")
                end
                reply(req, deep_copy(uart_config))
            end,
            {}
        },

        -- 设置串口配置
        set_uart_config = {
            function(req, msg)
                local res = set_uart_config(msg)
                reply(req, { result = res })
            end,
            {}
        },

        -- 获取离线缓存配置
        get_offline_cache_config = {
            function(req, msg)
                reply(req, deep_copy(offline_cache_config))
            end,
            {}
        },

        -- 设置离线缓存配置
        set_offline_cache_config = {
            function(req, msg)
                local res = set_offline_cache(msg)
                reply(req, { result = res })
            end,
            {}
        },

        -- 获取TF卡信息
        get_tf_info = {
            function(req, msg)
                reply(req, deep_copy(tf_info))
            end,
            {}
        },

        -- 格式化TF卡
        format_tf_card = {
            function(req, msg)
                log_info("Formatting TF card...")
                -- 实际应该调用系统命令: os.execute("mkfs.vfat /dev/mmcblk0p1")
                reply(req, { result = true })
            end,
            {}
        },

        -- 设置系统时间
        set_system_time = {
            function(req, msg)
                local timestamp = msg.timestamp
                log_info("Setting system time to: " .. tostring(timestamp))
                if timestamp then
                    -- 格式化时间字符串，例如 "2023-10-27 10:00:00"
                    -- 注意：date -s @timestamp 在某些嵌入式系统中可能不支持 @ 语法
                    -- 如果不支持，可以使用 os.date 格式化后再设置
                    -- 这里假设支持 date -s @timestamp 或者 date -s "YYYY-MM-DD HH:MM:SS"

                    -- 方法1: 直接使用 timestamp (如果 date 支持 @)
                    -- os.execute("date -s @" .. timestamp)

                    -- 方法2: 格式化后设置 (更通用)
                    local date_str = os.date("%Y-%m-%d %H:%M:%S", timestamp)
                    local cmd = string.format("date -s \"%s\"", date_str)
                    log_info("Executing: " .. cmd)
                    os.execute(cmd)

                    -- 同步到硬件时钟 (可选)
                    --os.execute("hwclock -w")

                    reply(req, { result = true })
                else
                    reply(req, { result = false })
                end
            end,
            { timestamp = ubus.INT32 }
        },

        -- 通用设置配置接口
        set_config = {
            function(req, msg)
                local module = msg.module
                local args = {}
                for k, v in pairs(msg) do
                    if k ~= "module" then
                        args[k] = v
                    end
                end

                local result = false
                if module == "uart" then
                    result = set_uart_config(args)
                elseif module == "comm_tunnel" then
                    result = set_comm_tunnel_config(args)
                elseif module == "offline_cache" then
                    result = set_offline_cache(args)
                elseif module == "misc" then
                    result = set_misc_config_values(args)
                elseif module == "network" then
                    result = set_network_config_values(args)
                elseif module == "edge" then
                    result = set_edge_config_values(args)
                else
                    log_error("Unknown module: " .. tostring(module))
                end

                reply(req, { result = result })
            end,
            { module = ubus.STRING }
        },

        -- 获取边缘计算配置（实时从 UCI 读取 enable）
        get_edge_config = {
            function(req, msg)
                local cursor = uci_lib.cursor()
                local enable = tonumber(cursor:get("edge", "@edge[0]", "enable")) or edge_config.all_en
                reply(req, {
                    all_en            = enable,
                    refresh_frequency = edge_config.refresh_frequency,
                    calc_period       = edge_config.calc_period,
                    poll_interval     = edge_config.poll_interval
                })
            end,
            {}
        },

        -- 设置边缘计算配置
        set_edge_config = {
            function(req, msg)
                local res = set_edge_config_values(msg)
                reply(req, { result = res })
            end,
            {}
        },

        -- 获取边缘计算上报配置
        get_edge_report_config = {
            function(req, msg)
                reply(req, deep_copy(edge_report_config))
            end,
            {}
        },

        -- 设置边缘计算上报配置 (增强：增加文件拆分持久化)
        set_edge_report_config = {
            function(req, msg)
                if msg.group then
                    edge_report_config.group = msg.group
                    -- 将配置持久化到 JSON 文件 (迁移自 entry.lua)
                    os.execute("rm -f /etc/config/device/edge_report/*.json")
                    os.execute("mkdir -p /etc/config/device/edge_report")
                    for _, g in ipairs(edge_report_config.group) do
                        if g.name then
                            write_file_content("/etc/config/device/edge_report/" .. g.name .. ".json", cjson.encode(g))
                        end
                    end
                    log_info("Edge report config saved to files")
                    os.execute("touch /tmp/edge_commit")
                    reply(req, { result = true })
                else
                    reply(req, { result = false, error = "No group data" })
                end
            end,
            {}
        },

        -- 设置边缘计算上报模板配置 (新增：迁移自 entry.lua)
        set_edge_template_config = {
            function(req, msg)
                if msg.content then
                    os.execute("mkdir -p /etc/config/device/template")
                    -- 正则解析拆分逻辑
                    -- Content format: Report0:{...}\nReport1:{...}
                    for key, val in string.gmatch(msg.content, "([^:]+):(%b{})") do
                        -- Trim whitespace/newlines from key
                        key = string.match(key, "^%s*(.-)%s*$")
                        if key and key ~= "" then
                            write_file_content("/etc/config/device/template/" .. key .. ".json", val)
                        end
                    end
                    log_info("Edge template config saved to files")
                    os.execute("touch /tmp/edge_commit")
                    reply(req, { result = true })
                else
                    reply(req, { result = false, error = "No content" })
                end
            end,
            { content = ubus.STRING }
        },

        -- 设置 TCP 链接配置 (新增：从 entry.lua 迁移)
        set_tpc_config = {
            function(req, msg)
                if msg.content then
                    if write_file_content("/etc/config/device/tpc.json", msg.content) then
                        log_info("TPC config saved to tpc.json")
                        os.execute("touch /tmp/comm_commit")
                        reply(req, { result = true })
                    else
                        reply(req, { result = false, error = "Failed to write file" })
                    end
                else
                    reply(req, { result = false, error = "No content" })
                end
            end,
            { content = ubus.STRING }
        },

        -- 获取边缘计算协议转换配置（从 JSON 文件读取）
        get_edge_access_config = {
            function(req, msg)
                local config = { group = {} }
                local p = io.popen("ls /etc/config/device/edge_access/*.json 2>/dev/null")
                if p then
                    for file_path in p:lines() do
                        local content = read_file_content(file_path)
                        if content then
                            local ok, g = pcall(cjson.decode, content)
                            if ok and g then
                                table.insert(config.group, g)
                            end
                        end
                    end
                    p:close()
                end
                -- 文件为空时返回内存默认值
                if #config.group == 0 then
                    config = deep_copy(edge_access_config)
                else
                    edge_access_config = config
                end
                reply(req, config)
            end,
            {}
        },

        -- 设置边缘计算协议转换配置（将 group 持久化到 JSON 文件）
        set_edge_access_config = {
            function(req, msg)
                if msg.group then
                    edge_access_config.group = msg.group
                    -- 将配置持久化到 JSON 文件
                    os.execute("rm -f /etc/config/device/edge_access/*.json")
                    os.execute("mkdir -p /etc/config/device/edge_access")
                    for i, g in pairs(edge_access_config.group) do
                        write_file_content("/etc/config/device/edge_access/" .. i .. ".json", cjson.encode(g))
                    end
                    log_info("Edge access config saved to files")
                    os.execute("touch /tmp/edge_commit")
                end
                reply(req, { result = true })
            end,
            {}
        },

        -- 获取边缘计算链路控制配置
        get_edge_link_ctrl_config = {
            function(req, msg)
                reply(req, deep_copy(edge_link_ctrl_config))
            end,
            {}
        },

        -- 设置边缘计算链路控制配置
        set_edge_link_ctrl_config = {
            function(req, msg)
                if msg.group then
                    edge_link_ctrl_config.group = msg.group
                end
                reply(req, { result = true })
            end,
            {}
        },

        -- 获取边缘计算点位CSV数据
        get_edge_points_csv = {
            function(req, msg)
                reply(req, { content = edge_points_csv })
            end,
            {}
        },

        -- 设置边缘计算点位CSV数据
        set_edge_points_csv = {
            function(req, msg)
                if msg.content then
                    edge_points_csv = msg.content
                end
                reply(req, { result = true })
            end,
            { content = ubus.STRING }
        },

        -- 获取协议转换点位CSV数据
        get_edge_proto_access_csv = {
            function(req, msg)
                reply(req, { content = edge_proto_access_csv })
            end,
            {}
        },

        -- 设置协议转换点位CSV数据
        set_edge_proto_access_csv = {
            function(req, msg)
                if msg.content then
                    local path = "/etc/config/device/points.csv"
                    if write_file_content(path, msg.content) then
                        load_edge_point_configs() -- 配置保存后立即重新加载内存缓存
                        os.execute("touch /tmp/edge_commit")
                        reply(req, { result = true })
                    else
                        reply(req, { result = false, error = "Failed to write file" })
                    end
                else
                    reply(req, { result = false, error = "No content provided" })
                end
            end,
            { content = ubus.STRING }
        },

        -- 系统重启
        reboot = {
            function(req, msg)
                log_info("System reboot requested...")
                reply(req, { result = true })
                -- 实际应该调用: os.execute("reboot")
            end,
            {}
        },

        -- 恢复出厂设置
        factory_reset = {
            function(req, msg)
                local apply = tonumber(msg.apply) or 1
                log_info("Factory reset requested (apply=" .. apply .. ")")

                if apply == 0 then
                    log_info("Factory reset check passed, waiting for apply=1 trigger.")
                    reply(req, { result = true })
                    return
                end

                -- 执行阶段
                log_info("Executing factory reset now...")
                reply(req, { result = true })
                -- 实际应该调用: os.execute("firstboot -y && reboot")
                -- 两阶段模式下不再需要 sleep 2，直接执行
                os.execute(
                    "(/etc/init.d/edge stop;\
                      /etc/init.d/socket stop;\
                      /etc/init.d/mqtt_app stop;\
                      /etc/init.d/cloud stop;\
                      /etc/init.d/modem-monitor stop;\
                      /etc/init.d/network stop;\
                      /etc/init.d/nginx_hlk stop;\
                      rm -rf /etc/config/device/*;\
                      rm -rf /etc/config/cert/*;\
                      sync;\
                      jffs2mark -y;jffs2reset -y;\
                      firstboot -y;\
                      reboot -f) &")
            end,
            { apply = ubus.INT32 }
        },

        -- 固件升级
        upgrade_firmware = {
            function(req, msg)
                local apply = tonumber(msg.apply) or 0
                local reset_factory = tonumber(msg.reset_factory) or 0
                log_info("Firmware upgrade requested (apply=" .. apply .. ", reset_factory=" .. reset_factory .. ")")

                if apply == 0 then
                    -- 准备阶段：校验固件合法性
                    if not check_firmware_validity("/tmp/firmware.bin") then
                        log_info("Firmware validation failed.")
                        reply(req, { result = false, error = "Invalid firmware" })
                        return
                    end
                    log_info("Firmware validation passed.")
                    reply(req, { result = true })
                    return
                end

                -- 执行阶段
                log_info("Executing firmware upgrade now...")

                -- 立即返回成功响应给前端，确保响应在网络关闭前发出
                reply(req, { result = true })

                -- 构建升级命令 (后台静默执行)
                -- 1. 停止所有 Lua 定时器（防止在后台进程运行时继续干扰系统）
                if led_mgmt_timer then
                    led_mgmt_timer:cancel()
                    led_mgmt_timer = nil
                end

                -- 2. 拼接完整的系统清理与升级命令
                -- 先等待 1 秒让 ubus 响应包离开网卡，然后停止所有服务并执行 sysupgrade
                local cmd_parts = {
                    "sleep 1",
                    "echo \"0 0 0 0\" > /proc/sys/kernel/printk",
                    "/etc/init.d/edge stop",
                    "/etc/init.d/socket stop",
                    "/etc/init.d/mqtt_app stop",
                    "/etc/init.d/cloud stop",
                    "/etc/init.d/modem-monitor stop",
                    "/etc/init.d/cron stop",
                    "/etc/init.d/network stop",
                    "sync",
                }

                local sys_cmd = "sysupgrade "
                if reset_factory == 1 then
                    sys_cmd = sys_cmd .. "-n "
                end
                sys_cmd = sys_cmd .. "/tmp/firmware.bin"
                table.insert(cmd_parts, sys_cmd)

                local final_cmd = "( " .. table.concat(cmd_parts, " ; ") .. " ) > /dev/null 2>&1 &"

                log_info("Executing upgrade sequence in background: " .. final_cmd)
                --关闭LED 开始闪烁
                blink_led()
                --关闭看门狗
                os.execute("echo 1 > /sys/kernel/hlk_watchdog/disarm")

                os.execute(final_cmd)
            end,
            { apply = ubus.INT32, reset_factory = ubus.INT32 }
        },

        -- 重启服务
        restart_service = {
            function(req, msg)
                local apply = tonumber(msg.apply) or 1
                log_info("Service restart requested (apply=" .. apply .. ")")

                if apply == 0 then
                    -- 准备阶段：仅返回成功
                    log_info("Service restart check passed, waiting for apply=1 trigger.")
                    reply(req, { result = true })
                    return
                end

                -- 执行阶段：识别需要重启的服务
                local need_wifi_reset = (os.execute("test -f /tmp/wifi_commit") == 0)
                local need_network = need_wifi_reset or
                    (os.execute("test -f /tmp/network_commit") == 0) or
                    (os.execute("test -f /tmp/firewall_commit") == 0)
                local need_nginx = (os.execute("test -f /tmp/nginx_commit") == 0)
                local need_dhcp = (os.execute("test -f /tmp/dhcp_restart") == 0)


                local has_any_commit = need_network or need_nginx or
                    (os.execute("test -f /tmp/misc_commit") == 0) or
                    (os.execute("test -f /tmp/uart_commit") == 0) or
                    (os.execute("test -f /tmp/comm_commit") == 0) or
                    (os.execute("test -f /tmp/edge_commit") == 0)

                if not has_any_commit then
                    log_info("No configuration changes detected, skipping restart.")
                    reply(req, { result = true })
                    return
                end

                -- 构建重启命令串
                local cmd_parts = { "sleep 1" }

                if need_network then
                    table.insert(cmd_parts, "/etc/init.d/nginx_hlk stop")

                    -- WiFi 特殊处理：卸载驱动防止死锁
                    if need_wifi_reset then
                        log_info("WiFi change detected, executing driver hard reset sequence.")
                        table.insert(cmd_parts, "wifi down")
                        table.insert(cmd_parts, "rmmod mt7603e")
                        table.insert(cmd_parts, "sleep 1")
                        table.insert(cmd_parts, "modprobe mt7603e")
                    end
                    --关闭网络灯
                    current_led_mode = LED_MODE_OFF
                    table.insert(cmd_parts, "/etc/init.d/network restart")
                    table.insert(cmd_parts, "/etc/init.d/modem-monitor restart")
                end

                -- 应用层服务总是重启 (根据反馈，它们影响较小)
                table.insert(cmd_parts, "/etc/init.d/edge restart")
                table.insert(cmd_parts, "/etc/init.d/mqtt_app restart")
                table.insert(cmd_parts, "/etc/init.d/socket restart")
                table.insert(cmd_parts, "/etc/init.d/cloud restart")
                os.execute("rm -f /tmp/cloud_CLOUD_status")
                table.insert(cmd_parts, "/etc/init.d/cron restart")

                if need_network or need_nginx then
                    table.insert(cmd_parts, "/etc/init.d/firewall restart")
                    table.insert(cmd_parts, "/etc/init.d/nginx_hlk restart")
                end

                if need_dhcp then
                    table.insert(cmd_parts, "/etc/init.d/dnsmasq restart")
                end

                -- 清理所有标记文件
                table.insert(cmd_parts, "rm -f /tmp/*_commit")

                local cmd = "( " .. table.concat(cmd_parts, "; ") .. " ) </dev/null >/dev/null 2>&1 &"

                log_info("Executing optimized restart command with WiFi reset: " .. cmd)
                os.execute(cmd)

                -- 立即返回成功响应
                reply(req, { result = true })
            end,
            { apply = ubus.INT32 }
        },

        -- 获取边缘计算实时数据 (从共享内存读取)
        get_edge_values = {
            function(req, msg)
                local values = shm.read_values()
                if values then
                    -- 这里的 values 是嵌套结构 { slave_name = { point_name = value, ... }, ... }
                    for slave, points in pairs(values) do
                        if type(points) == "table" then
                            for key, val in pairs(points) do
                                local cfg = edge_point_configs[key]
                                if cfg then
                                    points[key] = format_edge_value(val, cfg.data_type, cfg.precision)
                                end
                            end
                        end
                    end

                    -- 注入系统从机数据
                    values["System_Slave"] = get_system_slave_data()
                    reply(req, { result = true, data = values })
                else
                    values = {}
                    values["System_Slave"] = get_system_slave_data()
                    reply(req, { result = true, data = values })
                end
            end,
            {}
        },

        -- WiFi扫描
        wifi_scan = {
            function(req, msg)
                local act = msg.act
                local result = {}

                if act == "start" then
                    -- 检查锁文件
                    local lock_file = io.open(SCAN_LOCK_FILE, "r")
                    if lock_file then
                        lock_file:close()
                        -- 检查是否超时
                        local file_stat = io.popen("date -r " .. SCAN_LOCK_FILE .. " +%s")
                        if file_stat then
                            local mtime_str = file_stat:read("*a")
                            file_stat:close()
                            local mtime_clean = string.gsub(mtime_str, "\n", "")
                            local mtime = tonumber(mtime_clean)
                            if mtime and (os.time() - mtime < SCAN_TIMEOUT) then
                                result = { result = true, status = "scanning" }
                            else
                                -- 超时，删除锁文件
                                os.remove(SCAN_LOCK_FILE)
                                os.remove(SCAN_RESULT_FILE)
                                result = { result = false, msg = "timeout" }
                            end
                        else
                            result = { result = false, msg = "date failed" }
                        end
                    else
                        -- 开始扫描
                        local lock = io.open(SCAN_LOCK_FILE, "w")
                        if lock then
                            lock:write(os.time())
                            lock:close()
                            -- 异步执行动态扫描脚本 (由于AP和STA可能都关闭导致没有网卡，需要动态创建)
                            local default_iface = get_wifi_ifname_by_mode("sta") or ""
                            local scan_cmd = string.format([[
                                (
                                    IFACE="%s"
                                    TEMP_IFACE=""
                                    # 检查默认或常见的无线接口是否已存在
                                    if [ -n "$IFACE" ] && ip link show $IFACE >/dev/null 2>&1; then
                                        true
                                    else
                                        # 全部网卡都Down了，执行方案A：动态创建虚拟网卡
                                        PHY=$(iw phy | awk '/^Wiphy/ {print $2}' | head -n 1)
                                        if [ -n "$PHY" ]; then
                                            iw phy $PHY interface add wlan_scan type station
                                            ifconfig wlan_scan up
                                            sleep 1
                                            IFACE="wlan_scan"
                                            TEMP_IFACE="wlan_scan"
                                        fi
                                    fi
                                    /usr/bin/iwinfo $IFACE scan > %s 2>/dev/null

                                    # 扫描完毕，销毁临时网卡
                                    if [ -n "$TEMP_IFACE" ]; then
                                        iw dev $TEMP_IFACE del
                                    fi
                                ) &
                            ]], default_iface, SCAN_RESULT_FILE)

                            log_info("wifi_scan: dynamic start (fallback to single PHY logic)")
                            log_info("scan_cmd: " .. scan_cmd)
                            os.execute(scan_cmd)
                            result = { result = true, status = "started" }
                        else
                            result = { result = false, msg = "cannot create lock file" }
                        end
                    end
                elseif act == "check" then
                    -- 检查扫描结果
                    local lock_file = io.open(SCAN_LOCK_FILE, "r")
                    if not lock_file then
                        result = { result = false, msg = "no scan in progress" }
                    else
                        lock_file:close()
                        -- 检查是否超时
                        local file_stat = io.popen("date -r " .. SCAN_LOCK_FILE .. " +%s")
                        if file_stat then
                            local mtime_str = file_stat:read("*a")
                            file_stat:close()
                            local mtime_clean = string.gsub(mtime_str, "\n", "")
                            local mtime = tonumber(mtime_clean)
                            if mtime and (os.time() - mtime >= SCAN_TIMEOUT) then
                                -- 超时
                                os.remove(SCAN_LOCK_FILE)
                                os.remove(SCAN_RESULT_FILE)
                                result = { result = false, msg = "timeout" }
                            else
                                -- 检查结果文件
                                local result_file = io.open(SCAN_RESULT_FILE, "r")
                                if not result_file then
                                    result = { result = true, status = "scanning" }
                                else
                                    result_file:close()
                                    -- 检查文件大小
                                    local result_file = io.open(SCAN_RESULT_FILE, "r")
                                    local size = 0
                                    if result_file then
                                        local content = result_file:read("*a")
                                        result_file:close()
                                        size = string.len(content)
                                        if size and size > 0 then
                                            -- 解析结果
                                            if content then
                                                local wifi_list = {}
                                                -- 按Cell切分解析
                                                local cell_start = 1
                                                while true do
                                                    local cell_end = string.find(content, "Cell %d+", cell_start + 1)
                                                    if not cell_end then
                                                        cell_end = string.len(content) + 1
                                                    end

                                                    local cell = string.sub(content, cell_start, cell_end - 1)
                                                    if string.match(cell, "Cell %d+") then
                                                        local ssid = string.match(cell, 'ESSID: "([^"]*)"')
                                                        if not ssid then
                                                            ssid = string.match(cell, 'ESSID: ([^\n]+)')
                                                        end

                                                        -- 规范化：如果为 "unknown" 或匹配失败，视为空字符串（代表隐藏 SSID）
                                                        if not ssid or ssid == "unknown" then
                                                            ssid = ""
                                                        end

                                                        local bssid = string.match(cell, 'Address: ([^\n]+)')
                                                        local signal = string.match(cell, 'Signal: ([-]?%d+) dBm')
                                                        local enc_str = string.match(cell, 'Encryption: ([^\n]+)')


                                                        -- 只要有 BSSID 和 信号强度，即认为是有效热点 (SSID 可能隐藏)
                                                        if bssid and signal then
                                                            -- 过滤 WEP 加密方式 (安全性低，根据需求不兼容)
                                                            if not (enc_str and string.find(enc_str, "WEP")) then
                                                                local security_type = 0 -- NONE
                                                                if enc_str and string.find(enc_str, "WPA") then
                                                                    if string.find(enc_str, "SAE") then
                                                                        security_type = 2 -- WPA3
                                                                    else
                                                                        security_type = 1 -- WPA2
                                                                    end
                                                                end

                                                                table.insert(wifi_list, {
                                                                    ssid = ssid,
                                                                    bssid = bssid,
                                                                    signal = signal,
                                                                    security = security_type
                                                                })
                                                            end
                                                        end
                                                    end

                                                    if cell_end > string.len(content) then
                                                        break
                                                    end
                                                    cell_start = cell_end
                                                end

                                                -- 清理文件
                                                os.remove(SCAN_LOCK_FILE)
                                                os.remove(SCAN_RESULT_FILE)

                                                result = {
                                                    result = true,
                                                    status = "done",
                                                    data = wifi_list
                                                }
                                            else
                                                result = { result = false, msg = "cannot read result file" }
                                            end
                                        else
                                            result = { result = true, status = "scanning" }
                                        end
                                    else
                                        result = { result = false, msg = "cannot check file size" }
                                    end
                                end
                            end
                        else
                            result = { result = false, msg = "date failed" }
                        end
                    end
                else
                    result = { result = false, msg = "invalid action" }
                end

                reply(req, result)
            end,
            { act = ubus.STRING }
        },

        -- 下载服务证书集合
        download_cert_bundle = {
            function(req, msg)
                local service = msg.service
                -- 白名单校验
                local allowed = { SOCKA = true, SOCKB = true, MQTT1 = true, MQTT2 = true }
                if not allowed[service] then
                    reply(req, { status = "error", msg = "Invalid service name" })
                    return
                end

                local base_path = "/etc/config/cert/" .. service .. "/"
                local data = {
                    server_cert = base64_encode_file(base_path .. "server_cert.pem"),
                    client_cert = base64_encode_file(base_path .. "client_cert.pem"),
                    client_key = base64_encode_file(base_path .. "client_key.pem")
                }

                reply(req, {
                    status = "success",
                    service = service,
                    data = data,
                    msg = "OK"
                })
            end,
            { service = ubus.STRING }
        }
    }
}

-- ==========================================================
-- 程序主入口 (带全局异常捕获)
-- ==========================================================
local function main_service()
    sync_nginx_settings()
    load_edge_point_configs() -- 启动时加载一次边缘计算点位配置

    -- ==========================================================
    -- 注册 ubus 对象并启动事件循环
    -- ==========================================================

    conn:add(methods)

    log_info("=========================================")
    log_info("Hilink ubus daemon started successfully")
    --[[
    log_info("Object: hilink")
    log_info("=========================================")
    log_info("Available methods:")
    for obj_name, obj_methods in pairs(methods) do
        for method_name, _ in pairs(obj_methods) do
            log_info("  - " .. obj_name .. "." .. method_name)
        end
    end
    log_info("=========================================")
    ]] --

    -- ==========================================================
    -- LED 指示灯控制：使用单一250ms定时器管理所有LED
    -- （避免旧方案中 cancel/recreate/re-arm 触发 uloop C 库异常）
    -- ==========================================================
    os.execute("echo none > /sys/class/leds/system:work:status/trigger")
    os.execute("echo 0 > /sys/class/leds/system:work:status/brightness")
    led_mgmt_timer = uloop.timer(led_mgmt_cb)
    led_mgmt_timer:set(250)

    os.execute("/etc/init.d/nginx_hlk restart")

    --开启看门狗
    os.execute("insmod /lib/modules/5.4.238/hlk_watchdog.ko gpio_pin=480;echo 1 > /sys/kernel/hlk_watchdog/heartbeat")

    update_net_led_logic()

    --写入一个系统配置文件 其他进程可以获取比如MAC SN IMEI ICCID MODEL
    init_hlk_system()

    uloop.run()
end
-- 执行受保护的主函数
local function safe_traceback(msg)
    local result = tostring(msg)
    if debug and type(debug.traceback) == "function" then
        local ok, trace = pcall(debug.traceback, "", 2)
        if ok and type(trace) == "string" and trace ~= "" then
            result = result .. "\n" .. trace
        end
    end
    return result
end

local status, err = xpcall(main_service, safe_traceback)

if not status then
    log_info("=========================================")
    log_info("FATAL ERROR DETECTED IN MAIN LOOP")
    log_info(err)
    log_info("=========================================")
    -- 强制退出以触发 procd 重启，但保留了错误栈到日志
    os.exit(1)
end
