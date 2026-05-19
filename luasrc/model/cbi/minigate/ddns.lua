local m,s,o
local sys=require"luci.sys"

m=Map("minigate", translate("MiniGate - Dynamic DNS"), translate("Supports multiple domains and IPv4/IPv6 dual-stack. Syncs immediately after save. Requires global switch to be enabled."))

m.on_after_commit=function(self)
    sys.call("/bin/sh /usr/lib/minigate/ddns.sh force >/dev/null 2>&1 &")
    local en=self.uci:get("minigate","global","enabled")
    if en=="1"then sys.call("/etc/init.d/minigate restart >/dev/null 2>&1 &") end
end

s=m:section(TypedSection,"ddns", translate("DDNS Records"))
s.anonymous=true; s.addremove=true; s.sortable=true

o=s:option(Flag,"enabled", translate("Enable")); o.rmempty=false

o=s:option(Value,"domain", translate("Domain")); o.rmempty=false; o.placeholder="*.example.com or home.example.com"

o=s:option(Value,"cf_zone_id","Zone ID"); o.rmempty=false; o.placeholder="Cloudflare Zone ID"

o=s:option(Value,"cf_api_token", translate("API Token")); o.rmempty=false; o.password=true

o=s:option(ListValue,"ip_version", translate("IP Version"))
o:value("ipv4", translate("IPv4 only (A record)"))
o:value("ipv6", translate("IPv6 only (AAAA record)"))
o:value("dual", translate("Dual-stack (A + AAAA)"))
o.default="ipv4"
o.description= translate("Select which DNS record type to update. Dual-stack updates both A and AAAA records.")

o=s:option(ListValue,"ip_source", translate("IP Source"))
o:value("interface", translate("From network interface")); o:value("url", translate("From external URL")); o.default="interface"

o=s:option(ListValue,"interface", translate("IPv4 network interface")); o.default="wan"
local uci=require"luci.model.uci".cursor()
uci:foreach("network","interface",function(sec) if sec[".name"]~="loopback"then o:value(sec[".name"],sec[".name"])end end)
o:depends("ip_source","interface")

o=s:option(ListValue,"ip_url", translate("IPv4 detection URL"))
o:value("http://ip.3322.net","ip.3322.net")
o:value("http://members.3322.org/dyndns/getip","members.3322.org")
o:value("http://ns1.dnspod.net:6666","ns1.dnspod.net (Tencent)")
o:value("http://ip.tool.chinaz.com/getip","chinaz.com")
o.default="http://ip.3322.net"
o.description= translate("In NAT/proxy environments, bypasses proxy to get the real public IP.")
o:depends("ip_source","url")

o=s:option(ListValue,"interface6", translate("IPv6 network interface")); o.default="wan6"
o.description= translate("Interface used to obtain the IPv6 address (usually wan6).")
uci:foreach("network","interface",function(sec) if sec[".name"]~="loopback"then o:value(sec[".name"],sec[".name"])end end)
o:depends({ip_source="interface",ip_version="ipv6"})
o:depends({ip_source="interface",ip_version="dual"})

o=s:option(ListValue,"ip_url6", translate("IPv6 detection URL"))
o:value("https://api6.ipify.org","api6.ipify.org")
o:value("https://6.ipw.cn","6.ipw.cn")
o:value("https://v6.ident.me","v6.ident.me")
o:value("https://ifconfig.co","ifconfig.co (v6)")
o:value("http://v6.66666.host:66/ip","v6.66666.host")
o.default="https://api6.ipify.org"
o.description= translate("Fetches address via IPv6-only connection.")
o:depends({ip_source="url",ip_version="ipv6"})
o:depends({ip_source="url",ip_version="dual"})

o=s:option(Value,"check_interval", translate("Interval (seconds)")); o.datatype="uinteger"; o.default="300"

o=s:option(DummyValue,"_info", translate("Status")); o.rawhtml=true
o.cfgvalue=function(self,section)
    local st=m.uci:get("minigate",section,"status")or"unknown"
    local msg=m.uci:get("minigate",section,"status_msg")or""
    local ip=m.uci:get("minigate",section,"last_ip")or""
    local ip6=m.uci:get("minigate",section,"last_ip6")or""
    local lu=m.uci:get("minigate",section,"last_update")or""
    local ns=m.uci:get("minigate",section,"next_sync")or""
    local ver=m.uci:get("minigate",section,"ip_version")or"ipv4"
    local t_partial   = translate("Partial")
    local t_error     = translate("Error")
    local t_notsynced = translate("Not synced")
    local t_updated   = translate("Updated: ")
    local t_next      = translate("Next: ")
    local t_syncnow   = translate("Sync now")

    local h=""
    if st=="ok"then
        h='<span style="color:#4caf50">&#10003; OK</span>'
    elseif st=="partial"then
        h='<span style="color:#ff9800">&#9888; '..t_partial..'</span>'
    elseif st=="error"then
        h='<span style="color:#f44336">&#10007; '..(msg~=""and msg or t_error)..'</span>'
    else h='<span style="color:#999">'..t_notsynced..'</span>' end

    if ip~=""then h=h..'<br><span style="font-size:11px;color:#888">A: '..ip..'</span>' end
    if ip6~=""then h=h..'<br><span style="font-size:11px;color:#2196f3">AAAA: '..ip6..'</span>' end
    if msg~=""and st~="error"then h=h..'<br><span style="font-size:11px;color:#888">'..msg..'</span>' end
    if lu~=""then h=h..'<br><span style="font-size:11px;color:#888">'..t_updated..lu..'</span>' end
    if ns~=""then h=h..'<br><span style="font-size:11px;color:#888">'..t_next..ns..'</span>' end

    h=h..'<br><button class="cbi-button cbi-button-action" style="margin-top:4px;font-size:12px;padding:2px 10px" '
    h=h..'onclick="doSync(\''..section..'\',this)">'..t_syncnow..'</button>'
    h=h..'<span id="sr-'..section..'" style="margin-left:8px;font-size:12px"></span>'
    return h
end

-- Inject JS
s=m:section(NamedSection,"global","global"); s.anonymous=true
o=s:option(DummyValue,"_js"," "); o.rawhtml=true
o.cfgvalue=function()
    local url=luci.dispatcher.build_url("admin/services/minigate/ddns_sync")
    local t_syncing = translate("Syncing...")
    local t_syncnow = translate("Sync now")
    local t_failed  = translate("Failed")
    return '<script type="text/javascript">function doSync(s,b){b.disabled=true;b.textContent="'..t_syncing..'";var e=document.getElementById("sr-"+s);e.textContent="";XHR.get("'..url..'",{section:s},function(x,d){b.disabled=false;b.textContent="'..t_syncnow..'";if(d&&d.success){e.innerHTML=\'<span style="color:#4caf50">\\u2713 \'+d.ip+(d.ip6?\' / \'+d.ip6:\'\')+\'</span>\';setTimeout(function(){location.reload()},1500)}else e.innerHTML=\'<span style="color:#f44336">\\u2717 '..t_failed..'</span>\'})}</script>'
end

return m
