local m, s, o
local sys = require "luci.sys"

m = Map("minigate", "MiniGate 轻网关", "轻量级网关管理：动态域名解析、SSL 证书签发、反向代理。")

m.on_after_commit = function(self)
    local en = self.uci:get("minigate", "global", "enabled")
    if en == "1" then
        sys.call("/etc/init.d/minigate restart >/dev/null 2>&1 &")
    else
        sys.call("/etc/init.d/minigate stop >/dev/null 2>&1 &")
    end
end

s = m:section(NamedSection, "global", "global", "服务状态")
s.anonymous = true
s:tab("status", "总览")

local su = luci.dispatcher.build_url("admin/services/minigate/status")

o = s:taboption("status", DummyValue, "_status")
o.rawhtml = true
o.cfgvalue = function() return [[
<div id="mg" style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px">
<div id="mg-ddns-card" style="background:#f8f9fa;border-radius:8px;padding:15px;border-left:4px solid #4caf50">
<div style="font-size:12px;color:#666">动态DNS</div>
<div id="mg-d1" style="font-size:16px;font-weight:bold;margin:5px 0">--</div>
<div id="mg-d2" style="font-size:12px;color:#888"></div>
</div>
<div style="background:#f8f9fa;border-radius:8px;padding:15px;border-left:4px solid #2196f3">
<div style="font-size:12px;color:#666">SSL/TLS 证书</div>
<div id="mg-a1" style="font-size:16px;font-weight:bold;margin:5px 0">--</div>
<div id="mg-a2" style="font-size:12px;color:#888"></div>
</div>
<div style="background:#f8f9fa;border-radius:8px;padding:15px;border-left:4px solid #ff9800">
<div style="font-size:12px;color:#666">反向代理</div>
<div id="mg-p1" style="font-size:16px;font-weight:bold;margin:5px 0">--</div>
<div id="mg-p2" style="font-size:12px;color:#888"></div>
</div>
</div>
<script type="text/javascript">
XHR.poll(6,']] .. su .. [[',null,function(x,d){
if(!d)return;
var d1=document.getElementById('mg-d1'),d2=document.getElementById('mg-d2');
var card=document.getElementById('mg-ddns-card');
if(d.ddns_list&&d.ddns_list.length>0){
var e=d.ddns_list[0];
var c=e.status=='ok'?'#4caf50':(e.enabled=='1'?'#f44336':'#999');
var l=e.status=='ok'?'\u2713 \u8fd0\u884c\u4e2d':(e.enabled=='1'?'\u26a0 \u5f02\u5e38':'\u672a\u542f\u7528');
card.style.borderLeftColor=c;
d1.innerHTML='<span style="color:'+c+'">'+l+'</span>';
var info=(e.domain||'')+' \u2192 '+(e.last_ip||'--');
if(e.status_msg)info+='\n'+e.status_msg;
if(e.last_update)info+='\n\u66f4\u65b0: '+e.last_update;
if(e.next_sync)info+='\n\u4e0b\u6b21: '+e.next_sync;
if(d.ddns_list.length>1)info+='\n(+'+(d.ddns_list.length-1)+' \u6761\u8bb0\u5f55)';
d2.innerHTML=info.replace(/\n/g,'<br>');
}else{d1.innerHTML='<span style="color:#999">\u672a\u914d\u7f6e</span>';d2.textContent='';card.style.borderLeftColor='#999';}

var a1=document.getElementById('mg-a1'),a2=document.getElementById('mg-a2');
if(d.acme&&d.acme.enabled=='1'){
a1.innerHTML=d.acme.status=='ok'?'<span style="color:#2196f3">\u2713 \u6709\u6548</span>':'<span style="color:#f44336">'+d.acme.status+'</span>';
a2.innerHTML=(d.acme.last_domain||'')+(d.acme.cert_expiry?'<br>\u8fc7\u671f: '+d.acme.cert_expiry:'');
}else{a1.innerHTML='<span style="color:#999">\u672a\u542f\u7528</span>';a2.textContent='';}

var p1=document.getElementById('mg-p1'),p2=document.getElementById('mg-p2');
p1.innerHTML=d.proxy_running?'<span style="color:#ff9800">\u2713 \u8fd0\u884c\u4e2d</span>':'<span style="color:#999">\u5df2\u505c\u6b62</span>';
var pinfo='';
if(d.proxy_rules&&d.proxy_rules.length>0){
for(var i=0;i<d.proxy_rules.length;i++){
var r=d.proxy_rules[i];
var url=r.scheme+'://'+r.domain+(r.listen_port!='443'&&r.listen_port!='80'?':'+r.listen_port:'');
pinfo+='<div style="font-size:11px;margin-top:3px"><span style="color:#4caf50">'+url+'</span> \u2192 '+r.target+'</div>';
}}else if(d.proxy_running){pinfo='Nginx \u8fd0\u884c\u4e2d';}
p2.innerHTML=pinfo;
});</script>
]] end

s = m:section(NamedSection, "global", "global", "全局设置")
s.anonymous = true
o = s:option(Flag, "enabled", "启用 MiniGate")
o.description = "总开关。关闭后停止 DDNS 定时任务、ACME 续期和反向代理。保存后立即生效。"
o.rmempty = false
return m
