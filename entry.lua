-- /usr/lib/lua/web_backend/entry.lua
local cjson = require "cjson"
local ubus_adapter = require "ubus_adapter" -- Import the adapter

-- ==========================================================
-- 1. 基础工具函数
-- ==========================================================

-- 标准 JSON 响应封装
local function send_json(data)
    local json_str = cjson.encode(data)
    ngx.log(ngx.ERR, "[DEBUG] send_json response: ", json_str)
    ngx.say(json_str)
    ngx.exit(ngx.HTTP_OK)
end

-- 发送错误响应
local function send_error(msg)
    ngx.log(ngx.ERR, "[DEBUG] send_error: ", msg)
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
            data = file:read("*a")
            file:close()
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

-- 保存文件到系统
local function save_file_to_system(filename, content)
    local path = "/etc/edge_gateway/" .. filename
    -- Ensure directory exists (optional, depending on environment)
    -- os.execute("mkdir -p /etc/edge_gateway/")
    local file = io.open(path, "w+")
    if not file then return false, "Cannot open file" end
    file:write(content)
    file:close()
    return true
end

-- 通知 C 核心进程 (IPC)
local function notify_core_process(module_name)
    -- 模拟 Ubus 调用
    -- os.execute("ubus call edge_core reload { module = '".. module_name .."' }")
    ngx.log(ngx.INFO, "IPC Notify: Reloading " .. module_name)
end

-- ==========================================================
-- 2. 业务逻辑处理模块 (Controllers)
-- ==========================================================

-- 处理 /download_nv.cgi (获取静态配置)
local function handle_download_nv(args)
    ngx.log(ngx.ERR, "[DEBUG] handle_download_nv args: ", cjson.encode(args))
    local name = args.name
    local response = {}

    if name == "misc" then
        response = ubus_adapter.get_misc_config()
        
    elseif name == "network" then
        response = ubus_adapter.get_network_config()
        
    elseif name == "comm_tunnel" then
        response = ubus_adapter.get_comm_tunnel_config()
        
    elseif name == "uart" then
        response = ubus_adapter.get_uart_config()
        
    elseif name == "offline_cache" then
        response = ubus_adapter.get_offline_cache_config()
    end

    -- Ensure response is not nil
    if not response then response = {} end
    
    send_json(response)
end

-- 处理 /download_flex.cgi (获取动态状态)
local function handle_download_flex(args)
    ngx.log(ngx.ERR, "[DEBUG] handle_download_flex args: ", cjson.encode(args))
    local name = args.name
    local response = {}

    if name == "status" then
        response = ubus_adapter.get_status()
        
    elseif name == "network" then
        response = ubus_adapter.get_network_status()
    end

    -- Ensure response is not nil
    if not response then response = {} end

    send_json(response)
end

-- 处理 /update_nv.cgi (保存配置)
local function handle_update_nv(args)
    ngx.log(ngx.ERR, "[DEBUG] handle_update_nv args: ", cjson.encode(args))
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
    ngx.log(ngx.ERR, "[DEBUG] handle_download_file args: ", cjson.encode(args))
    local name = args.name
    local content = ""
    
    if name == "edge" then
        -- 读取 /etc/edge_gateway/points.csv
        -- content = read_file("/etc/edge_gateway/points.csv")
        content = "V,V1.0,N7X0,;\nSC,Device1,234,2,1,100,0,0,192.168.0.21:2100,Device1,;\n"
    elseif name == "edge_proto_access" then
        content = "S,1,6,10,ModBusTCP\nC,node01,Device1,18,00001"
    end
    
    -- 直接输出文本内容，非 JSON
    ngx.header.content_type = "text/plain"
    ngx.print(content)
    ngx.exit(ngx.HTTP_OK)
end

