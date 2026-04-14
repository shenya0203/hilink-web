#!/usr/bin/lua

-- --- 配置部分 ---
local DEVICE = "/dev/ttyUSB1"
local INTERFACE = "lte"
local INFO_FILE = "/tmp/modem_info.json"
local CHECK_INTERVAL = 10
local FAIL_THRESHOLD = 10

-- 全局串口句柄
local G_SERIAL_FD = nil

-- --- 全局状态 ---
local state = {
    current_slot = -1,
    online_since = 0,
    last_config_mode = -1,
    fail_count = 0,
    imei = "N/A",
    slots = {
        ["0"] = { iccid = "N/A", imsi = "N/A" },
        ["1"] = { iccid = "N/A", imsi = "N/A" }
    }
}

-- --- 日志 ---
local function log(msg)
    os.execute(string.format("logger -t 'Modem-Monitor-Lua' %q", tostring(msg)))
end

-- --- 简易 JSON ---
local function json_encode(t)
    local s = "{"
    local first = true
    for k, v in pairs(t) do
        if not first then s = s .. "," end
        s = s .. string.format("%q:%q", k, tostring(v))
        first = false
    end
    return s .. "}"
end

-- --- 串口初始化 (改进版：单句柄+非阻塞配置) ---
local function init_serial_port()
    -- stty 参数：min 0 time 1 意味着 read(1) 如果 0.1s 没数据就会返回 nil，不再死等。
    os.execute(string.format("stty -F %s 115200 raw -echo min 0 time 1 2>/dev/null", DEVICE))
    G_SERIAL_FD = io.open(DEVICE, "r+")
    if not G_SERIAL_FD then
        log("Critical Error: Cannot open " .. DEVICE)
        os.exit(1)
    end
    -- 设置缓冲区模式为无缓冲，确保数据立即下发
    G_SERIAL_FD:setvbuf("no")
end

-- --- 指令下发与异步读取 (核心修复) ---
local function send_at(cmd, timeout_sec)
    timeout_sec = timeout_sec or 3
    if not G_SERIAL_FD then return nil end

    log(">> " .. cmd)

    -- 1. 物理清空：通过重复读取清除旧缓冲区
    while G_SERIAL_FD:read(1) do end

    -- 2. 写入指令
    G_SERIAL_FD:write(cmd .. "\r\n")
    G_SERIAL_FD:flush()

    -- 3. 分阶段异步读取
    local response = ""
    local start_t = os.time()
    
    while os.difftime(os.time(), start_t) < timeout_sec do
        -- 这里的 read(1) 会受 stty time 1 约束，0.1s 无数据即返回
        local char = G_SERIAL_FD:read(1)
        if char then
            response = response .. char
            -- 成功匹配关键结论标志则提前退出
            if response:find("OK") or response:find("ERROR") then
                break
            end
        end
    end
    
    -- 4. 文本清洗
    local results = {}
    for line in response:gmatch("[^\r\n]+") do
        -- 跳过指令本身的回显
        if not line:find(cmd, 1, true) then
            line = line:gsub("^%s*(.-)%s*$", "%1") -- Trim
            if #line > 0 then table.insert(results, line) end
        end
    end
    
    local output = table.concat(results, " ")
    log("<< " .. output)
    return output
end

-- --- 联网状态获取 ---
local function get_mwan3_status()
    local f = io.popen("mwan3 status 2>/dev/null")
    if not f then return "offline" end
    local content = f:read("*a")
    f:close()
    if not content then return "offline" end
    -- 定位 lte 接口的特定状态块
    local lte_section = content:match("interface " .. INTERFACE .. ".-interface") or content:match("interface " .. INTERFACE .. ".*")
    if lte_section and lte_section:find("online") then
        return "online"
    end
    return "offline"
end

-- --- 获取路由器配置 ---
local function get_uci_config(key)
    local f = io.popen(string.format("uci -q get network.%s.%s", INTERFACE, key))
    local val = f and f:read("*l") or nil
    if f then f:close() end
    return val
end

