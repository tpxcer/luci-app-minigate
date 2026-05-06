# MiniGate - OpenWrt 轻量网关管理

一个类似 Lucky 的轻量级 OpenWrt 应用，提供 DDNS、SSL 证书、反向代理、登录防护。

当前版本：**v1.3.5**

> OpenWrt 用户请从 [Releases](https://github.com/tpxcer/luci-app-minigate/releases/latest) 下载 `luci-app-minigate_1.3.5-1_all.ipk`。不要把 GitHub 自动生成的 `Source code (zip)` / `Source code (tar.gz)` 当安装包上传到 LuCI。

## 安装

```sh
cd /tmp
wget -O luci-app-minigate_1.3.5-1_all.ipk https://github.com/tpxcer/luci-app-minigate/releases/download/v1.3.5/luci-app-minigate_1.3.5-1_all.ipk
opkg install /tmp/luci-app-minigate_1.3.5-1_all.ipk
/etc/init.d/uhttpd restart
/etc/init.d/minigate restart
```

## 更新内容

### v1.3.5

- 登录防护页面保存设置时，改为执行 MiniGate 轻量重载，而不是完整重启。
- 修复通过 MiniGate 反向代理访问 LuCI 时，保存登录防护设置后当前网页连接被反代 nginx 断开，导致浏览器显示“无法访问此网站”的问题。

### v1.3.4

- 修复 LuCI 白天模式下总览和登录防护页面仍显示深色卡片/表格的问题。
- 保留黑夜模式原有深色显示效果，页面会跟随系统/浏览器配色切换。

## 功能

- Cloudflare DDNS
- Let's Encrypt ACME 证书
- Nginx 反向代理
- 登录防护 Login Guard
- 访客追踪和归属地查询

## 依赖

- `luci-base`
- `nginx-ssl`
- `openssl-util`
- `wget`
- `curl`
- `jsonfilter`
- `coreutils-stat`
- `nftables`

## 许可证

MIT License
