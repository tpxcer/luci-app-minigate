include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI MiniGate (DDNS + ACME + Reverse Proxy + Login Guard)
LUCI_DEPENDS:=+luci-base +luci-compat +nginx-ssl +openssl-util +wget +curl +jsonfilter +coreutils-stat +nftables
LUCI_PKGARCH:=all

PKG_NAME:=luci-app-minigate
PKG_VERSION:=1.3.5
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_MAINTAINER:=MiniGate

include $(TOPDIR)/feeds/luci/luci.mk

define Package/$(PKG_NAME)/description
Lightweight gateway management for OpenWrt: Cloudflare DDNS, Let's Encrypt SSL certificates,
Nginx reverse proxy, and SSH/LuCI brute-force ban (Login Guard) with LuCI web interface.
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/minigate
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/minigate
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/minigate
	$(CP) ./luasrc/controller/minigate.lua $(1)/usr/lib/lua/luci/controller/
	$(CP) ./luasrc/model/cbi/minigate/*.lua $(1)/usr/lib/lua/luci/model/cbi/minigate/
	$(CP) ./luasrc/view/minigate/*.htm $(1)/usr/lib/lua/luci/view/minigate/

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-minigate.json $(1)/usr/share/rpcd/acl.d/

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-minigate.json $(1)/usr/share/luci/menu.d/

	$(INSTALL_DIR) $(1)/usr/lib/minigate
	$(INSTALL_BIN) ./root/usr/lib/minigate/ddns.sh $(1)/usr/lib/minigate/
	$(INSTALL_BIN) ./root/usr/lib/minigate/acme.sh $(1)/usr/lib/minigate/
	$(INSTALL_BIN) ./root/usr/lib/minigate/proxy.sh $(1)/usr/lib/minigate/
	$(INSTALL_BIN) ./root/usr/lib/minigate/login_guard.sh $(1)/usr/lib/minigate/
	$(INSTALL_BIN) ./root/usr/lib/minigate/geofence.sh $(1)/usr/lib/minigate/

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/minigate $(1)/etc/config/

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/minigate $(1)/etc/init.d/

	$(INSTALL_DIR) $(1)/etc/minigate/acme
	$(INSTALL_DIR) $(1)/etc/minigate/certs
	$(INSTALL_DIR) $(1)/etc/minigate/nginx/sites
	$(INSTALL_DIR) $(1)/etc/minigate/login-guard
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/minigate enable
}
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/minigate stop
	/etc/init.d/minigate disable
}
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
