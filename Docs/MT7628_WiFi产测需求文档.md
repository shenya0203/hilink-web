# MT7628 Failsafe 模式 WiFi 产测需求文档

**文档版本**：v1.0  
**硬件平台**：MediaTek MT7628  
**软件环境**：OpenWrt 21.02.7  
**创建日期**：待填写  
**负责人**：待填写

---

## 1. 背景与目标

### 1.1 背景

在硬件生产流程中，需要在 Failsafe（安全模式）下对 WiFi 射频模组进行出厂产测。Failsafe 模式是 OpenWrt 的一种最小化启动模式，仅挂载只读根文件系统，不启动常规守护进程（netifd、hostapd、wpa_supplicant 等），不自动加载 WiFi 驱动模块。

### 1.2 测试目标

在 Failsafe 模式下，通过脚本自动完成以下流程：

1. 手动加载 mt76 开源驱动，使 WiFi 网卡接口正常出现
2. 以 **STA（客户端）模式** 连接指定产测 AP
3. 连接成功后采集 RSSI 信号强度
4. 根据预设阈值输出 **PASS / FAIL** 判定结果，供产测上位机解析

---

## 2. 硬件与软件环境确认

| 项目 | 参数 |
|------|------|
| SoC | MediaTek MT7628 |
| 系统 | OpenWrt 21.02.7 |
| WiFi 驱动 | 开源 mt76（内核模块：mt7603e） |
| 校准数据分区 | factory 分区（mt76 驱动自动处理，脚本无需干预） |
| 天线配置 | 单天线（生产时仅插一根，模组出厂已配置为单天线模式） |
| 可写目录 | `/tmp`（内存文件系统，根目录只读） |

---

## 3. 产测 AP 配置

| 项目 | 参数 |
|------|------|
| SSID | `xuxu` |
| 加密方式 | WPA2-PSK |
| 密码 | `12345678` |
| 信道 | **【待确认】** 建议固定信道，避免 DFS 或自动选信道干扰测试 |
| 环境保障 | 产测区域内无同名 SSID，由生产环境管理保障 |

---

## 4. 执行流程设计

### 4.1 总体流程

```
启动 Failsafe
    │
    ▼
[Step 1] 环境检查
  - 检查 iw、wpa_supplicant 工具是否存在
  - 动态识别 WiFi 接口名（不硬编码 wlan0）
    │
    ▼
[Step 2] 加载驱动
  - 按依赖顺序 insmod 加载 mt76 相关模块
  - 等待 wlan 接口出现（超时判定为驱动加载失败）
    │
    ▼
[Step 3] 激活接口
  - ifconfig <iface> up
    │
    ▼
[Step 4] 生成 wpa_supplicant 配置
  - 写入 /tmp/wpa_supplicant.conf
    │
    ▼
[Step 5] 扫描确认 AP 可见性
  - iw <iface> scan 确认 SSID xuxu 可被扫到
  - 若扫不到 → 判定为射频故障，输出 FAIL(NO_AP)，终止
    │
    ▼
[Step 6] 启动 wpa_supplicant 连接
  - 后台启动 wpa_supplicant
  - 等待关联成功（超时阈值：15 秒）
  - 若超时 → 清理残留进程和 socket → 重试（最多共 3 次）
  - 3 次均失败 → 输出 FAIL(ASSOC_TIMEOUT)，终止
    │
    ▼
[Step 7] 采集 RSSI
  - 关联成功后等待 2 秒（信号稳定）
  - 连续采样 5 次，取中位数作为最终 RSSI 值
    │
    ▼
[Step 8] 判定输出
  - RSSI ≥ 阈值 → PASS
  - RSSI ＜ 阈值 → FAIL(WEAK_SIGNAL)
    │
    ▼
[Step 9] 清理
  - kill wpa_supplicant
  - 删除 /tmp 下的临时文件和 socket
  - ifconfig <iface> down
```

### 4.2 重试机制

- 单次连接超时阈值：**15 秒**
- 最大尝试次数：**3 次**（首次 + 重试 2 次）
- 每次重试前必须执行完整清理：
  1. `kill` 残留的 `wpa_supplicant` 进程
  2. 删除 `/tmp/wpa_supplicant/` 目录下的 socket 文件（否则下次启动报错）
  3. `ifconfig <iface> down && ifconfig <iface> up`（复位网卡状态）

---

## 5. 关键技术细节

### 5.1 驱动加载

