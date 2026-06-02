#!/usr/bin/lua

local socket           = require("socket")
local cjson            = require("cjson")

-- ================= 配置区 =================
local SERVER_IP        = "192.168.68.197"
local SERVER_PORT      = 998
local AT_PORT          = "/dev/ttyUSB3"
local G_SERIAL_FD      = nil

-- 错误代码常量 (用于与上位机沟通)
local ERR_LAN_SPEED    = "LAN_SPEED_ERROR"
local ERR_WAN_SPEED    = "WAN_SPEED_ERROR"
local ERR_WAN_IP       = "WAN_IP_ERROR"

-- WiFi 产测配置 (Failsafe 模式，参数来自产测需求文档)
local WIFI_SSID        = "xuxu"
local WIFI_PSK         = "12345678"
local WIFI_RSSI_THRES  = -70 -- PASS/FAIL 阈值 (dBm)，待硬件工程师标定
local WIFI_TIMEOUT     = 15  -- 单次连接超时 (秒)
local WIFI_MAX_RETRIES = 3   -- 最大重试次数
-- ==========================================

-- 工具函数：执行Shell并获取输出
local function exec_cmd(cmd)
    local f = io.popen(cmd)
    if not f then return "" end
    local result = f:read("*a")
    f:close()
    return result or ""
end

-- 工具函数：将字符串转换为 16 进制字符串，方便调试不可见字符或干扰
local function to_hex(str)
    if not str then return "" end
    local hex = {}
    for i = 1, #str do
        table.insert(hex, string.format("%02X", string.byte(str, i)))
    end
    return table.concat(hex, " ")
end

-- 打印日志
local function log(msg)
    print("[Factory] " .. tostring(msg))
end

-- 检查 4G 模组 USB 是否存在 (ID 19d1:1003)
local function is_modem_present()
    local res = exec_cmd("lsusb")
    if res:find("19d1:1003") then
        return true
    end
    return false
end

-- 从 /dev/mtd2 读取 MAC 地址 (偏移 0x4, 长 6 bytes)
local function get_mac_address()
    local cmd = "hexdump -s 4 -n 6 -e '/1 \"%02X\"' /dev/mtd2 2>/dev/null"
    local hex_mac = exec_cmd(cmd)
    if hex_mac and #hex_mac == 12 then
        return hex_mac:gsub("..", "%1:"):sub(1, -2) -- 格式化为 00:11:22:33:44:55
    end
    return "UNKNOWN_MAC"
end

-- ================= LTE AT 指令交互库 =================

-- 打开 AT 串口
local function open_at_port()
    if G_SERIAL_FD then
        G_SERIAL_FD:close()
        G_SERIAL_FD = nil
    end
    log("打开 AT 串口 " .. tostring(AT_PORT))
    os.execute(string.format("stty -F %s 115200 raw -echo min 0 time 1 2>/dev/null", AT_PORT))
    G_SERIAL_FD = io.open(AT_PORT, "r+")
    if not G_SERIAL_FD then
        log("警告: 无法打开 AT 串口 " .. AT_PORT)
        return false
    end

    log("AT 串口打开成功")
    G_SERIAL_FD:setvbuf("no")
    return true
end

