local cjson = require "cjson"
local ubus = require "ubus"

-- ubus连接缓存
local ubus_conn = nil

-- 获取ubus连接
local function get_ubus_conn()
    if not ubus_conn then
        ubus_conn = ubus.connect()
        if not ubus_conn then
            ngx.log(ngx.ERR, "Failed to connect to ubus")
            return nil
        end
    end
    return ubus_conn
end

-- 调用ubus方法的通用函数
local function ubus_call(object, method, params)
    local conn = get_ubus_conn()
    if not conn then
        return nil, "ubus connection failed"
    end
    
    local result = conn:call(object, method, params or {})
    if not result then
        ngx.log(ngx.ERR, "ubus call failed: " .. object .. "." .. method)
        return nil, "ubus call failed"
    end
    
    return result
end

-- 读取文件内容
local function read_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

-- UCI Helper
local function get_uci(key)
    local f = io.popen("uci get " .. key .. " 2>/dev/null")
    if f then
        local content = f:read("*a")
        f:close()
        if content then
            return string.gsub(content, "\n", "")
        end
    end
    return nil
end

local _M = {}

-- ==========================================================
-- Ubus Adapter Module
-- ==========================================================

-- 1. Status Data
function _M.get_status()
    ngx.log(ngx.ERR, "-------------------- get_status ")
    local result = ubus_call("hilink", "get_status", {})
    if result then
        ngx.log(ngx.ERR, "-------------------- get_status result: " .. cjson.encode(result))
        return result
    end
    ngx.log(ngx.WARN, "ubus call failed for get_status")
    return nil
end

-- 2. Network Status Data
function _M.get_network_status()
    ngx.log(ngx.ERR, "-------------------- get_network_status ")
    local result = ubus_call("hilink", "get_network_status", {})
    if result then
        ngx.log(ngx.ERR, "-------------------- get_network_status result: " .. cjson.encode(result))
        return result
    end
    ngx.log(ngx.WARN, "ubus call failed for get_network_status")
    return nil
end

-- 3. Network Config Data
-- 3. Network Config Data
function _M.get_network_config()
    -- Read WAN config from UCI
    local wan_proto = get_uci("network.wan.proto")
    local wan_ip = get_uci("network.wan.ipaddr") or ""
    local wan_netmask = get_uci("network.wan.netmask") or ""
    local wan_gateway = get_uci("network.wan.gateway") or ""
    local wan_dns_enable = get_uci("network.wan.peerdns") or 1  --0 手动设置 1 自动获取

    local lte_dns_enable = get_uci("network.lte.peerdns") or 1  --0 手动设置 1 自动获取
    local lte_device = get_uci("network.lte.modem_device") or ""
    local lte_apn = get_uci("network.lte.modem_apn") or ""
    local lte_user = get_uci("network.lte.modem_user") or ""
    local lte_pswd = get_uci("network.lte.modem_passwd") or ""
    local lte_auth = get_uci("network.lte.modem_auth") or 0
    local lte_simnum = get_uci("network.lte.modem_simnum") or 0

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
    
    return {
        net_select = net_select, keepalive_period = track_period,
        keepalive_addr = {track_ip1, track_ip2},
        eth0 = {
            ip_mode = ip_mode, 
            sip = wan_ip, 
            gip = wan_gateway,
            mip = wan_netmask, 
            dns_mode = wan_dns_enable, 
            dns_ip = {wan_dns[1] or "", wan_dns[2] or ""}
        },
        cell = {
            sim_switch = lte_simnum,
            apn = { addr = lte_apn, user = lte_user, pswd = lte_pswd, auth = lte_auth },
            dns_mode = lte_dns_enable, dns_ip = {lte_dns[1] or "", lte_dns[2] or ""}
        }
    }
end

-- 4. Misc Config Data (完整配置)
function _M.get_misc_config()
    -- 2. 调用 Daemon 接口 (对象名: hilink, 方法名: get_misc_config)
    -- 第三个参数是参数表，get请求通常为空表 {}
    local res = ubus_call("hilink", "get_misc_config", {})
    -- 4. 处理结果
    if not res then
        ngx.log(ngx.ERR, "Ubus call 'get_misc_config' failed: " .. tostring(err))
        return { error = "Failed to fetch config" }
    end

    -- res 已经是解码后的 Lua table 了
    return res
