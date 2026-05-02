local m, s, o
local sys = require "luci.sys"

m = Map("minigate", "MiniGate 轻网关", "轻量级网关管理：动态域名解析（IPv4/IPv6双栈）、SSL 证书签发、反向代理。")

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
o.cfgvalue = function()
    local su = luci.dispatcher.build_url("admin/services/minigate/status")
    local au = luci.dispatcher.build_url("admin/services/minigate/proxy_access")
    local gu = luci.dispatcher.build_url("admin/services/minigate/geo_lookup")
    return [[
<style>
.mg-wrap{display:flex;flex-direction:column;gap:16px}
.mg-status-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}
.mg-card{position:relative;min-height:154px;border-radius:8px;padding:18px 18px 16px;background:#fff;border:1px solid #d7dce3;box-shadow:0 10px 24px rgba(15,23,42,.08);overflow:hidden}
.mg-card:before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px;background:var(--accent,#777)}
.mg-card-title{font-size:12px;color:#5f6b7a;margin-bottom:12px}
.mg-card-state{font-size:18px;font-weight:700;margin-bottom:14px;line-height:1.25}
.mg-card-body{font-size:12px;color:#2f3a47;line-height:1.9;word-break:break-word}
.mg-card-body a,.mg-link{color:#15803d;text-decoration:none}
.mg-card-body a:hover,.mg-link:hover{text-decoration:underline}
.mg-panel{border-radius:8px;background:#fff;border:1px solid #d7dce3;box-shadow:0 10px 24px rgba(15,23,42,.08);overflow:hidden}
.mg-panel-head{display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;padding:14px 16px;border-bottom:1px solid #d7dce3}
.mg-panel-title{font-size:13px;font-weight:700;color:#1f2937}
.mg-count{color:#7c3aed;font-weight:600}
.mg-limit-label{display:flex;align-items:center;gap:6px;font-size:12px;color:#5f6b7a;white-space:nowrap}
.mg-select{height:28px;border-radius:6px;border:1px solid #c8d0dc;background:#fff;color:#1f2937;padding:0 8px;font-size:12px}
.mg-table-wrap{overflow-x:auto}
.mg-table{width:100%;border-collapse:collapse;min-width:760px}
.mg-table th{padding:10px 12px;color:#5f6b7a;font-size:11px;font-weight:600;text-align:left;border-bottom:1px solid #d7dce3;background:#f6f8fb}
.mg-table td{padding:11px 12px;color:#1f2937;font-size:12px;border-bottom:1px solid #e6eaf0;vertical-align:middle}
.mg-table tr:nth-child(even) td{background:#f8fafc}
.mg-table tr:hover td{background:#eef4ff}
.mg-status{display:inline-flex;align-items:center;gap:6px;white-space:nowrap}
.mg-dot{display:inline-block;width:7px;height:7px;border-radius:50%;background:#777}
.mg-dot.on{background:#4caf50;box-shadow:0 0 0 3px rgba(76,175,80,.14)}
.mg-ip{display:inline-block;border-radius:6px;background:#e8edf6;color:#1f2937;padding:2px 7px;font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace;font-size:12px}
.mg-empty{padding:18px 16px;color:#667085;font-size:12px}
@media(prefers-color-scheme:dark){
.mg-card{background:#262626;border-color:rgba(255,255,255,.08);box-shadow:0 10px 24px rgba(0,0,0,.18)}
.mg-card-title{color:#a8a8a8}
.mg-card-body{color:#c8c8c8}
.mg-card-body a,.mg-link{color:#56d87a}
.mg-panel{background:#262626;border-color:rgba(255,255,255,.08);box-shadow:0 10px 24px rgba(0,0,0,.16)}
.mg-panel-head{border-bottom-color:rgba(255,255,255,.08)}
.mg-panel-title{color:#ededed}
.mg-count{color:#c16cff}
.mg-limit-label{color:#bdbdbd}
.mg-select{border-color:rgba(255,255,255,.14);background:#1d1d1d;color:#eee}
.mg-table th{color:#9d9d9d;border-bottom-color:rgba(255,255,255,.08);background:#202020}
.mg-table td{color:#dddddd;border-bottom-color:rgba(255,255,255,.06);background:transparent}
.mg-table tr:nth-child(even) td{background:#262626}
.mg-table tr:hover td{background:#2e2e2e}
.mg-ip{background:#383b45;color:#f2f4ff}
.mg-empty{color:#aaa}
}
@media(max-width:900px){.mg-status-grid{grid-template-columns:1fr}.mg-card{min-height:auto}}
</style>

<div class="mg-wrap">
<div id="mg" class="mg-status-grid">
<div id="mg-ddns-card" class="mg-card" style="--accent:#4caf50">
<div class="mg-card-title">动态 DNS</div>
<div id="mg-d1" class="mg-card-state">--</div>
<div id="mg-d2" class="mg-card-body"></div>
</div>
<div id="mg-cert-card" class="mg-card" style="--accent:#2196f3">
<div class="mg-card-title">SSL/TLS 证书</div>
<div id="mg-a1" class="mg-card-state">--</div>
<div id="mg-a2" class="mg-card-body"></div>
</div>
<div id="mg-proxy-card" class="mg-card" style="--accent:#ff9800">
<div class="mg-card-title">反向代理</div>
<div id="mg-p1" class="mg-card-state">--</div>
<div id="mg-p2" class="mg-card-body"></div>
</div>
</div>

<div id="mg-visitors" class="mg-panel">
<div class="mg-panel-head">
<div class="mg-panel-title">访问记录 <span id="mg-v-count" class="mg-count"></span></div>
<label class="mg-limit-label">显示
<select id="mg-v-limit" class="mg-select">
<option value="5" selected>5</option>
<option value="20">20</option>
<option value="50">50</option>
</select>条</label>
</div>
<div id="mg-v-list" class="mg-table-wrap"><div class="mg-empty">加载中...</div></div>
</div>
</div>

<script type="text/javascript">
var _geoCache={};
var _visitorLimit=localStorage.getItem('mgVisitorLimit')||'5';
if(_visitorLimit!='5'&&_visitorLimit!='20'&&_visitorLimit!='50')_visitorLimit='5';

function fmtT(iso){
    if(!iso)return'--';
    var m=iso.match(/(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/);
    return m?(m[2]+'-'+m[3]+' '+m[4]+':'+m[5]+':'+m[6]):iso;
}

function queryGeo(ip,cb){
    if(_geoCache[ip]){cb(_geoCache[ip]);return;}
    XHR.get(']] .. gu .. [[',{ip:ip},function(x,d){
        if(d&&d.geo){_geoCache[ip]=d.geo;cb(d.geo);}
        else{_geoCache[ip]='未知';cb('未知');}
    });
}

function loadVisitors(){
    XHR.get(']] .. au .. [[',{limit:_visitorLimit},function(x,d){
        var el=document.getElementById('mg-v-list');
        var ct=document.getElementById('mg-v-count');
        if(!d||!d.visitors||d.visitors.length===0){
            el.innerHTML='<div class="mg-empty">暂无访问记录</div>';
            ct.textContent='';
            return;
        }
        ct.textContent='('+d.visitors.length+' 个IP)';
        var h='<table class="mg-table">';
        h+='<thead><tr><th>状态</th><th>IP 地址</th><th>归属地</th><th>最后访问</th><th>域名</th><th>次数</th></tr></thead><tbody>';
        for(var i=0;i<d.visitors.length;i++){
            var v=d.visitors[i];
            var dot=v.online
                ?'<span class="mg-dot on" title="在线"></span>'
                :'<span class="mg-dot" title="离线"></span>';
            var stxt=v.online?'<span style="color:#72d987">在线</span>':'<span style="color:#a6a6a6">离线</span>';
            h+='<tr>';
            h+='<td><span class="mg-status">'+dot+stxt+'</span></td>';
            h+='<td><code class="mg-ip">'+v.ip+'</code></td>';
            h+='<td id="geo-'+i+'"><span style="color:#999">查询中...</span></td>';
            h+='<td style="white-space:nowrap">'+fmtT(v.last_time)+'</td>';
            h+='<td>'+v.domain+'</td>';
            h+='<td>'+v.count+'</td>';
            h+='</tr>';
        }
        h+='</tbody></table>';
        el.innerHTML=h;
        // 逐个查询归属地（避免并发太多）
        var qi=0;
        function nextGeo(){
            if(qi>=d.visitors.length)return;
            var idx=qi;qi++;
            queryGeo(d.visitors[idx].ip,function(loc){
                var ge=document.getElementById('geo-'+idx);
                if(ge)ge.innerHTML='<span style="font-size:11px">'+loc+'</span>';
                setTimeout(nextGeo,150);
            });
        }
        nextGeo();
    });
}

var limitSel=document.getElementById('mg-v-limit');
if(limitSel){
    limitSel.value=_visitorLimit;
    limitSel.onchange=function(){
        _visitorLimit=this.value;
        localStorage.setItem('mgVisitorLimit',_visitorLimit);
        loadVisitors();
    };
}

XHR.poll(6,']] .. su .. [[',null,function(x,d){
if(!d)return;
var d1=document.getElementById('mg-d1'),d2=document.getElementById('mg-d2');
var card=document.getElementById('mg-ddns-card');
if(d.ddns_list&&d.ddns_list.length>0){
var e=d.ddns_list[0];
var c=e.status=='ok'?'#4caf50':(e.status=='partial'?'#ff9800':(e.enabled=='1'?'#f44336':'#999'));
var l=e.status=='ok'?'\u2713 \u8fd0\u884c\u4e2d':(e.status=='partial'?'\u26a0 \u90e8\u5206\u6210\u529f':(e.enabled=='1'?'\u26a0 \u5f02\u5e38':'\u672a\u542f\u7528'));
card.style.setProperty('--accent',c);
d1.innerHTML='<span style="color:'+c+'">'+l+'</span>';
var info=(e.domain||'')+'\n';
if(e.last_ip)info+='A: '+e.last_ip+'\n';
if(e.last_ip6)info+='AAAA: '+e.last_ip6+'\n';
var sm=e.status_msg||'';
if(sm){
    var dupA=e.last_ip&&sm.indexOf('A:'+e.last_ip)>=0;
    var dupAAAA=e.last_ip6&&sm.indexOf('AAAA:'+e.last_ip6)>=0;
    var onlyIpStatus=sm.replace(/A:[^;]+;?/g,'').replace(/AAAA:[^;]+;?/g,'').replace(/\s+/g,'')=='';
    if(!(onlyIpStatus&&(dupA||dupAAAA)))info+=sm+'\n';
}
if(e.last_update)info+='\u66f4\u65b0: '+e.last_update+'\n';
if(e.next_sync)info+='\u4e0b\u6b21: '+e.next_sync;
if(d.ddns_list.length>1)info+='\n(+'+(d.ddns_list.length-1)+' \u6761\u8bb0\u5f55)';
d2.innerHTML=info.replace(/\n/g,'<br>');
}else{d1.innerHTML='<span style="color:#999">\u672a\u914d\u7f6e</span>';d2.textContent='';card.style.setProperty('--accent','#777');}

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
var v6tag=r.ipv6_listen=='1'?' <span style="color:#2196f3;font-size:10px">[IPv6]</span>':'';
pinfo+='<div><span class="mg-link">'+url+'</span>'+v6tag+' \u2192 '+r.target+'</div>';
}}else if(d.proxy_running){pinfo='Nginx \u8fd0\u884c\u4e2d';}
p2.innerHTML=pinfo;
});

loadVisitors();
setInterval(loadVisitors,15000);
</script>
]] end

s = m:section(NamedSection, "global", "global", "全局设置")
s.anonymous = true
o = s:option(Flag, "enabled", "启用 MiniGate")
o.description = "总开关。关闭后停止 DDNS 定时任务、ACME 续期和反向代理。保存后立即生效。"
o.rmempty = false

o = s:option(Flag, "ipv6_listen", "反向代理监听 IPv6")
o.description = "开启后，Nginx 反向代理将同时监听 IPv4 和 IPv6 地址（listen [::]:port）。"
o.rmempty = false
o.default = "0"

return m
