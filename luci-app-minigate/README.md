# MiniGate - OpenWrt 轻量网关管理

一个类似 Lucky 的轻量级 OpenWrt 应用，提供三大核心功能：

## 功能特性

### 🌐 DDNS (动态域名解析)
- **Cloudflare** DNS API 支持
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
- 自动 HTTP → HTTPS 跳转
- HTTP/2 支持
- WebSocket 代理支持
- 自动 SSL 证书关联
- 安全 Headers（HSTS、X-Frame-Options 等）
- 多站点管理

## 安装方法

### 方法 1: 直接安装（推荐测试用）

```bash
# 1. 将项目上传到路由器
scp -r luci-app-minigate root@192.168.1.1:/tmp/

# 2. SSH 到路由器
ssh root@192.168.1.1

# 3. 安装依赖
opkg update
opkg install nginx-ssl openssl-util curl wget jsonfilter

# 4. 复制文件
cp /tmp/luci-app-minigate/root/etc/config/minigate /etc/config/
cp /tmp/luci-app-minigate/root/etc/init.d/minigate /etc/init.d/
chmod +x /etc/init.d/minigate

mkdir -p /usr/lib/minigate
cp /tmp/luci-app-minigate/root/usr/lib/minigate/*.sh /usr/lib/minigate/
chmod +x /usr/lib/minigate/*.sh

mkdir -p /usr/lib/lua/luci/controller
mkdir -p /usr/lib/lua/luci/model/cbi/minigate
mkdir -p /usr/lib/lua/luci/view/minigate

cp /tmp/luci-app-minigate/luasrc/controller/minigate.lua /usr/lib/lua/luci/controller/
cp /tmp/luci-app-minigate/luasrc/model/cbi/minigate/*.lua /usr/lib/lua/luci/model/cbi/minigate/
cp /tmp/luci-app-minigate/luasrc/view/minigate/*.htm /usr/lib/lua/luci/view/minigate/

mkdir -p /etc/minigate/{acme,certs,nginx/sites}

# 5. 启用服务
/etc/init.d/minigate enable

# 6. 清除 LuCI 缓存
rm -rf /tmp/luci-*

# 7. 访问 LuCI → 服务 → MiniGate
```

### 方法 2: OpenWrt SDK 编译

```bash
# 将 luci-app-minigate 目录放入 OpenWrt SDK 的 package/ 目录
cp -r luci-app-minigate ~/openwrt/package/

# 编译
cd ~/openwrt
make package/luci-app-minigate/compile V=s

# 生成的 ipk 在 bin/packages/ 目录下
# 上传到路由器后:
opkg install luci-app-minigate_1.0.0-1_all.ipk
```

## 使用指南

### 第一步：基础配置
1. 进入 **LuCI → 服务 → MiniGate**
2. 在「总览」页面开启 MiniGate

### 第二步：配置 DDNS
1. 切换到 **DDNS** 标签页
2. 启用 DDNS
3. 填入你的 Cloudflare Zone ID 和 API Token
4. 设置要更新的域名
5. 保存并应用

### 第三步：签发 SSL 证书
1. 切换到 **SSL 证书** 标签页
2. 启用 ACME
3. 填入 Cloudflare API Token（需要 Zone:DNS:Edit 权限）
4. 先用 Staging 模式测试
5. 点击「Issue / Renew Now」签发证书
6. 测试成功后关闭 Staging 模式重新签发

### 第四步：配置反向代理
1. 切换到 **反向代理** 标签页
2. 添加新的代理规则
3. 填写域名、目标地址和端口
4. 启用 SSL（会自动使用 ACME 签发的证书）
5. 保存并应用

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
├── luasrc/
│   ├── controller/
│   │   └── minigate.lua               # LuCI 路由控制器
│   ├── model/cbi/minigate/
│   │   ├── general.lua                # 总览页面
│   │   ├── ddns.lua                   # DDNS 配置页面
│   │   ├── acme.lua                   # ACME 配置页面
│   │   └── proxy.lua                  # 反向代理配置页面
│   └── view/minigate/
│       ├── log.htm                    # 日志查看页面
│       └── certs.htm                  # 证书列表模板
└── root/
    ├── etc/
    │   ├── config/
    │   │   └── minigate               # UCI 配置文件
    │   └── init.d/
    │       └── minigate               # procd 服务脚本
    └── usr/lib/minigate/
        ├── ddns.sh                    # DDNS 更新脚本
        ├── acme.sh                    # ACME 证书管理
        └── proxy.sh                   # Nginx 反向代理管理
```

## 依赖

- `luci-base` - LuCI Web 界面
- `nginx-ssl` - Nginx（带 SSL 支持）
- `openssl-util` - 证书工具
- `curl` - HTTP 客户端（Cloudflare API）
- `wget` - 下载工具
- `jsonfilter` - JSON 解析

## 许可证

MIT License
