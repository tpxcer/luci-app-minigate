# MiniGate - OpenWrt 轻量网关管理

一个类似 Lucky 的轻量级 OpenWrt 应用，提供四大核心功能：DDNS、SSL 证书、反向代理、登录防护。

当前版本：**v1.3.3**

> OpenWrt 用户请从 [Releases](https://github.com/tpxcer/luci-app-minigate/releases/latest) 下载 `luci-app-minigate_1.3.3-1_all.ipk`。不要把 GitHub 自动生成的 `Source code (zip)` / `Source code (tar.gz)` 当安装包上传到 LuCI。

## 功能特性

### 🌐 DDNS (动态域名解析)
- **Cloudflare** DNS API 支持
- **IPv4 / IPv6 / 双栈** 模式，同时更新 A 和 AAAA 记录
- 自动检测 WAN IP 变化并更新 DNS 记录
- 支持从网络接口或外部 URL 获取 IP
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
- HTTP/2、WebSocket 支持
- 自动 SSL 证书关联
- 安全 Headers（HSTS 等）
- 多站点管理
- **直接 IP 访问拒绝**：只允许域名访问，扫描器直接断开

### 🛡 登录防护 (Login Guard)
- 监控 **SSH（dropbear）** 和 **LuCI 网页** 登录失败
- 在「失败窗口」内累积达到阈值（默认 3 次/10 分钟）→ 自动用 nftables 封禁源 IP
- 可配置封禁时长（1 小时 / 6 小时 / **12 小时（默认）** / 24 小时 / 1 周 / 30 天）
- **LAN 私有段自动豁免**（192.168.x / 10.x / 127.x / 172.16-31.x），可加额外白名单
- **滑动时间窗口**：超过窗口未再失败则计数自动清零
- 持久化存储 `/etc/minigate/login-guard/bans.txt`，重启/固件升级后已生效封禁自动恢复
- LuCI 页面实时显示封禁列表、剩余时间、归属地（结合归属地查询 API）
- 失败计数列表默认显示 5 条，支持切换 5 / 20 / 30 条，并复用访客追踪归属地查询
- 支持网页**一键解封**、**手动封禁**、**清空全部**
- 后台 watchdog 每 5 分钟自检 nft set，防 fw4 reload 后规则丢失

### 👁 访客追踪
- 总览页面实时显示访客 IP、归属地、在线状态
- 5 分钟内有访问记为「在线」（绿点），否则「离线」（灰点）
- IP 归属地后端查询（ip9.com.cn → ip-api.com → pconline 多源回退）

---

## 安装方法

### 方法 1：IPK 安装（推荐，OpenWrt / ImmortalWrt opkg 版本）

从 [Releases](https://github.com/tpxcer/luci-app-minigate/releases/latest) 下载：

`luci-app-minigate_1.3.3-1_all.ipk`

**通过 LuCI 界面安装：**
1. 打开 LuCI → **系统** → **软件包**
2. 点击 **上传软件包**
3. 选择 `luci-app-minigate_1.3.3-1_all.ipk`，点击安装

**通过命令行安装：**

```bash
cd /tmp
wget -O luci-app-minigate_1.3.3-1_all.ipk https://github.com/tpxcer/luci-app-minigate/releases/download/v1.3.3/luci-app-minigate_1.3.3-1_all.ipk
opkg update
opkg install /tmp/luci-app-minigate_1.3.3-1_all.ipk
rm -rf /tmp/luci-* /tmp/luci-indexcache /tmp/luci-modulecache
/etc/init.d/uhttpd restart
/etc/init.d/minigate restart
```

> 如果 LuCI 上传时报 `Malformed package file`，通常是上传了错误文件。请确认文件名是 `luci-app-minigate_1.3.3-1_all.ipk`，不要上传 `Source code`、`.zip`、`src.tar.gz`。

### 方法 2：源码安装（适用所有版本）

适用于 **OpenWrt 25.xx（apk）**、**OpenWrt 24.xx 及以下（opkg）** 以及 **ImmortalWrt**。

```bash
# 1. 下载源码包到电脑，然后上传到路由器
scp luci-app-minigate-v1.3.3-src.tar.gz root@192.168.1.1:/tmp/

# 2. SSH 到路由器
ssh root@192.168.1.1

# 3. 解压并安装
cd /tmp
tar xzf luci-app-minigate-v1.3.3-src.tar.gz
cd luci-app-minigate-v1.3.3
sh install.sh

# 4. 启动服务
/etc/init.d/minigate restart

# 5. 访问 LuCI → 服务 → MiniGate
```

### 方法 3：OpenWrt SDK 编译（适用所有版本，含 APK）

如果需要正规的 `.apk` 安装包，需使用 OpenWrt SDK 编译：

```bash
# 将源码放入 SDK 的 package 目录
cp -r luci-app-minigate ~/openwrt/package/

# 编译
cd ~/openwrt
make package/luci-app-minigate/compile V=s

# 生成的 ipk 或 apk 在 bin/packages/ 目录下
```

---

## 升级方法

### 源码升级（通用）

```bash
scp luci-app-minigate-v1.3.3-src.tar.gz root@192.168.1.1:/tmp/
ssh root@192.168.1.1
cd /tmp && tar xzf luci-app-minigate-v1.3.3-src.tar.gz
cd luci-app-minigate-v1.3.3
sh install.sh
/etc/init.d/minigate restart
```

### IPK 升级

```bash
opkg install --force-reinstall /tmp/luci-app-minigate_1.3.3-1_all.ipk
rm -rf /tmp/luci-* /tmp/luci-indexcache /tmp/luci-modulecache
/etc/init.d/minigate restart
```

配置文件 `/etc/config/minigate` 会自动保留。

---

## 卸载方法

### 完整卸载

```bash
# 1. 停止服务
/etc/init.d/minigate stop 2>/dev/null
/etc/init.d/minigate disable 2>/dev/null

# 2. 卸载包（如果通过包管理器安装的）
opkg remove luci-app-minigate --force-depends 2>/dev/null  # opkg 用户
apk del luci-app-minigate 2>/dev/null                       # apk 用户

# 3. 清理所有文件
rm -f /usr/lib/opkg/info/luci-app-minigate.*
rm -rf /usr/lib/lua/luci/controller/minigate.lua
rm -rf /usr/lib/lua/luci/model/cbi/minigate/
rm -rf /usr/lib/lua/luci/view/minigate/
rm -rf /usr/lib/minigate/
rm -f /etc/init.d/minigate

# 4. 清理数据（可选，跳过则保留配置）
rm -f /etc/config/minigate
rm -rf /etc/minigate/

# 5. 清理日志和定时任务
rm -f /var/log/minigate-*.log
sed -i '/minigate/d' /etc/crontabs/root 2>/dev/null
/etc/init.d/cron restart 2>/dev/null

# 6. 清除 LuCI 缓存
rm -rf /tmp/luci-*
```

### 仅卸载保留配置

```bash
opkg remove luci-app-minigate --force-depends 2>/dev/null
apk del luci-app-minigate 2>/dev/null
rm -f /usr/lib/opkg/info/luci-app-minigate.*
rm -rf /usr/lib/lua/luci/controller/minigate.lua
rm -rf /usr/lib/lua/luci/model/cbi/minigate/
rm -rf /usr/lib/lua/luci/view/minigate/
rm -rf /usr/lib/minigate/
rm -f /etc/init.d/minigate
rm -rf /tmp/luci-*
# /etc/config/minigate 和 /etc/minigate/ 保留，重装后自动恢复
```

---

## 使用指南

### 第一步：基础配置
1. 进入 **LuCI → 服务 → MiniGate**
2. 在「总览」页面开启 MiniGate
3. 如需 IPv6 反代监听，开启「反向代理监听 IPv6」

### 第二步：配置 DDNS
1. 切换到 **DDNS** 标签页
2. 启用 DDNS，填入 Cloudflare Zone ID 和 API Token
3. 设置域名，选择协议版本（IPv4 / IPv6 / 双栈）
4. 保存并应用

### 第三步：签发 SSL 证书
1. 切换到 **SSL 证书** 标签页，启用 ACME
2. 先用 Staging 模式测试
3. 点击「立即签发 / 续期」
4. 成功后关闭 Staging 重新签发正式证书

### 第四步：配置反向代理
1. 切换到 **反向代理** 标签页
2. 添加规则，填写域名、目标地址和端口
3. 启用 SSL（自动关联 ACME 证书）
4. 保存并应用

### Cloudflare API Token 创建方法
1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 头像 → **My Profile** → **API Tokens** → **Create Token**
3. 使用 **Edit zone DNS** 模板
4. Zone Resources 选择你的域名
5. 创建并复制 Token

---

## 安全特性

### 域名访问限制
安装后，反向代理自动拒绝直接使用 IP 地址访问的请求（返回 444 断开连接）。只有通过正确域名访问才能到达后端服务。这可以有效防止网络扫描器探测。

### 访客追踪
总览页面实时显示所有通过反向代理访问的 IP 地址、归属地和在线状态，帮助你发现异常访问。

---

## 文件结构

```
luci-app-minigate/
├── Makefile                           # OpenWrt 编译配置
├── README.md
├── install.sh                         # 一键安装脚本（兼容 opkg/apk）
├── luasrc/
│   ├── controller/minigate.lua        # LuCI 路由控制器
│   ├── model/cbi/minigate/
│   │   ├── general.lua                # 总览（含访客追踪）
│   │   ├── ddns.lua                   # DDNS（IPv4/IPv6）
│   │   ├── acme.lua                   # ACME 证书
│   │   ├── proxy.lua                  # 反向代理
│   │   └── login_guard.lua            # 登录防护
│   └── view/minigate/log.htm          # 日志页面
└── root/
    ├── etc/config/minigate            # UCI 配置（含 login_guard 段）
    ├── etc/init.d/minigate            # 服务脚本（启停含 login_guard）
    └── usr/lib/minigate/
        ├── ddns.sh                    # DDNS（双栈）
        ├── acme.sh                    # 证书管理
        ├── proxy.sh                   # 反代（IPv6+访问日志+IP拒绝）
        └── login_guard.sh             # 登录防护 watcher + CLI
```

## 依赖

- `luci-base` - LuCI Web 界面
- `nginx-ssl` - Nginx（带 SSL 支持）
- `openssl-util` - 证书工具
- `curl` - HTTP 客户端
- `jsonfilter` - JSON 解析
- `nftables` - 登录防护用（OpenWrt 22.03+ / ImmortalWrt 默认已装）

## 更新日志

### v1.3.3
- 🐛 重新生成 OpenWrt opkg 更兼容的 `.ipk` ar 归档格式，修复部分系统仍提示 `Malformed package file`

### v1.3.2
- ✨ 登录防护「失败计数中」默认显示 5 条，支持 5 / 20 / 30 条下拉切换
- ✨ 失败计数归属地查询复用总览「访问记录」的查询方式
- 🐛 修复失败计数文件异常时 `lg_status` 刷新卡住的问题

### v1.3.1
- 🐛 修复手工安装脚本在 OpenWrt `/bin/sh` 下目录创建失败的问题
- 🐛 重新生成标准 `.ipk` 安装包，避免 LuCI 提示 `Malformed package file`

### v1.3.0
- ⚡ 归属地查询增加 24 小时本地缓存
- ⚡ 缩短外部归属地接口超时时间，减少页面等待

### v1.2.0
- ✨ 新增 **登录防护 (Login Guard)** —— SSH/LuCI 失败登录达到阈值自动封禁源 IP
- ✨ LuCI 网页：实时封禁列表 + 归属地 + 一键解封/封禁/清空
- ✨ 持久化封禁，重启/固件升级后自动恢复
- ✨ Watchdog 自检 nftables 资源，防 fw4 reload 后失效
- 🔧 install.sh 自动清理旧的独立 login-guard 部署（如有）+ 迁移 bans.txt

### v1.1.0
- ✨ DDNS 支持 IPv6 / 双栈模式（A + AAAA 记录）
- ✨ 反向代理支持 IPv6 监听
- ✨ 总览页面新增访客追踪（IP、归属地、在线状态）
- ✨ 归属地后端查询（解决浏览器跨域问题）
- ✨ 直接 IP 访问拒绝（防扫描器）
- ✨ 同时兼容 opkg（IPK）和 apk（源码安装）
- ✨ install.sh 自动适配 opkg/apk 环境
- 🐛 目标地址支持 IPv6 格式

### v1.0.0
- 🎉 初始版本：Cloudflare DDNS、Let's Encrypt ACME、Nginx 反向代理

## 许可证

MIT License
