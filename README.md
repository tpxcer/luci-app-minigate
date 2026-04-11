# MiniGate - OpenWrt 轻量网关管理

一个类似 Lucky 的轻量级 OpenWrt 应用，提供三大核心功能：DDNS、SSL证书、反向代理。

## 功能特性

### 🌐 DDNS (动态域名解析)
- **Cloudflare** DNS API 支持
- **IPv4 / IPv6 / 双栈** 模式，同时更新 A 和 AAAA 记录
- 自动检测 WAN IP 变化并更新 DNS 记录
- 支持从网络接口或外部 URL 获取 IP
- IPv6 支持 wan6 接口和 api6.ipify.org 等外部获取
- 可配置检查间隔和强制更新间隔
- 一键手动触发更新

### 🔒 SSL/TLS 证书 (ACME)
- **Let's Encrypt** 自动证书签发
- 使用 **DNS-01** 挑战方式（Cloudflare）
- 支持 ECC / RSA 多种密钥类型
- 自动续期（通过 cron 每天检查）
- Staging 模式用于测试

### 🔄 反向代理
- 基于 **Nginx** 的轻量反向代理
- **IPv6 监听**支持（listen [::]:port 双栈）
- 自动 HTTP → HTTPS 跳转
- HTTP/2 支持
- WebSocket 代理支持
- 自动 SSL 证书关联
- 安全 Headers（HSTS、X-Frame-Options 等）
- 多站点管理
- **访客追踪**：总览页面实时显示访客 IP、归属地、在线状态

## 安装方法

### 方法 1: IPK 安装（推荐）