-- 发送 AT 指令
local function send_at(cmd, timeout_sec)
    timeout_sec = timeout_sec or 1 -- 缩短默认等待时间至 1s
    if not G_SERIAL_FD then return nil end

    -- Drain buffer
    while G_SERIAL_FD:read(1) do end

    G_SERIAL_FD:write(cmd .. "\r\n")
    G_SERIAL_FD:flush()

    local response = ""
    local start_t = os.time()
    while os.difftime(os.time(), start_t) < timeout_sec do
        local char = G_SERIAL_FD:read(1)
        if char then
            response = response .. char
            if response:find("OK") or response:find("ERROR") then break end
        end
    end

    local results = {}
    for line in response:gmatch("[^\r\n]+") do
        line = line:gsub("^%s*(.-)%s*$", "%1")
        if #line > 0 and not line:find(cmd, 1, true) then
            -- 仅当存在其他有效数据行时，才过滤掉单纯的 OK 和 ERROR 行
            if line ~= "OK" and line ~= "ERROR" then
                table.insert(results, line)
            end
        end
    end

    -- 如果没有有效数据行，但收到了 OK/ERROR，则返回它们作为状态反馈
    if #results == 0 then
        if response:find("OK") then return "OK" end
        if response:find("ERROR") then return "ERROR" end
    end

    local output = table.concat(results, " ")
    if #output == 0 then
        log(string.format("AT >> %s | << [TIMEOUT/EMPTY]", cmd))
    else
        log(string.format("AT >> %s | << %s", cmd, output))
    end
    return output
end

-- 带有重试机制的 AT 命令获取工具
local function get_at_with_retry(cmd, label, max_tries)
    for i = 1, max_tries do
        local res = send_at(cmd)
        if res and res ~= "" and not res:find("ERROR") then
            return res
        end
        log(string.format("Get %s failed (Attempt %d/%d)", label, i, max_tries))
        if i < max_tries then os.execute("sleep 2") end
    end
    return "ERROR"
end

-- 卡槽切换逻辑：0=外置，1=内置 (增加验证与重试)
local function perform_slot_switch(target)
    for i = 1, 2 do
        log(string.format("Switching SIM to slot: %d (Attempt %d/2)", target, i))
        send_at("AT+CFUN=0")
        send_at("AT+SIMCROSS=" .. tostring(target))
        send_at("AT+CFUN=1")

        -- 用户建议增加1秒间隔 (原3秒 -> 4秒)
        os.execute("sleep 4")

        -- 闭环验证：使用正则提取数值，防止因空格差异导致校验失败
        local status_raw = send_at("AT+SIMCROSS?") or ""
        local current_val = status_raw:match("%+SIMCROSS%s*:%s*(%d+)")

        if current_val and tonumber(current_val) == target then
            log(string.format("Slot %d verified successfully.", target))
            return true
        else
            log(string.format("Verification FAILED! Current: '%s', Expected: '+SIMCROSS:%d'", status_raw, target))
            if i < 2 then
                log("Retrying switch after 2s delay...")
                os.execute("sleep 2")
            end
        end
    end
    return false
end

-- ================= 网络接收模块 =================
local function receive_json_stream(tcp)
    local depth = 0
    local in_string = false
    local escape = false
    local json_str = ""
    local started = false

    while true do
        local char, err = tcp:receive(1)
        if not char then return nil, err end

        json_str = json_str .. char

        if not in_string then
            if char == '{' then
                depth = depth + 1
                started = true
            elseif char == '}' then
                depth = depth - 1
            elseif char == '"' then
                in_string = true
            end
        else
            if char == '"' and not escape then
                in_string = false
            elseif char == '\\' and not escape then
                escape = true
            else
                escape = false
            end
        end

        if started and depth == 0 then
            return json_str
        end
    end
end

-- ================= 核心测试项处理 =================

