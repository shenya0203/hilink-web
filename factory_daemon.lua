#!/usr/bin/lua

local socket        = require("socket")
local cjson         = require("cjson")

-- ================= 配置区 =================
local SERVER_IP     = "192.168.68.197"
local SERVER_PORT   = 998
local AT_PORT       = "/dev/ttyUSB3"
local G_SERIAL_FD   = nil

-- 错误代码常量 (用于与上位机沟通)
local ERR_LAN_SPEED = "LAN_SPEED_ERROR"
local ERR_WAN_SPEED = "WAN_SPEED_ERROR"
local ERR_WAN_IP    = "WAN_IP_ERROR"

-- WiFi 产测配置 (Failsafe 模式，参数来自产测需求文档)
local WIFI_SSID         = "xuxu"
local WIFI_PSK          = "12345678"
local WIFI_RSSI_THRES   = -70     -- PASS/FAIL 阈值 (dBm)，待硬件工程师标定
local WIFI_TIMEOUT      = 15      -- 单次连接超时 (秒)
local WIFI_MAX_RETRIES  = 3       -- 最大重试次数
-- ==========================================

-- 工具函数：执行Shell并获取输出
local function exec_cmd(cmd)
    local f = io.popen(cmd)
    if not f then return "" end
    local result = f:read("*a")
    f:close()
    return result or ""
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
    timeout_sec = timeout_sec or 3
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
        if not line:find(cmd, 1, true) then
            line = line:gsub("^%s*(.-)%s*$", "%1")
            if #line > 0 then table.insert(results, line) end
        end
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
    local port_name = req.port or "ttyS0"
    local port_path = "/dev/" .. port_name
    local req_data = req.data or ""

    local f_out = io.open(port_path, "w")
    if f_out then
        f_out:write(req_data)
        f_out:flush()
        f_out:close()
    else
        return { cmd = "test_serial", result = "fail", detail = "Cannot open " .. port_name }
    end

    local reply_data = exec_cmd("timeout 1 cat " .. port_path)
    reply_data = reply_data:gsub("%s+", "")

    return {
        cmd = "test_serial",
        data = reply_data
    }
end

function do_test_lte()
    open_at_port()

    local sim_ext = { ready = false, iccid = "ERROR" }
    local sim_int = { ready = false, iccid = "ERROR" }

    -- 1. 获取外置槽位 (Slot 0)
    if perform_slot_switch(0) then
        os.execute("sleep 2")
        local cpin_ext_raw = send_at("AT+CPIN?") or ""
        sim_ext.ready = cpin_ext_raw:find("READY") ~= nil
        --当sim 卡 不是ready状态时， 不需要获取iccid
        if sim_ext.ready then
            sim_ext.iccid = get_at_with_retry("AT+ICCID", "EXT_ICCID", 3)
        else
            sim_ext.iccid = "ERROR"
        end
    end

    -- 2. 获取内置槽位 (Slot 1)
    if perform_slot_switch(1) then
        os.execute("sleep 2")
        local cpin_int_raw = send_at("AT+CPIN?") or ""
        sim_int.ready = cpin_int_raw:find("READY") ~= nil
        if sim_int.ready then
            sim_int.iccid = get_at_with_retry("AT+ICCID", "INT_ICCID", 3)
        else
            sim_int.iccid = "ERROR"
        end
    end

    if G_SERIAL_FD then
        G_SERIAL_FD:close()
        G_SERIAL_FD = nil
    end

    local is_pass = (sim_ext.ready and sim_int.ready) and "pass" or "fail"

    return {
        cmd = "test_lte",
        result = is_pass,
        sim_ext = sim_ext,
        sim_int = sim_int
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
        res.log = logs
    end

    return res
end

-- WiFi 产测 (依据 MT7628_WiFi产测需求文档 v1.0)
function do_test_wifi(req)
    req = req or {}
    local ssid      = req.ssid or WIFI_SSID
    local psk       = req.psk  or WIFI_PSK
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
        "cfg80211.ko", "mac80211.ko",
        "mt76.ko", "mt76x02-lib.ko", "mt76x02-common.ko",
        "mt7603e.ko"
    }
    for _, m in ipairs(mod_list) do
        exec_cmd("insmod " .. mod_base .. m .. " 2>/dev/null")
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
update_config=1
network={
    ssid="%s"
    psk="%s"
    key_mgmt=WPA-PSK
}
]], ssid, psk)

    local function write_wpa_conf()
        local f = io.open("/tmp/wpa_supplicant.conf", "w")
        if f then f:write(wpa_conf) f:close() end
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
        if i < 5 then os.execute("sleep 0.5") end
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
        r.code  = "WEAK_SIGNAL"
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
    --[[ 测试时注释掉
    exec_cmd("modprobe /lib/modules/5.4.238/option.ko")
    exec_cmd("modprobe /lib/modules/5.4.238/usb-serial.ko")
    exec_cmd("modprobe /lib/modules/5.4.238/cdc_ncm.ko")
    exec_cmd("modprobe /lib/modules/5.4.238/cdc_ether.ko")
    exec_cmd("mknod /dev/ttyUSB1 c 188 1")
    exec_cmd("mknod /dev/ttyUSB3 c 188 3")
    exec_cmd("mknod /dev/ttyUSB5 c 188 5")
    ]] --

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
                    boot_iccid = get_at_with_retry("AT+ICCID", "ICCID", 3)
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

