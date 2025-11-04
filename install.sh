#!/bin/bash

echo "========================================"
echo "  FlyOS Flash Automator 安装脚本"
echo "========================================"

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请使用 root 权限运行此脚本"
    echo "使用: sudo ./install.sh"
    exit 1
fi

# 创建日志目录
mkdir -p /var/log

# 检查必要的命令是否存在
echo "检查系统依赖..."
if ! command -v fly-flash &> /dev/null; then
    echo "错误: fly-flash 命令未找到"
    exit 1
fi

if ! command -v poweroff &> /dev/null; then
    echo "错误: poweroff 命令未找到"
    exit 1
fi

# 检查固件文件是否存在
echo "检查固件文件..."
if [ ! -f "/usr/lib/firmware/bootloader/hid_bootloader_h723_v1.0.bin" ]; then
    echo "错误: Bootloader 文件不存在: /usr/lib/firmware/bootloader/hid_bootloader_h723_v1.0.bin"
    exit 1
fi

if [ ! -f "/usr/lib/firmware/klipper/stm32h723-128k-usb.bin" ]; then
    echo "错误: Klipper 固件不存在: /usr/lib/firmware/klipper/stm32h723-128k-usb.bin"
    exit 1
fi

# 复制服务文件到系统目录
echo "安装 systemd 服务..."
cp fly-flash-automator.service /etc/systemd/system/
chmod 644 /etc/systemd/system/fly-flash-automator.service

# 安装带日志版本（可选）
if [ -f "fly-flash-automator-with-logging.service" ] && [ -f "run-with-logging.sh" ]; then
    echo "安装带日志版本..."
    mkdir -p /opt/flyos-flash-automator
    cp run-with-logging.sh /opt/flyos-flash-automator/
    chmod +x /opt/flyos-flash-automator/run-with-logging.sh
    cp fly-flash-automator-with-logging.service /etc/systemd/system/
    chmod 644 /etc/systemd/system/fly-flash-automator-with-logging.service
fi

# 重新加载 systemd
echo "重新加载 systemd 配置..."
systemctl daemon-reload

# 启用服务
echo "启用开机启动..."
systemctl enable fly-flash-automator.service

# 测试服务配置
echo "测试服务配置..."
if systemctl is-enabled fly-flash-automator.service > /dev/null; then
    echo "✅ 服务已启用"
else
    echo "❌ 服务启用失败"
    exit 1
fi

echo ""
echo "========================================"
echo "安装完成!"
echo "========================================"
echo "服务已安装并启用: fly-flash-automator.service"
echo ""
echo "特性:"
echo "- 延迟10秒后执行"
echo "- 日志输出到控制台和系统日志"
echo "- 可通过串口查看实时日志"
echo ""
echo "查看日志方式:"
echo "1. 串口连接: 实时查看控制台输出"
echo "2. 系统日志: journalctl -u fly-flash-automator.service -f"
echo "3. 文件日志: tail -f /var/log/flyos-flash-automator.log (如果安装了带日志版本)"
echo ""
echo "下次开机时将延迟10秒后自动执行烧录流程并关机"
echo "========================================"