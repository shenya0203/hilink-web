-- /usr/lib/lua/web_backend/entry.lua
local cjson = require "cjson"
local ubus_adapter = require "ubus_adapter" -- Import the adapter

-- ==========================================================
-- 1. 基础工具函数
-- ==========================================================

-- 标准 JSON 响应封装
local function send_json(data)
    local json_str = cjson.encode(data)
    ngx.say(json_str)
    ngx.exit(ngx.HTTP_OK)
end

-- 发送错误响应
local function send_error(msg)
    ngx.say(cjson.encode({ err = 1, msg = msg }))
    ngx.exit(ngx.HTTP_OK)
end

-- 成功响应
local function send_success()
    ngx.say(cjson.encode({ err = 0 }))
    ngx.exit(ngx.HTTP_OK)
end

-- 获取请求 Body (用于文件上传)
local function get_request_body()
    ngx.req.read_body()
    local data = ngx.req.get_body_data()
    if not data then
        local filepath = ngx.req.get_body_file()
        if filepath then
            local file = io.open(filepath, "rb")
            if file then
                data = file:read("*a")
                file:close()
            end
        end
    end
    return data
end

-- 去除二进制前缀 (针对 ¹¼k{...} 这种格式)
local function strip_binary_prefix(content)
    local start_idx = string.find(content, "{")
    if start_idx then
        return string.sub(content, start_idx)
    end
    return content -- 如果没找到 {，可能就是纯 CSV 或其他格式
end

-- 读取文件内容
local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        --ngx.log(ngx.ERR, "[DEBUG] Cannot open file: ", path)
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

local function save_file_to_system(path, content)
    local file = io.open(path, "w+")
    if not file then
        return false, "Cannot open file"
    end
    file:write(content)
    file:close()
    return true
end

-- 解析 multipart form-data 提取 filename 和文件内容
local function parse_multipart(body)
    local result = {
        filename = nil,
        content = nil
    }

    -- 1. 获取请求头中的 Content-Type 以提取真实的 boundary
    local content_type = ngx.req.get_headers()["Content-Type"] or ngx.req.get_headers()["content-type"]
    local boundary = nil
    if content_type then
        boundary = string.match(content_type, "boundary=([^;]+)")
        if boundary then
            -- 去除可能附带的双引号和首尾空格
            boundary = string.gsub(boundary, '"', '')
            boundary = string.gsub(boundary, '^%s*(.-)%s*$', '%1')
        end
    end

    -- 2. 从 Content-Disposition 头中提取 filename
    local filename_pattern = 'filename="([^"]+)"'
    local filename = string.match(body, filename_pattern)
    if filename then
        result.filename = filename
    end

    -- 3. 提取文件内容 (在两个空行之后，到下一个 boundary 之前)
    -- multipart 格式: boundary\r\nheaders\r\n\r\ncontent\r\n--boundary
    local content_start = string.find(body, "\r\n\r\n")
    if content_start then
        local content = string.sub(body, content_start + 4)

        -- 4. 去除尾部的 boundary
        if boundary and boundary ~= "" then
            -- 真实 boundary 在 body 里是以 -- 开头的，例如 \r\n--boundary...
            local full_boundary = "\r\n--" .. boundary
            -- 第四个参数 true 表示禁用模式匹配，当作纯文本查找 (plain search)
            local boundary_start = string.find(content, full_boundary, 1, true)
            if boundary_start then
                content = string.sub(content, 1, boundary_start - 1)
            end
        else
            -- 降级方案：如果没有在请求头拿到 boundary，为了防止误杀证书里中间的 \r\n--
            -- 退回到从后往前找最后一个匹配
            local last_match = nil
            local start_idx = 1
            while true do
                local s, e = string.find(content, "\r\n%-%-", start_idx)
                if not s then break end
                last_match = s
                start_idx = e + 1
            end
            if last_match then
                content = string.sub(content, 1, last_match - 1)
            end
        end

        result.content = content
    else
        result.content = body
    end

    return result
end

-- 根据 filename 获取证书存放目录
local function get_cert_directory(filename, cert_type)
    -- filename 格式: SOCK0, SOCK1, MQTT0, MQTT1
    local dir_map = {
        SOCK0 = "/etc/config/cert/SOCKA/",
        SOCK1 = "/etc/config/cert/SOCKB/",
        MQTT1 = "/etc/config/cert/MQTT1/",
        MQTT2 = "/etc/config/cert/MQTT2/"
    }

    local dir = dir_map[filename]
    if not dir then
        -- 默认目录
        dir = "/etc/config/cert/"
    end

    return dir
end

local function save_group_config(content)
    save_file_to_system("/etc/config/device/group.json", content)
end


local function save_points_csv(content)
    save_file_to_system("/etc/config/device/points.csv", content)
end

-- 保存证书文件到指定目录
local function save_cert_file(filename, cert_name, content)
    local dir = get_cert_directory(filename, cert_name)
    local path = dir .. cert_name

    -- 确保目录存在
    --os.execute("mkdir -p " .. dir)

    -- 如果存在 则需要删除文件内容重写文件
    local file = io.open(path, "w+")
    if not file then
        ngx.log(ngx.ERR, "[DEBUG] Cannot open file: ", path)
        return false, "Cannot open file"
    end
    file:write(content)
    file:close()
    return true
end

-- 通知 C 核心进程 (IPC)
local function notify_core_process(module_name)
    -- 模拟 Ubus 调用
    -- os.execute("ubus call edge_core reload { module = '".. module_name .."' }")
end

-- ==========================================================
-- 2. 业务逻辑处理模块 (Controllers)
-- ==========================================================

-- 处理 /download_cert_bundle.cgi
local function handle_download_cert_bundle(args)
    local service = args.service
    if not service then
        send_error("Missing service parameter")
        return
    end

    local response = ubus_adapter.download_cert_bundle(service)
    if not response then
        send_error("Failed to fetch cert bundle")
        return
    end

    send_json(response)
end

-- 处理 /download_nv.cgi (获取静态配置)
local function handle_download_nv(args)
    local name = args.name
    local response = {}

    if name == "misc" then
        response = ubus_adapter.get_misc_config()
    elseif name == "network" then
        response = ubus_adapter.get_network_config()
    elseif name == "network_lan" then
        response = ubus_adapter.get_network_lan_config()
    elseif name == "comm_tunnel" then
        response = ubus_adapter.get_comm_tunnel_config()
    elseif name == "uart" then
        response = ubus_adapter.get_uart_config()
    elseif name == "offline_cache" then
        response = ubus_adapter.get_offline_cache_config()
    elseif name == "edge" then
        response = ubus_adapter.get_edge_config()
    elseif name == "edge_report" then
        response = ubus_adapter.get_edge_report_config()
    elseif name == "edge_access" then
        response = ubus_adapter.get_edge_access_config()
    elseif name == "edge_link_ctrl" then
        response = ubus_adapter.get_edge_link_ctrl_config()
    end

    -- Ensure response is not nil
    if not response then response = {} end

    send_json(response)
end

-- 处理 /download_flex.cgi (获取动态状态)
local function handle_download_flex(args)
    local name = args.name
    local response = {}

    if name == "status" then
        response = ubus_adapter.get_status()
    elseif name == "network" then
        response = ubus_adapter.get_network_status()
    elseif name == "edge_values" then
        response = ubus_adapter.get_edge_values()
    elseif name == "all" then
        response = ubus_adapter.get_homepage_data()
    end

    -- Ensure response is not nil
    if not response then response = {} end

    send_json(response)
end

-- 处理 /update_nv.cgi (保存配置)
local function handle_update_nv(args)
    local file = args.file

    if not file then
        send_error("Missing file parameter")
        return
    end

    -- Call adapter to save config
    local success = ubus_adapter.set_config(file, args)

    if success then
        -- Notify core process if needed
        notify_core_process(file)
        send_success()
    else
        send_error("Failed to save config")
    end
end

-- 处理 /download_file.cgi (下载文件)
local function handle_download_file(args)
    local name = args.name
    local content = ""

    if name == "edge" then
        content = read_file("/etc/config/device/points.csv")
        if not content or content == "" then content = "V,V1.0,N7X0,;" end
    elseif name == "edge_proto_access" then
        content = read_file("/etc/config/device/edge_access/edge_proto_access")
        if not content or content == "" then content = "S,1,6,10,ModBusTCP" end
    end

    --ngx.log(ngx.ERR, "[DEBUG] handle_download_file content: ", content)

    -- 直接输出文本内容，非 JSON
    ngx.header.content_type = "text/plain"
    ngx.print(content)
    ngx.exit(ngx.HTTP_OK)
end

-- 处理 /download_multi_file.cgi (批量下载文件)
local function handle_download_multi_file(args)
    local names = args.name
    local response = {}

    -- Ensure names is a table (array)
    if type(names) ~= "table" then
        names = { names }
    end

    local is_template = false
    local target_files = {}

    for _, name in ipairs(names) do
        if name == "template" then
            is_template = true
        else
            table.insert(target_files, name)
        end
    end

    if is_template then
        for _, file_name in ipairs(target_files) do
            local path = "/etc/config/device/template/" .. file_name .. ".json"
            local content = read_file(path)
            if content then
                -- Try to decode JSON to ensure validity, or just send as string?
                -- User requested: "Report0": { ... } (JSON object)
                -- So we should decode the file content if it's JSON string
                local ok, json_data = pcall(cjson.decode, content)
                if ok then
                    response[file_name] = json_data
                else
                    -- If not valid JSON, maybe send as string or ignore?
                    -- Assuming valid JSON for now as per user description
                    response[file_name] = content
                end
            end
        end
    end

    send_json(response)
end

-- 处理 /upload/* (文件上传)
local function handle_upload(uri)
    local body = get_request_body()
    if not body then
        send_error("Empty body")
        return
    end

    -- 解析 multipart form-data 获取 filename 和内容
    local parsed = parse_multipart(body)
    local target_name = parsed.filename -- SOCK0, SOCK1, MQTT0, MQTT1
    local content = parsed.content or body

    if string.find(uri, "/upload/edge") then
        -- 3.2 边缘计算点位 CSV
        --[[
            CSV 格式：
            V,V1.0,N7X0,;
            SC,Device1,234,2,1,100,0,0,192.168.0.222:2100,Device1,;
            C,Device1,Device1_state,,18,0,0,0,0,0,0,,State,0,0,0,0,0,0,,;
            V开头的 表示虚拟设备
        ]] --

        if ubus_adapter.set_edge_proto_access_csv(content) then
            -- Note: set_edge_proto_access_csv in daemon already saves and reloads
            send_success()
        else
            send_error("Failed to save edge points via ubus")
        end
        return -- Response already sent
    elseif string.find(uri, "/upload/nv1") or string.find(uri, "/upload/nv2") then
        -- 3.3 Socket 链接同步 (Filename: link) 或 上报策略 (Filename: edge_report)
        local clean_json = strip_binary_prefix(content)

        if string.find(clean_json, "tcpc") then
            -- 调用 ubus 接口保存 TCP 配置
            if ubus_adapter.set_tpc_config(clean_json) then
                ngx.log(ngx.INFO, "TPC config saved via ubus")
            end
        elseif string.find(clean_json, "group") then
            -- 调用 ubus 接口保存上报策略 (内部处理分拆逻辑)
            local data = cjson.decode(clean_json)
            if data and data.group then
                if ubus_adapter.set_edge_report_config(data.group) then
                    ngx.log(ngx.INFO, "Edge report strategy saved via ubus")
                end
            end
        end
    elseif string.find(uri, "/upload/template") then
        -- 3.4 上报模板 (内部处理拆分逻辑)
        if ubus_adapter.set_edge_template_config(content) then
            ngx.log(ngx.INFO, "Report template saved via ubus")
        end
    elseif string.find(uri, "/upload/conver_csv") then
        -- 4.2 协议转换 CSV
        os.execute("mkdir -p /etc/config/device/edge_access")
        save_file_to_system("/etc/config/device/edge_access/edge_proto_access", content)
        notify_core_process("proto_map")
    elseif string.find(uri, "/upload/scert") then
        -- 服务器证书上传 (根据 filename 区分 SOCK0/SOCK1/MQTT0/MQTT1)
        if target_name then
            save_cert_file(target_name, "server_cert.pem", content)
        end
        notify_core_process("server_cert")
    elseif string.find(uri, "/upload/ccert") then
        -- 客户端证书上传 (根据 filename 区分 SOCK0/SOCK1/MQTT0/MQTT1)
        if target_name then
            save_cert_file(target_name, "client_cert.pem", content)
        end
        notify_core_process("client_cert")
    elseif string.find(uri, "/upload/ckey") then
        -- 客户端私钥上传 (根据 filename 区分 SOCK0/SOCK1/MQTT0/MQTT1)
        if target_name then
            save_cert_file(target_name, "client_key.pem", content)
        end
        notify_core_process("client_key")
    elseif string.find(uri, "/upload/firmware") then
        -- 固件上传
        -- 保存到 /tmp/firmware.bin
        save_file_to_system("/tmp/firmware.bin", content)
    end

    send_success()
end

-- 处理 /action_restart.cgi
local function handle_restart()
    -- 立即返回成功，然后重启
    ngx.say(cjson.encode({ err = 0 }))
    ngx.flush(true)
    -- 执行重启
    os.execute("sleep 1 && reboot &")
    ngx.exit(ngx.HTTP_OK)
end

-- 处理 /action_restart_service.cgi
local function handle_restart_service()
    local args = ngx.req.get_uri_args(0)
    local apply = tonumber(args.apply) or 1
    local success, msg = ubus_adapter.restart_service(apply)
    if success then
        send_success()
    else
        send_error(msg or "Failed to restart service")
    end
end

-- 处理 /action_tf.cgi (TF卡操作)
local function handle_tf_action(args)
    local act = args.act
    local response = {}

    if act == "getinfo" then
        -- 获取TF卡信息
        response = ubus_adapter.get_tf_info()
    elseif act == "format" then
        -- 格式化TF卡
        local success = ubus_adapter.format_tf_card()
        if success then
            response = { err = 0 }
        else
            response = { err = 1, msg = "Format failed" }
        end
    else
        response = { err = 1, msg = "Unknown action" }
    end

    send_json(response)
end

-- 处理 /action_time.cgi (时间操作)
local function handle_time_action(args)
    local act = args.act
    local timestamp = tonumber(args.time)
    local response = {}

    if act == "sync" or act == "set" then
        if timestamp then
            -- 设置系统时间
            local success = ubus_adapter.set_system_time(timestamp)
            if success then
                response = { err = 0 }
            else
                response = { err = 1, msg = "Failed to set time" }
            end
        else
            response = { err = 1, msg = "Invalid timestamp" }
        end
    else
        response = { err = 1, msg = "Unknown action" }
    end

    send_json(response)
end

-- 处理 /action_reset.cgi (恢复出厂)
local function handle_reset(args)
    local act = args.act

    if act == "factory" then
        local apply = tonumber(args.apply) or 1
        local success, msg = ubus_adapter.factory_reset(apply)
        if success then
            ngx.say(cjson.encode({ err = 0 }))
        else
            send_error(msg or "Failed to factory reset")
        end
        ngx.exit(ngx.HTTP_OK)
    else
        send_error("Unknown action")
    end
end

-- 处理 /action_upgrade.cgi (固件升级)
local function handle_upgrade(args)
    local reset_factory = tonumber(args.reset_factory) or 0
    local apply = tonumber(args.apply) or 1 -- 默认值为1以保持对旧前端调用方式的一定兼容性

    -- 调用 ubus 触发升级
    local success, msg = ubus_adapter.upgrade_firmware(apply, reset_factory)

    if success then
        send_success()
    else
        send_error(msg or "Failed to start upgrade")
    end
end

-- 处理 /action_wifi.cgi (WiFi扫描)
local function handle_wifi_scan(args)
    local act = args.act

    if not act then
        send_error("Missing act parameter")
        return
    end

    -- 调用 ubus 触发WiFi扫描
    local result = ubus_adapter.wifi_scan(act)

    if result then
        send_json(result)
    else
        send_error("WiFi scan failed")
    end
end

-- ==========================================================
-- 3. 主路由入口
-- ==========================================================

local uri = ngx.var.uri
local method = ngx.req.get_method()
local args = ngx.req.get_uri_args(0) -- 获取 GET 参数

-- 路由分发
if uri == "/download_cert_bundle.cgi" then
    handle_download_cert_bundle(args)
elseif uri == "/download_nv.cgi" then
    handle_download_nv(args)
elseif uri == "/download_flex.cgi" then
    handle_download_flex(args)
elseif uri == "/update_nv.cgi" then
    handle_update_nv(args)
elseif uri == "/download_file.cgi" then
    handle_download_file(args)
elseif uri == "/download_multi_file.cgi" then
    handle_download_multi_file(args)
elseif uri == "/action_restart.cgi" then
    handle_restart()
elseif uri == "/action_restart_service.cgi" then
    handle_restart_service()
elseif uri == "/action_tf.cgi" then
    handle_tf_action(args)
elseif uri == "/action_time.cgi" then
    handle_time_action(args)
elseif uri == "/action_reset.cgi" then
    handle_reset(args)
elseif uri == "/action_upgrade.cgi" then
    handle_upgrade(args)
elseif uri == "/action_wifi.cgi" then
    handle_wifi_scan(args)

    -- 匹配 /upload/ 开头的 URI
elseif string.sub(uri, 1, 8) == "/upload/" then
    if method == "POST" then
        handle_upload(uri)
    else
        send_error("Method not allowed")
    end
else
    ngx.status = 404
    ngx.say("Not Found")
    ngx.exit(404)
end