end

-- 5. Comm Tunnel Config
function _M.get_comm_tunnel_config()
    ngx.log(ngx.ERR, "-------------------- get_comm_tunnel_config ")
    -- 通过ubus接口从后端daemon获取通讯通道配置
    local result = ubus_call("hilink", "get_comm_tunnel_config")
    if result then
        ngx.log(ngx.ERR, "-------------------- get_comm_tunnel_config result: " .. cjson.encode(result))
        return result
    end
    -- 如果ubus调用失败，返回nil
    ngx.log(ngx.WARN, "ubus call failed for get_comm_tunnel_config")
    return nil
end

-- 6. UART Config
local uart_config = {
    UART = {
        { enable = 1, name = "Uart1", work_mode = 2, baud_rate = 115200, data_bit = 8, stop_bit = 1, parity = 0, pack_len = 1460, pack_time = 0, func = 1 },
        { enable = 1, select = 0, name = "Uart2", work_mode = 2, baud_rate = 9600, data_bit = 8, stop_bit = 1, parity = 0, pack_len = 1460, pack_time = 0 }
    }
}

function _M.get_uart_config()
    ngx.log(ngx.ERR, "-------------------- get_uart_config ")
    -- 通过ubus接口从后端daemon获取串口配置
    local result = ubus_call("hilink", "get_uart_config")
    if result then
        ngx.log(ngx.ERR, "-------------------- get_uart_config result: " .. cjson.encode(result))
        return result
    end
    -- 如果ubus调用失败，返回本地默认配置
    ngx.log(ngx.WARN, "ubus call failed, using local uart_config")
    --失败 不要返回数据 会令人迷惑
    return nil
end

-- 7. Offline cache config
local offline_cache_config = {
    mgt = { rpt_time = 200, queue_type = 0 },
    tunnel = {
        { name = "SOCKA", enable = 0 },
        { name = "SOCKB", enable = 0 },
        { name = "MQTT1", enable = 0 },
        { name = "MQTT2", enable = 0 },
        { name = "Cloud", enable = 0 }
    }
}

function _M.get_offline_cache_config()
    return offline_cache_config
end

-- ==========================================================
-- 边缘计算配置 (Moved to top for scope visibility)
-- ==========================================================

-- 12. Edge Config - 边缘计算基本配置
local edge_config = {
    all_en = 1,
    refresh_frequency = 100,
    calc_period = 100,
    poll_interval = 100
}

-- 13. Edge Report Config - 数据上报配置
local edge_report_config = {
    group = {}
}

-- 14. Edge Access Config - 协议转换访问配置
local edge_access_config = {
    group = {}
}

-- 15. Edge Link Control Config - 链路控制配置
local edge_link_ctrl_config = {
    group = {}
}

-- 8. TF Card Info
function _M.get_tf_info()
    -- 模拟TF卡信息
    -- status: 0=未插入, 1=已插入
    -- err: 0=正常, 1=错误
    return {
        status = 1,
        err = 0,
        total = 16 * 1024 * 1024 * 1024,  -- 16GB
        used = 2 * 1024 * 1024 * 1024      -- 2GB used
    }
end

-- 9. Format TF Card
function _M.format_tf_card()
    -- 模拟格式化TF卡
    ngx.log(ngx.INFO, "Formatting TF card...")
    -- 实际应该调用系统命令: os.execute("mkfs.vfat /dev/mmcblk0p1")
    return true
end

-- 10. Set System Time
function _M.set_system_time(timestamp)
    -- 设置系统时间
    ngx.log(ngx.INFO, "Setting system time to: " .. tostring(timestamp))
    
    local result = ubus_call("hilink", "set_system_time", { timestamp = timestamp })
    if result and result.result then
        return true
    else
        ngx.log(ngx.ERR, "Failed to set system time via ubus")
        return false
    end
end