-- RS485 纯透传测试
function do_test_serial(req)
    local req_data = req.data or ""
    local baudrate = 115200
    local timeout = 2.0

    log("开始双路串口测试 (P1:ttyS1/GPIO4, P2:ttyS0/GPIO11) @ " .. baudrate)

    -- 1. 硬件初始化：配置两个串口的波特率和 GPIO 方向 (4 & 11)
    os.execute(string.format(
        "stty -F /dev/ttyS1 %d raw -echo -echoe -echok -echoctl -echoke min 0 time 1 >/dev/null 2>&1", baudrate))
    os.execute(string.format(
        "stty -F /dev/ttyS0 %d raw -echo -echoe -echok -echoctl -echoke min 0 time 1 >/dev/null 2>&1", baudrate))
    os.execute("mem 0x10000600 0x810 >/dev/null 2>&1") -- 静默输出

    local function test_port(path, set_mask, clr_mask)
        local fd = io.open(path, "r+")
        if not fd then return "OPEN_ERR" end
        fd:setvbuf("no")

        -- 接收前清理：读掉缓冲区里可能存在的 Console 脏数据
        while true do
            local junk = fd:read(1)
            if not junk then break end
        end

        -- 发送
        os.execute("mem 0x10000630 " .. set_mask .. " >/dev/null 2>&1")
        fd:write(req_data)
        fd:flush()
        socket.sleep(0.02)

        -- 接收
        os.execute("mem 0x10000640 " .. clr_mask .. " >/dev/null 2>&1")
        local recv = ""
        local start_t = socket.gettime()
        while (socket.gettime() - start_t) < timeout do
            local char = fd:read(1)
            if char then
                recv = recv .. char
                if #recv >= #req_data then break end
            end
        end
        fd:close()

        -- 核心调试：输出收到的原始 16 进制数据
        log(string.format("[%s] 原始接收 Hex: [%s]", path, to_hex(recv)))

        return recv:gsub("%s+", "")
    end

    -- 执行测试
    local reply_data1 = test_port("/dev/ttyS1", "0x10", "0x10")
    local reply_data2 = test_port("/dev/ttyS0", "0x800", "0x800")

    log("P1 读回: " .. reply_data1)
    log("P2 读回: " .. reply_data2)

    local is_match = (reply_data1 == req_data and reply_data2 == req_data) and "pass" or "fail"
    return {
        cmd = "test_serial",
        result = is_match,
        data1 = reply_data1,
        data2 = reply_data2
    }
end

-- 辅助测试函数：用于顺序测试单个端口
local function internal_port_check(path, test_data, set_mask, clr_mask, timeout)
    local fd = io.open(path, "r+")
    if not fd then return "" end
    fd:setvbuf("no")

    -- 接收前清理：排空缓冲区中可能的指令残留或日志输出
    while true do
        local junk = fd:read(1)
        if not junk then break end
    end

    -- 切换到发送
    os.execute("mem 0x10000630 " .. set_mask)
    os.execute("mem 0x10000630 " .. set_mask .. " >/dev/null 2>&1")
    fd:write(test_data)
    fd:flush()
    socket.sleep(0.02)

    -- 切换到接收
    os.execute("mem 0x10000640 " .. clr_mask)
    os.execute("mem 0x10000640 " .. clr_mask .. " >/dev/null 2>&1")
    local reply = ""
    local start_t = socket.gettime()
    while (socket.gettime() - start_t) < timeout do
        local char = fd:read(1)
        if char then
            reply = reply .. char
            if #reply >= #test_data then break end
        end
    end
    fd:close()

    -- 自检模式下的 16 进制输出
    log(string.format("[%s] 自检接收 Hex: [%s]", path, to_hex(reply)))

    return reply:gsub("%s+", "")
end

