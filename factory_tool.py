import socket
import threading
import json
import time
import base64
import queue
from datetime import datetime
import customtkinter as ctk
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad

# ================= 配置与常量 =================
SERVER_PORT = 998
WATCHDOG_TIMEOUT = 40  # 看门狗重连超时（秒）
AES_KEY = b'1234567890123456'  # 16字节密钥
AES_IV = b'abcdefghij123456'   # 16字节偏移量

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
            return base64.b64encode(text.encode()).decode() # 降级方案

class CloudAPI:
    """模拟云端接口"""
    @staticmethod
    def fetch_tuple(mac):
        # 模拟网络延迟和可能的失败
        time.sleep(1)
        # 假设 80% 概率获取成功
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
        self.status = "Connected"
        self.results = {}
        self.tuple_data = None
        self.last_seen = time.time()
        self.current_step = "Idle"
        self.interactive_event = threading.Event()
        self.interactive_result = False
        self.is_rebooting = False  # 是否处于看门狗重启等待期
        self.socket = None
        self.is_done = False

    def log(self, msg):
        print(f"[{self.mac}] {msg}")

# ================= UI 组件 =================

class DeviceCard(ctk.CTkFrame):
    """设备测试卡片组件"""
    def __init__(self, master, session, on_led_confirm):
        super().__init__(master)
        self.session = session
        
        self.grid_columnconfigure(1, weight=1)
        self.configure(fg_color=("#EAEAEA", "#2B2B2B"), corner_radius=10)
        
        # MAC & 状态
        self.label_info = ctk.CTkLabel(self, text=f"MAC: {session.mac}\nIMEI: {session.imei}", 
                                      justify="left", font=("Consolas", 12))
        self.label_info.grid(row=0, column=0, padx=15, pady=10, sticky="nw")
        
        # 进度/状态说明
        self.label_status = ctk.CTkLabel(self, text="正在初始化...", text_color="#3B8ED0")
        self.label_status.grid(row=0, column=1, padx=10, pady=10)
        
        # 各项结果点状显示 (Mock LED 墙)
        self.res_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.res_frame.grid(row=0, column=2, padx=15)
        
        # LED 确认按钮 (初始隐藏)
        self.btn_led = ctk.CTkButton(self, text="确认LED闪烁?", width=100, 
                                     command=lambda: on_led_confirm(session, True),
                                     fg_color="#28a745", hover_color="#218838")
        self.btn_led_fail = ctk.CTkButton(self, text="异常", width=60, 
                                          command=lambda: on_led_confirm(session, False),
                                          fg_color="#dc3545", hover_color="#c82333")

    def update_ui(self):
        self.label_status.configure(text=f"当前阶段: {self.session.current_step}")
        if self.session.current_step == "LED人工确认":
            self.btn_led.grid(row=0, column=3, padx=5)
            self.btn_led_fail.grid(row=0, column=4, padx=5)
        else:
            self.btn_led.grid_forget()
            self.btn_led_fail.grid_forget()
        
        if "test_net" in self.session.results:
            color = "#28a745" if self.session.results.get("test_net") else "#dc3545"
            self.label_status.configure(text_color=color)

# ================= 主程序 =================

class FactoryApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Hilink 工业产测全自动上位机 V1.0")
        self.geometry("1000x700")
        ctk.set_appearance_mode("dark")
        
        self.sessions = {} # MAC -> DeviceSession
        self.cards = {}    # MAC -> DeviceCard
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
        self.header = ctk.CTkFrame(self, height=60, corner_radius=0)
        self.header.grid(row=0, column=0, sticky="nsew")
        self.title_label = ctk.CTkLabel(self.header, text="PRO-FACTORY 自动化生产测试平台", 
                                       font=("Microsoft YaHei", 20, "bold"))
        self.title_label.pack(side="left", padx=20, pady=15)
        
        self.stat_label = ctk.CTkLabel(self.header, text="在线设备: 0", font=("Consolas", 14))
        self.stat_label.pack(side="right", padx=20)

        # Device List (Scrollable)
        self.scroll_frame = ctk.CTkScrollableFrame(self, label_text="待测设备列表")
        self.scroll_frame.grid(row=1, column=0, padx=20, pady=20, sticky="nsew")
        
        # Log Console
        self.console = ctk.CTkTextbox(self, height=150, font=("Consolas", 12))
        self.console.grid(row=2, column=0, padx=20, pady=(0, 20), sticky="nsew")
        self.append_log("系统启动, 监听端口: " + str(SERVER_PORT))

    def append_log(self, msg):
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
        try:
            # 1. 等待注册报文
            raw_data = self.receive_json(conn)
            if not raw_data or raw_data.get("cmd") != "device_register":
                return

            mac = raw_data.get("mac")
            with self.lock:
                if mac in self.sessions and self.sessions[mac].is_rebooting:
                    # 原有设备重连（看门狗验证成功）
                    session = self.sessions[mac]
                    session.socket = conn
                    session.is_rebooting = False
                    session.status = "Reconnected"
                    self.append_log(f"设备 {mac} 看门狗重启验证成功！")
                    # 直接跳到烧写流程在测试循环里处理
                else:
                    # 新设备接入
                    session = DeviceSession(mac, raw_data.get("imei"), raw_data.get("iccid"))
                    session.socket = conn
                    self.sessions[mac] = session
                    self.after(0, self.add_device_ui, session)
                    self.append_log(f"新设备接入: {mac}")
            
            self.run_test_pipeline(session)
            
        except Exception as e:
            print(f"Error handling {addr}: {e}")

    def receive_json(self, conn):
        # 简单的 JSON 流解析逻辑
        buffer = ""
        while True:
            chunk = conn.recv(1024).decode('utf-8')
            if not chunk: return None
            buffer += chunk
            try:
                print("JSON 数据:", buffer)
                # 处理粘包/半包逻辑（这里假设一次收一个完整JSON）
                return json.loads(buffer)
            except:
                print("等待完整的 JSON 数据...")
                continue

    def send_json(self, session, data):
        if session.socket:
            session.socket.sendall(json.dumps(data).encode('utf-8'))

    def run_test_pipeline(self, session):
        """全自动测试流水线"""
        try:
            # Step 1: 获取云端数据 (异步但不阻塞其他项)
            session.current_step = "获取云端SN"
            while not session.tuple_data:
                data = CloudAPI.fetch_tuple(session.mac)
                if data:
                    session.tuple_data = data
                    self.append_log(f"{session.mac} 云端数据获取成功")
                else:
                    session.current_step = "获取SN失败, 重试中..."
                    time.sleep(2)

            # Step 2: 自动化固件测试
            session.current_step = "基础功能测试"
            print("正在进行 Net 测试...")
            # Net 测试
            self.send_json(session, {"cmd": "test_net"})
            resp = self.receive_json(session.socket)
            print("Net 测试结果:", resp)
            session.results["test_net"] = (resp.get("result") == "pass")

            # LTE 测试
            print("正在进行 LTE 测试...")
            self.send_json(session, {"cmd": "test_lte"})
            resp = self.receive_json(session.socket)
            print("LTE 测试结果:", resp)
            session.results["test_lte"] = (resp.get("result") == "pass")

            # Serial 测试 (加密)
            print("Serial 测试 (加密)...")
            payload = CryptoHelper.encrypt_b64("FACTORY_TEST_DATA_2024")
            print("加密后数据:", payload)
            self.send_json(session, {"cmd": "test_serial", "data": payload})
            resp = self.receive_json(session.socket)
            session.results["test_serial"] = (resp.get("data") is not None)

            # Step 3: LED 人工确认
            session.current_step = "LED人工确认"
            self.send_json(session, {"cmd": "test_led"})
            session.interactive_event.wait() # 等待 UI 点击
            session.results["test_led"] = session.interactive_result

            # Step 4: 看门狗重启测试
            session.current_step = "看门狗重启验证"
            session.is_rebooting = True
            session.last_seen = time.time()
            self.send_json(session, {"cmd": "test_wdog"}) # 发送该命令后设备应停止喂狗并重启
            
            # 设置一个较短的超时，用来探测设备是否在规定时间内断开
            session.socket.settimeout(5) 
            try:
                # 下发指令后，设备应该会停止喂狗。
                # 这里的 recv(1024) 会阻塞直到：1. 收到数据 2. 超时 3. 连接断开
                dummy_data = session.socket.recv(1024)
                
                # 如果能走到这里且连接没断开，说明设备没重启
                if session.socket:
                    session.current_step = "看门狗失效(Fail)"
                    self.append_log(f"{session.mac} 错误: 25秒内未检测到设备重启断连")
                    return
            except (socket.timeout):
                # 如果是超时了，说明连接还在，看门狗没起作用
                session.current_step = "看门狗未触发(Fail)"
                self.append_log(f"{session.mac} 错误: 设备仍在线，看门狗未能使其重启")
                return
            except (ConnectionResetError, BrokenPipeError, socket.error):
                # 捕获到连接重置或错误，说明设备已经断开了，符合看门狗重启预期
                self.append_log(f"{session.mac} 检测到连接断开(正常重启)")
            finally:
                if session.socket:
                    session.socket.close()
                    session.socket = None
            # 继续执行原来的等待重连逻辑
            self.append_log(f"{session.mac} 进入40s重连等待窗口...")

            # Step 5: 最终烧写
            session.current_step = "写入五元组"
            write_cmd = {"cmd": "write_tuple"}
            write_cmd.update(session.tuple_data)
            self.send_json(session, write_cmd)
            
            resp = self.receive_json(session.socket)
            if resp.get("result") == "pass":
                session.current_step = "产测成功"
                session.is_done = True
                self.append_log(f"{session.mac} 全部流程圆满完成")
                time.sleep(3) # 留时间看结果
                self.remove_device_ui(session)

        except Exception as e:
            session.current_step = f"异常终止: {str(e)}"
            self.append_log(f"{session.mac} 测试异常: {e}")

    # --- UI 辅助方法 ---
    def add_device_ui(self, session):
        card = DeviceCard(self.scroll_frame, session, self.on_led_confirm)
        card.pack(fill="x", padx=10, pady=5)
        self.cards[session.mac] = card
        self.update_stat()

    def on_led_confirm(self, session, result):
        session.interactive_result = result
        session.interactive_event.set()
        self.append_log(f"{session.mac} 人工确认LED: {'Pass' if result else 'Fail'}")

    def remove_device_ui(self, session):
        if session.mac in self.cards:
            self.cards[session.mac].destroy()
            del self.cards[session.mac]
        if session.mac in self.sessions:
            del self.sessions[session.mac]
        self.update_stat()

    def update_stat(self):
        self.stat_label.configure(text=f"在线设备: {len(self.sessions)}")

    def check_timeouts(self):
        """定期更新 UI 状态"""
        while True:
            with self.lock:
                for mac, card in list(self.cards.items()):
                    card.update_ui()
            time.sleep(0.5)

if __name__ == "__main__":
    app = FactoryApp()
    app.mainloop()
