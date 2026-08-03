-- /usr/lib/lua/web_backend/session.lua
-- Web 管理 Session / CSRF / 登录失败锁定

local cjson = require "cjson"

local _M = {}

local COOKIE_NAME = "HLKSESS"
local SESSION_DIR = "/tmp/web_sessions"
local LOCK_DIR = "/tmp/web_login_lock"
local IDLE_TIMEOUT = 30 * 60      -- 空闲 30 分钟
local ABS_TIMEOUT = 8 * 60 * 60   -- 绝对 8 小时
local MAX_FAILS = 5
local LOCK_SECONDS = 10 * 60      -- 锁定 10 分钟
local MAX_SESSIONS = 20

local function ensure_dir(path)
    os.execute("mkdir -p " .. path)
end

local function random_hex(nbytes)
    local f = io.open("/dev/urandom", "rb")
    if not f then
        return tostring(ngx.now()):gsub("%.", "") .. tostring(math.random(100000, 999999))
    end
    local data = f:read(nbytes)
    f:close()
    if not data then
        return tostring(ngx.now()):gsub("%.", "") .. tostring(math.random(100000, 999999))
    end
    local t = {}
    for i = 1, #data do
        t[#t + 1] = string.format("%02x", string.byte(data, i))
    end
    return table.concat(t)
end

local function session_path(sid)
    return SESSION_DIR .. "/" .. sid
end

local function lock_path(key)
    local safe = string.gsub(key or "unknown", "[^%w%._%-]", "_")
    return LOCK_DIR .. "/" .. safe
end

local function read_json(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    if not content or content == "" then return nil end
    local ok, data = pcall(cjson.decode, content)
    if ok then return data end
    return nil
end

local function write_json(path, data)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(cjson.encode(data))
    f:close()
    return true
end

local function get_cookie(name)
    local header = ngx.var.http_cookie
    if not header then return nil end
    for part in string.gmatch(header, "([^;]+)") do
        local k, v = string.match(part, "^%s*(.-)%s*=%s*(.-)%s*$")
        if k == name then
            return v
        end
    end
    return nil
end

local function set_session_cookie(sid)
    -- Secure：强制 HTTPS 后生效；HttpOnly + SameSite=Lax
    local cookie = string.format(
        "%s=%s; Path=/; HttpOnly; Secure; SameSite=Lax",
        COOKIE_NAME, sid
    )
    ngx.header["Set-Cookie"] = cookie
end

local function clear_session_cookie()
    ngx.header["Set-Cookie"] = COOKIE_NAME .. "=; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Lax"
end

local function client_ip()
    return ngx.var.remote_addr or "0.0.0.0"
end

local function cleanup_expired_sessions()
    ensure_dir(SESSION_DIR)
    local now = ngx.time()
    local handle = io.popen("ls -1 " .. SESSION_DIR .. " 2>/dev/null")
    if not handle then return end
    local count = 0
    for name in handle:lines() do
        local path = session_path(name)
        local data = read_json(path)
        if not data or (data.expire and data.expire < now) or (data.abs_expire and data.abs_expire < now) then
            os.remove(path)
        else
            count = count + 1
        end
    end
    handle:close()
    -- 超过上限时删最旧的（简单：再扫一遍按 expire 排序代价高，直接 rm 多余若干）
    if count > MAX_SESSIONS then
        os.execute("ls -1t " .. SESSION_DIR .. " 2>/dev/null | tail -n +" .. (MAX_SESSIONS + 1) .. " | while read f; do rm -f " .. SESSION_DIR .. "/$f; done")
    end
end

function _M.get_credentials()
    local ok, uci_lib = pcall(require, "uci")
    if not ok or not uci_lib then
        return "admin", "admin"
    end
    local cursor = uci_lib.cursor()
    local user = cursor:get("nginx", "global", "uci_user") or "admin"
    local pass = cursor:get("nginx", "global", "uci_pass") or "admin"
    return user, pass
end

function _M.lock_key(username)
    return (username or "") .. "@" .. client_ip()
end

function _M.is_locked(username)
    ensure_dir(LOCK_DIR)
    local data = read_json(lock_path(_M.lock_key(username)))
    if not data then
        return false, 0
    end
    local now = ngx.time()
    if data.locked_until and data.locked_until > now then
        return true, data.locked_until - now
    end
    -- 过期清理
    if data.locked_until and data.locked_until <= now then
        os.remove(lock_path(_M.lock_key(username)))
    end
    return false, 0
end

function _M.record_fail(username)
    ensure_dir(LOCK_DIR)
    local path = lock_path(_M.lock_key(username))
    local data = read_json(path) or { fails = 0 }
    local now = ngx.time()
    if data.locked_until and data.locked_until > now then
        return true, data.locked_until - now
    end
    data.fails = (data.fails or 0) + 1
    if data.fails >= MAX_FAILS then
        data.locked_until = now + LOCK_SECONDS
        data.fails = 0
        write_json(path, data)
        return true, LOCK_SECONDS
    end
    write_json(path, data)
    return false, 0
end

function _M.clear_fail(username)
    os.remove(lock_path(_M.lock_key(username)))
end

function _M.create(username)
    ensure_dir(SESSION_DIR)
    cleanup_expired_sessions()
    local sid = random_hex(16)
    local csrf = random_hex(16)
    local now = ngx.time()
    local data = {
        user = username,
        csrf = csrf,
        created = now,
        expire = now + IDLE_TIMEOUT,
        abs_expire = now + ABS_TIMEOUT,
        ip = client_ip()
    }
    if not write_json(session_path(sid), data) then
        return nil, nil
    end
    set_session_cookie(sid)
    return sid, csrf
end

function _M.destroy()
    local sid = get_cookie(COOKIE_NAME)
    if sid and sid ~= "" then
        os.remove(session_path(sid))
    end
    clear_session_cookie()
end

function _M.destroy_all()
    os.execute("rm -rf " .. SESSION_DIR .. "/*")
end

-- 返回 session data 或 nil
-- touch=false 时只校验不滑动续期（只读/轮询接口用）；默认 true
function _M.check(touch)
    if touch == nil then
        touch = true
    end
    local sid = get_cookie(COOKIE_NAME)
    if not sid or sid == "" then
        return nil
    end
    local path = session_path(sid)
    local data = read_json(path)
    if not data then
        clear_session_cookie()
        return nil
    end
    local now = ngx.time()
    if (data.expire and data.expire < now) or (data.abs_expire and data.abs_expire < now) then
        os.remove(path)
        clear_session_cookie()
        return nil
    end
    if touch then
        -- 滑动空闲续期
        data.expire = now + IDLE_TIMEOUT
        write_json(path, data)
    end
    return data
end

function _M.get_csrf(data)
    if data then return data.csrf end
    local s = _M.check()
    return s and s.csrf or nil
end

function _M.validate_csrf(data)
    local token = ngx.req.get_headers()["X-CSRF-Token"]
        or ngx.req.get_headers()["x-csrf-token"]
    if not token or token == "" then
        return false
    end
    return data and data.csrf and token == data.csrf
end

function _M.needs_csrf(uri, method)
    method = string.upper(method or "GET")
    if method ~= "GET" and method ~= "HEAD" and method ~= "OPTIONS" then
        return true
    end
    if string.sub(uri, 1, 8) == "/upload/" then
        return true
    end
    if string.match(uri, "^/update_") then
        return true
    end
    if string.match(uri, "^/action_") then
        return true
    end
    return false
end

-- ========== 登录 RSA ==========
local LOGIN_PUB = "/etc/nginx/ssl/web_login.pub"
local LOGIN_KEY = "/etc/nginx/ssl/web_login.key"
local NONCE_DIR = "/tmp/web_login_nonce"
local NONCE_TTL = 120  -- 秒
local TS_SKEW = 120

function _M.read_login_pubkey()
    local f = io.open(LOGIN_PUB, "r")
    if not f then return nil end
    local pem = f:read("*a")
    f:close()
    return pem
end

local function is_b64(s)
    return type(s) == "string" and #s > 0 and #s < 4096 and string.match(s, "^[A-Za-z0-9+/=]+$") ~= nil
end

local function is_nonce(s)
    return type(s) == "string" and #s >= 16 and #s <= 64 and string.match(s, "^[A-Za-z0-9_%-]+$") ~= nil
end

-- 消耗 nonce：已用过返回 false
function _M.consume_nonce(nonce)
    if not is_nonce(nonce) then return false end
    ensure_dir(NONCE_DIR)
    local path = NONCE_DIR .. "/" .. nonce
    local f = io.open(path, "r")
    if f then
        f:close()
        return false
    end
    local now = ngx.time()
    write_json(path, { t = now })
    -- 清理过期 nonce
    local handle = io.popen("ls -1 " .. NONCE_DIR .. " 2>/dev/null")
    if handle then
        for name in handle:lines() do
            if name ~= nonce then
                local p = NONCE_DIR .. "/" .. name
                local meta = read_json(p)
                if not meta or not meta.t or (now - meta.t) > NONCE_TTL then
                    os.remove(p)
                end
            end
        end
        handle:close()
    end
    return true
end

-- 解密 password_enc，返回 password 或 nil
-- 明文格式: password\\nnonce\\nts
function _M.decrypt_login_payload(password_enc, expect_nonce)
    if not is_b64(password_enc) then return nil end
    if not is_nonce(expect_nonce) then return nil end

    local bin = ngx.decode_base64(password_enc)
    if not bin or #bin < 32 then return nil end

    local pid = tostring(ngx.worker.pid() or 0) .. "_" .. tostring(ngx.now()):gsub("%.", "")
    local tin = "/tmp/web_login_enc." .. pid
    local tout = "/tmp/web_login_dec." .. pid

    local wf = io.open(tin, "wb")
    if not wf then return nil end
    wf:write(bin)
    wf:close()

    -- RSA-OAEP SHA-256，与 WebCrypto 一致
    os.execute(string.format(
        "openssl pkeyutl -decrypt -inkey %s -in %s -out %s -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 -pkeyopt rsa_mgf1_md:sha256 2>/dev/null",
        LOGIN_KEY, tin, tout
    ))
    os.remove(tin)

    local rf = io.open(tout, "rb")
    if not rf then return nil end
    local plain = rf:read("*a")
    rf:close()
    os.remove(tout)
    if not plain or plain == "" then return nil end

    local password, nonce, ts_str = string.match(plain, "^(.-)\n(.-)\n(%d+)$")
    if not password or not nonce or not ts_str then
        return nil
    end
    if nonce ~= expect_nonce then
        return nil
    end
    local ts = tonumber(ts_str)
    local now = ngx.time()
    if not ts or math.abs(now - ts) > TS_SKEW then
        return nil
    end
    if not _M.consume_nonce(nonce) then
        return nil
    end
    return password
end

return _M
