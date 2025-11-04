#!/bin/bash

echo "========================================"
echo "  FlyOS Flash Automator 卸载脚本"
echo "========================================"

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请使用 root 权限运行此脚本"
    echo "使用: sudo ./uninstall.sh"
    exit 1
fi

# 停止服务
echo "停止服务..."
systemctl stop fly-flash-automator.service 2>/dev/null || true

# 禁用服务
echo "禁用服务..."
systemctl disable fly-flash-automator.service 2>/dev/null || true

# 删除服务文件
echo "删除服务文件..."
rm -f /etc/systemd/system/fly-flash-automator.service

# 重新加载 systemd
echo "重新加载 systemd 配置..."
systemctl daemon-reload

# 删除脚本文件（可选，保留日志）
echo "删除脚本文件..."
rm -f /data/flyos-flash-automator/flash-with-network.sh

echo ""
echo "========================================"
echo "卸载完成!"
echo "========================================"
echo "服务已卸载，但日志文件保留在:"
echo "/data/flyos-flash-automator/flash.log"
echo ""
echo "如需完全删除，请手动删除目录:"
echo "rm -rf /data/flyos-flash-automator/"
echo "========================================"