- **禁止**使用 `modprobe`（Failsafe 下不可用），必须使用 `insmod`
- 需要按模块依赖顺序从底层到上层逐一加载
- **【待确认】** 请在目标设备上执行 `modinfo mt7603e` 确认完整依赖链，以确定 `insmod` 的正确顺序

### 5.2 接口名动态识别

- 不得硬编码 `wlan0`
- 驱动加载后，使用 `iw dev` 命令解析实际接口名
- 若接口未出现（等待超时），判定为驱动加载失败，输出 `FAIL(DRIVER_ERROR)`

### 5.3 工具依赖确认

以下工具需在 Failsafe 只读镜像中可用，**部署前必须逐一验证**：

| 工具 | 用途 | 验证命令 | 备选方案 |
|------|------|----------|----------|
| `wpa_supplicant` | WPA2 握手认证 | `which wpa_supplicant` | 无（必须存在） |
| `iw` | 扫描、链路状态查询 | `which iw` | `iwconfig`（wireless-tools） |
| `insmod` | 手动加载内核模块 | `which insmod` | 通常内置，无需确认 |
| `ifconfig` | 接口控制 | `which ifconfig` | `ip link`（iproute2） |

> **补充**：`wpa_supplicant` 存在不代表可用，还需确认其依赖的动态库（`libnl` 系列）在 Failsafe 下可被找到。验证方法：`ldd /usr/sbin/wpa_supplicant`

### 5.4 随机数（Entropy）

WPA2 四次握手依赖内核随机数。OpenWrt 21.02 内核通常通过 `getrandom()` syscall 提供支持，不依赖 `rngd` 守护进程，预计不会造成握手阻塞。若实测中出现握手卡顿，可在脚本中加入 `cat /dev/urandom > /dev/null &` 临时加速熵池填充。

### 5.5 RSSI 采集

- 连接成功后等待 **2 秒**再开始采集（避免关联瞬间信号不稳定）
- 采样 **5 次**，每次间隔 500ms
- 取 **中位数** 作为最终上报值（排除瞬时干扰）
- 采集命令优先使用：`iw dev <iface> link | grep signal`
- 备选：`cat /proc/net/wireless`

---

## 6. 输出格式规范

脚本通过 `stdout` 输出结果，供产测上位机解析，格式如下：

### 6.1 通过

```
RESULT=PASS RSSI=-52 UNIT=dBm
```

### 6.2 失败（含失败原因码）

```
RESULT=FAIL CODE=<失败原因码> RSSI=<实测值或N/A>
```

### 6.3 失败原因码定义

| 原因码 | 含义 | 排查方向 |
|--------|------|----------|
| `DRIVER_ERROR` | 驱动加载失败或接口未出现 | 内核模块依赖、硬件连接 |
| `NO_AP` | 扫描不到目标 SSID | 射频收发链路故障（硬件问题） |
| `ASSOC_TIMEOUT` | 连接超时，3 次均失败 | 密码/加密配置、环境干扰 |
| `WEAK_SIGNAL` | 连接成功但信号强度低于阈值 | 天线、射频性能不达标 |

> **重要**：`NO_AP` 和 `ASSOC_TIMEOUT` / `WEAK_SIGNAL` 的区分非常关键。前者指向硬件射频故障，后者可能是环境或配置问题，需区别对待，避免误判。

---

## 7. RSSI 判定阈值

**【待确认 — 必须在脚本开发前明确】**

| 判定 | 条件 | 说明 |
|------|------|------|
| PASS | RSSI ≥ `___` dBm | 根据硬件规格书和天线增益确定 |
| FAIL | RSSI ＜ `___` dBm | 同上 |

> 建议由硬件工程师参考模组规格书，并结合产测 AP 与 DUT 的实测距离，给出合理阈值范围，并保留至少 5 dBm 的余量以应对环境波动。

---

## 8. 脚本运行环境约束

| 约束项 | 说明 |
|--------|------|
| 根文件系统 | 只读，禁止向 `/etc`、`/var`（非 tmpfs 部分）写入 |
| 临时文件 | 全部写入 `/tmp`（内存 tmpfs，可读写） |
| 日志文件 | 建议写入 `/tmp/wifi_test.log`，便于失败时调试 |
| 进程残留 | 脚本退出前必须清理所有后台进程和临时文件 |
| 系统时钟 | Failsafe 下时钟未同步，禁止使用时间戳判断超时，统一使用 `sleep` 计时 |

---

## 9. 待确认事项汇总

在进入脚本开发阶段前，以下事项需逐一确认：

