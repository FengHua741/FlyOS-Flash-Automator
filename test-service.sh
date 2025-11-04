#!/bin/bash

echo "测试 FlyOS Flash Automator 服务"
echo "========================================"

# 手动启动服务进行测试
echo "1. 停止服务（如果正在运行）..."
systemctl stop fly-flash-automator.service 2>/dev/null

echo "2. 手动启动服务..."
systemctl start fly-flash-automator.service

echo "3. 查看服务状态..."
systemctl status fly-flash-automator.service --no-pager

echo ""
echo "4. 实时查看日志 (按 Ctrl+C 停止):"
journalctl -u fly-flash-automator.service -f