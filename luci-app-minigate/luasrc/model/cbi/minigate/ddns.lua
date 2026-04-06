local m,s,o
local sys=require"luci.sys"

m=Map("minigate","MiniGate - 动态DNS","支持多域名。保存后立即同步。需先启用全局开关。")

m.on_after_commit=function(self)
    sys.call("/bin/sh /usr/lib/minigate/ddns.sh force >/dev/null 2>&1 &")
    local en=self.uci:get("minigate","global","enabled")
    if en=="1"then sys.call("/etc/init.d/minigate restart >/dev/null 2>&1 &") end
end

s=m:section(TypedSection,"ddns","DDNS 记录")
s.anonymous=true; s.addremove=true; s.sortable=true

o=s:option(Flag,"enabled","启用"); o.rmempty=false

o=s:option(Value,"domain","域名"); o.rmempty=false; o.placeholder="*.example.com 或 home.example.com"

o=s:option(Value,"cf_zone_id","Zone ID"); o.rmempty=false; o.placeholder="Cloudflare 区域 ID"

o=s:option(Value,"cf_api_token","API 令牌"); o.rmempty=false; o.password=true

o=s:option(ListValue,"ip_source","IP 来源")
o:value("interface","从网卡获取"); o:value("url","从外部URL获取"); o.default="interface"

o=s:option(ListValue,"interface","网络接口"); o.default="wan"
local uci=require"luci.model.uci".cursor()
uci:foreach("network","interface",function(sec) if sec[".name"]~="loopback"then o:value(sec[".name"],sec[".name"])end end)
o:depends("ip_source","interface")

o=s:option(ListValue,"ip_url","获取地址")
o:value("https://api.ipify.org","api.ipify.org")
o:value("https://4.ipw.cn","4.ipw.cn")
o:value("https://ip.3322.net","ip.3322.net")
o:value("https://ddns.oray.com/checkip","ddns.oray.com")
o:value("https://myip.ipip.net","myip.ipip.net")
o:value("http://v4.66666.host:66/ip","v4.66666.host")
o.default="https://api.ipify.org"
o:depends("ip_source","url")

o=s:option(Value,"check_interval","间隔(秒)"); o.datatype="uinteger"; o.default="300"

-- 状态+手动同步
o=s:option(DummyValue,"_info","运行状态"); o.rawhtml=true
o.cfgvalue=function(self,section)
    local st=m.uci:get("minigate",section,"status")or"unknown"
    local msg=m.uci:get("minigate",section,"status_msg")or""
    local ip=m.uci:get("minigate",section,"last_ip")or""
    local lu=m.uci:get("minigate",section,"last_update")or""
    local ns=m.uci:get("minigate",section,"next_sync")or""
    local sync_url=luci.dispatcher.build_url("admin/services/minigate/ddns_sync")

    local h=""
    if st=="ok"then h='<span style="color:#4caf50">&#10003; '..ip..'</span>'
    elseif st=="error"then h='<span style="color:#f44336">&#10007; '..(msg~=""and msg or"异常")..'</span>'
    else h='<span style="color:#999">未同步</span>' end

    if msg~=""and st=="ok"then h=h..'<br><span style="font-size:11px;color:#888">'..msg..'</span>' end
    if lu~=""then h=h..'<br><span style="font-size:11px;color:#888">更新: '..lu..'</span>' end
    if ns~=""then h=h..'<br><span style="font-size:11px;color:#888">下次: '..ns..'</span>' end

    h=h..'<br><button class="cbi-button cbi-button-action" style="margin-top:4px;font-size:12px;padding:2px 10px" '
    h=h..'onclick="doSync(\''..section..'\',this)">手动同步</button>'
    h=h..'<span id="sr-'..section..'" style="margin-left:8px;font-size:12px"></span>'
    return h
end

-- 注入 JS（放在单独 section 避免重复）
s=m:section(NamedSection,"global","global"); s.anonymous=true
o=s:option(DummyValue,"_js"," "); o.rawhtml=true
o.cfgvalue=function()
    local url=luci.dispatcher.build_url("admin/services/minigate/ddns_sync")
    return'<script type="text/javascript">function doSync(s,b){b.disabled=true;b.textContent="同步中...";var e=document.getElementById("sr-"+s);e.textContent="";XHR.get("'..url..'",{section:s},function(x,d){b.disabled=false;b.textContent="手动同步";if(d&&d.success){e.innerHTML=\'<span style="color:#4caf50">\\u2713 \'+d.ip+\'</span>\';setTimeout(function(){location.reload()},1500)}else e.innerHTML=\'<span style="color:#f44336">\\u2717 失败</span>\'})}</script>'
end

return m
