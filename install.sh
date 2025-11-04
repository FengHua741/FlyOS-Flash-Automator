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

# 复制服务文件到系统目录
echo "安装 systemd 服务..."
cp fly-flash-automator.service /etc/systemd/system/

# 重新加载 systemd
echo "重新加载 systemd 配置..."
systemctl daemon-reload

# 启用服务
echo "启用开机启动..."
systemctl enable fly-flash-automator.service

echo ""
echo "========================================"
echo "安装完成!"
echo "========================================"
echo "服务已安装并启用: fly-flash-automator.service"
echo ""
echo "管理命令:"
echo "- 启动服务: systemctl start fly-flash-automator.service"
echo "- 停止服务: systemctl stop fly-flash-automator.service"
echo "- 查看状态: systemctl status fly-flash-automator.service"
echo "- 查看日志: journalctl -u fly-flash-automator.service -f"
echo ""
echo "下次开机时将自动执行烧录流程并关机"
echo "========================================"