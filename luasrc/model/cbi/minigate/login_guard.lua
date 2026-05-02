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
    local function esc(v)
        v = tostring(v or "")
        v = v:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
        v = v:gsub('"', "&quot;"):gsub("'", "&#39;")
        return v
    end

    local function fmt_duration(s)
        s = tonumber(s) or 0
        if s >= 3600 then
            return string.format("%dh%dm", math.floor(s / 3600), math.floor((s % 3600) / 60))
        elseif s >= 60 then
            return string.format("%dm%ds", math.floor(s / 60), s % 60)
        end
        return tostring(s) .. "s"
    end

    local threshold = tonumber(m.uci:get("minigate", "login_guard", "threshold")) or 3
    local now = os.time()
    local watching_rows = {}
    local counter_dir = "/var/run/minigate/login-guard/counters"
    local list_out = sys.exec("ls " .. counter_dir .. " 2>/dev/null") or ""
    for ip in list_out:gmatch("[^\n]+") do
        local fh = io.open(counter_dir .. "/" .. ip, "r")
        if fh then
            local line = fh:read("*l") or ""
            fh:close()
            local first, count = line:match("^(%d+)%s+(%d+)")
            if first and count then
                local age = now - tonumber(first)
                watching_rows[#watching_rows + 1] =
                    '<tr><td><code class="lg-ip">' .. esc(ip) .. '</code></td>' ..
                    '<td><span style="color:#999">等待刷新...</span></td>' ..
                    '<td><span style="font-weight:bold">' .. esc(count) .. ' / ' .. esc(threshold) .. '</span></td>' ..
                    '<td>' .. esc(fmt_duration(age)) .. '</td></tr>'
            end
        end
    end

    local initial_watching = '<div class="lg-empty">无</div>'
    if #watching_rows > 0 then
        initial_watching =
            '<table class="lg-table"><thead><tr><th>IP 地址</th><th>归属地</th><th>失败次数</th><th>距首次失败</th></tr></thead><tbody>' ..
            table.concat(watching_rows, "") ..
            '</tbody></table>'
    end

    return [[
<style>
.lg-wrap{display:flex;flex-direction:column;gap:16px}
.lg-summary{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}
.lg-card{position:relative;min-height:118px;border-radius:8px;padding:18px;background:#262626;border:1px solid rgba(255,255,255,.08);box-shadow:0 10px 24px rgba(0,0,0,.18);overflow:hidden}
.lg-card:before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px;background:var(--accent,#777)}
.lg-card-title{font-size:12px;color:#a8a8a8;margin-bottom:14px}
.lg-card-value{font-size:22px;font-weight:700;line-height:1.25}
.lg-panel{border-radius:8px;background:#262626;border:1px solid rgba(255,255,255,.08);box-shadow:0 10px 24px rgba(0,0,0,.16);overflow:hidden}
.lg-panel-head{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;padding:14px 16px;border-bottom:1px solid rgba(255,255,255,.08)}
.lg-panel-title{font-size:13px;font-weight:700;color:#ededed}
.lg-tools{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.lg-input{height:30px;min-width:180px;border-radius:6px;border:1px solid rgba(255,255,255,.14);background:#1d1d1d;color:#eee;padding:0 10px;font-size:12px;box-sizing:border-box}
.lg-btn{height:30px;border:0;border-radius:6px;padding:0 12px;font-size:12px;color:#fff;cursor:pointer}
.lg-btn-primary{background:#5b55c8}
.lg-btn-danger{background:#f08a24}
.lg-table-wrap{overflow-x:auto}
.lg-table{width:100%;border-collapse:collapse;min-width:720px}
.lg-table th{padding:10px 12px;color:#9d9d9d;font-size:11px;font-weight:600;text-align:left;border-bottom:1px solid rgba(255,255,255,.08);background:#202020}
.lg-table td{padding:11px 12px;color:#dddddd;font-size:12px;border-bottom:1px solid rgba(255,255,255,.06);vertical-align:middle}
.lg-table tr:hover td{background:#2e2e2e}
.lg-ip{display:inline-block;border-radius:6px;background:#383b45;color:#f2f4ff;padding:2px 7px;font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace;font-size:12px}
.lg-ip-danger{background:#4a3030;color:#ffb8b8}
.lg-empty{padding:18px 16px;color:#aaa;font-size:12px}
.lg-unban{height:26px;border:1px solid rgba(255,255,255,.16);border-radius:6px;background:#313131;color:#eee;padding:0 10px;font-size:11px;cursor:pointer}
@media(max-width:900px){.lg-summary{grid-template-columns:1fr}.lg-card{min-height:auto}.lg-input{width:100%;min-width:0}.lg-tools{width:100%}}
</style>

<div class="lg-wrap">
<div id="lg-summary" class="lg-summary">
  <div class="lg-card" style="--accent:#4caf50">
    <div class="lg-card-title">服务状态</div>
    <div id="lg-running" class="lg-card-value">--</div>
  </div>
  <div class="lg-card" style="--accent:#f44336">
    <div class="lg-card-title">当前已封禁</div>
    <div id="lg-banned-count" class="lg-card-value" style="color:#ff7b72">--</div>
  </div>
  <div class="lg-card" style="--accent:#ff9800">
    <div class="lg-card-title">失败计数中</div>
    <div id="lg-watching-count" class="lg-card-value" style="color:#ffb35c">--</div>
  </div>
</div>

<div class="lg-panel">
  <div class="lg-panel-head">
    <div class="lg-panel-title">已封禁 IP 列表</div>
    <div class="lg-tools">
      <input id="lg-ban-input" class="lg-input" type="text" placeholder="输入 IP 手动封禁" />
      <button class="lg-btn lg-btn-primary" onclick="lgManualBan()">封禁</button>
      <button class="lg-btn lg-btn-danger" onclick="lgFlushAll()">清空全部</button>
    </div>
  </div>
  <div id="lg-banned-list" class="lg-table-wrap"><div class="lg-empty">加载中...</div></div>
</div>

<div class="lg-panel">
  <div class="lg-panel-head">
    <div class="lg-panel-title">失败计数中（未达阈值）</div>
  </div>
  <div id="lg-watching-list" class="lg-table-wrap">]] .. initial_watching .. [[</div>
</div>
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

function lgRenderWatching(watching,threshold){
    var wEl=document.getElementById('lg-watching-list');
    if(!wEl)return;
    watching=watching||[];
    threshold=Number(threshold)||3;
    if(watching.length==0){
        wEl.innerHTML='<div class="lg-empty">无</div>';
        return;
    }
    var h2='<table class="lg-table">';
    h2+='<thead><tr><th>IP 地址</th><th>归属地</th><th>失败次数</th><th>距首次失败</th></tr></thead><tbody>';
    for(var j=0;j<watching.length;j++){
        var w=watching[j]||{};
        var ip=w.ip||'--';
        var count=Number(w.count)||0;
        var age=Number(w.age)||0;
        var pct=Math.min(100,Math.round(count*100/threshold));
        var color=pct>=66?'#ff7b72':(pct>=33?'#ffb35c':'#aaa');
        h2+='<tr>';
        h2+='<td><code class="lg-ip">'+ip+'</code></td>';
        h2+='<td id="lg-watch-geo-'+j+'"><span style="color:#999">查询中...</span></td>';
        h2+='<td><span style="color:'+color+';font-weight:bold">'+count+' / '+threshold+'</span></td>';
        h2+='<td>'+fmtDuration(age)+'</td>';
        h2+='</tr>';
    }
    h2+='</tbody></table>';
    wEl.innerHTML=h2;
    var wq=0;
    function nextWatchingGeo(){
        if(wq>=watching.length)return;
        var idx=wq++;
        var row=watching[idx]||{};
        if(!row.ip){
            setTimeout(nextWatchingGeo,0);
            return;
        }
        lgQueryGeo(row.ip,function(loc){
            var ge=document.getElementById('lg-watch-geo-'+idx);
            if(ge) ge.innerHTML='<span style="font-size:11px">'+loc+'</span>';
            nextWatchingGeo();
        });
    }
    for(var n=0;n<3;n++)nextWatchingGeo();
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
            listEl.innerHTML='<div class="lg-empty">暂无封禁</div>';
        }else{
            var h='<table class="lg-table">';
            h+='<thead><tr><th>IP 地址</th><th>归属地</th><th>剩余时间</th><th>操作</th></tr></thead><tbody>';
            for(var i=0;i<d.banned.length;i++){
                var b=d.banned[i];
                h+='<tr>';
                h+='<td><code class="lg-ip lg-ip-danger">'+b.ip+'</code></td>';
                h+='<td id="lg-geo-'+i+'"><span style="color:#999">查询中...</span></td>';
                h+='<td>'+fmtDuration(b.remaining)+'</td>';
                h+='<td><button class="lg-unban" onclick="lgUnban(\''+b.ip+'\',this)">解封</button></td>';
                h+='</tr>';
            }
            h+='</tbody></table>';
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
        try{lgRenderWatching(d.watching,d.threshold);}
        catch(e){
            var wEl=document.getElementById('lg-watching-list');
            if(wEl)wEl.innerHTML='<div class="lg-empty">渲染失败：'+e.message+'</div>';
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
