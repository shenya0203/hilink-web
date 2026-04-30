#!/usr/bin/lua

-- --- 配置部分 ---
local DEVICE = "/dev/ttyUSB1"
local INTERFACE = "lte"
local INFO_FILE = "/tmp/modem_info.json"
local CHECK_INTERVAL = 10
local FAIL_THRESHOLD = 10 -- 长周期重拨阈值
local SWITCH_FAIL_LIMIT = 3 -- 模式3自动切卡阈值

-- 全局串口句柄
local G_SERIAL_FD = nil

-- --- 全局状态 ---
-- --- 全局状态 ---
local state = {
    modem_simnum = 0,
    current_slot = -1,
    last_slot = -1,
    online_since = 0,
    fail_count = 0, -- 网络层重拨计数
    net_offline_count = 0, -- 业务层切卡计数
    imei = "N/A",
    is_internal_switching = false,
    slots = {
        ["0"] = { iccid = "N/A", imsi = "N/A" },
        ["1"] = { iccid = "N/A", imsi = "N/A" }
    },
    -- 周期内采集到的实时数据
    data = {
        sim_ready = "absent",
        mwan_stat = "offline",
        sig_str = "No Signal",
        local_ip = "0.0.0.0",
        net_reg_status = "Unknown",
        diag_msg = ""
    }
}

-- --- 解析函数：日志记录 ---
local last_logs = {}
local function log(msg, key)
    if key then
        if last_logs[key] == msg then return end
        last_logs[key] = msg
    end
    os.execute(string.format("logger -t 'Modem-Monitor-Lua' %q", tostring(msg)))
end

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

-- --- 串口初始化 ---
local function init_serial_port()
    log("Initializing Serial Port " .. DEVICE .. "...")
    os.execute(string.format("stty -F %s 115200 raw -echo min 0 time 1 2>/dev/null", DEVICE))
    G_SERIAL_FD = io.open(DEVICE, "r+")
    if not G_SERIAL_FD then
        log("CRITICAL ERROR: Failed to open serial device.")
        os.exit(1)
    end
    G_SERIAL_FD:setvbuf("no")
end

-- --- AT 指令交互 ---
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
    
    local log_msg
    if #output == 0 then
        log_msg = string.format("AT >> %s | << [TIMEOUT/EMPTY]", cmd)
    else
        log_msg = string.format("AT >> %s | << %s", cmd, output)
    end
    log(log_msg, cmd)
    return output
end

-- --- 硬件特性同步 ---
local function sync_modem_hardware(mode)
    log(string.format("--- Syncing Modem Hardware (Mode:%d) ---", mode))
    send_at("ATE0")
    if mode == 0 or mode == 3 then
        send_at("AT+CSDT=1")
        send_at("AT*SIMAUTO=1")
    else
        send_at("AT+CSDT=0")
        send_at("AT*SIMAUTO=0")
    end
    send_at("AT+CFUN=1")
    os.execute("sleep 5")
end

-- --- 网络状态获取 ---
local function get_mwan3_status()
    local f = io.popen("mwan3 status 2>/dev/null")
    if not f then return "offline" end
    local content = f:read("*a")
    f:close()
    local lte_section = content:match("interface " .. INTERFACE .. ".-interface") or content:match("interface " .. INTERFACE .. ".*")
    if lte_section and lte_section:find("online") then
        return "online"
    end
    return "offline"
end

-- --- 执行卡槽切换 ---
local function perform_slot_switch(target)
    log(string.format("!!! TRIGGER: Software Switch to SIM%d !!!", target))
    os.execute(string.format("ubus call network.interface.%s down", INTERFACE))
    state.is_internal_switching = true
    send_at("AT+CFUN=0")
    os.execute("sleep 1")
    send_at("AT+SIMCROSS=" .. target)
    os.execute("sleep 1")
    send_at("AT+CFUN=1")
    state.net_offline_count = 0
    state.fail_count = 0
    os.execute("sleep 5")
    os.execute(string.format("ubus call network.interface.%s up", INTERFACE))
end

