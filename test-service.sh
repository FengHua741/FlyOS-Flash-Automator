#!/bin/bash

echo "测试 FlyOS Flash Automator 服务"
echo "========================================"

# 检查服务状态
echo "1. 检查服务状态..."
systemctl status fly-flash-automator.service --no-pager

echo ""
echo "2. 检查脚本权限..."
ls -la /data/flyos-flash-automator/flash-with-network.sh

echo ""
echo "3. 手动测试网络检查..."
/data/flyos-flash-automator/flash-with-network.sh

echo ""
echo "4. 查看测试日志..."
tail -f /data/flyos-flash-automator/flash.log