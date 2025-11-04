#!/bin/bash

# FlyOS Flash Automator with Network Check
# 放置在 /data/flyos-flash-automator/flash-with-network.sh

LOG_FILE="/data/flyos-flash-automator/flash.log"

# 记录开始时间
echo "==========================================" | tee -a $LOG_FILE
echo "FlyOS Flash Automator 开始执行: $(date)" | tee -a $LOG_FILE
echo "==========================================" | tee -a $LOG_FILE

# 函数：发送状态到服务器（增强版本）
send_status() {
    local step="$1"
    local status="$2"
    local message="$3"
    
    # 添加时间戳
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local full_message="[$timestamp] $message"
    
    echo "$full_message" | tee -a $LOG_FILE
    
    # 尝试发送状态到设备A（不保证成功）
    curl -s -X POST -H "Content-Type: application/json" \
         -d "{\"step\":\"$step\",\"status\":\"$status\",\"message\":\"$full_message\",\"timestamp\":\"$timestamp\"}" \
         http://192.168.101.239:8081/update > /dev/null 2>&1 || true
}

# 函数：执行命令并实时上报日志
execute_command() {
    local cmd="$1"
    local step="$2"
    
    send_status "$step" "running" "开始执行: $cmd"
    
    # 创建临时文件用于捕获输出
    local temp_file=$(mktemp)
    
    # 执行命令并实时捕获输出
    {
        eval "$cmd" 2>&1 | while IFS= read -r line; do
            # 清理ANSI颜色代码
            clean_line=$(echo "$line" | sed -r 's/\x1B\[[0-9;]*[mGK]//g')
            send_status "$step" "running" "$clean_line"
            echo "$clean_line" | tee -a $LOG_FILE
        done
    } > "$temp_file" 2>&1
    
    local exit_code=${PIPESTATUS[0]}
    
    # 读取命令输出
    local output=$(cat "$temp_file")
    rm -f "$temp_file"
    
    return $exit_code
}

# 函数：检查网络连接
check_network() {
    send_status "network_check" "running" "开始检查网络连接"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        # 尝试ping设备A（状态服务器）
        if ping -c 1 -W 2 192.168.101.239 &> /dev/null; then
            send_status "network_check" "success" "网络连接正常 (尝试 $attempt/$max_attempts)"
            return 0
        else
            send_status "network_check" "running" "网络连接检查中... ($attempt/$max_attempts)"
            sleep 2
            ((attempt++))
        fi
    done
    
    send_status "network_check" "warning" "网络连接可能不稳定，继续执行但状态上报可能延迟"
    return 1
}

# 主程序开始
send_status "system_start" "running" "FlyOS Flash Automator 启动"

echo "步骤0: 等待网络连接" | tee -a $LOG_FILE

if check_network; then
    send_status "network_check" "success" "网络连接就绪"
else
    send_status "network_check" "warning" "网络连接不稳定，继续执行"
fi

echo "步骤1: 开始烧录..." | tee -a $LOG_FILE
send_status "flash_start" "running" "开始烧录流程"

send_status "bl_flash" "running" "开始执行BL烧录 (DFU模式)"

if execute_command "fly-flash -d auto -u -f /usr/lib/firmware/bootloader/hid_bootloader_h723_v1.0.bin" "bl_flash"; then
    send_status "bl_flash" "success" "BL烧录成功完成"
else
    send_status "bl_flash" "error" "BL烧录失败"
    send_status "shutdown" "error" "烧录失败，退出系统"
    exit 1
fi

send_status "hid_flash" "running" "开始执行HID烧录"

if execute_command "fly-flash -d auto -h -f /usr/lib/firmware/klipper/stm32h723-128k-usb.bin" "hid_flash"; then
    send_status "hid_flash" "success" "HID烧录成功完成"
else
    send_status "hid_flash" "error" "HID烧录失败"
    send_status "shutdown" "error" "烧录失败，退出系统"
    exit 1
fi

send_status "usb_check" "running" "检查USB设备状态"
execute_command "lsusb" "usb_check"
send_status "usb_check" "success" "USB设备检查完成"

send_status "shutdown" "success" "所有烧录步骤完成，立即关机"
send_status "final" "success" "系统将在2秒后关机"

sleep 2
poweroff