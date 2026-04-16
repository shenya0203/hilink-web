#!/usr/bin/lua

-- --- 配置部分 ---
local DEVICE = "/dev/ttyUSB1"
local INTERFACE = "lte"
local INFO_FILE = "/tmp/modem_info.json"
local CHECK_INTERVAL = 10
local FAIL_THRESHOLD = 5 -- 长周期重拨阈值
local SWITCH_FAIL_LIMIT = 3 -- 模式3自动切卡阈值

-- 全局串口句柄
local G_SERIAL_FD = nil

-- --- 全局状态 ---
local state = {
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
    }
}

-- --- 解析函数：日志记录 ---
local function log(msg)
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
    
    if #output == 0 then
        log(string.format("AT >> %s | << [TIMEOUT/EMPTY]", cmd))
    else
        log(string.format("AT >> %s | << %s", cmd, output))
    end
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
    state.is_internal_switching = true
    send_at("AT+CFUN=0")
    os.execute("sleep 1")
    send_at("AT+SIMCROSS=" .. target)
    os.execute("sleep 1")
    send_at("AT+CFUN=1")
    os.execute(string.format("ubus call network.interface.%s up", INTERFACE))
    state.net_offline_count = 0
    state.fail_count = 0
    os.execute("sleep 5")
end

-- --- 主循环守护 ---
local function monitor_main()
    init_serial_port()

    local f_uci = io.popen(string.format("uci -q get network.%s.modem_simnum", INTERFACE))
    local modem_simnum = tonumber(f_uci and f_uci:read("*l")) or 0
    if f_uci then f_uci:close() end
    
    sync_modem_hardware(modem_simnum)
    
    log(string.format("Service Started. Mode:%d Device:%s", modem_simnum, DEVICE))

    while true do
        -- 1. 物理层侦测
        local resp_slot = send_at("AT+SIMCROSS?")
        state.current_slot = tonumber(resp_slot and resp_slot:match(":%s*(%d)")) or -1
        
        if state.last_slot ~= -1 and state.current_slot ~= state.last_slot then
            if state.is_internal_switching then
                log(string.format("Slot Switch Confirmed: New Slot %d [System]", state.current_slot))
                state.is_internal_switching = false
            else
                log(string.format("EVENT: External/Hardware SIM swap detected! Now on Slot %d", state.current_slot))
            end
        end
        state.last_slot = state.current_slot

        -- 2. 状态感知
        local cpin_resp = send_at("AT+CPIN?")
        local sim_ready = (cpin_resp and cpin_resp:find("READY")) and "ready" or "absent"
        local mwan_stat = get_mwan3_status()
        
        if state.imei == "N/A" then
            state.imei = send_at("AT+CGSN"):match("%d+") or "N/A"
        end

        -- 3. 网络增强数据采集 (信号, IP, 注册状态)
        local sig_str = "No Signal"
        local local_ip = "0.0.0.0"
        local net_reg_status = "Unknown"

        if sim_ready == "ready" then
            -- 信号采集
            local csq_val = send_at("AT+CSQ"):match("%+CSQ:%s*(%d+)")
            if csq_val and tonumber(csq_val) ~= 99 then
                sig_str = (-113 + tonumber(csq_val) * 2) .. " dBm"
            end

            -- 注册状态解析 (CEREG)
            local cereg_stat = send_at("AT+CEREG?"):match("%+CEREG:%s*%d+,(%d+)")
            if cereg_stat == "1" then
                net_reg_status = "Registered (Home)"
            elseif cereg_stat == "5" then
                net_reg_status = "Registered (Roaming)"
            else
                net_reg_status = "Not Registered (" .. (cereg_stat or "N/A") .. ")"
            end

            -- IP 解析
            local ip_val = send_at("AT+CGPADDR=1"):match(':%s*%d+,"([^"]+)"')
            if ip_val and ip_val ~= "0.0.0.0" then
                local_ip = ip_val
            end

            -- 卡槽元数据更新 (ICCID & IMSI)
            if state.current_slot ~= -1 then
                local sid_str = tostring(state.current_slot)
                
                -- ICCID
                local iccid = send_at("AT+ICCID"):match(":%s*([%dA-Z]+)")
                if iccid then state.slots[sid_str].iccid = iccid end
                
                -- IMSI (CIMI)
                local imsi = send_at("AT+CIMI"):match("%d+")
                if imsi then state.slots[sid_str].imsi = imsi end
            end
        end

        -- 4. 业务逻辑决策
        local diag_msg = string.format("Cycle: [Mode:%d] [Slot:%d] [Net:%s]", modem_simnum, state.current_slot, mwan_stat)
        if modem_simnum == 3 then
            if state.current_slot == 0 and mwan_stat == "offline" then
                state.net_offline_count = state.net_offline_count + 1
                diag_msg = diag_msg .. string.format(" [Backup-Fail:%d/%d]", state.net_offline_count, SWITCH_FAIL_LIMIT)
                if state.net_offline_count >= SWITCH_FAIL_LIMIT then
                    log("Backup triggered: Fallback to SIM1")
                    perform_slot_switch(1)
                end
            else
                state.net_offline_count = 0
            end
        elseif modem_simnum == 1 and state.current_slot == 0 then
            perform_slot_switch(1)
        elseif modem_simnum == 2 and state.current_slot == 1 then
            perform_slot_switch(0)
        end

        if mwan_stat == "offline" then
            state.fail_count = state.fail_count + 1
            diag_msg = diag_msg .. string.format(" [Redial-Fail:%d/%d]", state.fail_count, FAIL_THRESHOLD)
        else
            state.fail_count = 0
        end
        log(diag_msg)

        -- 5. JSON 数据上报
        local active_sid_str = tostring(state.current_slot)
        local cur_slot_meta = state.slots[active_sid_str] or {iccid="N/A", imsi="N/A"}
        
        local full_status_text = net_reg_status
        if mwan_stat == "online" then full_status_text = full_status_text .. " (Online)" end

        local status_out = {
            imei = state.imei,
            iccid = cur_slot_meta.iccid,
            imsi = cur_slot_meta.imsi, -- 新增报送字段
            signal = sig_str,
            local_ip = local_ip,
            status = full_status_text,
            sim_status = sim_ready,
            updated = os.date("%H:%M:%S")
        }
        local f_json = io.open(INFO_FILE, "w")
        if f_json then 
            f_json:write(json_encode(status_out))
            f_json:close()
        end

        -- 6. 重拨拉起
        if mwan_stat == "offline" and state.fail_count >= FAIL_THRESHOLD then
            log("Threshold reached. Triggering ubus up...")
            os.execute(string.format("ubus call network.interface.%s up", INTERFACE))
            state.fail_count = 0
        end

        os.execute("sleep " .. CHECK_INTERVAL)
    end
end

monitor_main()
