#!/bin/bash

# FlyOS Flash Automator with Network Check
LOG_FILE="/data/flyos-flash-automator/flash.log"
DEBUG_LOG="/data/flyos-flash-automator/debug.log"

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

# 函数：发送状态到服务器（增强调试版本）
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
    
    # 构建设备B的IP地址
    local device_b_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "unknown")
    debug_log "设备B IP: $device_b_ip"
    
    # 构建JSON数据
    local json_data="{
        \"step\": \"$step\",
        \"status\": \"$status\",
        \"progress\": 0,
        \"device_info\": \"FlyOS Flash Automator\",
        \"device_b_ip\": \"$device_b_ip\",
        \"timestamp\": \"$timestamp\",
        \"log\": ["
    
    # 添加所有日志行到log数组
    for ((i=0; i<${#LOG_LINES[@]}; i++)); do
        # JSON转义日志内容
        local escaped_line=$(echo "${LOG_LINES[$i]}" | sed 's/"/\\"/g')
        json_data="$json_data\"$escaped_line\""
        if [ $i -lt $((${#LOG_LINES[@]}-1)) ]; then
            json_data="$json_data,"
        fi
    done
    
    json_data="$json_data]}"
    
    debug_log "准备发送的JSON数据: $json_data"
    
    # 测试网络连接
    debug_log "测试网络连接到设备A..."
    if ping -c 1 -W 2 192.168.101.239 &> /dev/null; then
        debug_log "设备A可达"
    else
        debug_log "警告: 设备A不可达"
    fi
    
    # 尝试发送状态到设备A，并捕获详细输出
    debug_log "开始发送HTTP请求..."
    local response=$(curl -v -X POST -H "Content-Type: application/json" \
         -d "$json_data" \
         http://192.168.101.239:8081/update 2>&1)
    
    debug_log "HTTP响应: $response"
    
    # 检查curl退出码
    local curl_exit=$?
    debug_log "Curl退出码: $curl_exit"
    
    if [ $curl_exit -eq 0 ]; then
        debug_log "状态发送成功"
    else
        debug_log "状态发送失败，退出码: $curl_exit"
    fi
}

# 函数：执行命令并实时上报日志
execute_command() {
    local cmd="$1"
    local step="$2"
    
    send_status "$step" "running" "开始执行: $cmd"
    
    # 使用命名管道来实时捕获输出
    local pipe_file=$(mktemp -u)
    mkfifo "$pipe_file"
    
    # 执行命令并将输出重定向到命名管道
    {
        eval "$cmd" 2>&1
        echo $? > /tmp/exit_code_$$
    } > "$pipe_file" &
    
    local cmd_pid=$!
    
    # 从命名管道逐行读取输出并实时上报
    while IFS= read -r line; do
        # 清理ANSI颜色代码
        clean_line=$(echo "$line" | sed -r 's/\x1B\[[0-9;]*[mGK]//g')
        
        # 实时上报每一行日志
        send_status "$step" "running" "$clean_line"
        
        # 同时输出到控制台和日志文件
        echo "$clean_line" | tee -a $LOG_FILE
        
    done < "$pipe_file"
    
    # 等待命令完成并获取退出码
    wait $cmd_pid
    local exit_code=$(cat /tmp/exit_code_$$ 2>/dev/null || echo 1)
    rm -f "$pipe_file" /tmp/exit_code_$$
    
    return $exit_code
}

# 函数：检查网络连接
check_network() {
    send_status "network_check" "running" "开始检查网络连接"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        debug_log "网络检查尝试 $attempt/$max_attempts"
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
debug_log "脚本启动"
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
if execute_command "lsusb" "usb_check"; then
    send_status "usb_check" "success" "USB设备检查完成"
else
    send_status "usb_check" "warning" "USB设备检查完成（可能有警告）"
fi

send_status "shutdown" "success" "所有烧录步骤完成，立即关机"
send_status "final" "success" "系统将在2秒后关机"

debug_log "脚本执行完成，准备关机"
sleep 2
poweroff
