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

-- 4. Misc Config Data
function _M.get_misc_config()
    return { host_name = "N720", web_lang = 1 }
end

-- 5. Comm Tunnel Config
function _M.get_comm_tunnel_config()
    return {
        SOCK = {
            {
                enable = 1, name = "SOCKA", mode = 0,
                tcpc = { server_ip = "192.168.0.201", dns_timeout = 30, reconn_interval = 5,
                    server_port = 8234, local_port = 0, ssl_mode = 0, ssl_verify = 0,
                    ssl_server_name = "null", ssl_client_name = "null", ssl_client_key = "null",
                    regp_en = 0, regp_fmt = 0, regp_ctx = "", regp_tim = 0,
                    hrtp_en = 0, hrtp_fmt = 0, hrtp_ctx = "", hrtp_tim = 60 },
                tcps = { local_port = 8029, conn_max_num = 4, timeout_handling = 0, idle_handling = 0, idle_timeout = 3600 },
                udpc = { server_ip = "192.168.20.21", dns_timeout = 30, server_port = 1593, local_port = 0, ip_port_verify = 0 },
                httpc = { mode = 0, url = "/1.php?", header = "Accept:text/html", cut_header = 1,
                    server_ip = "test.usr.cn", server_port = 80, resp_timeout = 10, local_port = 0 }
            },
            {
                enable = 0, name = "SOCKB", mode = 0,
                tcpc = { server_ip = "192.168.0.201", dns_timeout = 30, reconn_interval = 5,
                    server_port = 8234, local_port = 0, ssl_mode = 0, ssl_verify = 0,
                    ssl_server_name = "null", ssl_client_name = "null", ssl_client_key = "null",
                    regp_en = 0, regp_fmt = 0, regp_ctx = "", regp_tim = 0,
                    hrtp_en = 0, hrtp_fmt = 0, hrtp_ctx = "", hrtp_tim = 60 },
                tcps = { local_port = 20108, conn_max_num = 4, timeout_handling = 0, idle_handling = 0, idle_timeout = 3600 },
                udpc = { server_ip = "192.168.20.21", dns_timeout = 30, server_port = 1593, local_port = 0, ip_port_verify = 0 },
                httpc = { mode = 0, url = "/1.php?", header = "Accept:text/html", cut_header = 1,
                    server_ip = "test.usr.cn", server_port = 80, resp_timeout = 10, local_port = 0 }
            }
        },
        MQTT = {
            {
                enable = 0, name = "MQTT1", mqtt_ver = 4, server_ip = "192.168.0.201",
                ssl_mode = 0, ssl_verify = 0, ssl_server_name = "null", ssl_client_name = "null", ssl_client_key = "null",
                loacl_port = 0, server_port = 1883, keepalive = 60, reconn_space = 5, clean_session = 0,
                client_id = "1234567", conn_verify = 0, conn_user_name = "", conn_user_password = "",
                will_flag = 0, will = { topic = "/will", msg = "offline", qos = 0, retention = 0 }
            },
            {
                enable = 0, name = "MQTT2", mqtt_ver = 4, server_ip = "192.168.0.201",
                ssl_mode = 0, ssl_verify = 0, ssl_server_name = "null", ssl_client_name = "null", ssl_client_key = "null",
                loacl_port = 0, server_port = 1883, keepalive = 60, reconn_space = 5, clean_session = 0,
                client_id = "", conn_verify = 0, conn_user_name = "", conn_user_password = "",
                will_flag = 0, will = { topic = "/will", msg = "offline", qos = 0, retention = 0 }
            }
        },
        UCLOUD = { enable = 1, name = "Cloud", pvt_deploy_enable = 0, server_ip = "192.168.0.201", server_port = 1234 }
    }
end

-- 6. UART Config
local uart_config = {
    UART = {
        { enable = 1, name = "Uart1", work_mode = 2, baud_rate = 115200, data_bit = 8, stop_bit = 1, parity = 0, pack_len = 1460, pack_time = 0, func = 1 },
        { enable = 1, select = 0, name = "Uart2", work_mode = 2, baud_rate = 9600, data_bit = 8, stop_bit = 1, parity = 0, pack_len = 1460, pack_time = 0 }
    }
}

function _M.get_uart_config()
    return uart_config
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

-- 8. Set Config
function _M.set_config(module, args)
    if module == "uart" then
        for k, v in pairs(args) do
            local index, key = string.match(k, "n_UART%[(%d+)%]%.(.+)")
            if index and key then
                index = tonumber(index) + 1
                if uart_config.UART[index] then
                    uart_config.UART[index][key] = tonumber(v) or v
                end
            end
        end
        return true
    end
    
    if module == "comm_tunnel" then
        for k, v in pairs(args) do
            local prefix, index, key = string.match(k, "([ns])_SOCK%[(%d+)%]%.(.+)")
            if prefix and index and key then
                ngx.log(ngx.INFO, "SOCK[" .. index .. "]." .. key .. " = " .. tostring(v))
            end
        end
        return true
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
    
    return true
end

return _M