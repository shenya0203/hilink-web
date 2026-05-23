import serial
import serial.tools.list_ports
import threading
import time
from datetime import datetime
import customtkinter as ctk


BAUDRATES = [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600]
ECHO_DELAY = 1.0


class SerialChannel:
    def __init__(self, port_name, baudrate, log_callback, status_callback):
        self.port_name = port_name
        self.baudrate = baudrate
        self.log_callback = log_callback
        self.status_callback = status_callback
        self.ser = None
        self.running = False
        self.thread = None

    def open(self):
        try:
            self.ser = serial.Serial(
                port=self.port_name,
                baudrate=self.baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=0.1,
            )
            self.running = True
            self.status_callback(self.port_name, "已打开", "#28a745")
            self.log_callback(self.port_name, f"串口已打开 (波特率: {self.baudrate})", "info")
            self.thread = threading.Thread(target=self._read_loop, daemon=True)
            self.thread.start()
            return True
        except Exception as e:
            self.status_callback(self.port_name, f"打开失败", "#dc3545")
            self.log_callback(self.port_name, f"打开失败: {e}", "error")
            return False

    def close(self):
        self.running = False
        if self.thread:
            self.thread.join(timeout=2)
        if self.ser and self.ser.is_open:
            try:
                self.ser.close()
            except Exception:
                pass
        self.status_callback(self.port_name, "已关闭", "gray")

    def _read_loop(self):
        while self.running:
            try:
                if self.ser and self.ser.is_open and self.ser.in_waiting > 0:
                    data = self.ser.read(self.ser.in_waiting)
                    if data:
                        hex_str = ' '.join(f'{b:02X}' for b in data)
                        ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in data)
                        try:
                            text_str = data.decode('utf-8')
                        except UnicodeDecodeError:
                            text_str = None
                        display = f"← 收到 {len(data)} 字节\n  HEX: {hex_str}\n  ASC: {ascii_str}"
                        if text_str:
                            display += f"\n  TXT: {text_str}"
                        self.log_callback(self.port_name, display, "receive")

                        time.sleep(ECHO_DELAY)

                        if self.running and self.ser and self.ser.is_open:
                            self.ser.write(data)
                            self.log_callback(
                                self.port_name,
                                f"→ 回显 {len(data)} 字节 (延时 {ECHO_DELAY}s)",
                                "send",
                            )
                else:
                    time.sleep(0.05)
            except Exception as e:
                if self.running:
                    self.log_callback(self.port_name, f"读线程异常: {e}", "error")
                    self.status_callback(self.port_name, "异常", "#dc3545")
                time.sleep(0.5)


class SerialEchoApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("串口回环测试工具 v1.0")
        self.geometry("900x650")
        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("blue")

        self.channels = {}
        self.running = False
        self.start_time = None

        self._build_ui()
        self._refresh_ports()

    def _build_ui(self):
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(2, weight=1)

        header = ctk.CTkFrame(self, height=50, corner_radius=0)
        header.grid(row=0, column=0, sticky="nsew")
        ctk.CTkLabel(
            header,
            text="串口回环测试工具",
            font=("Microsoft YaHei", 18, "bold"),
        ).pack(side="left", padx=20, pady=10)
        self.time_label = ctk.CTkLabel(header, text="运行时间: 00:00:00", font=("Consolas", 14))
        self.time_label.pack(side="right", padx=20)

        cfg_frame = ctk.CTkFrame(self)
        cfg_frame.grid(row=1, column=0, padx=15, pady=(10, 5), sticky="ew")
        cfg_frame.grid_columnconfigure((0, 1, 2, 3, 4), weight=1)

        ctk.CTkLabel(cfg_frame, text="串口1:", font=("Microsoft YaHei", 13)).grid(row=0, column=0, padx=5, pady=10, sticky="e")
        self.port1_var = ctk.StringVar()
        self.port1_menu = ctk.CTkOptionMenu(cfg_frame, variable=self.port1_var, values=[""], width=140)
        self.port1_menu.grid(row=0, column=1, padx=5, pady=10, sticky="w")
        self.status1_lbl = ctk.CTkLabel(cfg_frame, text="未打开", text_color="gray", font=("Consolas", 12))
        self.status1_lbl.grid(row=0, column=2, padx=5, pady=10, sticky="w")

        ctk.CTkLabel(cfg_frame, text="串口2:", font=("Microsoft YaHei", 13)).grid(row=0, column=3, padx=(20, 5), pady=10, sticky="e")
        self.port2_var = ctk.StringVar()
        self.port2_menu = ctk.CTkOptionMenu(cfg_frame, variable=self.port2_var, values=[""], width=140)
        self.port2_menu.grid(row=0, column=4, padx=5, pady=10, sticky="w")
        self.status2_lbl = ctk.CTkLabel(cfg_frame, text="未打开", text_color="gray", font=("Consolas", 12))
        self.status2_lbl.grid(row=0, column=5, padx=5, pady=10, sticky="w")

        ctk.CTkLabel(cfg_frame, text="波特率:", font=("Microsoft YaHei", 13)).grid(row=0, column=6, padx=(20, 5), pady=10, sticky="e")
        self.baud_var = ctk.StringVar(value="115200")
        self.baud_menu = ctk.CTkOptionMenu(
            cfg_frame, variable=self.baud_var, values=[str(b) for b in BAUDRATES], width=100
        )
        self.baud_menu.grid(row=0, column=7, padx=5, pady=10, sticky="w")

        self.refresh_btn = ctk.CTkButton(cfg_frame, text="刷新", command=self._refresh_ports, width=60)
        self.refresh_btn.grid(row=0, column=8, padx=5, pady=10)

        self.start_btn = ctk.CTkButton(
            cfg_frame, text="开始测试", command=self._toggle_test, width=100, fg_color="#28a745", hover_color="#218838"
        )
        self.start_btn.grid(row=0, column=9, padx=(10, 15), pady=10)

        log_frame = ctk.CTkFrame(self)
        log_frame.grid(row=2, column=0, padx=15, pady=(5, 15), sticky="nsew")
        log_frame.grid_rowconfigure(0, weight=1)
        log_frame.grid_columnconfigure(0, weight=1)

        self.log_box = ctk.CTkTextbox(log_frame, font=("Consolas", 12), wrap="word")
        self.log_box.grid(row=0, column=0, sticky="nsew")
        self.log_box.configure(state="disabled")

        self._update_timer()

    def _refresh_ports(self):
        ports = [p.device for p in serial.tools.list_ports.comports()]
        if not ports:
            ports = [""]
        if self.port1_menu.cget("values") != ports:
            self.port1_menu.configure(values=ports)
        if self.port2_menu.cget("values") != ports:
            self.port2_menu.configure(values=ports)

    def _toggle_test(self):
        if self.running:
            self._stop_test()
        else:
            self._start_test()

    def _start_test(self):
        port1 = self.port1_var.get()
        port2 = self.port2_var.get()
        baud = int(self.baud_var.get())

        if not port1 or not port2:
            self._append_log("系统", "请选择两个串口号", "error")
            return
        if port1 == port2:
            self._append_log("系统", "两个串口号不能相同", "error")
            return

        self.running = True
        self.start_btn.configure(text="停止测试", fg_color="#dc3545", hover_color="#c82333")
        self.port1_menu.configure(state="disabled")
        self.port2_menu.configure(state="disabled")
        self.baud_menu.configure(state="disabled")
        self.refresh_btn.configure(state="disabled")
        self._clear_log()

        self.start_time = time.time()
        self._append_log("系统", f"开始测试 串口1={port1} 串口2={port2} 波特率={baud}", "info")

        for name, var, lbl in [
            ("串口1", port1, self.status1_lbl),
            ("串口2", port2, self.status2_lbl),
        ]:
            ch = SerialChannel(
                port_name=var,
                baudrate=baud,
                log_callback=self._append_log,
                status_callback=self._update_status,
            )
            self.channels[name] = ch
            ch.open()

    def _stop_test(self):
        self.running = False
        self.start_time = None
        for ch in self.channels.values():
            ch.close()
        self.channels.clear()

        self.start_btn.configure(text="开始测试", fg_color="#28a745", hover_color="#218838")
        self.port1_menu.configure(state="normal")
        self.port2_menu.configure(state="normal")
        self.baud_menu.configure(state="normal")
        self.refresh_btn.configure(state="normal")
        self._append_log("系统", "测试已停止", "warn")

    def _update_status(self, port_name, text, color):
        p1 = self.port1_var.get()
        p2 = self.port2_var.get()
        if port_name == p1:
            self.after(0, lambda: self.status1_lbl.configure(text=text, text_color=color))
        elif port_name == p2:
            self.after(0, lambda: self.status2_lbl.configure(text=text, text_color=color))

    def _append_log(self, channel, msg, level="info"):
        self.after(0, self._sync_append_log, channel, msg, level)

    def _sync_append_log(self, channel, msg, level):
        now = datetime.now().strftime("%H:%M:%S")
        tag_map = {"info": "#CCCCCC", "receive": "#3B8ED0", "send": "#28a745", "error": "#ff4d4d", "warn": "#ffcc00"}
        color = tag_map.get(level, "#CCCCCC")
        self.log_box.configure(state="normal")
        self.log_box.insert("end", f"[{now}] [{channel}] {msg}\n")
        last_line_start = self.log_box.index("end-1c linestart")
        last_line_end = self.log_box.index("end-1c")
        self.log_box.tag_add(level, last_line_start, last_line_end)
        self.log_box.tag_config(level, foreground=color)
        self.log_box.see("end")
        self.log_box.configure(state="disabled")

    def _clear_log(self):
        self.log_box.configure(state="normal")
        self.log_box.delete("0.0", "end")
        self.log_box.configure(state="disabled")

    def _update_timer(self):
        if self.start_time is not None and self.running:
            elapsed = int(time.time() - self.start_time)
            h, m, s = elapsed // 3600, (elapsed % 3600) // 60, elapsed % 60
            self.time_label.configure(text=f"运行时间: {h:02d}:{m:02d}:{s:02d}")
        self.after(1000, self._update_timer)


if __name__ == "__main__":
    app = SerialEchoApp()
    app.mainloop()
