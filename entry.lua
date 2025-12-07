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

-- 读取文件内容
local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        ngx.log(ngx.ERR, "[DEBUG] Cannot open file: ", path)
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

local function save_file_to_system(path, content)
    local file = io.open(path, "w+")
    if not file then 
        ngx.log(ngx.ERR, "[DEBUG] Cannot open file: ", path)
        return false, "Cannot open file" 
    else
        ngx.log(ngx.ERR, "[DEBUG] Open file: ", path)
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
    
    -- 从 Content-Disposition 头中提取 filename
    -- 格式: Content-Disposition: form-data; name="c"; filename="SOCK0"
    local filename_pattern = 'filename="([^"]+)"'
    local filename = string.match(body, filename_pattern)
    if filename then
        result.filename = filename
        ngx.log(ngx.ERR, "[DEBUG] Parsed filename: ", filename)
    end
    
    -- 提取文件内容 (在两个空行之后，到下一个 boundary 之前)
    -- multipart 格式: boundary\r\nheaders\r\n\r\ncontent\r\n--boundary
    local content_start = string.find(body, "\r\n\r\n")
    if content_start then
        local content = string.sub(body, content_start + 4)
        -- 去除尾部的 boundary
        local boundary_start = string.find(content, "\r\n%-%-")
        if boundary_start then
            content = string.sub(content, 1, boundary_start - 1)
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
    
    ngx.log(ngx.ERR, "[DEBUG] Certificate directory for ", filename, ": ", dir)
    return dir
end

local function save_group_config(content)
    save_file_to_system("/etc/config/device/group.json", content)
end

local function save_tpc_config(content)
    save_file_to_system("/etc/config/device/tpc.json", content)
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
    ngx.log(ngx.ERR, "[DEBUG] Saving certificate to: ", path)
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
        content = read_file("/etc/config/device/points.csv") or "V,V1.0,N7X0,;"
    elseif name == "edge_proto_access" then
        content = "S,1,6,10,ModBusTCP\nC,node01,Device1,18,00001"
    end

    ngx.log(ngx.ERR, "[DEBUG] handle_download_file content: ", content)
    
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

    -- 解析 multipart form-data 获取 filename 和内容
    local parsed = parse_multipart(body)
    local target_name = parsed.filename  -- SOCK0, SOCK1, MQTT0, MQTT1
    local content = parsed.content or body
    
    ngx.log(ngx.ERR, "[DEBUG] Parsed target: ", target_name or "nil")
    
    if string.find(uri, "/upload/edge") then
        -- 3.2 边缘计算点位 CSV
        --[[
            CSV 格式：
            V,V1.0,N7X0,;
            SC,Device1,234,2,1,100,0,0,192.168.0.222:2100,Device1,;
            C,Device1,Device1_state,,18,0,0,0,0,0,0,,State,0,0,0,0,0,0,,;
            V开头的 表示虚拟设备
        ]]--
        save_points_csv(content)
        notify_core_process("edge_points")
        
    elseif string.find(uri, "/upload/nv1") or string.find(uri, "/upload/nv2") then
        -- 3.3 Socket 链接同步 (Filename: link) 或 上报策略 (Filename: edge_report)
        local clean_json = strip_binary_prefix(content)
        
        if string.find(clean_json, "tcpc") then
            save_tpc_config(clean_json)
            notify_core_process("link_sync")
        elseif string.find(clean_json, "group") then
            save_group_config(clean_json)
            notify_core_process("report_strategy")
        end
    elseif string.find(uri, "/upload/template") then
        -- 3.4 上报模板
        save_file_to_system("/etc/config/device/report_template.json", content)
        notify_core_process("report_template")
        
    elseif string.find(uri, "/upload/conver_csv") then
        -- 4.2 协议转换 CSV
        save_file_to_system("proto_map.csv", content)
        notify_core_process("proto_map")
        
    elseif string.find(uri, "/upload/scert") then
        -- 服务器证书上传 (根据 filename 区分 SOCK0/SOCK1/MQTT0/MQTT1)
        ngx.log(ngx.ERR, "[DEBUG] Uploading server certificate for: ", target_name or "unknown")
        if target_name then
            save_cert_file(target_name, "server_cert.pem", content)
        end
        notify_core_process("server_cert")
        
    elseif string.find(uri, "/upload/ccert") then
        -- 客户端证书上传 (根据 filename 区分 SOCK0/SOCK1/MQTT0/MQTT1)
        ngx.log(ngx.ERR, "[DEBUG] Uploading client certificate for: ", target_name or "unknown")
        if target_name then
            save_cert_file(target_name, "client_cert.pem", content)
        end
        notify_core_process("client_cert")
        
    elseif string.find(uri, "/upload/ckey") then
        -- 客户端私钥上传 (根据 filename 区分 SOCK0/SOCK1/MQTT0/MQTT1)
        ngx.log(ngx.ERR, "[DEBUG] Uploading client key for: ", target_name or "unknown")
        if target_name then
            save_cert_file(target_name, "client_key.pem", content)
        end
        notify_core_process("client_key")
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

-- 处理 /action_tf.cgi (TF卡操作)
local function handle_tf_action(args)
    ngx.log(ngx.ERR, "[DEBUG] handle_tf_action args: ", cjson.encode(args))
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
    ngx.log(ngx.ERR, "[DEBUG] handle_time_action args: ", cjson.encode(args))
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
    ngx.log(ngx.ERR, "[DEBUG] handle_reset args: ", cjson.encode(args))
    local act = args.act
    
    if act == "factory" then
        ngx.say(cjson.encode({ err = 0 }))
        ngx.flush(true)
        -- 执行恢复出厂设置
        os.execute("sleep 1 && factory_reset &")
        ngx.exit(ngx.HTTP_OK)
    else
        send_error("Unknown action")
    end
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

elseif uri == "/action_tf.cgi" then
    handle_tf_action(args)

elseif uri == "/action_time.cgi" then
    handle_time_action(args)

elseif uri == "/action_reset.cgi" then
    handle_reset(args)

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

