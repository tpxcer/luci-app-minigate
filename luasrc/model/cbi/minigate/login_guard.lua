local m, s, o
local sys = require "luci.sys"

m = Map("minigate", "登录防护 (Login Guard)",
    "监控 SSH（dropbear）和 LuCI 网页登录失败，达到阈值自动封禁源 IP。" ..
    "适用于 SSH 端口被映射到公网、防爆破。LAN 私有 IP 自动豁免。")

m.on_after_commit = function(self)
    sys.call("/etc/init.d/minigate restart >/dev/null 2>&1 &")
end

-- ============== 实时状态 ==============
s = m:section(NamedSection, "login_guard", "login_guard", "实时状态")
s.anonymous = true

local lu = luci.dispatcher.build_url("admin/services/minigate/lg_status")
local uu = luci.dispatcher.build_url("admin/services/minigate/lg_unban")
local bu = luci.dispatcher.build_url("admin/services/minigate/lg_ban")
local fu = luci.dispatcher.build_url("admin/services/minigate/lg_flush")
local gu = luci.dispatcher.build_url("admin/services/minigate/geo_lookup")

o = s:option(DummyValue, "_dash")
o.rawhtml = true
o.cfgvalue = function()
    return [[
<div id="lg-summary" style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:12px">
  <div style="background:#f8f9fa;border-radius:8px;padding:15px;border-left:4px solid #4caf50">
    <div style="font-size:12px;color:#666">服务状态</div>
    <div id="lg-running" style="font-size:16px;font-weight:bold;margin:5px 0">--</div>
  </div>
  <div style="background:#f8f9fa;border-radius:8px;padding:15px;border-left:4px solid #f44336">
    <div style="font-size:12px;color:#666">当前已封禁</div>
    <div id="lg-banned-count" style="font-size:24px;font-weight:bold;margin:5px 0;color:#f44336">--</div>
  </div>
  <div style="background:#f8f9fa;border-radius:8px;padding:15px;border-left:4px solid #ff9800">
    <div style="font-size:12px;color:#666">失败计数中</div>
    <div id="lg-watching-count" style="font-size:24px;font-weight:bold;margin:5px 0;color:#ff9800">--</div>
  </div>
</div>

<!-- 已封禁 IP 列表 -->
<div style="background:#fff;border:1px solid #e0e0e0;border-radius:8px;padding:15px;margin-bottom:12px">
  <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">
    <span style="font-weight:bold">🛡 已封禁 IP 列表</span>
    <div>
      <input id="lg-ban-input" type="text" placeholder="输入 IP 手动封禁" style="padding:4px 8px;border:1px solid #ccc;border-radius:4px;font-size:12px;width:140px" />
      <button class="cbi-button cbi-button-action" style="padding:4px 12px;font-size:12px" onclick="lgManualBan()">封禁</button>
      <button class="cbi-button cbi-button-negative" style="padding:4px 12px;font-size:12px;margin-left:8px" onclick="lgFlushAll()">清空全部</button>
    </div>
  </div>
  <div id="lg-banned-list" style="font-size:12px">加载中...</div>
</div>

<!-- 失败计数中 -->
<div style="background:#fff;border:1px solid #e0e0e0;border-radius:8px;padding:15px">
  <div style="font-weight:bold;margin-bottom:10px">⚠ 失败计数中（未达阈值）</div>
  <div id="lg-watching-list" style="font-size:12px">加载中...</div>
</div>

<script type="text/javascript">
var _lgGeoCache={};

function lgQueryGeo(ip,cb){
    if(_lgGeoCache[ip]){cb(_lgGeoCache[ip]);return;}
    XHR.get(']] .. gu .. [[',{ip:ip},function(x,d){
        var v=(d&&d.geo)?d.geo:'未知';
        _lgGeoCache[ip]=v; cb(v);
    });
}

function fmtDuration(s){
    if(s>=3600) return Math.floor(s/3600)+'h'+Math.floor((s%3600)/60)+'m';
    if(s>=60)   return Math.floor(s/60)+'m'+(s%60)+'s';
    return s+'s';
}

function lgUnban(ip,btn){
    if(!confirm('确认解封 '+ip+' ?'))return;
    btn.disabled=true; btn.textContent='...';
    XHR.get(']] .. uu .. [[',{ip:ip},function(x,d){
        if(d&&d.success){lgRefresh();}
        else{btn.disabled=false;btn.textContent='解封';alert('失败');}
    });
}

function lgManualBan(){
    var ip=document.getElementById('lg-ban-input').value.trim();
    if(!ip){alert('请输入 IP');return;}
    if(!ip.match(/^\d+\.\d+\.\d+\.\d+$/)){alert('IP 格式不对');return;}
    XHR.get(']] .. bu .. [[',{ip:ip},function(x,d){
        if(d&&d.success){
            document.getElementById('lg-ban-input').value='';
            lgRefresh();
        }else alert('失败');
    });
}

function lgFlushAll(){
    if(!confirm('确认清空所有封禁？此操作不可撤销。'))return;
    XHR.get(']] .. fu .. [[',null,function(x,d){
        if(d&&d.success)lgRefresh();
    });
}

function lgRefresh(){
    XHR.get(']] .. lu .. [[',null,function(x,d){
        if(!d) return;
        // 服务状态
        var rEl=document.getElementById('lg-running');
        if(d.enabled=='1'){
            if(d.running) rEl.innerHTML='<span style="color:#4caf50">✓ 运行中</span>';
            else rEl.innerHTML='<span style="color:#f44336">✗ 未运行</span>';
        }else{
            rEl.innerHTML='<span style="color:#999">未启用</span>';
        }
        document.getElementById('lg-banned-count').textContent=(d.banned||[]).length;
        document.getElementById('lg-watching-count').textContent=(d.watching||[]).length;

        // 已封禁列表
        var listEl=document.getElementById('lg-banned-list');
        if(!d.banned||d.banned.length==0){
            listEl.innerHTML='<span style="color:#999">暂无封禁</span>';
        }else{
            var h='<table style="width:100%;border-collapse:collapse">';
            h+='<tr style="border-bottom:1px solid #e0e0e0;color:#666;font-size:11px">';
            h+='<td style="padding:4px 8px">IP 地址</td>';
            h+='<td style="padding:4px 8px">归属地</td>';
            h+='<td style="padding:4px 8px">剩余时间</td>';
            h+='<td style="padding:4px 8px">操作</td></tr>';
            for(var i=0;i<d.banned.length;i++){
                var b=d.banned[i];
                h+='<tr style="border-bottom:1px solid #f0f0f0">';
                h+='<td style="padding:5px 8px"><code style="background:#ffe8e8;color:#c62828;padding:1px 6px;border-radius:3px">'+b.ip+'</code></td>';
                h+='<td style="padding:5px 8px" id="lg-geo-'+i+'"><span style="color:#bbb">查询中...</span></td>';
                h+='<td style="padding:5px 8px">'+fmtDuration(b.remaining)+'</td>';
                h+='<td style="padding:5px 8px"><button class="cbi-button cbi-button-action" style="padding:2px 10px;font-size:11px" onclick="lgUnban(\''+b.ip+'\',this)">解封</button></td>';
                h+='</tr>';
            }
            h+='</table>';
            listEl.innerHTML=h;
            // 异步查归属地
            var qi=0;
            (function next(){
                if(qi>=d.banned.length)return;
                var idx=qi; qi++;
                lgQueryGeo(d.banned[idx].ip,function(loc){
                    var ge=document.getElementById('lg-geo-'+idx);
                    if(ge) ge.innerHTML='<span style="font-size:11px">'+loc+'</span>';
                    setTimeout(next,150);
                });
            })();
        }

        // 失败计数列表
        var wEl=document.getElementById('lg-watching-list');
        if(!d.watching||d.watching.length==0){
            wEl.innerHTML='<span style="color:#999">无</span>';
        }else{
            var h2='<table style="width:100%;border-collapse:collapse">';
            h2+='<tr style="border-bottom:1px solid #e0e0e0;color:#666;font-size:11px">';
            h2+='<td style="padding:4px 8px">IP 地址</td>';
            h2+='<td style="padding:4px 8px">归属地</td>';
            h2+='<td style="padding:4px 8px">失败次数</td>';
            h2+='<td style="padding:4px 8px">距首次失败</td></tr>';
            for(var j=0;j<d.watching.length;j++){
                var w=d.watching[j];
                var pct=Math.min(100,Math.round(w.count*100/d.threshold));
                var color=pct>=66?'#f44336':(pct>=33?'#ff9800':'#999');
                h2+='<tr style="border-bottom:1px solid #f0f0f0">';
                h2+='<td style="padding:5px 8px"><code style="background:#fff3e0;padding:1px 6px;border-radius:3px">'+w.ip+'</code></td>';
                h2+='<td style="padding:5px 8px" id="lg-watch-geo-'+j+'"><span style="color:#bbb">查询中...</span></td>';
                h2+='<td style="padding:5px 8px"><span style="color:'+color+';font-weight:bold">'+w.count+' / '+d.threshold+'</span></td>';
                h2+='<td style="padding:5px 8px">'+fmtDuration(w.age)+'</td>';
                h2+='</tr>';
            }
            h2+='</table>';
            wEl.innerHTML=h2;
            var wq=0;
            (function nextWatchingGeo(){
                if(wq>=d.watching.length)return;
                var idx=wq; wq++;
                lgQueryGeo(d.watching[idx].ip,function(loc){
                    var ge=document.getElementById('lg-watch-geo-'+idx);
                    if(ge) ge.innerHTML='<span style="font-size:11px">'+loc+'</span>';
                    setTimeout(nextWatchingGeo,150);
                });
            })();
        }
    });
}

lgRefresh();
XHR.poll(8,']] .. lu .. [[',null,lgRefresh);
</script>
]]
end