function do_test_lte(req)
    open_at_port()

    local sim_ext = { ready = false, iccid = "ERROR" }
    local sim_int = { ready = false, iccid = "ERROR" }
    local signal = req.signal or 27
    local signal_check = false

    -- 1. 获取外置槽位 (Slot 0)
    if perform_slot_switch(0) then
        local cpin_ext_raw = send_at("AT+CPIN?") or ""
        sim_ext.ready = cpin_ext_raw:find("READY") ~= nil
        --当sim 卡 不是ready状态时， 不需要获取iccid
        if sim_ext.ready then
            local raw_iccid = get_at_with_retry("AT+ICCID", "EXT_ICCID", 3)
            sim_ext.iccid = raw_iccid:match(":%s*(%w+)") or raw_iccid
        else
            sim_ext.iccid = "ERROR"
        end
    end

    -- 2. 获取内置槽位 (Slot 1)
    if perform_slot_switch(1) then
        local cpin_int_raw = send_at("AT+CPIN?") or ""
        sim_int.ready = cpin_int_raw:find("READY") ~= nil
        if sim_int.ready then
            local raw_iccid = get_at_with_retry("AT+ICCID", "INT_ICCID", 3)
            sim_int.iccid = raw_iccid:match(":%s*(%w+)") or raw_iccid
        else
            sim_int.iccid = "ERROR"
        end
    end

    --检测信号强度:
    local cnt = 5
    while cnt > 0 do
        local signal_strength = get_at_with_retry("AT+CSQ", "SIGNAL_STRENGTH", 3)
        log("Factory : signal strength: " .. signal_strength)
        if signal_strength and signal_strength:find("%+CSQ:%s*(%d+)") then
            local rssi_val = tonumber(signal_strength:match("%+CSQ:%s*(%d+)"))
            log("信号强度: " .. rssi_val)
            log("信号标准：" .. tostring(signal))
            if signal > rssi_val then
                log("信号强度不足")
            else
                log("信号强度充足")
                signal_check = true
                break
            end
        else
            log("无法获取信号强度")
        end
        cnt = cnt - 1
    end

    if G_SERIAL_FD then
        G_SERIAL_FD:close()
        G_SERIAL_FD = nil
    end

    local is_pass = "fail"
    local err_code = nil

    if sim_ext.ready and sim_int.ready and signal_check then
        is_pass = "pass"
    elseif not sim_ext.ready and not sim_int.ready then
        err_code = "BOTH_SIM_FAIL"
    elseif not sim_ext.ready then
        err_code = "EXT_SIM_FAIL"
    elseif not sim_int.ready then
        err_code = "INT_SIM_FAIL"
    else
        err_code = "SIGNAL_FAIL"
    end

    return {
        cmd = "test_lte",
        result = is_pass,
        code = err_code,
        logs = string.format("EXT:%s(Ready:%s), INT:%s(Ready:%s)",
            sim_ext.iccid, tostring(sim_ext.ready), sim_int.iccid, tostring(sim_int.ready))
    }
end

function do_test_net()
    local res = {}
    res.cmd = "test_net"
    local logs = {}

    -- 1. LAN口测试 (Port 1)
    -- 检查协商速率是否为 100M
    local out_lan = exec_cmd("swconfig dev switch0 port 1 show")
    if not out_lan:match("speed:100baseT") then
        table.insert(logs, ERR_LAN_SPEED)
    end

    -- 2. WAN口物理层测试 (Port 0)
    -- 检查协商速率是否为 100M
    local out_wan = exec_cmd("swconfig dev switch0 port 0 show")
    if not out_wan:match("speed:100baseT") then
        table.insert(logs, ERR_WAN_SPEED)
    end

    -- 3. WAN口网络层测试 (eth0.2)
    -- 检查是否获取到 IPv4 地址
    local out_ip = exec_cmd("ifconfig eth0.2")
    if not out_ip:match("inet addr:%d+%.%d+%.%d+%.%d+") then
        table.insert(logs, ERR_WAN_IP)
    end

    -- 4. 汇总结果
    if #logs == 0 then
        res.result = "pass"
    else
        res.result = "fail"
        res.code = table.concat(logs, ",")
        res.logs = table.concat(logs, " | ")
    end

    return res
end