-- 处理 /upload/* (文件上传)
local function handle_upload(uri)
    ngx.log(ngx.ERR, "[DEBUG] handle_upload uri: ", uri)
    local body = get_request_body()
    if not body then
        send_error("Empty body")
        return
    end

    -- 注意：这里是一个简化的 Multipart 解析
    -- 实际 POST 请求包含 boundary，可以通过 lua-resty-upload 库完美解析
    -- 这里假设我们只关心内容，或者进行简单的字符串截取找到实际 payload
    
    local content = body -- 暂时简化，实际需提取 payload
    
    if string.find(uri, "/upload/edge") then
        -- 3.2 边缘计算点位 CSV
        save_file_to_system("points.csv", content)
        notify_core_process("edge_points")
        
    elseif string.find(uri, "/upload/nv1") or string.find(uri, "/upload/nv2") then
        -- 3.3 Socket 链接同步 (Filename: link) 或 上报策略 (Filename: edge_report)
        -- 这种请求通常混合了二进制头，需要清洗
        local clean_json = strip_binary_prefix(content)
        
        -- 根据内容判断是 Link 还是 Report (或者根据 Header 中的 filename)
        if string.find(clean_json, "tcpc") then
            save_file_to_system("link_config.json", clean_json)
            notify_core_process("link_sync")
        elseif string.find(clean_json, "group") then
            save_file_to_system("report_strategy.json", clean_json)
            notify_core_process("report_strategy")
        end
        
    elseif string.find(uri, "/upload/template") then
        -- 3.4 上报模板
        save_file_to_system("report_template.json", content)
        notify_core_process("report_template")
        
    elseif string.find(uri, "/upload/conver_csv") then
        -- 4.2 协议转换 CSV
        save_file_to_system("proto_map.csv", content)
        notify_core_process("proto_map")
        
    elseif string.find(uri, "/upload/scert") then
        -- MQTT 服务器证书上传
        ngx.log(ngx.ERR, "[DEBUG] Uploading MQTT server certificate")
        -- 这里简化处理，实际应该保存到系统路径
        save_file_to_system("mqtt_server_cert.pem", content)
        notify_core_process("mqtt_server_cert")
        
    elseif string.find(uri, "/upload/ccert") then
        -- MQTT 客户端证书上传
        ngx.log(ngx.ERR, "[DEBUG] Uploading MQTT client certificate")
        save_file_to_system("mqtt_client_cert.pem", content)
        notify_core_process("mqtt_client_cert")
        
    elseif string.find(uri, "/upload/ckey") then
        -- MQTT 客户端私钥上传
        ngx.log(ngx.ERR, "[DEBUG] Uploading MQTT client key")
        save_file_to_system("mqtt_client_key.pem", content)
        notify_core_process("mqtt_client_key")
    end

    send_success()
end

-- 处理 /action_restart.cgi
local function handle_restart()
    ngx.log(ngx.ERR, "[DEBUG] handle_restart triggered")
    -- 立即返回成功，然后重启
    ngx.say(cjson.encode({ err = 0 }))
    ngx.flush(true)
    -- 执行重启
    os.execute("sleep 1 && reboot &")
    ngx.exit(ngx.HTTP_OK)
end

-- ==========================================================
-- 3. 主路由入口
-- ==========================================================

local uri = ngx.var.uri
local method = ngx.req.get_method()
local args = ngx.req.get_uri_args() -- 获取 GET 参数

ngx.log(ngx.ERR, "[DEBUG] Incoming Request: ", method, " ", uri)
if next(args) then
    ngx.log(ngx.ERR, "[DEBUG] Request Args: ", cjson.encode(args))
end

-- 路由分发
if uri == "/download_nv.cgi" then
    handle_download_nv(args)

elseif uri == "/download_flex.cgi" then
    handle_download_flex(args)

elseif uri == "/update_nv.cgi" then
    handle_update_nv(args)

elseif uri == "/download_file.cgi" then
    handle_download_file(args)

elseif uri == "/action_restart.cgi" then
    handle_restart()

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
