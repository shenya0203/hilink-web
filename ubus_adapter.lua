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
        if content and content ~= "" then
            local res = string.gsub(content, "\n", "")
            if res ~= "" then return res end
        end
    end
    return nil
end

local _M = {}

-- ==========================================================
-- Ubus Adapter Module
-- ==========================================================

function _M.get_homepage_data()
    local result = ubus_call("hilink", "get_homepage_data", {})
    if result then
        return result
    end
    return nil
end

-- 1. Status Data
function _M.get_status()
    local result = ubus_call("hilink", "get_status", {})
    if result then
        return result
    end
    ngx.log(ngx.WARN, "ubus call failed for get_status")
    return nil
end

-- 2. Network Status Data
function _M.get_network_status()
    local result = ubus_call("hilink", "get_network_status", {})
    if result then
        return result
    end
    return nil
end

-- 3. Network Config Data (WAN/LTE)
function _M.get_network_config()
    -- 通过ubus接口从后端daemon获取WAN/LTE网络配置
    local result = ubus_call("hilink", "get_network_config_wan", {})
    if result then
        return result
    end
    return nil
end

-- 3.1 Network LAN Config Data (LAN + DHCP)
function _M.get_network_lan_config()
    -- 通过ubus接口从后端daemon获取LAN + DHCP网络配置
    local result = ubus_call("hilink", "get_network_config", {})
    if result then
        return result
    end
    return nil
end

-- 4. Misc Config Data (完整配置)
function _M.get_misc_config()
    -- 2. 调用 Daemon 接口 (对象名: hilink, 方法名: get_misc_config)
    -- 第三个参数是参数表，get请求通常为空表 {}
    local res = ubus_call("hilink", "get_misc_config", {})
    -- 4. 处理结果
    if not res then
        return { error = "Failed to fetch config" }
    end

    -- res 已经是解码后的 Lua table 了
    return res
end

-- 5. Comm Tunnel Config
function _M.get_comm_tunnel_config()
    -- 通过ubus接口从后端daemon获取通讯通道配置
    local result = ubus_call("hilink", "get_comm_tunnel_config")
    if result then
        return result
    end
    -- 如果ubus调用失败，返回nil
    return nil
end

-- 6. UART Config
local uart_config = {
    UART = {
        { enable = 1, name = "Uart1", work_mode = 2,  baud_rate = 115200, data_bit = 8,     stop_bit = 1, parity = 0,   pack_len = 1460, pack_time = 0,   func = 1 },
        { enable = 1, select = 0,     name = "Uart2", work_mode = 2,      baud_rate = 9600, data_bit = 8, stop_bit = 1, parity = 0,      pack_len = 1460, pack_time = 0 }
    }
}

function _M.get_uart_config()
    -- 通过ubus接口从后端daemon获取串口配置
    local result = ubus_call("hilink", "get_uart_config")
    if result then
        return result
    end
    -- 如果ubus调用失败，返回本地默认配置
    --失败 不要返回数据 会令人迷惑
    return nil
end

-- 7. Offline cache config (状态由 ubus_daemon 管理)
function _M.get_offline_cache_config()
    local result = ubus_call("hilink", "get_offline_cache_config", {})
    if result then
        return result
    end
    return nil
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

-- 14. Edge Access Config - 协议转换访问配置 (状态由 ubus_daemon 管理)

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
        total = 16 * 1024 * 1024 * 1024, -- 16GB
        used = 2 * 1024 * 1024 * 1024    -- 2GB used
    }
end

-- 9. Format TF Card
function _M.format_tf_card()
    -- 模拟格式化TF卡
    -- 实际应该调用系统命令: os.execute("mkfs.vfat /dev/mmcblk0p1")
    return true
end

