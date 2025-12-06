import os
import socket

def copy_file(input_file, output_path):
    try:
        # 排除当前的 Python 脚本文件
        if input_file == os.path.abspath(__file__):
            return

        # 以二进制模式打开输入文件进行读取
        with open(input_file, 'rb') as f_input:
            # 读取输入文件内容
            file_content = f_input.read()

            # 构造输出文件路径
            output_file = os.path.join(output_path, os.path.basename(input_file))

            # 以二进制模式打开输出文件进行写入
            with open(output_file, 'wb') as f_output:
                # 将读取的内容写入输出文件
                f_output.write(file_content)

        print("文件内容已成功保存到", output_file)
        # # 创建UDP socket对象
        # udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        #
        # # 目标地址和端口
        # dest_addr = ('192.168.3.4', 10848)
        #
        # # 要发送的消息
        # message = 'OK'
        #
        # # 发送消息
        # udp_socket.sendto(message.encode(), dest_addr)
        #
        # # 关闭socket
        # udp_socket.close()


    except FileNotFoundError:
        print("找不到文件:", input_file)
    except Exception as e:
        print("发生错误:", str(e))

def make_writable(file_path):
    try:
        # 获取文件权限并设置为可写
        os.chmod(file_path, 0o666)
        print("文件已设置为可写:", file_path)
    except Exception as e:
        print("无法设置文件为可写:", str(e))

def process_folder(folder_path):
    try:
        # 获取文件夹中的所有文件和子文件夹
        items = os.listdir(folder_path)
        for item in items:
            item_path = os.path.join(folder_path, item)
            if os.path.isfile(item_path):
                file_name = os.path.basename(item_path)
                if file_name != "test.bat" and file_name != "test.py" and file_name != "_system~.ini" and file_name != "run.bat" and file_name != "udp_client.py":
                    make_writable(item_path)
                    copy_file(item_path, folder_path)
            elif os.path.isdir(item_path):
                folder_name = os.path.basename(item_path)
                if folder_name != "Python":
                    process_folder(item_path)
    except Exception as e:
        print("发生错误:", str(e))

if __name__ == "__main__":
    current_dir = os.path.dirname(os.path.abspath(__file__))
    process_folder(current_dir)