-- ============== 设置 ==============
s = m:section(NamedSection, "login_guard", "login_guard", "设置")
s.anonymous = true

o = s:option(Flag, "enabled", "启用登录防护")
o.description = "开启后将自动监控 SSH/LuCI 失败登录。LAN IP 永远不会被封禁。"
o.rmempty = false

o = s:option(Value, "threshold", "失败次数阈值")
o.description = "在「失败窗口」时间内累积达到此次数则封禁。"
o.datatype = "uinteger"
o.default = "3"
o.placeholder = "3"

o = s:option(ListValue, "window", "失败窗口（秒）")
o.description = "在多长时间内累计失败次数。超过此时间未再失败则计数清零。"
o:value("300", "5 分钟")
o:value("600", "10 分钟")
o:value("1800", "30 分钟")
o:value("3600", "1 小时")
o:value("86400", "24 小时")
o.default = "600"

o = s:option(ListValue, "bantime", "封禁时长")
o:value("3600", "1 小时")
o:value("21600", "6 小时")
o:value("43200", "12 小时")
o:value("86400", "24 小时")
o:value("604800", "1 周")
o:value("2592000", "30 天")
o.default = "43200"

o = s:option(DynamicList, "whitelist", "白名单（额外）")
o.description = "除了 LAN 私有段（192.168.x、10.x、127.x、172.16-31.x）默认豁免外，再加这些 IP/CIDR。" ..
                "支持单 IP（如 1.2.3.4）或 /8 /16 /24 /32 子网。"
o.placeholder = "如 8.8.8.8 或 203.0.113.0/24"

return m