-- 11. Set Config
function _M.set_config(module, args)
    if module == "uart" then
        -- 直接从args组装完整的UART配置数组
        local uart_array = {}
        
        for k, v in pairs(args) do
            local index, key = string.match(k, "n_UART%[(%d+)%]%.(.+)")
            if index and key then
                index = tonumber(index) + 1
                if not uart_array[index] then
                    uart_array[index] = {}
                end
                uart_array[index][key] = tonumber(v) or v
            end
        end

        ngx.log(ngx.ERR, "set_config uart via ubus: " .. cjson.encode(uart_array))
        
        -- 构建配置对象
        local uart_config = { UART = uart_array }
        
        ngx.log(ngx.ERR, "set_config uart via ubus: " .. cjson.encode(uart_config))
        
        -- 通过ubus接口设置uart配置
        local result = ubus_call("hilink", "set_uart_config", uart_config)
        if result and result.result then
            ngx.log(ngx.ERR, "Successfully set uart config via ubus")
            return true
        else
            ngx.log(ngx.ERR, "Failed to set uart config via ubus")
            return false
        end
    end
    
    if module == "comm_tunnel" then
        ngx.log(ngx.INFO, "Setting comm_tunnel config via ubus: " .. cjson.encode(args))
        
        -- 通过ubus接口设置通讯通道配置
        local result = ubus_call("hilink", "set_comm_tunnel_config", args)
        if result and result.result then
            ngx.log(ngx.INFO, "Successfully set comm_tunnel config via ubus")
            return true
        else
            ngx.log(ngx.ERR, "Failed to set comm_tunnel config via ubus")
            return false
        end
    end
    
    if module == "offline_cache" then
        for k, v in pairs(args) do
            local index, key = string.match(k, "n_tunnel%[(%d+)%]%.(.+)")
            if index and key then
                index = tonumber(index) + 1
                if offline_cache_config.tunnel[index] then
                    offline_cache_config.tunnel[index][key] = tonumber(v) or v
                end
            end
        end
        return true
    end
    
    if module == "misc" then
        local req_args = {}
        for k, v in pairs(args) do
            req_args[k] = v
        end
        req_args["module"] = "misc" -- 显式指明模块，虽然 set_config 里会用

        local result = ubus_call("hilink", "set_config", req_args)

        if not result then
            return { result = false, msg = "Backend communication error" }
        else
            ngx.log(ngx.INFO, "Ubus result: " .. cjson.encode(result))
            return result
        end

        return true
    end
    
    if module == "edge" then
        -- 处理边缘计算配置更新
        ngx.log(ngx.INFO, "Updating edge config...")
        return _M.set_edge_config(args)
    end

    if module == "edge_access" then
        ngx.log(ngx.INFO, "Updating edge_access config...")
        
        -- Reset group config to ensure we only save what's currently submitted
        edge_access_config.group = {}
        
        for k, v in pairs(args) do
            -- Parse n_group[i].key or s_group[i].key
            local type_prefix, index, key = string.match(k, "([ns])_group%[(%d+)%]%.(.+)")
            if index and key then
                index = tonumber(index) + 1
                if not edge_access_config.group[index] then
                    edge_access_config.group[index] = { up = {}, down = {} }
                end
                
                local val = v
                if type_prefix == "n" then val = tonumber(v) or 0 end
                
                -- Handle nested keys like up.link, down.qos
                local sub_key, sub_prop = string.match(key, "([^%.]+)%.([^%.]+)")
                if sub_key and sub_prop then
                    if not edge_access_config.group[index][sub_key] then
                        edge_access_config.group[index][sub_key] = {}
                    end
                    edge_access_config.group[index][sub_key][sub_prop] = val
                else
                    edge_access_config.group[index][key] = val
                end
            end
        end
        
        -- Save to files
        os.execute("rm -f /etc/config/device/edge_access/*.json")
        os.execute("mkdir -p /etc/config/device/edge_access")
        
        for i, g in pairs(edge_access_config.group) do
            local f = io.open("/etc/config/device/edge_access/" .. i .. ".json", "w+")
            if f then
                f:write(cjson.encode(g))
                f:close()
            end
        end
        
        return true
    end
    
    if module == "network" then
        ngx.log(ngx.INFO, "Updating network config...")
        
        local eth_mode = nil
        local eth_ip = nil
        local eth_mask = nil
        local eth_gw = nil
        local eth_dns1 = nil
        local eth_dns2 = nil
        local eth_dns_mode = nil
        
        local lte_simnum = nil
        local lte_apn = nil
        local lte_user = nil
        local lte_pswd = nil
        local lte_auth = nil
        local lte_dns_mode = nil
        local lte_dns = nil
        local lte_sdns = nil
        local net_select = nil
        local keepalive_period = nil
        local keepalive_addr1 = nil
        local keepalive_addr2 = nil
        
        
        for k, v in pairs(args) do
            if k == "n_eth0.ip_mode" then eth_mode = tonumber(v) end
            if k == "s_eth0.sip" then eth_ip = v end
            if k == "s_eth0.mip" then eth_mask = v end
            if k == "s_eth0.gip" then eth_gw = v end
            if k == "s_eth0.dns_ip[0]" then eth_dns1 = v end
            if k == "s_eth0.dns_ip[1]" then eth_dns2 = v end
            if k == "n_eth0.dns_mode" then eth_dns_mode = tonumber(v) end   
            
            if k == "n_cell.sim_switch" then lte_simnum = tonumber(v) end
            if k == "s_cell.apn.addr" then lte_apn = v end
            if k == "s_cell.apn.user" then lte_user = v end
            if k == "s_cell.apn.pswd" then lte_pswd = v end
            if k == "s_cell.dns_ip[0]" then lte_dns = v end
            if k == "s_cell.dns_ip[1]" then lte_sdns = v end
            if k == "n_cell.dns_mode" then lte_dns_mode = tonumber(v) end
            if k == "n_cell.apn.auth" then lte_auth = tonumber(v) end
            if k == "n_keepalive_period" then keepalive_period = tonumber(v) end
            if k == "s_keepalive_addr[0]" then keepalive_addr1 = v end  
            if k == "s_keepalive_addr[1]" then keepalive_addr2 = v end
            if k == "n_net_select" then net_select = tonumber(v) end
        end
        
        if eth_mode ~= nil then
            if eth_mode == 1 then
                os.execute("uci set network.wan.proto=dhcp")
            else
                os.execute("uci set network.wan.proto=static")
                if eth_ip then os.execute("uci set network.wan.ipaddr=" .. eth_ip) end
                if eth_mask then os.execute("uci set network.wan.netmask=" .. eth_mask) end
                if eth_gw then os.execute("uci set network.wan.gateway=" .. eth_gw) end
                
                os.execute("uci set network.wan.peerdns=" .. eth_dns_mode or 0)
                -- DNS
                os.execute("uci delete network.wan.dns")
                if eth_dns1 and eth_dns1 ~= "" then 
                    os.execute("uci add_list network.wan.dns=" .. eth_dns1) 
                end
                if eth_dns2 and eth_dns2 ~= "" then 
                    os.execute("uci add_list network.wan.dns=" .. eth_dns2) 
                end
            end
            os.execute("uci commit network")
        end

        os.execute("uci set network.lte.modem_simnum=" .. (lte_simnum or ""))

        os.execute("uci set network.lte.modem_apn=" .. (lte_apn or ""))

        os.execute("uci set network.lte.modem_user=" .. (lte_user or ""))

        os.execute("uci set network.lte.modem_passwd=" .. (lte_pswd or ""))

        os.execute("uci set network.lte.modem_auth=" .. (lte_auth or 0))

        os.execute("uci delete network.lte.dns")
        os.execute("uci delete network.lte._dns")
        if lte_dns_mode == 1 then --自动获取
            os.execute("uci add_list network.lte._dns=" .. (lte_dns or ""))   --配置为自动获取时 修改dns的option名称
            os.execute("uci add_list network.lte._dns=" .. (lte_sdns or "")) 
        else
            os.execute("uci add_list network.lte.dns=" .. (lte_dns or "")) 
            os.execute("uci add_list network.lte.dns=" .. (lte_sdns or "")) 
        end

        os.execute("uci set network.lte.peerdns=" .. (lte_dns_mode or 0))


        if net_select then os.execute("uci set mwan3.globals.net_select=" .. net_select) end

        if keepalive_period then os.execute("uci set mwan3.globals.keepalive_period=" .. keepalive_period) end
        if keepalive_addr1 then os.execute("uci set mwan3.globals.keepalive_ip1=" .. keepalive_addr1) end
        if keepalive_addr2 then os.execute("uci set mwan3.globals.keepalive_ip2=" .. keepalive_addr2) end
        os.execute("uci commit mwan3")
        os.execute("uci commit network")
        return true
    end
    
    return true
