# Basic Auth 认证集成说明

## 认证实现方案

项目已集成 HTTP Basic Authentication，支持访问需要认证的设备 Web 接口。

---

## 认证信息

### 当前配置
```
用户名：admin
密码：admin
认证方式：Basic Auth
编码方式：Base64（admin:admin → YWRtaW46YWRtaW4=）
```

---

## 实现方式

### 1. 服务端代理认证（Vite）
**文件**: `vite.config.js`

Vite 开发服务器代理会自动添加 Basic Auth 头：
```javascript
proxy: {
  '/download_flex.cgi': {
    target: 'http://192.168.2.177',
    auth: 'admin:admin'  // 自动转换为 Authorization: Basic YWRtaW46YWRtaW4=
  }
}
```

### 2. 客户端请求认证（axios）
**文件**: `api/services.js`

所有 HTTP 请求自动携带认证头：
```javascript
const apiClient = axios.create({
    headers: {
        'Authorization': `Basic ${BASIC_AUTH}`
    }
})
```

### 3. 认证配置管理
**文件**: `config/auth.js`

集中管理认证信息，便于修改：
```javascript
export const AUTH = {
    username: 'admin',
    password: 'admin'
}
```

---

## 文件结构

```
config/
└── auth.js              ← 认证配置（集中管理凭证）

api/
├── services.js          ← 使用 Basic Auth（从 config/auth.js 导入）
└── mockData.js          ← 数据处理

vite.config.js           ← Vite 代理配置（使用 config/auth.js）
```

---

## 请求流程

```
浏览器请求
    ↓
axios 客户端（自动添加 Authorization 头）
    ↓
Vite 代理服务器
    ↓
代理转发请求到 192.168.2.177（自动添加 auth）
    ↓
设备验证认证
    ↓
返回数据
```

---

## 修改认证信息

### 修改用户名和密码

编辑 `config/auth.js`：

```javascript
export const AUTH = {
    username: 'your-username',  // 改为新用户名
    password: 'your-password'   // 改为新密码
}
```

然后重启开发服务器：
```bash
npm run dev
```

### 修改设备 IP

编辑 `config/auth.js`：

```javascript
export const DEVICE_IP = '192.168.x.x'  // 改为新 IP
```

**同时** 在 `vite.config.js` 中修改：

```javascript
const proxyTarget = 'http://192.168.x.x'  // 改为新 IP
```

---

## 认证工作原理

### HTTP Basic Auth 编码

```
明文：admin:admin
Base64 编码：YWRtaW46YWRtaW4=

HTTP 请求头：
Authorization: Basic YWRtaW46YWRtaW4=
```

### 浏览器控制台验证

打开浏览器开发者工具（F12）→ Network 标签，查看请求头：

```
Authorization: Basic YWRtaW46YWRtaW4=
```

---

## 两层认证机制

项目实现了两层认证机制：

### 层级 1：客户端认证（axios）
- **作用**：对所有发往代理的请求自动添加认证头
- **实现**：`api/services.js` 中的 axios 实例配置
- **优点**：确保即使代理失败，仍能传递认证信息

### 层级 2：代理端认证（Vite）
- **作用**：代理转发时对目标服务器进行认证
- **实现**：`vite.config.js` 中的 `auth` 配置
- **优点**：在代理层面处理认证，减少错误

---

## 常见问题

### Q: 认证失败怎么办？
**A:** 
1. 检查用户名和密码是否正确
2. 确认设备是否需要认证
3. 查看浏览器控制台（F12）的错误信息
4. 检查设备是否在线

### Q: 如何验证认证是否生效？
**A:** 
1. 打开浏览器开发者工具（F12）
2. 切换到 Network 标签
3. 刷新页面
4. 查看请求的 Request Headers 中是否有 `Authorization: Basic ...`

### Q: 如何禁用认证？
**A:** 虽然不推荐，但可以这样做：

编辑 `config/auth.js`：
```javascript
export function getBasicAuth() {
    return ''  // 返回空字符串禁用认证
}
```

### Q: 服务器返回 401 错误怎么办？
**A:** 
1. 检查凭证是否正确
2. 确认设备是否接受该认证方式
3. 尝试在浏览器中直接访问 `http://admin:admin@192.168.2.177/` 测试

---

## 生产环境部署

### 打包后的认证

生产环境中，认证信息会被打包到应用中。建议：

1. **使用环境变量**（推荐）
   ```javascript
   export const AUTH = {
       username: process.env.VITE_AUTH_USER || 'admin',
       password: process.env.VITE_AUTH_PASS || 'admin'
   }
   ```

2. **在部署时配置**
   ```bash
   VITE_AUTH_USER=admin VITE_AUTH_PASS=admin npm run build
   ```

---

## 安全提示

⚠️ **重要**：
- ✅ Basic Auth 凭证会被 Base64 编码，但**不是加密**
- ✅ 始终在 HTTPS 环境使用（生产环境）
- ✅ 不要在代码中硬编码敏感信息
- ✅ 生产环境使用环境变量管理凭证

---

## 测试认证

### 手动测试

在浏览器控制台运行：

```javascript
// 测试 Basic Auth 编码
const auth = btoa('admin:admin')
console.log('Basic ' + auth)  // 输出：Basic YWRtaW46YWRtaW4=
```

### 使用 curl 测试

```bash
# 直接访问设备
curl -u admin:admin http://192.168.2.177/download_flex.cgi?name=status

# 查看返回的 JSON
curl -u admin:admin -H "Accept: application/json" \
  http://192.168.2.177/download_flex.cgi?name=status
```

---

## 调试模式

如需查看认证过程，编辑 `api/services.js`：

```javascript
// 请求拦截器（调试用）
apiClient.interceptors.request.use(
    config => {
        console.log('请求头:', config.headers)
        return config
    }
)
```

---

## 相关文件

- `config/auth.js` - 认证配置
- `api/services.js` - API 服务（包含认证）
- `vite.config.js` - 代理配置（包含认证）

---

## 后续支持

需要修改认证方式？常见的替代方案：

- **Token 认证**（Bearer Token）
- **OAuth 2.0**
- **API Key**
- **自定义认证头**

请参考项目文档或联系支持。