-- --- 采集指定卡槽的元数据 (ICCID/IMSI) ---
local function collect_slot_metadata(slot_id)
    if not slot_id or slot_id == -1 then return end
    local sid_str = tostring(slot_id)
    
    -- ICCID
    local iccid_resp = send_at("AT+ICCID")
    local iccid = iccid_resp and iccid_resp:match(":%s*([%dA-Z]+)")
    if iccid then state.slots[sid_str].iccid = iccid end

    -- IMSI (CIMI)
    local imsi_resp = send_at("AT+CIMI")
    local imsi = imsi_resp and imsi_resp:match("%d+")
    if imsi then state.slots[sid_str].imsi = imsi end
end

-- --- 初始化相关函数 ---
local function read_modem_config()
    local f_uci = io.popen(string.format("uci -q get network.%s.modem_simnum", INTERFACE))
    state.modem_simnum = tonumber(f_uci and f_uci:read("*l")) or 0
    if f_uci then f_uci:close() end
end

local function initial_sim_slot_setup()
    while state.current_slot == -1 do
        perform_slot_switch(1)
        local resp_slot = send_at("AT+SIMCROSS?")
        state.current_slot = tonumber(resp_slot and resp_slot:match(":%s*(%d)")) or -1
    end

    if state.current_slot ~= -1 then
        state.imei = send_at("AT+CGSN"):match("%d+") or "N/A"
    end

    collect_slot_metadata(state.current_slot)
end

local function init_service()
    init_serial_port()
    read_modem_config()
    initial_sim_slot_setup()
    --切到外置卡槽0
    if state.modem_simnum == 0 or state.modem_simnum == 2 or state.modem_simnum == 3 then
        perform_slot_switch(0)
    end

    perform_slot_switch(0)
    log(string.format("Service Started. Mode:%d Device:%s", state.modem_simnum, DEVICE))
end

-- --- 循环内部核心逻辑函数 ---

-- 1. 物理层侦测与业务逻辑切卡
local function process_sim_slot_detection()
    local resp_slot = send_at("AT+SIMCROSS?")
    state.current_slot = tonumber(resp_slot and resp_slot:match(":%s*(%d)")) or -1

    -- 强制卡槽逻辑 (模式1：仅内置卡槽1, 模式2：仅外置卡槽0)
    if state.modem_simnum == 1 and state.current_slot == 0 then
        perform_slot_switch(1)
        return true
    elseif state.modem_simnum == 2 and state.current_slot == 1 then
        perform_slot_switch(0)
        return true
    end
    return false
end

-- 2. 处理卡槽变动事件日志
local function handle_sim_slot_change_event()
    if state.last_slot ~= -1 and state.current_slot ~= state.last_slot then
        if state.is_internal_switching then
            log(string.format("Slot Switch Confirmed: New Slot %d [System]", state.current_slot))
            state.is_internal_switching = false
        else
            log(string.format("EVENT: External/Hardware SIM swap detected! Now on Slot %d", state.current_slot))
        end
    end
    state.last_slot = state.current_slot
end

-- 3. 基础状态感知
local function collect_modem_status()
    local cpin_resp = send_at("AT+CPIN?")
    state.data.sim_ready = (cpin_resp and cpin_resp:find("READY")) and "ready" or "absent"
    state.data.mwan_stat = get_mwan3_status()
    
    if state.imei == "N/A" then
        state.imei = send_at("AT+CGSN"):match("%d+") or "N/A"
    end
end