end

-- ==========================================================
-- 边缘计算配置
-- ==========================================================

-- 12. Edge Config - 边缘计算基本配置 (Moved to top)

function _M.get_edge_config()
    local enable = 0
    local f = io.popen("uci get edge.@edge[0].enable 2>/dev/null")
    if f then
        local content = f:read("*a")
        f:close()
        if content then
            enable = tonumber(content) or 0
        end
    end
    return {
        all_en = enable,
        refresh_frequency = 100,
        calc_period = 100,
        poll_interval = 100
    }
end

function _M.set_edge_config(args)
    local enable = nil
    for k, v in pairs(args) do
        if k == "n_all_en" then
            enable = tonumber(v)
        end
    end
    
    if enable ~= nil then
        os.execute("uci set edge.@edge[0].enable=" .. enable)
        os.execute("uci commit edge")
    end
    return true
end

-- 13. Edge Report Config - 数据上报配置 (Moved to top)

function _M.get_edge_report_config()
    local config = { group = {} }
    
    -- Read groups from /etc/config/device/edge_report/
    local p = io.popen("ls /etc/config/device/edge_report/*.json 2>/dev/null")
    if p then
        for file_path in p:lines() do
            local content = read_file(file_path)
            if content then
                local ok, g = pcall(cjson.decode, content)
                if ok then
                    -- Resolve template
                    -- Template content is now fetched via /download_multi_file.cgi
                    table.insert(config.group, g)
                end
            end
        end
        p:close()
    end
    
    return config
