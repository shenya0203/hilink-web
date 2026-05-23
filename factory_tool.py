import socket
import threading
import json
import time
import base64
from datetime import datetime
import customtkinter as ctk
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad

# ================= 配置与常量 =================
SERVER_PORT = 998
WATCHDOG_TIMEOUT = 40  
AES_KEY = b'1234567890123456'  
AES_IV = b'abcdefghij123456'   

RECONN_TIMEOUT = 100

TEST_ITEMS = {
    "fetch_sn": "获取云端SN",
    "test_net": "Net 测试",
    "test_wifi": "WiFi 测试",
    "test_lte": "LTE 测试",
    "test_serial": "Serial 测试",
    "test_led": "LED 人工确认",
    "test_wdog": "看门狗测试",
    "write_tuple": "写入五元组"
}

# ================= 业务逻辑类 =================

class CryptoHelper:
    """简单的 AES 对称加密工具"""
    @staticmethod
    def encrypt_b64(text):
        try:
            cipher = AES.new(AES_KEY, AES_MODE=AES.MODE_CBC, iv=AES_IV)
            ct_bytes = cipher.encrypt(pad(text.encode('utf-8'), AES.block_size))
            return base64.b64encode(ct_bytes).decode('utf-8')
        except:
            return base64.b64encode(text.encode()).decode() 

class CloudAPI:
    """模拟云端接口"""
    @staticmethod
    def fetch_tuple(mac):
        time.sleep(1)
        import random
        if random.random() > 0.2:
            return {
                "DN": f"Dev_{mac[-4:]}",
                "PjK": "Project_XYZ",
                "PdK": "Product_ABC",
                "PdS": "Secret_123",
                "DS": "Device_Secret_456"
            }
        return None

class DeviceSession:
    """单个测试设备会话管理"""
    def __init__(self, mac, imei, iccid):
        self.mac = mac
        self.imei = imei
        self.iccid = iccid
        self.results = {}
        self.tuple_data = None
        self.last_seen = time.time()
        self.interactive_event = threading.Event()
        self.interactive_result = False
        self.is_rebooting = False  
        self.reboot_start_time = 0 
        self.socket = None
        self.is_done = False
        self.finish_time = None 


# ================= UI 组件 =================

