#!/bin/bash

# FlyOS Flash Automator with Network Check
LOG_FILE="/data/FlyOS-Flash-Automator/flash.log"
DEBUG_LOG="/data/FlyOS-Flash-Automator/debug.log"

# 创建日志文件
mkdir -p /data/FlyOS-Flash-Automator
touch "$LOG_FILE" "$DEBUG_LOG"

# 初始化日志数组
LOG_LINES=()

# 记录开始时间
echo "==========================================" | tee -a $LOG_FILE
echo "FlyOS Flash Automator 开始执行: $(date)" | tee -a $LOG_FILE
echo "==========================================" | tee -a $LOG_FILE

# 调试函数
debug_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] DEBUG: $message" >> "$DEBUG_LOG"
}

# 兼容的IP地址获取函数
get_device_ip() {
    # 尝试多种方法获取IP地址
    local ip=""
    
    # 方法1: 使用ip命令
    ip=$(ip addr show 2>/dev/null | grep -oP 'inet \K[\d.]+' | grep -v '127.0.0.1' | head -1)
    
    # 方法2: 使用ifconfig
    if [ -z "$ip" ]; then
        ip=$(ifconfig 2>/dev/null | grep -oP 'inet addr:\K[\d.]+' | grep -v '127.0.0.1' | head -1)
    fi
    
    # 方法3: 使用hostname -i (BusyBox兼容)
    if [ -z "$ip" ]; then
        ip=$(hostname -i 2>/dev/null | awk '{print $1}' | grep -v '127.0.0.1')
    fi
    
    # 如果还是获取不到，使用默认值
    if [ -z "$ip" ]; then
        ip="unknown"
    fi
    
    echo "$ip"
}

# 函数：发送状态到服务器 - 修复版本
send_status() {
    local step="$1"
    local status="$2"
    local message="$3"
    
    # 添加时间戳
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local full_message="[$timestamp] $message"
    
    echo "$full_message" | tee -a $LOG_FILE
    debug_log "准备发送状态: step=$step, status=$status, message=$message"
    
    # 将消息添加到日志数组
    LOG_LINES+=("$full_message")
    
    # 保持日志数组大小（最多保留最近100行）
    if [ ${#LOG_LINES[@]} -gt 100 ]; then
        LOG_LINES=("${LOG_LINES[@]:1}")
    fi
    
    # 获取设备B的IP地址
    local device_b_ip=$(get_device_ip)
    debug_log "设备B IP: $device_b_ip"
    
    # 构建JSON数据 - 使用message字段而不是log字段
    local json_data="{
        \"step\": \"$step\",
        \"status\": \"$status\",
        \"message\": \"$full_message\",
        \"device_b_ip\": \"$device_b_ip\"
    }"
    
    debug_log "准备发送的JSON数据: $json_data"
    
    # 测试网络连接
    debug_log "测试网络连接到设备A..."
    if ping -c 1 -W 2 192.168.101.239 &> /dev/null; then
        debug_log "设备A可达"
    else
        debug_log "警告: 设备A不可达"
    fi
    
    # 尝试发送状态到设备A
    debug_log "开始发送HTTP请求..."
    local response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" \
         -d "$json_data" \
         http://192.168.101.239:8081/update 2>&1)
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    debug_log "HTTP响应码: $http_code"
    debug_log "响应内容: $response_body"
    
    if [ "$http_code" = "200" ]; then
        debug_log "状态发送成功"
        return 0
    else
        debug_log "状态发送失败，HTTP代码: $http_code"
        return 1
    fi
}

# 函数：重试发送状态
send_status_with_retry() {
    local step="$1"
    local status="$2"
    local message="$3"
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if send_status "$step" "$status" "$message"; then
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        debug_log "发送失败，重试 $retry_count/$max_retries..."
        sleep 2
    done
    
    debug_log "发送状态失败，已达到最大重试次数"
    return 1
}

# 主程序开始
debug_log "脚本启动"
send_status_with_retry "system_start" "running" "FlyOS Flash Automator 启动"

echo "步骤0: 检查网络连接" | tee -a $LOG_FILE
send_status_with_retry "network_check" "running" "检查网络连接"

# 网络检查
debug_log "测试网络连接到设备A..."
if ping -c 1 -W 2 192.168.101.239 &> /dev/null; then
    send_status_with_retry "network_check" "success" "网络连接正常"
else
    send_status_with_retry "network_check" "warning" "网络连接可能不稳定，继续执行"
fi

echo "步骤1: 开始烧录..." | tee -a $LOG_FILE
send_status_with_retry "flash_start" "running" "开始烧录流程"

# BL烧录
send_status_with_retry "bl_flash" "running" "开始执行BL烧录 (DFU模式)"
send_status_with_retry "bl_flash" "running" "开始执行: fly-flash -d auto -u -f /usr/lib/firmware/bootloader/hid_bootloader_h723_v1.0.bin"

echo "执行BL烧录命令..." | tee -a $LOG_FILE
if fly-flash -d auto -u -f /usr/lib/firmware/bootloader/hid_bootloader_h723_v1.0.bin; then
    send_status_with_retry "bl_flash" "success" "BL烧录成功完成"
else
    send_status_with_retry "bl_flash" "error" "BL烧录失败"
    send_status_with_retry "shutdown" "error" "烧录失败，退出系统"
    exit 1
fi

# HID烧录
send_status_with_retry "hid_flash" "running" "开始执行HID烧录"
send_status_with_retry "hid_flash" "running" "开始执行: fly-flash -d auto -h -f /usr/lib/firmware/klipper/stm32h723-128k-usb.bin"

echo "执行HID烧录命令..." | tee -a $LOG_FILE
if fly-flash -d auto -h -f /usr/lib/firmware/klipper/stm32h723-128k-usb.bin; then
    send_status_with_retry "hid_flash" "success" "HID烧录成功完成"
else
    send_status_with_retry "hid_flash" "error" "HID烧录失败"
    send_status_with_retry "shutdown" "error" "烧录失败，退出系统"
    exit 1
fi

# USB设备检查
send_status_with_retry "usb_check" "running" "检查USB设备状态"
echo "检查USB设备..." | tee -a $LOG_FILE
if lsusb; then
    send_status_with_retry "usb_check" "success" "USB设备检查完成"
else
    send_status_with_retry "usb_check" "warning" "USB设备检查完成（可能有警告）"
fi

# 完成并关机
send_status_with_retry "shutdown" "success" "所有烧录步骤完成，立即关机"
send_status_with_retry "final" "success" "系统将在2秒后关机"

debug_log "脚本执行完成，准备关机"
echo "所有步骤完成，系统关机..." | tee -a $LOG_FILE
echo "==========================================" | tee -a $LOG_FILE
echo "FlyOS Flash Automator 完成: $(date)" | tee -a $LOG_FILE
echo "==========================================" | tee -a $LOG_FILE

sleep 2
poweroff