-- 4. 增强数据采集 (信号, IP, 注册状态, 元数据更新)
local function collect_network_data()
    -- 重置瞬态数据
    state.data.sig_str = "No Signal"
    state.data.local_ip = "0.0.0.0"
    state.data.net_reg_status = "Unknown"

    if state.data.sim_ready == "ready" then
        -- 信号强度 (CSQ)
        local csq_resp = send_at("AT+CSQ")
        local csq_val = csq_resp and csq_resp:match("%+CSQ:%s*(%d+)")
        if csq_val and tonumber(csq_val) ~= 99 then
            state.data.sig_str = (-113 + tonumber(csq_val) * 2) .. " dBm"
        end

        -- 注册状态 (CEREG)
        local cereg_resp = send_at("AT+CEREG?")
        local cereg_stat = cereg_resp and cereg_resp:match("%+CEREG:%s*%d+,(%d+)")
        if cereg_stat == "1" then
            state.data.net_reg_status = "Registered (Home)"
        elseif cereg_stat == "5" then
            state.data.net_reg_status = "Registered (Roaming)"
        else
            state.data.net_reg_status = "Not Registered (" .. (cereg_stat or "N/A") .. ")"
        end

        -- IP 地址 (CGPADDR)
        local ip_resp = send_at("AT+CGPADDR=1")
        local ip_val = ip_resp and ip_resp:match(':%s*%d+,"([^"]+)"')
        if ip_val and ip_val ~= "0.0.0.0" then
            state.data.local_ip = ip_val
        end

        -- 卡槽元数据更新
        collect_slot_metadata(state.current_slot)
        return false
    else
        -- SIM 缺失时的特殊处理 (模式0且在卡槽0时强制切到内置卡槽1)
        if state.modem_simnum == 0 and state.current_slot == 0 then
            perform_slot_switch(1)
            return true
        end
    end
    return false
end

-- 5. 故障计数与诊断日志
local function update_failure_counters()
    state.data.diag_msg = string.format("Cycle: [Mode:%d] [Slot:%d] [Net:%s]", 
        state.modem_simnum, state.current_slot, state.data.mwan_stat)
    
    if state.data.mwan_stat == "offline" then
        state.fail_count = state.fail_count + 1
        state.data.diag_msg = state.data.diag_msg .. string.format(" [Redial-Fail:%d/%d]", state.fail_count, FAIL_THRESHOLD)
    else
        state.fail_count = 0
    end
    log(state.data.diag_msg, "cycle_diag")
end

-- 6. JSON 数据上报
local function report_status_json()
    local full_status_text = state.data.net_reg_status
    if state.data.mwan_stat == "online" then 
        full_status_text = full_status_text .. " (Online)" 
    end

    local status_out = {
        imei = state.imei,
        iccid = state.slots["1"].iccid,
        imsi = state.slots["1"].imsi,
        iccid_0 = state.slots["0"].iccid,
        imsi_0 = state.slots["0"].imsi,
        signal = state.data.sig_str,
        local_ip = state.data.local_ip,
        status = full_status_text,
        sim_status = state.data.sim_ready,
        updated = os.date("%H:%M:%S")
    }

    local f_json = io.open(INFO_FILE, "w")
    if f_json then 
        f_json:write(json_encode(status_out))
        f_json:close()
    end
end

-- 7. 重拨与切卡修复逻辑
local function handle_redial_and_switch_logic()
    if state.data.mwan_stat == "offline" and state.fail_count >= FAIL_THRESHOLD then
        log("Fail threshold reached. Triggering recovery...")
        
        -- 目前仅执行日志记录和特定模式下的切卡
        if state.modem_simnum == 3 then -- 双卡备份模式
            state.net_offline_count = state.net_offline_count + 1
            if state.net_offline_count >= SWITCH_FAIL_LIMIT then
                log("Backup switch triggered!")
                state.net_offline_count = 0
                perform_slot_switch(state.current_slot == 0 and 1 or 0)
            end
        elseif state.modem_simnum == 0 and state.current_slot == 0 then
            log("Mode 0 fallback to SIM1 triggered.")
            perform_slot_switch(1)
        end
        
        state.fail_count = 0
    end
end

-- --- 主循环守护 ---
local function monitor_main()
    init_service()

    while true do
        local skip_this_cycle = false

        -- 阶段 1: 物理感知与模式强制矫正
        if process_sim_slot_detection() then
            skip_this_cycle = true
        end

        if not skip_this_cycle then
            -- 阶段 2: 事件记录与基础状态
            handle_sim_slot_change_event()
            collect_modem_status()

            -- 阶段 3: 详细数据采集
            if collect_network_data() then
                skip_this_cycle = true
            end
        end

        if not skip_this_cycle then
            -- 阶段 4: 统计、上报与自动化维护
            update_failure_counters()
            report_status_json()
            handle_redial_and_switch_logic()
        end

        os.execute("sleep " .. CHECK_INTERVAL)
    end
end

monitor_main()

