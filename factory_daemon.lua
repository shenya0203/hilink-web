#!/usr/bin/lua

local socket = require("socket")
local cjson = require("cjson")

-- ================= 配置区 =================
local SERVER_IP = "192.168.254.245"
local SERVER_PORT = 998
local AT_PORT = "/dev/ttyUSB1"
local G_SERIAL_FD = nil
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
    if G_SERIAL_FD then G_SERIAL_FD:close() end
    G_SERIAL_FD = io.open(AT_PORT, "r+")
    if not G_SERIAL_FD then
        log("警告: 无法打开 AT 串口 " .. AT_PORT)
        return false
    end
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

-- 卡槽切换逻辑：0=外置，1=内置
local function perform_slot_switch(target)
    log("Switching SIM to slot: " .. tostring(target))
    send_at("AT+CFUN=0")
    send_at("AT+SIMCROSS=" .. tostring(target))
    send_at("AT+CFUN=1")
    os.execute("sleep 3")
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
        return {cmd="test_serial", result="fail", detail="Cannot open " .. port_name}
    end
    
    local reply_data = exec_cmd("timeout 1 cat " .. port_path)
    reply_data = reply_data:gsub("%s+", "")
    
    return {
        cmd = "test_serial",
        data = reply_data
    }
end

function do_test_lte()
    if not is_modem_present() then
        return {cmd="test_lte", result="fail", detail="USB_NOT_FOUND"}
    end

    open_at_port()
    
    -- 获取外置槽位
    perform_slot_switch(0)
    os.execute("sleep 2")
    local cpin_ext_raw = send_at("AT+CPIN?") or ""
    local sim_ext = {
        ready = cpin_ext_raw:find("READY") ~= nil,
        iccid = send_at("AT+CCID") or "ERROR"
    }

    -- 获取内置槽位
    perform_slot_switch(1)
    os.execute("sleep 2")
    local cpin_int_raw = send_at("AT+CPIN?") or ""
    local sim_int = {
        ready = cpin_int_raw:find("READY") ~= nil,
        iccid = send_at("AT+CCID") or "ERROR"
    }
    
    if G_SERIAL_FD then G_SERIAL_FD:close() end

    local is_pass = (sim_ext.ready and sim_int.ready) and "pass" or "fail"

    return {
        cmd = "test_lte",
        result = is_pass,
        sim_ext = sim_ext,
        sim_int = sim_int
    }
end

function do_test_net()
    local out = exec_cmd("swconfig dev switch0 port 1 show")
    if out:match("link: up") then
        return {cmd="test_net", result="pass"}
    else
        return {cmd="test_net", result="fail"}
    end
end

-- ================= 主控循环 =================

function main()
    log("Factory Daemon Started.")
    
    local boot_mac = get_mac_address()
    local boot_imei = "ERROR"
    local boot_iccid = "ERROR"
    local boot_imsi = "ERROR"
    local modem_status = "OK"

    -- 1. 检查 USB 设备是否存在
    if not is_modem_present() then
        log("Error: 4G Modem USB ID 19d1:1003 not found!")
        modem_status = "USB_ERROR"
    else
        -- 2. 存在则尝试获取 AT 信息
        if open_at_port() then
            -- A. 获取 IMEI
            boot_imei = send_at("AT+CGSN") or "ERROR"
            
            -- B. 切换到内置卡槽 (Slot 1) 获取 ICCID/IMSI
            perform_slot_switch(1)
            
            -- 等待 SIM 卡就绪 (最多尝试 5 次)
            local ready = false
            for i=1, 5 do
                local cpin = send_at("AT+CPIN?", 2)
                if cpin and cpin:find("READY") then
                    ready = true
                    break
                end
                os.execute("sleep 2")
            end

            if ready then
                boot_iccid = send_at("AT+CCID") or "ERROR"
                boot_imsi = send_at("AT+CIMI") or "ERROR"
            else
                log("Error: Built-in SIM not ready after switch")
                modem_status = "SIM_NOT_READY"
            end
            
            if G_SERIAL_FD then G_SERIAL_FD:close() end
        else
            modem_status = "PORT_ERROR"
        end
    end

    while true do
        local tcp = socket.tcp()
        tcp:settimeout(5)
        
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
                elseif req.cmd == "test_wdog" then
                    resp = {cmd="test_wdog", result="pass"}
                elseif req.cmd == "test_led" then
                    resp = {cmd="test_led", result="pass"}
                elseif req.cmd == "write_tuple" then
                    local cmd = string.format("tuple-write -d '%s' -p '%s' -k '%s' -s '%s' -e '%s' -f",
                                req.DN, req.PjK, req.PdK, req.PdS, req.DS)
                    if os.execute(cmd) == 0 then
                        os.execute("firstboot -y")
                        tcp:send(cjson.encode({cmd="write_tuple", result="pass"}) .. "\n")
                        log("Seal completed! Triggering Watchdog hard reset...")
                        os.execute("killall feed_wdog.sh")
                        while true do socket.sleep(10) end
                    else
                        resp = {cmd="write_tuple", result="fail"}
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
