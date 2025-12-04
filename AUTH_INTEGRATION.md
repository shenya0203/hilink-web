# Basic Auth 认证集成完成

## ✅ 已完成的集成

您的项目已成功集成 HTTP Basic Authentication，用于访问需要认证的 192.168.2.177 设备。

---

## 📋 集成方案

### 认证信息
```
用户名: admin
密码: admin
编码: Base64 → YWRtaW46YWRtaW4=
```

### 两层认证机制

#### 1️⃣ 客户端认证（axios）
**文件**: `api/services.js`

所有 HTTP 请求自动添加认证头：
```
Authorization: Basic YWRtaW46YWRtaW4=
```

#### 2️⃣ 代理端认证（Vite）
**文件**: `vite.config.js`

Vite 代理服务器转发请求时自动添加认证。

---

## 📁 新增文件

### `config/auth.js` - 认证配置管理
```javascript
export const AUTH = {
    username: 'admin',
    password: 'admin'
}

// 生成 Basic Auth 字符串
export function getBasicAuth()

// 获取代理配置
export function getProxyConfig()
```

### `docs/AUTH.md` - 完整的认证文档
包含：
- 认证原理说明
- 配置修改指南
- 常见问题解答
- 生产环境部署建议
- 测试和调试方法

---

## 🔄 请求流程

```
Vue 组件 (Status.vue)
    ↓
数据获取函数 (fetchStatusData)
    ↓
API 服务 (services.js)
    ↓ [自动添加 Authorization: Basic YWRtaW46YWRtaW4=]
    ↓
Vite 代理 (vite.config.js)
    ↓ [再次添加 auth: admin:admin]
    ↓
真实设备 (192.168.2.177)
    ↓ [验证认证成功]
    ↓
返回 JSON 数据
```

---

## 🔧 如何修改认证信息

### 方案 1：修改用户名和密码

编辑 `config/auth.js`：

```javascript
export const AUTH = {
    username: 'new-username',
    password: 'new-password'
}
```

保存后，自动生效（热更新）。

### 方案 2：修改设备 IP

编辑 `config/auth.js`：
```javascript
export const DEVICE_IP = '192.168.x.x'
```

**同时** 编辑 `vite.config.js`：
```javascript
const proxyTarget = 'http://192.168.x.x'
```

---

## 🚀 快速开始

1. **启动开发服务器**
   ```bash
   npm run dev
   ```

2. **打开浏览器**
   ```
   http://localhost:5173/
   ```

3. **自动进行认证**
   - 所有请求自动携带认证信息
   - 无需手动处理

---

## 🔍 验证认证是否生效

### 方法 1：浏览器开发者工具

1. 按 `F12` 打开开发者工具
2. 切换到 **Network** 标签
3. 刷新页面（F5）
4. 查看请求的 **Headers**
5. 找到 `Authorization` 字段：
   ```
   Authorization: Basic YWRtaW46YWRtaW4=
   ```

### 方法 2：Console 控制台

```javascript
// 验证 Base64 编码
const auth = btoa('admin:admin')
console.log('Basic ' + auth)
// 输出：Basic YWRtaW46YWRtaW4=
```

---

## 🎯 修改后需要做的

### ✅ 必须操作
1. 重启开发服务器（如已修改凭证）
   ```bash
   npm run dev
   ```

2. 清除浏览器缓存（可选）
   - 按 `Ctrl + Shift + Delete`
   - 清除所有数据

### ⚠️ 注意事项
- 认证信息在代码中存储，**生产环境使用环境变量**
- Basic Auth 是 Base64 编码，**不是加密**
- **生产环境必须使用 HTTPS**

---

## 📊 工作原理

### HTTP Basic Authentication 流程

```
1. 客户端生成凭证
   用户名 + ":" + 密码 = "admin:admin"
   
2. Base64 编码
   btoa("admin:admin") = "YWRtaW46YWRtaW4="
   
3. 添加到请求头
   Authorization: Basic YWRtaW46YWRtaW4=
   
4. 服务器验证
   服务器解码 Base64
   提取用户名和密码
   与存储的凭证比对
   
5. 允许或拒绝访问
```

---

## 🆘 常见问题

### Q: 401 Authorization Required 错误

**原因**：认证信息不正确或未正确传递

**解决**：
1. 检查 `config/auth.js` 中的用户名密码
2. 确认设备是否在线
3. 重启开发服务器
4. 清除浏览器缓存

### Q: 如何临时禁用认证测试？

编辑 `config/auth.js`：
```javascript
export function getBasicAuth() {
    return ''  // 返回空字符串
}
```

### Q: 如何使用其他认证方式？

当前只支持 Basic Auth。如需其他方式（如 Token 认证），编辑 `api/services.js`：

```javascript
headers: {
    'Authorization': `Bearer ${token}`  // 改为 Bearer Token
}
```

### Q: 生产环境怎么处理凭证？

**推荐使用环境变量**：

```javascript
export const AUTH = {
    username: import.meta.env.VITE_AUTH_USER || 'admin',
    password: import.meta.env.VITE_AUTH_PASS || 'admin'
}
```

部署时：
```bash
VITE_AUTH_USER=admin VITE_AUTH_PASS=admin npm run build
```

---

## 📝 相关文件

| 文件 | 作用 |
|------|------|
| `config/auth.js` | 认证配置（核心） |
| `api/services.js` | API 服务（已集成认证） |
| `vite.config.js` | 代理配置（已集成认证） |
| `docs/AUTH.md` | 完整的认证文档 |

---

## ✨ 集成特点

✅ **双层认证** - 客户端 + 代理端
✅ **自动处理** - 无需手动添加认证头
✅ **易于维护** - 统一的配置文件
✅ **无缝集成** - 不影响现有功能
✅ **完整文档** - 详细的使用说明

---

## 🎓 下一步

1. **测试连接**
   ```bash
   npm run dev
   ```
   访问 http://localhost:5173 查看是否正常显示数据

2. **查看详细文档**
   阅读 `docs/AUTH.md` 了解更多

3. **根据需要修改**
   - 更改用户名密码
   - 更改设备 IP
   - 调整认证策略

---

## 📞 快速参考

### 修改凭证
```javascript
// config/auth.js
export const AUTH = {
    username: 'admin',
    password: 'admin'
}
```

### 验证认证
```javascript
// 浏览器 Console
btoa('admin:admin')  // 输出：YWRtaW46YWRtaW4=
```

### 重启服务
```bash
npm run dev
```

---

**认证集成完成！现在可以安全访问需要认证的设备了。** ✅

请参考 `docs/AUTH.md` 获取更多信息。
