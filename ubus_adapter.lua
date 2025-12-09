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

local _M = {}

-- ==========================================================
-- Ubus Adapter Module
-- ==========================================================

-- 1. Status Data
function _M.get_status()
    return {
        systime = os.time(),
        runtime = 1575947,
        cloud_sta = 1,
        socketa_sta = 0,
        socketb_sta = 0,
        mqtt1_sta = 0,
        mqtt2_sta = 0,
        soft_ver = "V1.0.13.000000.0000",
        mac = "D4AD20DBBF2F",
        sn = "03300225101400005387",
        user_sn = "ÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿ"
    }
end

-- 2. Network Status Data
function _M.get_network_status()
    return {
        netdev = "EtherNET",
        eth = {
            link_sta = 1, ip_mode = 0, ip = "192.168.2.177",
            dns = "223.5.5.5", sdns = "223.6.6.6", netmask = "255.255.255.0"
        },
        lte = {
            ver = "16009.1037.00.01.53.05", iccid = "89861125204091384377",
            imei = "868892078327435", csq = 21, mode = "4G", oper = 1, sim = 1,
            cimi = "460113957693001", lte_sta = "Connected", lte_ip = "10.42.78.154",
            lte_netmask = "255.255.255.255", lte_dns = "202.96.128.86", lte_sdns = "202.96.134.133"
        }
    }
end

-- 3. Network Config Data
function _M.get_network_config()
    return {
        net_select = 0, keepalive_period = 10,
        keepalive_addr = {"223.5.5.5", "8.8.8.8"},
        eth0 = {
            ip_mode = 0, sip = "192.168.2.177", gip = "192.168.2.1",
            mip = "255.255.255.0", dns_mode = 0, dns_ip = {"223.5.5.5", "223.6.6.6"}
        },
        cell = {
            sim_switch = 2,
            apn = { addr = "", user = "", pswd = "", auth = 0 },
            dns_mode = 1, dns_ip = {"202.96.128.86", "202.96.134.133"}
        }
    }
end

-- 4. Misc Config Data (完整配置)
function _M.get_misc_config()
    return {
        web_lang = 2,
        host_name = "N720",
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
    -- 实际应该调用: os.execute("date -s @" .. timestamp)
    return true
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
        -- 处理misc配置更新
        ngx.log(ngx.INFO, "Updating misc config...")
        for k, v in pairs(args) do
            ngx.log(ngx.INFO, "misc: " .. k .. " = " .. tostring(v))
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

return _M