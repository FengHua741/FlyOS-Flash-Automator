# FlyOS Flash Automator

最简单的 FlyOS 自动烧录解决方案，支持网络连接检查和状态上报。

## 🎯 功能特点

- ✅ 极简设计 - 只有6个核心文件
- ✅ 等待网络连接后才执行烧录
- ✅ 延迟10秒后开始执行
- ✅ 自动状态上报到设备A
- ✅ 烧录完成后自动关机
- ✅ 串口可见完整日志
- ✅ 完整的安装和卸载脚本

## 📁 文件结构

```
FlyOS-Flash-Automator/
├── README.md                          # 项目说明文档
├── fly-flash-automator.service        # systemd 服务文件
├── flash-with-network.sh              # 带网络检查的烧录脚本
├── install.sh                         # 安装脚本
├── test-service.sh                    # 测试脚本
└── uninstall.sh                       # 卸载脚本
```

## 🚀 快速安装

```bash
rm -rf /data/FlyOS-Flash-Automator
cd /data && git clone https://github.com/FengHua741/FlyOS-Flash-Automator.git
cd /data/FlyOS-Flash-Automator
chmod +x install.sh
./install.sh
```

## ⚙️ 服务详情

**服务文件位置**: `/etc/systemd/system/fly-flash-automator.service`

**执行的命令**: 通过 `/data/FlyOS-Flash-Automator/flash-with-network.sh` 执行完整烧录流程

**烧录流程**:
```bash
fly-flash -d auto -u -f /usr/lib/firmware/bootloader/hid_bootloader_h723_v1.0.bin && \
fly-flash -d auto -h -f /usr/lib/firmware/klipper/stm32h723-128k-usb.bin && \
lsusb && \
poweroff
```

## 🔧 管理命令

```bash
# 查看服务状态
systemctl status fly-flash-automator.service

# 查看服务日志
journalctl -u fly-flash-automator.service -f

# 查看文件日志
tail -f /data/FlyOS-Flash-Automator/flash.log

# 手动启动服务
systemctl start fly-flash-automator.service

# 禁用开机启动
systemctl disable fly-flash-automator.service

# 重新启用开机启动
systemctl enable fly-flash-automator.service
```

## 📋 执行流程

1. **系统启动** - 服务随系统启动
2. **网络等待** - 等待网络连接可用（最多60秒）
3. **延迟执行** - 网络就绪后延迟10秒
4. **BL烧录** - 执行DFU模式烧录
5. **HID烧录** - 执行HID模式烧录  
6. **设备验证** - 列出USB设备确认烧录结果
7. **自动关机** - 烧录完成后立即关机

## 🛠️ 脚本说明

### `flash-with-network.sh`
- 主烧录脚本，包含网络检查和状态上报
- 位置: `/data/FlyOS-Flash-Automator/flash-with-network.sh`
- 日志: `/data/FlyOS-Flash-Automator/flash.log`

### `install.sh`
- 一键安装脚本，检查依赖并配置服务
- 自动创建所需目录和设置权限

### `test-service.sh`
- 测试脚本，手动验证服务功能

### `uninstall.sh`
- 卸载脚本，清理服务但保留日志

## 🔍 日志查看

### 方式1: 串口连接（实时）
通过串口连接设备，可直接看到控制台输出：
```
FlyOS Flash Automator 开始执行: 2024-01-01 12:00:00
检查网络连接...
✅ 网络连接正常
步骤1: 延迟10秒后开始烧录...
步骤2: 执行BL烧录 (DFU模式)
...
```

### 方式2: 系统日志
```bash
journalctl -u fly-flash-automator.service -f
```

### 方式3: 文件日志
```bash
tail -f /data/FlyOS-Flash-Automator/flash.log
```

## 🔄 状态上报

系统会自动向设备A发送状态更新：
- **网络检查状态**
- **烧录步骤进度** 
- **成功/失败状态**
- **最终关机通知**

上报地址: `http://192.168.101.239:8081/update`

## 🐛 故障排除

### 常见问题检查

1. **固件文件是否存在**:
   ```bash
   ls -la /usr/lib/firmware/bootloader/hid_bootloader_h723_v1.0.bin
   ls -la /usr/lib/firmware/klipper/stm32h723-128k-usb.bin
   ```

2. **fly-flash 工具是否可用**:
   ```bash
   which fly-flash
   ```

3. **网络连接是否正常**:
   ```bash
   ping 192.168.101.239
   ```

4. **查看详细服务日志**:
   ```bash
   journalctl -u fly-flash-automator.service -f
   ```

### 重新安装

如果遇到问题，可以重新安装：
```bash
./uninstall.sh
./install.sh
```

### 手动测试

不重启系统，手动测试烧录流程：
```bash
./test-service.sh
```

## 📝 自定义配置

### 修改网络检查目标
编辑 `flash-with-network.sh` 中的 IP 地址：
```bash
# 第24行附近
if ping -c 1 -W 2 192.168.101.239 &> /dev/null; then
```

### 修改延迟时间
编辑 `fly-flash-automator.service`：
```ini
# 修改延迟时间（秒）
ExecStartPre=/bin/sleep 2
```

## 🗑️ 卸载系统

```bash
./uninstall.sh
```

这会：
- 停止并禁用服务
- 删除系统服务文件
- 保留日志文件供后续分析

如需完全清理：
```bash
rm -rf /data/FlyOS-Flash-Automator/
```

## 📄 许可证

MIT License

## 🤝 技术支持

如果遇到问题：
1. 查看日志文件：`/data/FlyOS-Flash-Automator/flash.log`
2. 检查服务状态：`systemctl status fly-flash-automator.service`
3. 运行测试脚本：`./test-service.sh`
4. 重新安装系统：先运行 `./uninstall.sh` 再运行 `./install.sh`

---

**注意**: 安装后设备将在每次开机时自动执行烧录流程并关机，请确保这是期望的行为。