-- ================= 主控循环 =================

function main()
    log("Factory Daemon Started.")

    local boot_mac = get_mac_address()
    local boot_imei = "ERROR"
    local boot_iccid = "ERROR"
    local boot_imsi = "ERROR"
    local modem_status = "OK"
    --网口初始化
    --port_init()
    modem_status, boot_iccid, boot_imsi, boot_imei = lte_init()

    while true do
        local tcp = socket.tcp()
        tcp:settimeout(2)

        log("Connecting to " .. SERVER_IP .. ":" .. SERVER_PORT)
        local res, err = tcp:connect(SERVER_IP, SERVER_PORT)

        if res then
            -- 3. 注册设备 (上报所有采集到的状态)
            local reg_info = {
                cmd = "device_register",
                mac = boot_mac,
                imei = boot_imei,
                iccid = boot_iccid,
                imsi = boot_imsi,
                modem_status = modem_status,
                flashid = "TODO_Placeholder"
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

                if req.cmd == "test_net" then
                    resp = do_test_net()
                elseif req.cmd == "test_lte" then
                    resp = do_test_lte()
                elseif req.cmd == "test_serial" then
                    resp = do_test_serial(req)
                elseif req.cmd == "test_wifi" then
                    resp = do_test_wifi(req)
                elseif req.cmd == "test_wdog" then
                    resp = { cmd = "test_wdog", result = "pass" }
                elseif req.cmd == "test_led" then
                    resp = { cmd = "test_led", result = "pass" }
                elseif req.cmd == "write_tuple" then
                    local cmd = string.format("tuple-write -d '%s' -p '%s' -k '%s' -s '%s' -e '%s' -f", req.DN, req.PjK,
                        req.PdK, req.PdS, req.DS)
                    if os.execute(cmd) == 0 then
                        os.execute("firstboot -y")
                        tcp:send(cjson.encode({ cmd = "write_tuple", result = "pass" }) .. "\n")
                        log("Seal completed! Triggering Watchdog hard reset...")
                        os.execute("killall feed_wdog.sh")
                        while true do socket.sleep(10) end
                    else
                        resp = { cmd = "write_tuple", result = "fail" }
                    end
                end

                if resp.cmd then
                    local out_json = cjson.encode(resp)
                    tcp:send(out_json .. "\n")
                    log("Send: " .. out_json)
                end
            end
        end
        socket.sleep(3)
    end
end

main()
