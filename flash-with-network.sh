#!/bin/bash

# FlyOS Flash Automator with Network Check
# 放置在 /data/flyos-flash-automator/flash-with-network.sh

LOG_FILE="/data/flyos-flash-automator/flash.log"

# 记录开始时间
echo "==========================================" | tee -a $LOG_FILE
echo "FlyOS Flash Automator 开始执行: $(date)" | tee -a $LOG_FILE
echo "==========================================" | tee -a $LOG_FILE

# 函数：检查网络连接
check_network() {
    echo "检查网络连接..." | tee -a $LOG_FILE
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        # 尝试ping设备A（状态服务器）
        if ping -c 1 -W 2 192.168.101.239 &> /dev/null; then
            echo "✅ 网络连接正常 (尝试 $attempt/$max_attempts)" | tee -a $LOG_FILE
            return 0
        else
            echo "⏳ 网络连接检查中... ($attempt/$max_attempts)" | tee -a $LOG_FILE
            sleep 2
            ((attempt++))
        fi
    done
    
    echo "⚠️  网络连接可能不稳定，继续执行但状态上报可能延迟" | tee -a $LOG_FILE
    return 1
}

# 函数：发送状态到服务器
send_status() {
    local step="$1"
    local status="$2"
    local message="$3"
    
    # 尝试发送状态到设备A（不保证成功）
    curl -s -X POST -H "Content-Type: application/json" \
         -d "{\"step\":\"$step\",\"status\":\"$status\",\"message\":\"$message\",\"timestamp\":\"$(date '+%Y-%m-%d %H:%M:%S')\"}" \
         http://192.168.101.239:8081/update > /dev/null 2>&1 || true
}

echo "步骤0: 等待网络连接" | tee -a $LOG_FILE
send_status "network_check" "running" "检查网络连接"

if check_network; then
    echo "✅ 网络连接就绪" | tee -a $LOG_FILE
    send_status "network_check" "success" "网络连接正常"
else
    echo "⚠️  网络连接不稳定，继续执行" | tee -a $LOG_FILE
    send_status "network_check" "warning" "网络连接不稳定"
fi

echo "步骤1: 延迟10秒后开始烧录..." | tee -a $LOG_FILE
send_status "delay" "running" "延迟10秒后开始烧录"
sleep 10

echo "步骤2: 执行BL烧录 (DFU模式)" | tee -a $LOG_FILE
send_status "bl_flash" "running" "开始BL烧录 (DFU模式)"

if fly-flash -d auto -u -f /usr/lib/firmware/bootloader/hid_bootloader_h723_v1.0.bin; then
    echo "✅ BL烧录成功" | tee -a $LOG_FILE
    send_status "bl_flash" "success" "BL烧录成功"
else
    echo "❌ BL烧录失败" | tee -a $LOG_FILE
    send_status "bl_flash" "error" "BL烧录失败"
    echo "烧录失败，退出..." | tee -a $LOG_FILE
    exit 1
fi

echo "步骤3: 执行HID烧录" | tee -a $LOG_FILE
send_status "hid_flash" "running" "开始HID烧录"

if fly-flash -d auto -h -f /usr/lib/firmware/klipper/stm32h723-128k-usb.bin; then
    echo "✅ HID烧录成功" | tee -a $LOG_FILE
    send_status "hid_flash" "success" "HID烧录成功"
else
    echo "❌ HID烧录失败" | tee -a $LOG_FILE
    send_status "hid_flash" "error" "HID烧录失败"
    echo "烧录失败，退出..." | tee -a $LOG_FILE
    exit 1
fi

echo "步骤4: 显示USB设备" | tee -a $LOG_FILE
send_status "usb_check" "running" "检查USB设备"
lsusb | tee -a $LOG_FILE
send_status "usb_check" "success" "USB设备检查完成"

echo "步骤5: 关机" | tee -a $LOG_FILE
echo "烧录流程完成，立即关机..." | tee -a $LOG_FILE
send_status "shutdown" "success" "烧录完成，立即关机"

poweroff