-- 10. Set System Time
function _M.set_system_time(timestamp)
    -- 设置系统时间

    local result = ubus_call("hilink", "set_system_time", { timestamp = timestamp })
    if result and result.result then
        return true
    else
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

        -- 构建配置对象
        local uart_config = { UART = uart_array }

        -- 通过ubus接口设置uart配置
        local result = ubus_call("hilink", "set_uart_config", uart_config)
        if result and result.result then
            return true
        else
            return false
        end
    end

    if module == "comm_tunnel" then
        -- 通过ubus接口设置通讯通道配置
        local result = ubus_call("hilink", "set_comm_tunnel_config", args)
        if result and result.result then
            return true
        else
            return false
        end
    end

    if module == "offline_cache" then
        local result = ubus_call("hilink", "set_offline_cache_config", args)
        if result and result.result then
            return true
        else
            return false
        end
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
            return result
        end

        return true
    end

    if module == "edge" then
        -- 处理边缘计算配置更新
        return _M.set_edge_config(args)
    end

    if module == "dtu" then
        return _M.set_dtu_config(args)
    end

    if module == "edge_access" then
        -- 在 adapter 侧完成参数解析，组装成结构化 group 数组传给 daemon
        local group = {}
        for k, v in pairs(args) do
            local type_prefix, index, key = string.match(k, "([ns])_group%[(%d+)%]%.(.+)")
            if index and key then
                index = tonumber(index) + 1
                if not group[index] then
                    group[index] = { up = {}, down = {} }
                end
                local val = v
                if type_prefix == "n" then val = tonumber(v) or 0 end
                local sub_key, sub_prop = string.match(key, "([^%.]+)%.([^%.]+)")
                if sub_key and sub_prop then
                    if not group[index][sub_key] then
                        group[index][sub_key] = {}
                    end
                    group[index][sub_key][sub_prop] = val
                else
                    group[index][key] = val
                end
            end
        end

        local result = ubus_call("hilink", "set_edge_access_config", { group = group })
        if result and result.result then
            return true
        else
            return false
        end
    end

    if module == "network" then
        -- UCI 操作已迁移到 ubus_daemon 的 apply_network_config_to_uci 函数
        local result = ubus_call("hilink", "set_network_config", args)
        if result and result.result then
            return true
        else
            return false
        end
    end

    return true
end

-- ==========================================================
-- 边缘计算配置
-- ==========================================================

-- 12. Edge Config - 边缘计算基本配置 (Moved to top)

function _M.get_edge_config()
    -- UCI 读取已迁移到 ubus_daemon
    local result = ubus_call("hilink", "get_edge_config", {})
    if result then
        return result
    end
    return nil
end

function _M.get_dtu_config()
    local result = ubus_call("hilink", "get_dtu_config", {})
    if result then
        return result
    end
    return nil
end

function _M.set_dtu_config(args)
    local result = ubus_call("hilink", "set_dtu_config", args)
    if result and result.result then
        return true
    else
        return false
    end
end

function _M.set_edge_config(args)
    -- UCI 写入已迁移到 ubus_daemon 的 set_edge_config_values
    local result = ubus_call("hilink", "set_edge_config", args)
    if result and result.result then
        return true
    else
        return false
    end
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


-- 14. Edge Access Config - 协议转换访问配置 (Moved to top)

function _M.get_edge_access_config()
    -- 文件读取已迁移到 ubus_daemon
    local result = ubus_call("hilink", "get_edge_access_config", {})
    if result then
        return result
    end
    return nil
end

function _M.set_edge_access_config(data)
    -- 此函数保留供直接调用，内部转发给 daemon
    local result = ubus_call("hilink", "set_edge_access_config", data or {})
    return result and result.result
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
    local result = ubus_call("hilink", "set_edge_points_csv", { content = content })
    return result and result.result
end

-- 17. Edge Proto Access Data - 协议转换点位数据 (CSV格式)
local edge_proto_access_csv = "S,1,6,10,ModBusTCP\nC,node01,Device1,18,00001"

function _M.get_edge_proto_access_csv()
    return edge_proto_access_csv
end

function _M.set_edge_proto_access_csv(content)
    local result = ubus_call("hilink", "set_edge_proto_access_csv", { content = content })
    return result and result.result
end

function _M.set_tpc_config(content)
    local result = ubus_call("hilink", "set_tpc_config", { content = content })
    return result and result.result
end

function _M.set_edge_report_config(group)
    local result = ubus_call("hilink", "set_edge_report_config", { group = group })
    return result and result.result
end

function _M.set_edge_template_config(content)
    local result = ubus_call("hilink", "set_edge_template_config", { content = content })
    return result and result.result
end

-- 18. Upgrade Firmware
function _M.upgrade_firmware(apply, reset_factory)
    local result = ubus_call("hilink", "upgrade_firmware", {
        apply = tonumber(apply) or 0,
        reset_factory = tonumber(reset_factory) or 0
    })
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
function _M.factory_reset(apply)
    local result = ubus_call("hilink", "factory_reset", { apply = tonumber(apply) or 1 })
    if result and result.result then
        return true
    else
        return false, (result and result.error) or "Unknown error"
    end
end

-- 21. Restart Service
function _M.restart_service(apply)
    local result = ubus_call("hilink", "restart_service", { apply = tonumber(apply) or 1 })
    if result and result.result then
        return true
    else
        return false, (result and result.error) or "Unknown error"
    end
end

function _M.download_cert_bundle(service)
    local result = ubus_call("hilink", "download_cert_bundle", { service = service })
    if result then
        return result
    end
    return nil
end

-- 22. WiFi Scan
function _M.wifi_scan(action)
    local result = ubus_call("hilink", "wifi_scan", { act = action })
    if result then
        return result
    end
    return nil
end

return _M