从 [Releases](https://github.com/tpxcer/luci-app-minigate/releases) 下载最新 ipk 文件。

**通过 LuCI 界面安装：**
1. 打开 LuCI → **系统** → **软件包**
2. 点击 **上传软件包**
3. 选择下载的 `luci-app-minigate_x.x.x-x_all.ipk` 文件
4. 点击安装

**通过命令行安装：**
```bash
# 上传 ipk 到路由器
scp luci-app-minigate_1.1.0-1_all.ipk root@192.168.1.1:/tmp/

# SSH 安装
ssh root@192.168.1.1
opkg install /tmp/luci-app-minigate_1.1.0-1_all.ipk

# 清除缓存
rm -rf /tmp/luci-*
```

**安装后如果报 postinst Permission denied，执行：**
```bash
chmod +x /usr/lib/opkg/info/luci-app-minigate.postinst /usr/lib/opkg/info/luci-app-minigate.prerm
sh /usr/lib/opkg/info/luci-app-minigate.postinst
rm -rf /tmp/luci-*
```

### 方法 2: 手动安装

```bash
# 1. 将项目上传到路由器
scp -r luci-app-minigate root@192.168.1.1:/tmp/

# 2. SSH 到路由器执行安装脚本
ssh root@192.168.1.1
cd /tmp/luci-app-minigate
sh install.sh
```

### 方法 3: OpenWrt SDK 编译

```bash
# 将 luci-app-minigate 目录放入 OpenWrt SDK 的 package/ 目录
cp -r luci-app-minigate ~/openwrt/package/

# 编译
cd ~/openwrt
make package/luci-app-minigate/compile V=s

# 生成的 ipk 在 bin/packages/ 目录下
```

## 卸载方法

### 完整卸载

```bash
# 1. 停止服务
/etc/init.d/minigate stop 2>/dev/null
/etc/init.d/minigate disable 2>/dev/null

# 2. 通过 opkg 卸载
opkg remove luci-app-minigate --force-depends

# 3. 清理残留文件
rm -f /usr/lib/opkg/info/luci-app-minigate.*
rm -rf /usr/lib/lua/luci/controller/minigate.lua
rm -rf /usr/lib/lua/luci/model/cbi/minigate/
rm -rf /usr/lib/lua/luci/view/minigate/
rm -rf /usr/lib/minigate/
rm -f /etc/init.d/minigate

# 4. 清理数据（可选，如需保留配置请跳过）
rm -f /etc/config/minigate
rm -rf /etc/minigate/

# 5. 清理日志和 cron
rm -f /var/log/minigate-*.log
sed -i '/minigate/d' /etc/crontabs/root 2>/dev/null
/etc/init.d/cron restart 2>/dev/null

# 6. 清除 LuCI 缓存
rm -rf /tmp/luci-*
```

### 仅卸载保留配置

```bash
opkg remove luci-app-minigate --force-depends
rm -f /usr/lib/opkg/info/luci-app-minigate.*
rm -rf /usr/lib/lua/luci/controller/minigate.lua
rm -rf /usr/lib/lua/luci/model/cbi/minigate/
rm -rf /usr/lib/lua/luci/view/minigate/
rm -rf /usr/lib/minigate/
rm -f /etc/init.d/minigate
rm -rf /tmp/luci-*
# /etc/config/minigate 和 /etc/minigate/ 保留，重装后自动恢复配置
```

## 升级方法

```bash
# 直接覆盖安装即可，配置会保留
opkg install --force-reinstall /tmp/luci-app-minigate_1.1.0-1_all.ipk
rm -rf /tmp/luci-*
/etc/init.d/minigate restart
```

## 使用指南

### 第一步：基础配置
1. 进入 **LuCI → 服务 → MiniGate**
2. 在「总览」页面开启 MiniGate
3. 如需 IPv6 反代监听，开启「反向代理监听 IPv6」

### 第二步：配置 DDNS
1. 切换到 **DDNS** 标签页
2. 启用 DDNS
3. 填入你的 Cloudflare Zone ID 和 API Token
4. 设置要更新的域名
5. 选择协议版本：仅 IPv4 / 仅 IPv6 / 双栈
6. 保存并应用

### 第三步：签发 SSL 证书
1. 切换到 **SSL 证书** 标签页
2. 启用 ACME
3. 填入 Cloudflare API Token（需要 Zone:DNS:Edit 权限）
4. 先用 Staging 模式测试
5. 点击「立即签发 / 续期」签发证书
6. 测试成功后关闭 Staging 模式重新签发

### 第四步：配置反向代理
1. 切换到 **反向代理** 标签页
2. 添加新的代理规则
3. 填写域名、目标地址和端口
4. 启用 SSL（会自动使用 ACME 签发的证书）
5. 保存并应用

### 访客追踪
- 总览页面下方会自动显示通过反向代理访问的 IP
- 显示内容：在线状态（绿点/灰点）、IP 地址、归属地、最后访问时间、访问域名、访问次数
- 5 分钟内有访问记为「在线」
- IP 归属地通过 ip-api.com 查询（免费，带缓存）

## Cloudflare API Token 创建方法

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 点击右上角头像 → **My Profile** → **API Tokens**
3. 点击 **Create Token**
4. 使用 **Edit zone DNS** 模板
5. Zone Resources 选择你的域名
6. 创建并复制 Token

## 文件结构

```
luci-app-minigate/
├── Makefile                           # OpenWrt 编译配置
├── README.md                          # 本文件
├── install.sh                         # 一键安装脚本
├── po2lmo.sh                          # 翻译编译脚本
├── luasrc/
│   ├── controller/
│   │   └── minigate.lua               # LuCI 路由控制器
│   ├── model/cbi/minigate/
│   │   ├── general.lua                # 总览页面（含访客追踪）
│   │   ├── ddns.lua                   # DDNS 配置页面（IPv4/IPv6）
│   │   ├── acme.lua                   # ACME 配置页面
│   │   └── proxy.lua                  # 反向代理配置页面
│   └── view/minigate/
│       └── log.htm                    # 日志查看页面
└── root/
    ├── etc/
    │   ├── config/
    │   │   └── minigate               # UCI 配置文件
    │   └── init.d/
    │       └── minigate               # procd 服务脚本
    └── usr/lib/minigate/
        ├── ddns.sh                    # DDNS 更新脚本（IPv4/IPv6双栈）
        ├── acme.sh                    # ACME 证书管理
        └── proxy.sh                   # Nginx 反向代理管理（IPv6监听+访问日志）
```

## 依赖

- `luci-base` - LuCI Web 界面
- `nginx-ssl` - Nginx（带 SSL 支持）
- `openssl-util` - 证书工具
- `curl` - HTTP 客户端（Cloudflare API）
- `jsonfilter` - JSON 解析

## 更新日志

### v1.1.0
- ✨ DDNS 支持 IPv6 / 双栈模式（A + AAAA 记录）
- ✨ 反向代理支持 IPv6 监听
- ✨ 总览页面新增访客追踪（IP、归属地、在线状态）
- ✨ Nginx 访问日志（JSON 格式）
- 🐛 目标地址支持 IPv6 格式

### v1.0.0
- 🎉 初始版本
- Cloudflare DDNS
- Let's Encrypt ACME 证书
- Nginx 反向代理

## 许可证

MIT License
