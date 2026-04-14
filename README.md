# MiniGate - OpenWrt 轻量网关管理

一个类似 Lucky 的轻量级 OpenWrt 应用，提供三大核心功能：DDNS、SSL证书、反向代理。

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

### 👁 访客追踪
- 总览页面实时显示访客 IP、归属地、在线状态
- 5 分钟内有访问记为「在线」（绿点），否则「离线」（灰点）
- IP 归属地后端查询（ip9.com.cn → ip-api.com → pconline 多源回退）

---

## 安装方法

### 方法 1：源码安装（推荐，适用所有版本）

适用于 **OpenWrt 25.xx（apk）** 和 **OpenWrt 24.xx 及以下（opkg）** 以及 **ImmortalWrt** 所有版本。

```bash
# 1. 下载源码包到电脑，然后上传到路由器
scp luci-app-minigate-v1.1.0-src.tar.gz root@192.168.1.1:/tmp/

# 2. SSH 到路由器
ssh root@192.168.1.1

# 3. 解压并安装
cd /tmp
tar xzf luci-app-minigate-v1.1.0-src.tar.gz
sh install.sh

# 4. 启动服务
/etc/init.d/minigate restart

# 5. 访问 LuCI → 服务 → MiniGate
```

### 方法 2：IPK 安装（OpenWrt 24.xx / ImmortalWrt opkg 版本）

从 [Releases](https://github.com/tpxcer/luci-app-minigate/releases) 下载 `.ipk` 文件。

**通过 LuCI 界面安装：**
1. 打开 LuCI → **系统** → **软件包**
2. 点击 **上传软件包**
3. 选择 `.ipk` 文件，点击安装

**通过命令行安装：**
```bash
scp luci-app-minigate_1.1.0-1_all.ipk root@192.168.1.1:/tmp/
ssh root@192.168.1.1
opkg install /tmp/luci-app-minigate_1.1.0-1_all.ipk
rm -rf /tmp/luci-*
```

> 如果安装时报 `postinst Permission denied`，执行：
> ```bash
> chmod +x /usr/lib/opkg/info/luci-app-minigate.postinst
> sh /usr/lib/opkg/info/luci-app-minigate.postinst
> rm -rf /tmp/luci-*
> ```

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
scp luci-app-minigate-v1.1.0-src.tar.gz root@192.168.1.1:/tmp/
ssh root@192.168.1.1
cd /tmp && tar xzf luci-app-minigate-v1.1.0-src.tar.gz
sh install.sh
/etc/init.d/minigate restart
```

### IPK 升级

```bash
opkg install --force-reinstall /tmp/luci-app-minigate_1.1.0-1_all.ipk
rm -rf /tmp/luci-*
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
│   │   └── proxy.lua                  # 反向代理
│   └── view/minigate/log.htm          # 日志页面
└── root/
    ├── etc/config/minigate            # UCI 配置
    ├── etc/init.d/minigate            # 服务脚本
    └── usr/lib/minigate/
        ├── ddns.sh                    # DDNS（双栈）
        ├── acme.sh                    # 证书管理
        └── proxy.sh                   # 反代（IPv6+访问日志+IP拒绝）
```

## 依赖

- `luci-base` - LuCI Web 界面
- `nginx-ssl` - Nginx（带 SSL 支持）
- `openssl-util` - 证书工具
- `curl` - HTTP 客户端
- `jsonfilter` - JSON 解析

## 更新日志

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