class DeviceTab(ctk.CTkFrame):
    """单设备的完整的测试监控面板"""
    def __init__(self, master, session, on_led_confirm):
        super().__init__(master)
        self.session = session
        
        self.grid_columnconfigure(0, weight=1)
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(1, weight=1)
        
        # 1. 顶部基础信息
        info_text = f"MAC: {session.mac}    |    IMEI: {session.imei}"
        if session.iccid:
            info_text += f"    |    ICCID: {session.iccid}"
        self.info_lbl = ctk.CTkLabel(self, text=info_text, font=("Consolas", 14, "bold"), text_color="#3B8ED0")
        self.info_lbl.grid(row=0, column=0, columnspan=2, pady=(10, 15), padx=20, sticky="w")
        
        # 2. 左侧：测试项状态矩阵
        self.tests_frame = ctk.CTkFrame(self, fg_color=("#F0F0F0", "#2B2B2B"))
        self.tests_frame.grid(row=1, column=0, padx=(20, 10), pady=(0, 20), sticky="nsew")
        
        self.status_labels = {}
        self.reason_labels = {}
        
        for i, (key, name) in enumerate(TEST_ITEMS.items()):
            ctk.CTkLabel(self.tests_frame, text=name, width=120, anchor="w", font=("Microsoft YaHei", 12)).grid(row=i, column=0, padx=20, pady=8)
            st_lbl = ctk.CTkLabel(self.tests_frame, text="等待中", text_color="gray", width=60)
            st_lbl.grid(row=i, column=1, padx=10, pady=8)
            rsn_lbl = ctk.CTkLabel(self.tests_frame, text="", text_color="#dc3545", anchor="w")
            rsn_lbl.grid(row=i, column=2, padx=10, pady=8, sticky="we")
            self.status_labels[key] = st_lbl
            self.reason_labels[key] = rsn_lbl

        # 挂载于 LED 行的确认按钮框 (默认隐藏)
        self.led_frame = ctk.CTkFrame(self.tests_frame, fg_color="transparent")
        self.btn_led = ctk.CTkButton(self.led_frame, text="确认LED闪烁?", command=lambda: on_led_confirm(session, True), fg_color="#28a745", hover_color="#218838", width=110)
        self.btn_led_fail = ctk.CTkButton(self.led_frame, text="异常", command=lambda: on_led_confirm(session, False), fg_color="#dc3545", hover_color="#c82333", width=50)
        self.btn_led.pack(side="left", padx=5)
        self.btn_led_fail.pack(side="left", padx=5)

        # 3. 右侧：专属独立日志区
        self.log_box = ctk.CTkTextbox(self, font=("Consolas", 12))
        self.log_box.grid(row=1, column=1, padx=(10, 20), pady=(0, 20), sticky="nsew")
        # 尝试配置文本颜色标签
        if hasattr(self.log_box, "_textbox"):
            self.log_box._textbox.tag_config("error", foreground="#ff4d4d")
            self.log_box._textbox.tag_config("success", foreground="#00cc44")
            self.log_box._textbox.tag_config("warn", foreground="#ffcc00")
            self.log_box._textbox.tag_config("info", foreground="#FFFFFF")

    def sync_update_status(self, key, status, reason=""):
        """此方法在主线程被调用以安全更新 UI"""
        if key not in self.status_labels: return
        colors = {"等待中": "gray", "进行中": "#3B8ED0", "Pass": "#28a745", "Fail": "#dc3545"}
        
        self.status_labels[key].configure(text=status, text_color=colors.get(status, "white"))
        
        if reason:
            self.reason_labels[key].configure(text=reason)
            
        if key == "test_led":
            if status == "进行中":
                # 展示确认按钮
                self.led_frame.grid(row=list(TEST_ITEMS.keys()).index("test_led"), column=3, padx=10)
            else:
                self.led_frame.grid_forget()

    def sync_append_log(self, msg, level="info"):
        now = datetime.now().strftime("%H:%M:%S")
        text_line = f"[{now}] {msg}\n"
        self.log_box.insert("end", text_line)
        if hasattr(self.log_box, "_textbox"):
            # 获取最后插入一行的索引
            last_line = self.log_box._textbox.index("end-1c linestart")
            self.log_box._textbox.tag_add(level, last_line, "end-1c")
        self.log_box.see("end")

# ================= 主程序 =================

class FactoryApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Hilink 工业产测全自动上位机 V2.0")
        self.geometry("1100x750")
        ctk.set_appearance_mode("dark")
        
        self.sessions = {} # MAC -> DeviceSession
        self.tabs = {}     # MAC -> DeviceTab
        self.lock = threading.Lock()
        
        self.setup_ui()
        
        # 启动后端 Server
        self.server_thread = threading.Thread(target=self.run_server, daemon=True)
        self.server_thread.start()
        
        # 启动超时检测线程
        self.timeout_thread = threading.Thread(target=self.check_timeouts, daemon=True)
        self.timeout_thread.start()

    def setup_ui(self):
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)
        
        # Header
        self.header = ctk.CTkFrame(self, height=50, corner_radius=0)
        self.header.grid(row=0, column=0, sticky="nsew")
        self.title_label = ctk.CTkLabel(self.header, text="PRO-FACTORY 自动化生产测试平台", 
                                       font=("Microsoft YaHei", 18, "bold"))
        self.title_label.pack(side="left", padx=20, pady=10)
        
        self.stat_label = ctk.CTkLabel(self.header, text="在线设备: 0", font=("Consolas", 14))
        self.stat_label.pack(side="right", padx=20)

        # TabView
        self.tabview = ctk.CTkTabview(self)
        self.tabview.grid(row=1, column=0, padx=20, pady=(10, 20), sticky="nsew")

        # Global Log Console (精简版)
        self.console = ctk.CTkTextbox(self, height=100, font=("Consolas", 12), fg_color="#1a1a1a")
        self.console.grid(row=2, column=0, padx=20, pady=(0, 20), sticky="nsew")
        self.append_global_log("系统启动, 监听端口: " + str(SERVER_PORT))

    def append_global_log(self, msg):
        self.after(0, self._sync_global_log, msg)
        
    def _sync_global_log(self, msg):
        now = datetime.now().strftime("%H:%M:%S")
        self.console.insert("end", f"[{now}] {msg}\n")
        self.console.see("end")

    def run_server(self):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.bind(('0.0.0.0', SERVER_PORT))
        s.listen(10)
        while True:
            conn, addr = s.accept()
            threading.Thread(target=self.handle_client, args=(conn, addr), daemon=True).start()

    def handle_client(self, conn, addr):
        conn.settimeout(20)
        # 启用激进的 TCP Keepalive (Windows 专用)
        try:
            conn.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
            # 3秒无数据开始探测，每1秒探测一次，探测5次失败则断开
            conn.ioctl(socket.SIO_KEEPALIVE_VALS, (1, 3000, 1000))
        except:
            pass
        try:
            raw_data = self.receive_json(conn)
            if not raw_data or raw_data.get("cmd") != "device_register":
                return

            mac = raw_data.get("mac")
            with self.lock:
                if mac in self.sessions:
                    session = self.sessions[mac]
                    if session.is_rebooting:
                        elapsed = time.time() - session.reboot_start_time
                        if elapsed <= RECONN_TIMEOUT:
                            session.results["test_wdog"] = True
                            self.update_ui_state(mac, "test_wdog", "Pass")
                            self.append_device_log(mac, f"看门狗重连成功: 耗时 {elapsed:.1f}s", "success")
                        else:
                            session.results["test_wdog"] = False
                            self.update_ui_state(mac, "test_wdog", "Fail", "重连超时")
                            self.append_device_log(mac, f"看门狗重连超时: 耗时 {elapsed:.1f}s", "error")
                            self.finish_session(session, "看门狗超时")
                        session.is_rebooting = False
                        session.socket = conn
                    else:
                        session.socket = conn
                        if session.finish_time is not None:
                            # 已经完成的设备重复连接则忽略
                            return
                else:
                    session = DeviceSession(mac, raw_data.get("imei"), raw_data.get("iccid"))
                    session.socket = conn
                    self.sessions[mac] = session
                    self.after(0, self.add_device_tab, session)
                    self.append_global_log(f"新设备接入: {mac}")
            
            # 不论新旧连接，如果是尚未完成状态，都执行测试管线
            if not session.is_done:
                self.run_test_pipeline(session)

            # ----- 管线执行完毕或处于已完成状态，转入连接状态监控 -----
            try:
                while True:
                    try:
                        conn.settimeout(5.0)
                        data = conn.recv(1024)
                        if not data: # 收到空数据，表示对端正常关闭连接 (EOF)
                            break
                    except socket.timeout:
                        # 重点：对于已经完成的设备，定期发送一个空行(Heartbeat)
                        # 如果物理连接已断开，sendall 会立刻抛出异常
                        try:
                            conn.sendall(b"\n")
                        except:
                            break
                        continue
            except Exception:
                pass
            finally:
                with self.lock:
                    # 只有当不是因为重启导致的断开时，且 session 依然是当前这个时，才清理界面
                    if mac in self.sessions and self.sessions[mac] is session:
                        if not session.is_rebooting:
                            del self.sessions[mac]
                            self.after(0, self._sync_remove_tab, mac)
                            self.append_global_log(f"设备 {mac} 连接已断开，自动清理测试看板。")

        except Exception as e:
            self.append_global_log(f"连接处理异常 [{addr}]: {e}")

    def receive_json(self, conn, timeout=60):
        buffer = ""
        try:
            conn.settimeout(timeout)
        except:
            return None
            
        while True:
            try:
                chunk = conn.recv(1024).decode('utf-8')
                if not chunk: 
                    return None
                buffer += chunk
                if "}" in buffer:
                    return json.loads(buffer)
            except (socket.timeout, json.JSONDecodeError, Exception):
                return None

    def send_json(self, session, data):
        """发送指令并等待设备 ACK 确认是否收到"""
        if not session.socket:
            return False
        try:
            cmd_name = data.get("cmd", "unknown")
            session.socket.sendall((json.dumps(data) + "\n").encode('utf-8'))
            
            # 发送后立即等待 2s 的确认响应 (ACK)
            ack = self.receive_json(session.socket, timeout=2)
            if ack and ack.get("cmd") == "ack" and ack.get("ref_cmd") == cmd_name:
                return True
            self.append_device_log(session.mac, f"指令 [{cmd_name}] 发送失败: 设备未确认收到", "error")
        except Exception as e:
            self.append_global_log(f"Socket 发送异常: {e}")
        return False

    # ---------- 核心测试管线 ---------- #
    def run_test_pipeline(self, session):
        mac = session.mac
        try:
            # 1. 云端数据
            # 修改点：如果之前已经成功获取了 tuple_data，则跳过获取，不再重复请求
            if session.results.get("fetch_sn") != True:
                self.update_ui_state(mac, "fetch_sn", "进行中")
                self.append_device_log(mac, "正在请求云端设备信息...")
                data = CloudAPI.fetch_tuple(mac)
                if data:
                    session.tuple_data = data
                    session.results["fetch_sn"] = True
                    self.update_ui_state(mac, "fetch_sn", "Pass")
                    self.append_device_log(mac, "云端数据获取成功", "success")
                else:
                    session.results["fetch_sn"] = False
                    self.update_ui_state(mac, "fetch_sn", "Fail", "云端接口无响应/失败")
                    self.append_device_log(mac, "云端获取失败", "error")
            else:
                self.append_device_log(mac, "检测到已有云端SN数据，跳过获取步骤。")

            # 内部辅助函数用于测试基础项
            def do_check(step_key, cmd_name, title):
                if step_key not in session.results:
                    
                    self.update_ui_state(mac, step_key, "进行中")
                    self.append_device_log(mac, f"发起 [{title}] 测试...")
                    # 调用 send_json 时会自动阻塞等待 ACK
                    if not self.send_json(session, {"cmd": cmd_name}):
                        self.update_ui_state(mac, step_key, "Fail", "通信超时(ACK)")
                        return "BREAK"

                    # ACK 收到后，进入长时间的结果等待期
                    resp = self.receive_json(session.socket, timeout=60)
                    if resp:
                        if resp.get("result") == "pass":
                            session.results[step_key] = True
                            self.update_ui_state(mac, step_key, "Pass")
                            self.append_device_log(mac, f"[{title}] 结果: Pass", "success")
                            return True
                        elif resp.get("result") == "fail":
                            session.results[step_key] = False
                            rsn_code = resp.get("code", "ERROR")
                            if step_key == "test_wifi":
                                self.update_ui_state(mac, step_key, "Fail", f"代码:{rsn_code} RSSI:{resp.get('rssi','N/A')}")
                            else:
                                self.update_ui_state(mac, step_key, "Fail", f"代码:{rsn_code}")
                            self.append_device_log(mac, f"[{title}] 测试失败: {resp.get('logs', '')}", "error")
                            return True
                    else:
                        self.update_ui_state(mac, step_key, "Fail", "通信中断(Result超时)")
                        self.append_device_log(mac, f"[{title}] 执行超时，通信已断开", "error")
                        return "BREAK"
                return True

            # 执行基础测试项：Net, WiFi, LTE
            # 如果任意一项出现 BREAK (通信故障)，则停止后续所有测试
            for item in [("test_net", "test_net", "网口"), 
                        ("test_wifi", "test_wifi", "WiFi"), 
                        ("test_lte", "test_lte", "LTE")]:
                res = do_check(*item)
                if res == "BREAK": 
                    return self.finish_session(session, "设备连接异常(ACK Timeout)")

            if "test_serial" not in session.results:
                # 调用独立的串口测试函数
                res = self.perform_serial_test(session)
                if res == "BREAK":
                    return self.finish_session(session, "串口测试通讯故障")

            # LED
            if "test_led" not in session.results:
                self.update_ui_state(mac, "test_led", "进行中")
                self.append_device_log(mac, "下发LED指令，等待人工确认...", "warn")
                if not self.send_json(session, {"cmd": "test_led"}):
                    self.update_ui_state(mac, "test_led", "Fail", "通信异常")
                    return self.finish_session(session, "LED控制指令无响应")

                session.interactive_event.wait()
                if session.interactive_result:
                    session.results["test_led"] = True
                    self.update_ui_state(mac, "test_led", "Pass")
                    self.append_device_log(mac, "人工确认LED通过", "success")
                else:
                    session.results["test_led"] = False
                    self.update_ui_state(mac, "test_led", "Fail", "按下了异常")
                    self.append_device_log(mac, "人工判断LED错误", "error")

            # Watchdog
            if "test_wdog" not in session.results:
                self.update_ui_state(mac, "test_wdog", "进行中")
                self.append_device_log(mac, "下发看门狗重启指令，等待设备重连...", "warn")
                session.reboot_start_time = time.time()
                session.is_rebooting = True
                self.send_json(session, {"cmd": "test_wdog"})
                
                # 看门狗 ACK 检查 (必须确认设备收到了重启指令再断开连接)
                ack = self.receive_json(session.socket, timeout=2)
                if not ack or ack.get("cmd") != "ack":
                    session.is_rebooting = False
                    self.update_ui_state(mac, "test_wdog", "Fail", "ACK超时")
                    return self.finish_session(session, "看门狗指令发送失败")
                
                # 结束当前连接线程，等待设备重连后新的接受线程来继续触发
                if session.socket:
                    try: session.socket.close()
                    except: pass
                    session.socket = None
                return 

            # 如果前面触发过 watchdog 且重连回来的 session 会携带 test_wdog == True
            if session.results.get("test_wdog") == True:
                # --- 终审环节 ---
                # 检查除了 write_tuple 以外的所有项是否都为 True
                # 修复点：使用全局 TEST_ITEMS 避免 AttributeError
                failed_items = [TEST_ITEMS.get(k, k) for k, v in session.results.items() if v is False]
                
                if not failed_items:
                    if "write_tuple" not in session.results:
                        self.update_ui_state(mac, "write_tuple", "进行中")
                        write_cmd = {"cmd": "write_tuple"}
                        if session.tuple_data:
                            write_cmd.update(session.tuple_data)
                        if not self.send_json(session, write_cmd):
                            self.update_ui_state(mac, "write_tuple", "Fail", "通信异常")
                            return self.finish_session(session, "五元组写入指令无响应")

                        resp = self.receive_json(session.socket)
                        if resp and resp.get("result") == "pass":
                            session.results["write_tuple"] = True
                            self.update_ui_state(mac, "write_tuple", "Pass")
                            self.append_device_log(mac, "成功写入五元组，测试大成功！", "success")
                            self.finish_session(session)
                        elif resp is None:
                            self.update_ui_state(mac, "write_tuple", "Fail", "通信超时")
                            return self.finish_session(session, "五元组写入结果接收超时")
                        else:
                            rsn = resp.get("msg", "失败")
                            session.results["write_tuple"] = False
                            self.update_ui_state(mac, "write_tuple", "Fail", rsn)
                            self.append_device_log(mac, f"写入五元组失败: {rsn}", "error")
                            self.finish_session(session, "写入烧录阶段逻辑错误")
                else:
                    self.update_ui_state(mac, "write_tuple", "Fail", "前项有失败，跳过写入")
                    self.append_device_log(mac, f"检测到失败项: {', '.join(failed_items)}，禁止写入五元组。", "error")
                    self.finish_session(session, "测试项未全通过")
            else:
                 # watchdog timeout logic sets false
                 return self.finish_session(session, "看门狗未通过")

        except Exception as e:
            # 修复点：不再固定标记为 fetch_sn 失败，改为通用日志记录，避免误导
            # 如果需要，可以单独给 write_tuple 或 test_wdog 标记 Fail
            self.append_global_log(f"设备 {mac} 流程异常: {e}")
            self.append_device_log(mac, f"流程异常崩溃: {e}", "error")
            self.finish_session(session, "意外崩溃/断开连接")

    def perform_serial_test(self, session):
        """独立的双路串口回环测试函数"""
        mac = session.mac
        self.update_ui_state(mac, "test_serial", "进行中")
        
        # 1. 准备测试数据 (Base64 编码)
        raw_str = "FACTORY_TEST_DATA_2024"
        payload = base64.b64encode(raw_str.encode()).decode('utf-8')
        
        # 2. 构造指令 (固定波特率 115200)
        cmd = {
            "cmd": "test_serial",
            "data": payload,
            "baudrate": 115200
        }
        
        self.append_device_log(mac, "发起双路串口回环测试: 波特率 115200, 等待回传...")
        
        # 3. 发送并等待 ACK
        if not self.send_json(session, cmd):
            self.update_ui_state(mac, "test_serial", "Fail", "指令发送失败")
            return "BREAK"

        # 4. 接收结果 (严格 5s 超时)
        resp = self.receive_json(session.socket, timeout=5)
        
        if resp is None:
            self.update_ui_state(mac, "test_serial", "Fail", "超时 (5s)")
            self.append_device_log(mac, "串口测试失败: 5秒内未收到任何回传数据", "error")
            session.results["test_serial"] = False
            return False
            
        # 5. 校验双路数据一致性
        received_data1 = resp.get("data1")
        received_data2 = resp.get("data2")
        
        p1_ok = (received_data1 == payload)
        p2_ok = (received_data2 == payload)
        
        if p1_ok and p2_ok:
            session.results["test_serial"] = True
            self.update_ui_state(mac, "test_serial", "Pass")
            self.append_device_log(mac, "串口回环校验成功", "success")
            return True
        else:
            session.results["test_serial"] = False
            error_reason = ""
            if not p1_ok and not p2_ok:
                error_reason = "P1&P2 校验失败"
            elif not p1_ok:
                error_reason = "P1 校验失败"
            else:
                error_reason = "P2 校验失败"
            
            self.update_ui_state(mac, "test_serial", "Fail", error_reason)
            self.append_device_log(mac, f"串口回传异常: {error_reason}", "error")
            return False

    # ---------- UI 调度封装 ---------- #
    def add_device_tab(self, session):
        # 建立 Tab
        tab = self.tabview.add(session.mac)
        p_card = DeviceTab(tab, session, self.on_led_confirm)
        p_card.pack(fill="both", expand=True)
        self.tabs[session.mac] = p_card
        
        # 激活此 Tab
        self.tabview.set(session.mac)
        self.update_stat()

    def update_ui_state(self, mac, step_key, status, reason=""):
        self.after(0, self._sync_update_ui_state, mac, step_key, status, reason)
        
    def _sync_update_ui_state(self, mac, step_key, status, reason):
        if mac in self.tabs:
            self.tabs[mac].sync_update_status(step_key, status, reason)

    def append_device_log(self, mac, msg, level="info"):
        self.after(0, self._sync_append_device_log, mac, msg, level)

    def _sync_append_device_log(self, mac, msg, level):
        if mac in self.tabs:
            self.tabs[mac].sync_append_log(msg, level)

    def on_led_confirm(self, session, result):
        session.interactive_result = result
        session.interactive_event.set()

    def finish_session(self, session, reason=None):
        with self.lock:
            if not session.is_done:
                session.is_done = True
                session.finish_time = time.time()
                if reason:
                    self.append_device_log(session.mac, f"【流程停止】原因: {reason}", "error")
                else:
                    self.append_device_log(session.mac, f"【流程竣工】全部测试完美结束", "success")
                self.append_device_log(session.mac, f"测试已结束，等待连接断开后自动关闭界面...", "warn")

    def _sync_remove_tab(self, mac):
        if mac in self.tabs:
            # tkinter 并没有直接提供 destory tab 但 customTkinter 提供 delete
            try:
                self.tabview.delete(mac)
            except:
                pass
            del self.tabs[mac]
        self.update_stat()

    def update_stat(self):
        self.stat_label.configure(text=f"在线设备: {len(self.sessions)}")

    def check_timeouts(self):
        """定期检查重连超时及清理结束的设备"""
        while True:
            now = time.time()
            to_remove = []
            
            with self.lock:
                for mac, session in list(self.sessions.items()):
                    # 1. 看门狗重连超时
                    if session.is_rebooting and (now - session.reboot_start_time > RECONN_TIMEOUT):
                        # 人工介入设为 Fail
                        session.is_rebooting = False
                        session.results["test_wdog"] = False
                        self.update_ui_state(mac, "test_wdog", "Fail", "规定时间内未重连")
                        self.append_device_log(mac, f"重连验证超时 ({RECONN_TIMEOUT}s)", "error")
                        self.finish_session(session, "看门狗未重连")
                        
                    # 2. 移除旧的 10 秒倒计时清理逻辑（现在由连接断开自动触发）
                    pass
                        
                for mac in to_remove:
                    del self.sessions[mac]
                    self.after(0, self._sync_remove_tab, mac)
                    self.append_global_log(f"已自动清理设备 {mac} 的测试记录。")

            time.sleep(1)

if __name__ == "__main__":
    app = FactoryApp()
    app.mainloop()
