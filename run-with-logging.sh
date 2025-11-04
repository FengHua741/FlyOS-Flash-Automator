#!/bin/bash

# FlyOS Flash Automator - 带完整日志输出的版本
LOG_FILE="/var/log/flyos-flash-automator.log"

# 记录开始时间
echo "==========================================" >> $LOG_FILE
echo "FlyOS Flash Automator 开始执行: $(date)" >> $LOG_FILE
echo "==========================================" >> $LOG_FILE

# 同时输出到控制台和日志文件
exec > >(tee -a $LOG_FILE) 2>&1

echo "延迟10秒后开始执行..."
sleep 10

echo "开始执行烧录流程..."
echo "步骤1: BL烧录 (DFU模式)"

# 执行BL烧录
if fly-flash -d auto -u -f /usr/lib/firmware/bootloader/hid_bootloader_h723_v1.0.bin; then
    echo "✅ BL烧录成功"
else
    echo "❌ BL烧录失败"
    exit 1
fi

echo "步骤2: HID烧录"
# 执行HID烧录
if fly-flash -d auto -h -f /usr/lib/firmware/klipper/stm32h723-128k-usb.bin; then
    echo "✅ HID烧录成功"
else
    echo "❌ HID烧录失败"
    exit 1
fi

echo "步骤3: 检查USB设备"
lsusb

echo "步骤4: 关机"
echo "烧录完成，即将关机..."
poweroff