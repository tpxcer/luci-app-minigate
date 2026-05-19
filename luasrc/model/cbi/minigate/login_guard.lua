local m, s, o
local sys = require "luci.sys"
local fs = require "nixio.fs"

m = Map("minigate", translate("Login Guard"),
    translate("Monitors SSH (dropbear) and LuCI login failures and auto-bans source IPs on threshold.") ..
    " " .. translate("Intended for SSH ports exposed to the internet. LAN private IPs are always exempt."))

m.on_after_commit = function(self)
    sys.call("/etc/init.d/minigate reload >/dev/null 2>&1 &")
end

-- ============== 实时状态 ==============
s = m:section(NamedSection, "login_guard", "login_guard", translate("Live Status"))
s.anonymous = true

local lu = luci.dispatcher.build_url("admin/services/minigate/lg_status")
local uu = luci.dispatcher.build_url("admin/services/minigate/lg_unban")
local bu = luci.dispatcher.build_url("admin/services/minigate/lg_ban")
local fu = luci.dispatcher.build_url("admin/services/minigate/lg_flush")
local gu = luci.dispatcher.build_url("admin/services/minigate/geo_lookup")

o = s:option(DummyValue, "_dash")
o.rawhtml = true
o.cfgvalue = function()
    local t_svc_status   = translate("Service Status")
    local t_cur_banned   = translate("Currently Banned")
    local t_counting     = translate("Counting Failures")
    local t_banned_list  = translate("Banned IP List")
    local t_counting_sub = translate("Counting Failures (below threshold)")
    local t_show         = translate("Show")
    local t_enter_ip     = translate("Enter IP to ban")
    local t_ban          = translate("Ban")
    local t_flush_all    = translate("Flush All")
    local t_loading      = translate("Loading...")
    local t_ip_addr      = translate("IP Address")
    local t_location     = translate("Location")
    local t_failures     = translate("Failures")
    local t_last_seen    = translate("Last Seen")
    local t_since_first  = translate("Since First Failure")
    local t_remaining    = translate("Remaining")
    local t_action       = translate("Action")
    local t_none         = translate("None")
    local t_no_bans      = translate("No bans.")
    local t_querying     = translate("Querying...")
    local t_disabled     = translate("Disabled")
    local t_running      = translate("Running")
    local t_not_running  = translate("Not running")
    local t_unban        = translate("Unban")
    local t_confirm_unban= translate("Confirm unban")
    local t_failed       = translate("Failed")
    local t_please_ip    = translate("Please enter an IP")
    local t_invalid_ip   = translate("Invalid IP format")
    local t_confirm_flush= translate("Confirm flush all bans? This cannot be undone.")
    local t_refresh_fail = translate("Refresh failed, please retry.")
    local t_render_err   = translate("Render error: ")
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
    local watching_items = {}
    local counter_dir = "/var/run/minigate/login-guard/counters"
    local list_out = sys.exec("ls " .. counter_dir .. " 2>/dev/null") or ""
    for ip in list_out:gmatch("[^\n]+") do
        local path = counter_dir .. "/" .. ip
        local fh = io.open(path, "r")
        if fh then
            local line = fh:read("*l") or ""
            fh:close()
            local first, count = line:match("^(%d+)%s+(%d+)")
            if first and count then
                local stat = fs.stat(path)
                local last_time = (stat and stat.mtime) or tonumber(first)
                watching_items[#watching_items + 1] = {
                    ip = ip,
                    count = tonumber(count) or 0,
                    age = now - tonumber(first),
                    last_time = last_time,
                    last_seen = os.date("%Y-%m-%d %H:%M:%S", last_time)
                }
            end
        end
    end
    table.sort(watching_items, function(a,b)
        return (a.last_time or 0) > (b.last_time or 0)
    end)
    for i = 1, math.min(#watching_items, 30) do
        local item = watching_items[i]
        local style = (i > 5) and ' style="display:none"' or ''
        watching_rows[#watching_rows + 1] =
            '<tr class="lg-watch-row" data-ip="' .. esc(item.ip) .. '" data-index="' .. tostring(i) .. '"' .. style .. '><td><code class="lg-ip">' .. esc(item.ip) .. '</code></td>' ..
            '<td id="lg-watch-geo-initial-' .. tostring(i) .. '"><span style="color:#999">Querying...</span></td>' ..
            '<td><span style="font-weight:bold">' .. esc(item.count) .. ' / ' .. esc(threshold) .. '</span></td>' ..
            '<td>' .. esc(item.last_seen) .. '</td>' ..
            '<td>' .. esc(fmt_duration(item.age)) .. '</td></tr>'
    end

    local initial_watching = '<div class="lg-empty">None</div>'
    if #watching_rows > 0 then
        initial_watching =
            '<table class="lg-table"><thead><tr><th>IP Address</th><th>Location</th><th>Failures</th><th>Last Seen</th><th>Since First Failure</th></tr></thead><tbody>' ..
            table.concat(watching_rows, "") ..
            '</tbody></table>'
    end

    return [[
<style>
.lg-wrap{display:flex;flex-direction:column;gap:16px}
.lg-summary{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}
.lg-card{position:relative;min-height:118px;border-radius:8px;padding:18px;background:#fff;border:1px solid #d7dce3;box-shadow:0 10px 24px rgba(15,23,42,.08);overflow:hidden}
.lg-card:before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px;background:var(--accent,#777)}
.lg-card-title{font-size:12px;color:#5f6b7a;margin-bottom:14px}
.lg-card-value{font-size:22px;font-weight:700;line-height:1.25}
.lg-panel{border-radius:8px;background:#fff;border:1px solid #d7dce3;box-shadow:0 10px 24px rgba(15,23,42,.08);overflow:hidden}
.lg-panel-head{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;padding:14px 16px;border-bottom:1px solid #d7dce3}
.lg-panel-title{font-size:13px;font-weight:700;color:#1f2937}
.lg-tools{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.lg-input{height:30px;min-width:180px;border-radius:6px;border:1px solid #c8d0dc;background:#fff;color:#1f2937;padding:0 10px;font-size:12px;box-sizing:border-box}
.lg-select{height:30px;border-radius:6px;border:1px solid #c8d0dc;background:#fff;color:#1f2937;padding:0 8px;font-size:12px;box-sizing:border-box}
.lg-limit-label{display:flex;align-items:center;gap:6px;color:#5f6b7a;font-size:12px;white-space:nowrap}
.lg-btn{height:30px;border:0;border-radius:6px;padding:0 12px;font-size:12px;color:#fff;cursor:pointer}
.lg-btn-primary{background:#5b55c8}
.lg-btn-danger{background:#f08a24}
.lg-table-wrap{overflow-x:auto}
.lg-table{width:100%;border-collapse:collapse;min-width:720px}
.lg-table th{padding:10px 12px;color:#5f6b7a;font-size:11px;font-weight:600;text-align:left;border-bottom:1px solid #d7dce3;background:#f6f8fb}
.lg-table td{padding:11px 12px;color:#1f2937;font-size:12px;border-bottom:1px solid #e6eaf0;vertical-align:middle}
.lg-table tr:nth-child(even) td{background:#f8fafc}
.lg-table tr:hover td{background:#eef4ff}
.lg-ip{display:inline-block;border-radius:6px;background:#e8edf6;color:#1f2937;padding:2px 7px;font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace;font-size:12px}
.lg-ip-danger{background:#fee2e2;color:#991b1b}
.lg-empty{padding:18px 16px;color:#667085;font-size:12px}
.lg-unban{height:26px;border:1px solid #c8d0dc;border-radius:6px;background:#fff;color:#1f2937;padding:0 10px;font-size:11px;cursor:pointer}
@media(prefers-color-scheme:dark){
.lg-card{background:#262626;border-color:rgba(255,255,255,.08);box-shadow:0 10px 24px rgba(0,0,0,.18)}
.lg-card-title{color:#a8a8a8}
.lg-panel{background:#262626;border-color:rgba(255,255,255,.08);box-shadow:0 10px 24px rgba(0,0,0,.16)}
.lg-panel-head{border-bottom-color:rgba(255,255,255,.08)}
.lg-panel-title{color:#ededed}
.lg-input,.lg-select{border-color:rgba(255,255,255,.14);background:#1d1d1d;color:#eee}
.lg-limit-label{color:#aaa}
.lg-table th{color:#9d9d9d;border-bottom-color:rgba(255,255,255,.08);background:#202020}
.lg-table td{color:#dddddd;border-bottom-color:rgba(255,255,255,.06);background:transparent}
.lg-table tr:nth-child(even) td{background:#262626}
.lg-table tr:hover td{background:#2e2e2e}
.lg-ip{background:#383b45;color:#f2f4ff}
.lg-ip-danger{background:#4a3030;color:#ffb8b8}
.lg-empty{color:#aaa}
.lg-unban{border-color:rgba(255,255,255,.16);background:#313131;color:#eee}
}
@media(max-width:900px){.lg-summary{grid-template-columns:1fr}.lg-card{min-height:auto}.lg-input{width:100%;min-width:0}.lg-tools{width:100%}}
</style>

<div class="lg-wrap">
<div id="lg-summary" class="lg-summary">
  <div class="lg-card" style="--accent:#4caf50">
    <div class="lg-card-title">]] .. t_svc_status .. [[</div>
    <div id="lg-running" class="lg-card-value">--</div>
  </div>
  <div class="lg-card" style="--accent:#f44336">
    <div class="lg-card-title">]] .. t_cur_banned .. [[</div>
    <div id="lg-banned-count" class="lg-card-value" style="color:#ff7b72">--</div>
  </div>
  <div class="lg-card" style="--accent:#ff9800">
    <div class="lg-card-title">]] .. t_counting .. [[</div>
    <div id="lg-watching-count" class="lg-card-value" style="color:#ffb35c">--</div>
  </div>
</div>

<div class="lg-panel">
  <div class="lg-panel-head">
    <div class="lg-panel-title">]] .. t_banned_list .. [[</div>
    <div class="lg-tools">
      <label class="lg-limit-label">]] .. t_show .. [[
        <select id="lg-ban-limit" class="lg-select">
          <option value="5">5</option>
          <option value="20">20</option>
          <option value="30">30</option>
        </select>
      </label>
      <input id="lg-ban-input" class="lg-input" type="text" placeholder="]] .. t_enter_ip .. [[" />
      <button class="lg-btn lg-btn-primary" onclick="lgManualBan()">]] .. t_ban .. [[</button>
      <button class="lg-btn lg-btn-danger" onclick="lgFlushAll()">]] .. t_flush_all .. [[</button>
    </div>
  </div>
  <div id="lg-banned-list" class="lg-table-wrap"><div class="lg-empty">]] .. t_loading .. [[</div></div>
</div>

<div class="lg-panel">
  <div class="lg-panel-head">
    <div class="lg-panel-title">]] .. t_counting_sub .. [[</div>
    <div class="lg-tools">
      <label class="lg-limit-label">]] .. t_show .. [[
        <select id="lg-watch-limit" class="lg-select">
          <option value="5">5</option>
          <option value="20">20</option>
          <option value="30">30</option>
        </select>
      </label>
    </div>
  </div>
  <div id="lg-watching-list" class="lg-table-wrap">]] .. initial_watching .. [[</div>
</div>

</div>

<script type="text/javascript">
var _lgGeoCache={};
var _lgGeoPending={};
var _lgBanLimit=5;
var _lgWatchLimit=5;

function lgQueryGeo(ip,cb){
    if(_lgGeoCache[ip]){cb(_lgGeoCache[ip]);return;}
    if(_lgGeoPending[ip]){
        _lgGeoPending[ip].push(cb);
        return;
    }
    _lgGeoPending[ip]=[cb];
    XHR.get(']] .. gu .. [[',{ip:ip},function(x,d){
        var loc=(d&&d.geo)?d.geo:']] .. translate('Unknown') .. [[';
        var list=_lgGeoPending[ip]||[];
        delete _lgGeoPending[ip];
        _lgGeoCache[ip]=loc;
        for(var i=0;i<list.length;i++)list[i](loc);
    });
}

function lgApplyInitialWatchingLimit(){
    var rows=document.querySelectorAll('#lg-watching-list .lg-watch-row');
    for(var i=0;i<rows.length;i++){
        rows[i].style.display=(i<_lgWatchLimit)?'':'none';
    }
}

function lgQueryInitialWatchingGeo(){
    var rows=document.querySelectorAll('#lg-watching-list .lg-watch-row');
    var qi=0;
    function next(){
        while(qi<rows.length && rows[qi].style.display=='none')qi++;
        if(qi>=rows.length)return;
        var row=rows[qi++];
        var ip=row.getAttribute('data-ip')||'';
        var idx=row.getAttribute('data-index')||'';
        if(!ip){setTimeout(next,0);return;}
        lgQueryGeo(ip,function(loc){
            var ge=document.getElementById('lg-watch-geo-initial-'+idx);
            if(ge)ge.innerHTML='<span style="font-size:11px">'+loc+'</span>';
            setTimeout(next,150);
        });
    }
    next();
}

function fmtDuration(s){
    if(s>=3600) return Math.floor(s/3600)+'h'+Math.floor((s%3600)/60)+'m';
    if(s>=60)   return Math.floor(s/60)+'m'+(s%60)+'s';
    return s+'s';
}

function lgUnban(ip,btn){
    if(!confirm(']] .. t_confirm_unban .. [[ '+ip+' ?'))return;
    btn.disabled=true; btn.textContent='...';
    XHR.get(']] .. uu .. [[',{ip:ip},function(x,d){
        if(d&&d.success){lgRefresh();}
        else{btn.disabled=false;btn.textContent=']] .. t_unban .. [[';alert(']] .. t_failed .. [[');}
    });
}

function lgManualBan(){
    var ip=document.getElementById('lg-ban-input').value.trim();
    if(!ip){alert(']] .. t_please_ip .. [[');return;}
    if(!ip.match(/^\d+\.\d+\.\d+\.\d+$/)){alert(']] .. t_invalid_ip .. [[');return;}
    XHR.get(']] .. bu .. [[',{ip:ip},function(x,d){
        if(d&&d.success){
            document.getElementById('lg-ban-input').value='';
            lgRefresh();
        }else alert(']] .. t_failed .. [[');
    });
}

function lgFlushAll(){
    if(!confirm(']] .. t_confirm_flush .. [['))return;
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
        wEl.innerHTML='<div class="lg-empty">]] .. t_none .. [[</div>';
        return;
    }
    var h2='<table class="lg-table">';
    h2+='<thead><tr><th>]] .. t_ip_addr .. [[</th><th>]] .. t_location .. [[</th><th>]] .. t_failures .. [[</th><th>]] .. t_last_seen .. [[</th><th>]] .. t_since_first .. [[</th></tr></thead><tbody>';
    for(var j=0;j<watching.length;j++){
        var w=watching[j]||{};
        var ip=w.ip||'--';
        var count=Number(w.count)||0;
        var age=Number(w.age)||0;
        var lastSeen=w.last_seen||'--';
        var pct=Math.min(100,Math.round(count*100/threshold));
        var color=pct>=66?'#ff7b72':(pct>=33?'#ffb35c':'#aaa');
        h2+='<tr>';
        h2+='<td><code class="lg-ip">'+ip+'</code></td>';
        h2+='<td id="lg-watch-geo-'+j+'"><span style="color:#999">]] .. t_querying .. [[</span></td>';
        h2+='<td><span style="color:'+color+';font-weight:bold">'+count+' / '+threshold+'</span></td>';
        h2+='<td>'+lastSeen+'</td>';
        h2+='<td>'+fmtDuration(age)+'</td>';
        h2+='</tr>';
    }
    h2+='</tbody></table>';
    wEl.innerHTML=h2;
    // 与总览“访问记录”保持一致：逐个查询归属地，避免并发太多。
    var qi=0;
    function nextWatchingGeo(){
        if(qi>=watching.length)return;
        var idx=qi;qi++;
        var row=watching[idx]||{};
        if(!row.ip){
            setTimeout(nextWatchingGeo,0);
            return;
        }
        lgQueryGeo(row.ip,function(loc){
            var ge=document.getElementById('lg-watch-geo-'+idx);
            if(ge) ge.innerHTML='<span style="font-size:11px">'+loc+'</span>';
            setTimeout(nextWatchingGeo,150);
        });
    }
    nextWatchingGeo();
}

function lgApplyStatus(d){
        if(!d){
            var wEl=document.getElementById('lg-watching-list');
            if(wEl)wEl.innerHTML='<div class="lg-empty">]] .. t_refresh_fail .. [[</div>';
            return;
        }
        // 服务状态
        var rEl=document.getElementById('lg-running');
        if(d.enabled=='1'){
            if(d.running) rEl.innerHTML='<span style="color:#4caf50">&#10003; ]] .. t_running .. [[</span>';
            else rEl.innerHTML='<span style="color:#f44336">&#10007; ]] .. t_not_running .. [[</span>';
        }else{
            rEl.innerHTML='<span style="color:#999">]] .. t_disabled .. [[</span>';
        }
        document.getElementById('lg-banned-count').textContent=(d.banned_total!=null)?d.banned_total:(d.banned||[]).length;
        document.getElementById('lg-watching-count').textContent=(d.watching_total!=null)?d.watching_total:(d.watching||[]).length;

        // 已封禁列表
        var listEl=document.getElementById('lg-banned-list');
        if(!d.banned||d.banned.length==0){
            listEl.innerHTML='<div class="lg-empty">]] .. t_no_bans .. [[</div>';
        }else{
            var h='<table class="lg-table">';
            h+='<thead><tr><th>]] .. t_ip_addr .. [[</th><th>]] .. t_location .. [[</th><th>]] .. t_remaining .. [[</th><th>]] .. t_action .. [[</th></tr></thead><tbody>';
            for(var i=0;i<d.banned.length;i++){
                var b=d.banned[i];
                h+='<tr>';
                h+='<td><code class="lg-ip lg-ip-danger">'+b.ip+'</code></td>';
                h+='<td id="lg-geo-'+i+'"><span style="color:#999">]] .. t_querying .. [[</span></td>';
                h+='<td>'+fmtDuration(b.remaining)+'</td>';
                h+='<td><button class="lg-unban" onclick="lgUnban(\''+b.ip+'\',this)">]] .. t_unban .. [[</button></td>';
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
            if(wEl)wEl.innerHTML='<div class="lg-empty">]] .. t_render_err .. [['+e.message+'</div>';
        }

}

function lgRefresh(){
    XHR.get(']] .. lu .. [[',{ban_limit:_lgBanLimit,watch_limit:_lgWatchLimit},function(x,d){
        lgApplyStatus(d);
    });
}

var lgBanLimitSel=document.getElementById('lg-ban-limit');
if(lgBanLimitSel){
    lgBanLimitSel.value=String(_lgBanLimit);
    lgBanLimitSel.onchange=function(){
        var v=parseInt(this.value,10);
        _lgBanLimit=(v==20||v==30)?v:5;
        lgRefresh();
    };
}

var lgWatchLimitSel=document.getElementById('lg-watch-limit');
if(lgWatchLimitSel){
    lgWatchLimitSel.value=String(_lgWatchLimit);
    lgWatchLimitSel.onchange=function(){
        var v=parseInt(this.value,10);
        _lgWatchLimit=(v==20||v==30)?v:5;
        lgApplyInitialWatchingLimit();
        lgQueryInitialWatchingGeo();
        lgRefresh();
    };
}

lgApplyInitialWatchingLimit();
lgQueryInitialWatchingGeo();
lgRefresh();
setInterval(lgRefresh,8000);
</script>
]]
end

s = m:section(NamedSection, "login_guard", "login_guard", translate("Settings"))
s.anonymous = true

o = s:option(Flag, "enabled", translate("Enable Login Guard"))
o.description = translate("When enabled, SSH/LuCI login failures are monitored. LAN IPs are never banned.")
o.rmempty = false

o = s:option(Value, "threshold", translate("Failure threshold"))
o.description = translate("Number of failures within the window that triggers a ban.")
o.datatype = "uinteger"
o.default = "3"
o.placeholder = "3"

o = s:option(ListValue, "window", translate("Failure window (seconds)"))
o.description = translate("Time window for counting failures. Counter resets if no failures occur within this period.")
o:value("300", translate("5 minutes"))
o:value("600", translate("10 minutes"))
o:value("1800", translate("30 minutes"))
o:value("3600", translate("1 hour"))
o:value("86400", translate("24 hours"))
o.default = "600"

o = s:option(ListValue, "bantime", translate("Ban duration"))
o:value("3600", translate("1 hour"))
o:value("21600", translate("6 hours"))
o:value("43200", translate("12 hours"))
o:value("86400", translate("24 hours"))
o:value("604800", translate("1 week"))
o:value("2592000", translate("30 days"))
o.default = "43200"

o = s:option(DynamicList, "whitelist", translate("Whitelist (extra)"))
o.description = translate("In addition to LAN private ranges (192.168.x, 10.x, 127.x, 172.16-31.x) which are always exempt, add these IPs/CIDRs.") ..
                " " .. translate("Supports single IP (e.g. 1.2.3.4) or /8 /16 /24 /32 subnets.")
o.placeholder = "e.g. 8.8.8.8 or 203.0.113.0/24"

return m