-- --- 物理切换 SIM 卡 ---
local function switch_slot(target)
    log("Switching action triggered: To SIM" .. target)
    send_at("AT+CFUN=0")
    os.execute("sleep 1")
    send_at("AT+SIMCROSS=" .. target)
    os.execute("sleep 1")
    send_at("AT+CFUN=1")
    log("Radio is restarting, wait 5s...")
    os.execute("sleep 5")
    -- 开始拨号
    os.execute(string.format("ifdown %s; sleep 2; ifup %s", INTERFACE, INTERFACE))
    state.fail_count = 0
    state.online_since = 0
end

-- --- 守护主逻辑 ---
local function monitor_main()
    --init_serial_port()
    log("Modem Monitor Lua Service Started (Async-Safe Mode)")

    while true do
        -- 基础环境维护
        send_at("ATE0") -- 抑制回显

        -- 1. 检查配置对齐
        local modem_simnum = tonumber(get_uci_config("modem_simnum")) or 0
        if modem_simnum ~= state.last_config_mode then
            local simauto = (modem_simnum == 0 or modem_simnum == 3) and 1 or 0
            send_at("AT*SIMAUTO=" .. simauto)
            -- 使用 CFUN=1 而非 CFUN=1,1，防止 USB 重新枚举导致端口号变动
            send_at("AT+CFUN=1")
            os.execute("sleep 5")
            state.last_config_mode = modem_simnum
        end

        -- 2. 状态感知
        local resp_slot = send_at("AT+SIMCROSS?")
        state.current_slot = tonumber(resp_slot and resp_slot:match(":%s*(%d)")) or -1
        
        local cpin_resp = send_at("AT+CPIN?")
        local sim_ready = (cpin_resp and cpin_resp:find("READY")) and true or false
        
        if state.imei == "N/A" then 
            local imei_resp = send_at("AT+CGSN")
            state.imei = imei_resp and imei_resp:match("%d+") or "N/A" 
        end

        local mwan_stat = get_mwan3_status()
        if mwan_stat == "online" then
            state.online_since = (state.online_since == 0) and os.time() or state.online_since
        else
            state.online_since = 0
        end

        log(string.format("Report: MODE=%d SLOT=%d SIM=%s NET=%s", 
            modem_simnum, state.current_slot, sim_ready and "ready" or "absent", mwan_stat))

        -- 3. 动态属性采集
        if sim_ready and state.current_slot ~= -1 then
            local sid = tostring(state.current_slot)
            local iccid = send_at("AT+ICCID"):match(":%s*([%dA-Z]+)")
            if iccid then state.slots[sid].iccid = iccid end
        end

        -- 4. 流程判定 (模式驱动)
        if modem_simnum == 0 or modem_simnum == 2 then
            if state.current_slot == 1 and sim_ready then switch_slot(0) end
        elseif modem_simnum == 1 then
            if state.current_slot == 0 then switch_slot(1) end
        elseif modem_simnum == 3 then
            if mwan_stat == "offline" and state.current_slot == 0 then
                log("Primary failure, activating backup...")
                switch_slot(1)
            end
        end

        -- 5. 回馈系统状态
        local active_slot_idx = tostring(state.current_slot)
        local cur_slot_info = state.slots[active_slot_idx] or {iccid="N/A"}
        local status_out = {
            imei = state.imei,
            iccid = cur_slot_info.iccid,
            status = mwan_stat == "online" and "Online" or "Offline",
            sim_status = sim_ready and "ready" or "absent",
            updated = os.date("%H:%M:%S")
        }
        local f = io.open(INFO_FILE, "w")
        if f then f:write(json_encode(status_out)); f:close() end

        -- 6. 网络异常侦测
        if sim_ready and mwan_stat == "offline" then
            state.fail_count = state.fail_count + 1
            if state.fail_count >= FAIL_THRESHOLD then
                log("Connectivity lost detected, restarting interface...")
                --要触发重新拨号 而不是 重启接口 
                --os.execute(string.format("ifdown %s; sleep 3; ifup %s", INTERFACE, INTERFACE))
                state.fail_count = 0
                os.execute("sleep 10")
            end
        else
            state.fail_count = 0
        end

        os.execute("sleep " .. CHECK_INTERVAL)
    end
end

-- 执行
monitor_main()