| # | 待确认项 | 确认方法 | 负责人 |
|---|----------|----------|--------|
| 1 | mt7603e 完整模块依赖链 | 设备上执行 `modinfo mt7603e` | 固件工程师 |
| 2 | `wpa_supplicant` 及其动态库是否在 Failsafe 镜像中 | `which wpa_supplicant` + `ldd` | 固件工程师 |
| 3 | `iw` 工具是否在 Failsafe 镜像中 | `which iw` | 固件工程师 |
| 4 | 产测 AP 信道是否固定 | 查看 AP 配置 | 测试工程师 |
| 5 | RSSI 判定阈值（PASS/FAIL 分界线） | 硬件规格书 + 实测标定 | 硬件工程师 |
| 6 | 脚本最终输出格式是否满足上位机解析需求 | 与产测系统对接确认 | 产测系统负责人 |

---

## 10. 不在本次需求范围内的事项

以下事项明确排除在脚本职责之外：

- WiFi 校准数据（EEPROM）的正确性——由硬件生产流程保证，mt76 驱动自动处理
- 天线数量和模式配置——生产时模组已设置为单天线，驱动无需额外干预
- 网络连通性（IP 获取、Ping 测试）——本次仅测射频链路，不测网络层

---

*文档结束*

改动总结报告：
  3 处编辑，全部在 /home/shenya/hilink-web/factory_daemon.lua：

  1. 配置区 (第 17-22 行) — 新增 WiFi 产测参数常量：
    - WIFI_SSID = "xuxu", WIFI_PSK = "12345678" (来自需求文档)
    - WIFI_RSSI_THRES = -70 dBm (待硬件工程师标定)
    - WIFI_TIMEOUT = 15s, WIFI_MAX_RETRIES = 3
  2. do_test_wifi(req) 函数 (第 307-446 行) — 严格遵循需求文档的 9 步流程：

  | Step | 操作                                                | 失败码        |
  |------|-----------------------------------------------------|---------------|
  | 1    | 检查 iw / wpa_supplicant 工具是否存在               | DRIVER_ERROR  |
  | 2    | insmod 按依赖顺序加载 mt76 驱动，等待接口出现 (10s) | DRIVER_ERROR  |
  | 3    | ifconfig <iface> up                                 | —             |
  | 4    | 生成 /tmp/wpa_supplicant.conf                       | —             |
  | 5    | iw dev <iface> scan 确认 SSID 可见                  | NO_AP         |
  | 6    | 启动 wpa_supplicant 连接，超时 15s，最多重试 3 次   | ASSOC_TIMEOUT |
  | 7    | 等 2s 稳定后采样 RSSI 5 次 (间隔 500ms)，取中位数   | —             |
  | 8    | 清理 (kill wpa_supplicant, 删 socket/conf, ifdown)  | —             |
  | 9    | 中位数 >= 阈值 → PASS，否则 → WEAK_SIGNAL           | WEAK_SIGNAL   |

  3. 主控循环 dispatch (第 582-583 行) — 新增 test_wifi 指令分发

  设计要点

  - 返回格式：与现有 do_test_net/do_test_lte 一致，返回 JSON 兼容的 Lua table
    - PASS: {cmd="test_wifi", result="pass", rssi=-52}
    - FAIL: {cmd="test_wifi", result="fail", code="NO_AP", rssi="N/A"}
  - 可配置：SSID、密码、RSSI 阈值均可通过上位机 JSON 请求中的 req.ssid/req.psk/req.rssi_threshold 覆盖
  - Failsafe 兼容：全部临时文件写入 /tmp，使用 insmod 而非 modprobe
  - 重试机制：每次重试前完整清理残留 wpa_supplicant 进程、socket 目录和接口状态
  - NO_AP vs ASSOC_TIMEOUT 区分：扫描阶段失败 → NO_AP (射频硬件故障)；连接阶段失败 → ASSOC_TIMEOUT (配置/环境问题)

  待确认项 (来自需求文档第 9 节)

  1. mt7603e 在目标设备上的完整模块依赖链 — 当前代码同时尝试 mt76x02-lib.ko 和 mt76x02-common.ko，加载失败静默忽略
  2. wpa_supplicant 及其动态库在 Failsafe 镜像中是否可用 — 代码会检测并上报 DRIVER_ERROR
  3. RSSI 判定阈值 — 当前使用 -70 dBm 占位值，需硬件工程师标定后修改 WIFI_RSSI_THRES