end

function _M.set_edge_report_config(data)
    if data and data.group then
        edge_report_config.group = data.group
    end
    return true
end

-- 14. Edge Access Config - 协议转换访问配置 (Moved to top)

function _M.get_edge_access_config()
    local config = { group = {} }
    
    -- Read from /etc/config/device/edge_access/
    local p = io.popen("ls /etc/config/device/edge_access/*.json 2>/dev/null")
    if p then
        for file_path in p:lines() do
            local content = read_file(file_path)
            if content then
                local ok, g = pcall(cjson.decode, content)
                if ok then
                    table.insert(config.group, g)
                end
            end
        end
        p:close()
    end
    
    -- Update local cache
    edge_access_config = config
    
    return config
end

function _M.set_edge_access_config(data)
    if data and data.group then
        edge_access_config.group = data.group
    end
    return true
end


-- 15. Edge Link Control Config - 链路控制配置 (Moved to top)

function _M.get_edge_link_ctrl_config()
    return edge_link_ctrl_config
end

function _M.set_edge_link_ctrl_config(data)
    if data and data.group then
        edge_link_ctrl_config.group = data.group
    end
    return true
end

-- 16. Edge Points Data - 边缘计算点位数据 (CSV格式)
local edge_points_csv = "V,V1.0,N7X0,;\nSC,Device1,1,2,1,100,0,0,192.168.0.21:2100,Device1,;\n"

function _M.get_edge_points_csv()
    return edge_points_csv
end

function _M.set_edge_points_csv(content)
    edge_points_csv = content
    return true
end

-- 17. Edge Proto Access Data - 协议转换点位数据 (CSV格式)
local edge_proto_access_csv = "S,1,6,10,ModBusTCP\nC,node01,Device1,18,00001"

function _M.get_edge_proto_access_csv()
    return edge_proto_access_csv
end

function _M.set_edge_proto_access_csv(content)
    edge_proto_access_csv = content
    return true
end

-- 18. Upgrade Firmware
function _M.upgrade_firmware(reset_factory)
    ngx.log(ngx.INFO, "Triggering firmware upgrade via ubus... reset_factory=" .. tostring(reset_factory))
    local result = ubus_call("hilink", "upgrade_firmware", { reset_factory = reset_factory })
    if result and result.result then
        return true
    else
        return false, (result and result.error) or "Unknown error"
    end
end

-- 19. Get Edge Values (Real-time data from SHM)
function _M.get_edge_values()
    local result = ubus_call("hilink", "get_edge_values", {})
    if result and result.result then
        return result.data
    end
    return nil
end

-- 20. Factory Reset
function _M.factory_reset()
    ngx.log(ngx.INFO, "Triggering factory reset via ubus...")
    local result = ubus_call("hilink", "factory_reset", {})
    if result and result.result then
        return true
    else
        return false, (result and result.error) or "Unknown error"
    end
end

return _M