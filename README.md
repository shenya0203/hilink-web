# HiLink Web 工业路由网关配置系统

## 项目介绍
这是一个基于 Vue 3 + Vite 的工业路由网关 N720 的 Web 配置管理系统。通过代理动态获取设备的配置数据并显示在Web界面上。

## 快速开始

### 1. 安装依赖
```bash
npm install
```

### 2. 启动开发服务器
```bash
npm run dev
```

然后在浏览器中访问 `http://localhost:5173/`

### 3. 生产构建
```bash
npm run build
```

## API 接口

项目通过 Vite 代理访问真实设备上的以下接口：

### 状态数据接口
- **GET** `/download_flex.cgi?name=status`
  - 获取设备的实时状态数据（运行时间、固件版本、MAC地址等）

### 网络数据接口
- **GET** `/download_flex.cgi?name=network`
  - 获取网络配置信息（以太网、4G/LTE等）

### 杂项配置接口
- **GET** `/download_nv.cgi?name=misc`
  - 获取设备的杂项配置（主机名、端口、NTP服务器等）

### 通信隧道接口
- **GET** `/download_nv.cgi?name=comm_tunnel`
  - 获取通信隧道配置（Socket、MQTT、云服务等）

## 代理配置

在 `vite.config.js` 中已配置代理，将所有以下请求转发到 `http://192.168.2.177`：
- `/download_flex.cgi`
- `/download_nv.cgi`
- `/update_flex.cgi`
- `/update_nv.cgi`

## 项目结构

```
hilink-web/
├── index.html              # 应用入口
├── main.js                 # Vue应用主文件
├── APp.vue                 # 根组件
├── vite.config.js          # Vite配置
├── package.json            # 项目依赖
├── api/
│   ├── services.js         # API服务调用
│   └── mockData.js         # 数据处理和格式化
├── components/
│   └── Layout.vue          # 布局组件（导航栏、侧边栏）
├── router/
│   └── index.js            # 路由配置
├── views/
│   ├── Status.vue          # 状态页面
│   └── Network.vue         # 网络配置页面
├── src/
│   └── app.css             # 全局样式
└── utils/
    └── i18n.js             # 国际化（预留）
```

## 页面功能

### 当前状态页面
- 显示设备基本信息（型号、固件版本、SN等）
- 显示系统状态（运行时间、MAC地址、系统时间等）
- 显示以太网配置
- 显示蜂窝网络信息（SIM卡、信号强度、IMEI等）

### 网络页面
- 显示网络配置详情
- 以太网信息和配置
- 4G/LTE网络信息

## 数据获取流程

1. 页面加载时，通过 `api/services.js` 中的函数发起请求
2. Vite 代理将请求转发到真实设备
3. 获取到的数据通过 `api/mockData.js` 进行格式化处理
4. 组件接收格式化后的数据并显示
5. 每 30 秒自动刷新一次数据

## 注意事项

- 确保设备的 IP 地址为 `192.168.2.177`，如需修改请在 `vite.config.js` 中更新
- 开发环境仅在本机运行时通过代理访问设备
- 生产环境需要部署到实际设备上或配置适当的跨域解决方案
- 所有请求都采用只读模式，未来可根据需求添加数据修改功能

## 开发说明

### 添加新页面
1. 在 `views/` 下创建新的 `.vue` 文件
2. 在 `router/index.js` 中添加路由配置
3. 在 `components/Layout.vue` 中添加菜单项

### 调用新的API接口
1. 在 `api/services.js` 中添加新的接口函数
2. 在 `api/mockData.js` 中添加相应的数据处理函数
3. 在组件中导入并使用

## 样式定制

全局样式在 `src/app.css` 中定义，包括：
- 导航栏样式
- 侧边栏菜单样式
- 表单和表格样式
- 响应式布局

## 故障排查

### 页面显示 404 错误
- 确保已执行 `npm install` 安装了依赖
- 确保已执行 `npm run dev` 启动了开发服务器

### 无法获取设备数据
- 检查网络连接
- 确保设备 IP 地址为 `192.168.2.177`
- 检查浏览器控制台的错误日志
- 确保 Vite 代理配置正确

### 样式错乱
- 清除浏览器缓存
- 尝试重启开发服务器

## 许可证

MIT