-- WiFi 产测 (依据 MT7628_WiFi产测需求文档 v1.0)
function do_test_wifi(req)
    req             = req or {}
    local ssid      = req.ssid or WIFI_SSID
    local psk       = req.psk or WIFI_PSK
    local threshold = tonumber(req.rssi_threshold) or WIFI_RSSI_THRES

    local function wifi_fail(code, rssi_val, detail)
        local r = { cmd = "test_wifi", result = "fail", code = code, rssi = rssi_val or "N/A" }
        if detail then r.detail = detail end
        return r
    end

    -- Step 1: 环境检查 -- iw / wpa_supplicant 工具是否存在
    if exec_cmd("which iw 2>/dev/null"):find("iw") == nil then
        return wifi_fail("DRIVER_ERROR", nil, "iw not found")
    end
    if exec_cmd("which wpa_supplicant 2>/dev/null"):find("wpa_supplicant") == nil then
        return wifi_fail("DRIVER_ERROR", nil, "wpa_supplicant not found")
    end

    -- Step 2: 加载 mt76 驱动 (insmod 按依赖顺序，Failsafe 下 modprobe 不可用)
    local kern_ver = exec_cmd("uname -r"):gsub("%s+", "")
    local mod_base = "/lib/modules/" .. kern_ver .. "/"
    local mod_list = {
        "mt7603e.ko"
    }
    for _, m in ipairs(mod_list) do
        log("modprobe " .. mod_base .. m)
        exec_cmd("modprobe " .. mod_base .. m .. " 2>/dev/null")
    end

    -- 等待 wlan 接口出现 (最多10秒)
    local iface = nil
    for _ = 1, 10 do
        local out = exec_cmd("iw dev 2>/dev/null")
        iface = out:match("Interface%s+(%w+)")
        if iface then break end
        os.execute("sleep 1")
    end
    if not iface then
        return wifi_fail("DRIVER_ERROR", nil, "interface not found after insmod")
    end
    log("WiFi iface detected: " .. iface)

    -- Step 3: 激活接口
    exec_cmd("ifconfig " .. iface .. " up")
    os.execute("sleep 1")

    -- Step 4: 生成 wpa_supplicant 配置 -> /tmp/wpa_supplicant.conf
    local wpa_conf = string.format([[
ctrl_interface=/tmp/wpa_supplicant
network={
    ssid="%s"
    psk="%s"
    key_mgmt=WPA-PSK
}
]], ssid, psk)

    local function write_wpa_conf()
        local f = io.open("/tmp/wpa_supplicant.conf", "w")
        if f then
            f:write(wpa_conf)
            f:close()
        end
    end
    write_wpa_conf()

    -- Step 5: 扫描确认目标 AP 可见 (区分射频故障 vs 配置问题)
    local scan_out = exec_cmd("iw dev " .. iface .. " scan 2>/dev/null")
    if not scan_out:find("SSID: " .. ssid) then
        exec_cmd("ifconfig " .. iface .. " down")
        exec_cmd("rm -f /tmp/wpa_supplicant.conf")
        return wifi_fail("NO_AP")
    end

    -- Step 6: 启动 wpa_supplicant 连接 (超时15秒，最多重试3次)
    local connected = false
    for attempt = 1, WIFI_MAX_RETRIES do
        -- 清理上一次尝试的残留进程/socket/接口状态
        exec_cmd("killall wpa_supplicant 2>/dev/null")
        exec_cmd("rm -rf /tmp/wpa_supplicant 2>/dev/null")
        exec_cmd("ifconfig " .. iface .. " down; ifconfig " .. iface .. " up")
        os.execute("sleep 1")
        write_wpa_conf()

        exec_cmd("wpa_supplicant -i " .. iface .. " -c /tmp/wpa_supplicant.conf -B 2>/dev/null")

        local t0 = os.time()
        while os.difftime(os.time(), t0) < WIFI_TIMEOUT do
            local link = exec_cmd("iw dev " .. iface .. " link 2>/dev/null")
            if link:find("Connected to") then
                connected = true
                break
            end
            os.execute("sleep 1")
        end
        if connected then break end
        log("WiFi assoc attempt " .. attempt .. " failed, retrying...")
    end

    if not connected then
        exec_cmd("killall wpa_supplicant 2>/dev/null")
        exec_cmd("rm -rf /tmp/wpa_supplicant 2>/dev/null")
        exec_cmd("rm -f /tmp/wpa_supplicant.conf")
        exec_cmd("ifconfig " .. iface .. " down")
        return wifi_fail("ASSOC_TIMEOUT")
    end

    -- Step 7: 采集 RSSI (等2秒稳定后连续采样5次，间隔500ms，取中位数)
    os.execute("sleep 2")
    local samples = {}
    for i = 1, 5 do
        local link = exec_cmd("iw dev " .. iface .. " link 2>/dev/null")
        local dbm = link:match("signal:%s*(-?%d+)")
        if dbm then table.insert(samples, tonumber(dbm)) end
        if i < 5 then os.execute("sleep 1") end
    end

    -- Step 8: 清理环境
    exec_cmd("killall wpa_supplicant 2>/dev/null")
    exec_cmd("rm -rf /tmp/wpa_supplicant 2>/dev/null")
    exec_cmd("rm -f /tmp/wpa_supplicant.conf")
    exec_cmd("ifconfig " .. iface .. " down")

    -- Step 9: 判定 RSSI vs 阈值
    if #samples == 0 then
        return wifi_fail("WEAK_SIGNAL")
    end
    table.sort(samples)
    local median = samples[math.ceil(#samples / 2)]

    local r = { cmd = "test_wifi", rssi = median }
    if median >= threshold then
        r.result = "pass"
    else
        r.result = "fail"
        r.code   = "WEAK_SIGNAL"
        r.logs   = "RSSI: " .. median .. " < " .. threshold
    end
    return r
end

function port_init()
    --Failsafe模式下 需要把网口初始化
    --端口测试方案， 使用LAN口和 上位机通信， 如果通信且端口的协商速率时100M 说明正常
    --WAN口测试方案， 配置交换芯片，将WAN口分隔为vlan2 同时让wan口通过udhcpc获取IP 获取到IP且协商速率是100M， 说明正常
    exec_cmd("swconfig dev switch0 set enable_vlan 1")
    exec_cmd("swconfig dev switch0 set alternate_vlan_disable 0")
    exec_cmd("swconfig dev switch0 vlan 1 set ports \"1 2 3 4 6t\"")
    exec_cmd("swconfig dev switch0 vlan 2 set ports \"0 6t\"")
    exec_cmd("swconfig dev switch0 port 1 set pvid 1")
    exec_cmd("swconfig dev switch0 port 2 set pvid 1")
    exec_cmd("swconfig dev switch0 port 3 set pvid 1")
    exec_cmd("swconfig dev switch0 port 4 set pvid 1")
    exec_cmd("swconfig dev switch0 port 0 set pvid 2")
    exec_cmd("swconfig dev switch0 set apply 1")
    exec_cmd("ip link add link eth0 name eth0.2 type vlan id 2")
    exec_cmd("ip link set eth0.2 up")
    exec_cmd("(udhcpc -i eth0.2 -n -q -T 5 -t 3000 ) >/dev/null 2>&1 &")
end

function lte_init()
    local modem_status = "OK"
    local boot_iccid = "ERROR"
    local boot_imsi = "ERROR"
    local boot_imei = "ERROR"

    -- 驱动挂载
    exec_cmd("modprobe /lib/modules/5.4.238/option.ko")
    exec_cmd("modprobe /lib/modules/5.4.238/usb-serial.ko")
    exec_cmd("modprobe /lib/modules/5.4.238/cdc_ncm.ko")
    exec_cmd("modprobe /lib/modules/5.4.238/cdc_ether.ko")
    exec_cmd("mknod /dev/ttyUSB1 c 188 1")
    exec_cmd("mknod /dev/ttyUSB3 c 188 3")
    exec_cmd("mknod /dev/ttyUSB5 c 188 5")

    -- 1. 检查 USB 设备是否存在
    if not is_modem_present() then
        log("Error: 4G Modem USB ID 19d1:1003 not found!")
        modem_status = "USB_ERROR"
    else
        -- 2. 存在则尝试获取 AT 信息
        if open_at_port() then
            -- A. 获取 IMEI (尝试3次)
            boot_imei = get_at_with_retry("AT+CGSN", "IMEI", 3)

            -- B. 切换到内置卡槽 (Slot 1) 并验证
            if perform_slot_switch(1) then
                -- 等待 SIM 卡就绪 (尝试3次)
                local ready = false
                for i = 1, 3 do
                    local cpin = send_at("AT+CPIN?", 2)
                    if cpin and cpin:find("READY") then
                        ready = true
                        break
                    end
                    log(string.format("Waiting for SIM READY (Attempt %d/3)...", i))
                    os.execute("sleep 2")
                end

                if ready then
                    -- 获取 ICCID 和 IMSI (各尝试3次)
                    local raw_iccid = get_at_with_retry("AT+ICCID", "ICCID", 3)
                    boot_iccid = raw_iccid:match(":%s*(%w+)") or raw_iccid
                    boot_imsi = get_at_with_retry("AT+CIMI", "IMSI", 3)
                else
                    log("Error: Built-in SIM not ready after switch and retries")
                    modem_status = "SIM_NOT_READY"
                end
            else
                log("Error: Critical failure in slot switching verification")
                modem_status = "SLOT_SWITCH_ERROR"
            end
        else
            modem_status = "PORT_ERROR"
        end
    end

    return modem_status, boot_iccid, boot_imsi, boot_imei
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

local function close_led()
    os.execute("echo none > /sys/class/leds/system:data:data/trigger")
    os.execute("echo none > /sys/class/leds/system:net:info/trigger")
    os.execute("echo none > /sys/class/leds/system:work:status/trigger")
end


local function get_flash_id()
    return exec_cmd("cat /proc/unique_id")
end

-- 独立串口自检函数：强制配置并验证物理回环
function use_test_serial()
    local test_data = "RkFDVE9SWV9URVNUX0RBVEFfMjAyNA=="
    local baudrate = 115200
    local timeout = 2.0

    log("--- 独立双路 RS485 自检开始 ---")

    -- 1. 初始化
    os.execute(string.format("stty -F /dev/ttyS1 %d raw -echo min 0 time 1 2>/dev/null", baudrate))
    os.execute(string.format("stty -F /dev/ttyS0 %d raw -echo min 0 time 1 2>/dev/null", baudrate))
    os.execute("mem 0x10000600 0x810")
    os.execute(string.format(
        "stty -F /dev/ttyS1 %d raw -echo -echoe -echok -echoctl -echoke min 0 time 1 >/dev/null 2>&1", baudrate))
    os.execute(string.format(
        "stty -F /dev/ttyS0 %d raw -echo -echoe -echok -echoctl -echoke min 0 time 1 >/dev/null 2>&1", baudrate))
    os.execute("mem 0x10000600 0x810 >/dev/null 2>&1")

    -- 2. 测试 P1
    local res1 = internal_port_check("/dev/ttyS1", test_data, "0x10", "0x10", timeout)

    -- 3. 测试 P2
    local res2 = internal_port_check("/dev/ttyS0", test_data, "0x800", "0x800", timeout)

    -- 4. 结果判定
    if res1 == test_data and res2 == test_data then
        log("自检成功: P1 & P2 验证通过")
        return true
    else
        log(string.format("自检失败! P1:%s, P2:%s",
            (res1 == test_data and "OK" or "FAIL"),
            (res2 == test_data and "OK" or "FAIL")))
        return false
    end
end

local function n2n_init()
    os.execute("modprobe tun;sleep 1;mkdir -p /dev/net;mknod /dev/net/tun c 10 200;chmod 666 /dev/net/tun")
    os.execute("ifconfig lo up;ifconfig lo 127.0.0.1")
    os.execute("edge -a 192.168.103.200 -s 255.255.255.0 -c mynetwork -l 39.97.164.5:5000 -k 1q2w3e4r -t 0")
end

--[[
function main()
    use_test_serial()
end
]] --

-- ================= 主控循环 =================
function main()
    log("Factory Daemon Started.")

    local boot_mac = get_mac_address()
    local boot_imei = "ERROR"
    local boot_iccid = "ERROR"
    local boot_imsi = "ERROR"
    local modem_status = "OK"
    --网口初始化
    port_init()
    n2n_init()
    modem_status, boot_iccid, boot_imsi, boot_imei = lte_init()

    while true do
        local tcp = socket.tcp()
        tcp:settimeout(2)

        log("Connecting to " .. SERVER_IP .. ":" .. SERVER_PORT)
        local res, err = tcp:connect(SERVER_IP, SERVER_PORT)
        local flash_id = get_flash_id()

        if res then
            -- 3. 注册设备 (上报所有采集到的状态)
            local reg_info = {
                cmd = "device_register",
                mac = boot_mac,
                imei = boot_imei,
                iccid = boot_iccid,
                imsi = boot_imsi,
                modem_status = modem_status,
                flashid = flash_id
            }
            tcp:send(cjson.encode(reg_info) .. "\n")
            log("Reg info sent: " .. cjson.encode(reg_info))

            -- 4. 阻塞接收指令并处理
            tcp:settimeout(nil)
            while true do
                local raw_str, err = receive_json_stream(tcp)
                if not raw_str or err then
                    log("Connection lost: " .. tostring(err))
                    break
                end

                log("Recv: " .. raw_str)
                local req = cjson.decode(raw_str)
                local resp = {}

                -- 1. 定义支持的测试命令，用于过滤 ACK 响应
                local supported_cmds = {
                    test_net = true,
                    test_lte = true,
                    test_serial = true,
                    test_wifi = true,
                    test_wdog = true,
                    test_led = true,
                    write_tuple = true
                }

                -- 2. 如果收到有效测试命令，立即回复 ACK
                if req.cmd and supported_cmds[req.cmd] then
                    tcp:send(cjson.encode({ cmd = "ack", status = "received", ref_cmd = req.cmd }) .. "\n")
                    log("ACK sent for: " .. req.cmd)

                    -- 3. 执行具体的测试函数
                    if req.cmd == "test_net" then
                        resp = do_test_net()
                    elseif req.cmd == "test_lte" then
                        resp = do_test_lte(req)
                    elseif req.cmd == "test_serial" then
                        resp = do_test_serial(req)
                    elseif req.cmd == "test_wifi" then
                        resp = do_test_wifi(req)
                    elseif req.cmd == "test_wdog" then
                        close_led()
                        log("Watchdog test triggered. Restarting...")
                        tcp:close()
                        socket.sleep(5)
                        os.execute("mem 0x10000060 0x50154444;gpioset gpiochip0 0=0")
                        while true do socket.sleep(1) end
                    elseif req.cmd == "test_led" then
                        resp = { cmd = "test_led", result = "pass" }
                        blink_led()
                    elseif req.cmd == "write_tuple" then
                        local cmd = string.format("tuple-write -d '%s' -p '%s' -k '%s' -s '%s' -e '%s' -f",
                            req.DN, req.PjK, req.PdK, req.PdS, req.DS)
                        if os.execute(cmd) == 0 then
                            os.execute("firstboot -y")
                            tcp:send(cjson.encode({ cmd = "write_tuple", result = "pass" }) .. "\n")
                            os.execute("killall feed_wdog.sh")
                            while true do socket.sleep(10) end
                        else
                            resp = { cmd = "write_tuple", result = "fail" }
                        end
                    end

                    -- 4. 发送测试最终结果
                    if resp.cmd then
                        local out_json = cjson.encode(resp)
                        tcp:send(out_json .. "\n")
                        log("Send Result: " .. out_json)
                    end
                else
                    log("Ignored unknown or register command: " .. tostring(req.cmd))
                end
            end
        end
        socket.sleep(3)
    end
end

---
main()
