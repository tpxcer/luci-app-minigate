local m, s, o
local sys = require "luci.sys"
local uc = require "luci.model.uci".cursor()

m = Map("minigate", "MiniGate - 反向代理", "保存后自动生效。")

m.on_after_commit = function(self)
    sys.call("sleep 1 && /bin/sh /usr/lib/minigate/proxy.sh reload >/dev/null 2>&1 &")
end

local ddns_domains = {}
local ddns_ok = {}
local wildcard_domains = {}
local normal_domains = {}
uc:foreach("minigate", "ddns", function(sec)
    local d = sec.domain or ""
    local st = sec.status or ""
    if d ~= "" then
        ddns_domains[#ddns_domains + 1] = d
        if st == "ok" then ddns_ok[d] = true end
        if d:match("^%*%.") then
            wildcard_domains[#wildcard_domains + 1] = d
        else
            normal_domains[#normal_domains + 1] = d
        end
    end
end)

-- ================================
-- 通配符域名
-- ================================
if #wildcard_domains > 0 then

s = m:section(TypedSection, "proxy_wildcard", "通配符域名",
    "配置监听端口和HTTPS，具体转发由「子域名」控制。")
s.anonymous = false
s.addremove = true
s.template = "cbi/tblsection"
s.sectionhead = "名称"

o = s:option(ListValue, "enabled", "启用")
o:value("1", "✓ 启用")
o:value("0", "✗ 禁用")
o.default = "1"
o.rmempty = false

o = s:option(ListValue, "domain", "域名")
o:value("", "-- 请选择 --")
for _, d in ipairs(wildcard_domains) do
    local label = d
    if ddns_ok[d] then label = d .. " ✓" end
    o:value(d, label)
end
o.rmempty = false

o = s:option(Value, "listen_port", "监听端口")
o.datatype = "port"
o.default = "2000"
o.rmempty = false

o = s:option(ListValue, "ssl", "HTTPS")
o:value("1", "✓ 开启")
o:value("0", "✗ 关闭")
o.default = "1"
o.rmempty = false

-- ================================
-- 子域名规则
-- ================================
s = m:section(TypedSection, "subproxy", "子域名规则")
s.anonymous = true
s.addremove = true
s.sortable = true
s.template = "cbi/tblsection"

o = s:option(ListValue, "parent_domain", "主域名")
o:value("", "--")
for _, d in ipairs(wildcard_domains) do
    local base = d:gsub("^%*%.", "")
    o:value(base, d)
end
o.rmempty = false

o = s:option(Value, "prefix", "前缀")
o.rmempty = false
o.placeholder = "app"

o = s:option(Value, "target_addr", "目标地址")
o.rmempty = false
o.placeholder = "192.168.1.100"

o = s:option(Value, "target_port", "端口")
o.datatype = "port"
o.default = "80"
o.rmempty = false

o = s:option(DummyValue, "_final", "实际域名")
o.rawhtml = true
o.cfgvalue = function(self, section)
    local base = m.uci:get("minigate", section, "parent_domain") or ""
    local prefix = m.uci:get("minigate", section, "prefix") or ""
    if prefix ~= "" and base ~= "" then
        return '<strong style="color:#4caf50">' .. prefix .. '.' .. base .. '</strong>'
    end
    return '<span style="color:#999">--</span>'
end

end -- wildcard_domains

-- ================================
-- 普通域名代理
-- ================================
if #normal_domains > 0 or #wildcard_domains == 0 then

s = m:section(TypedSection, "proxy", "代理规则",
    "非通配符域名的反向代理。")
s.anonymous = false
s.addremove = true
s.template = "cbi/tblsection"
s.sortable = true
s.sectionhead = "名称"

o = s:option(ListValue, "enabled", "启用")
o:value("1", "✓ 启用")
o:value("0", "✗ 禁用")
o.default = "1"
o.rmempty = false

o = s:option(ListValue, "domain", "域名")
o:value("", "-- 请选择 --")
for _, d in ipairs(normal_domains) do
    local label = d
    if ddns_ok[d] then label = d .. " ✓" end
    o:value(d, label)
end
o.rmempty = false

o = s:option(Value, "listen_port", "端口")
o.datatype = "port"
o.default = "443"
o.rmempty = false

o = s:option(Value, "target_addr", "目标地址")
o.rmempty = false
o.placeholder = "192.168.1.100"

o = s:option(Value, "target_port", "目标端口")
o.datatype = "port"
o.default = "80"
o.rmempty = false

o = s:option(ListValue, "ssl", "HTTPS")
o:value("1", "✓ 开启")
o:value("0", "✗ 关闭")
o.default = "1"
o.rmempty = false

o = s:option(ListValue, "websocket", "WS")
o:value("0", "✗ 关闭")
o:value("1", "✓ 开启")
o.default = "0"
o.rmempty = false

end -- normal_domains

-- ================================
-- 最近访问记录
-- ================================
s = m:section(NamedSection, "global", "global", "最近访问记录")
s.anonymous = true

o = s:option(DummyValue, "_access_log", " ")
o.rawhtml = true
o.cfgvalue = function()
    local access_url = luci.dispatcher.build_url("admin/services/minigate/proxy_access")
    return [[
<div style="margin-bottom:10px">
    <button class="cbi-button cbi-button-action" onclick="loadAccess()" id="btn-refresh-access">刷新</button>
    <label style="margin-left:15px"><input type="checkbox" id="access-auto" checked> 自动刷新(10秒)</label>
    <select id="access-limit" style="margin-left:15px;padding:4px 8px;border-radius:4px;border:1px solid #ccc">
        <option value="20">20条</option>
        <option value="50" selected>50条</option>
        <option value="100">100条</option>
    </select>
</div>
<div style="overflow-x:auto">
<table class="table" id="access-table">
<tr class="tr table-titles">
    <th class="th" style="width:160px">时间</th>
    <th class="th" style="width:160px">访客 IP</th>
    <th class="th" style="width:160px">域名</th>
    <th class="th" style="width:60px">方法</th>
    <th class="th">路径</th>
    <th class="th" style="width:50px">状态</th>
    <th class="th" style="width:70px">大小</th>
</tr>
<tr class="tr"><td class="td" colspan="7" style="text-align:center;color:#999;padding:20px">加载中...</td></tr>
</table>
</div>
<script type="text/javascript">
var accessTimer;
function fmtTime(iso){
    if(!iso)return'--';
    var m=iso.match(/(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/);
    if(m)return m[1]+'-'+m[2]+'-'+m[3]+' '+m[4]+':'+m[5]+':'+m[6];
    return iso;
}
function fmtSize(b){
    if(b<1024)return b+'B';
    if(b<1048576)return (b/1024).toFixed(1)+'K';
    return (b/1048576).toFixed(1)+'M';
}
function statusColor(s){
    if(s>=200&&s<300)return'#4caf50';
    if(s>=300&&s<400)return'#2196f3';
    if(s>=400&&s<500)return'#ff9800';
    return'#f44336';
}
function ipTag(ip){
    if(!ip)return'--';
    var isV6=ip.indexOf(':')!==-1;
    var tag=isV6?'<span style="background:#e3f2fd;color:#1565c0;font-size:10px;padding:1px 4px;border-radius:3px;margin-left:4px">v6</span>':'<span style="background:#e8f5e9;color:#2e7d32;font-size:10px;padding:1px 4px;border-radius:3px;margin-left:4px">v4</span>';
    return '<code>'+ip+'</code>'+tag;
}
function loadAccess(){
    var limit=document.getElementById('access-limit').value;
    XHR.get(']] .. access_url .. [[',{limit:limit},function(x,d){
        var tb=document.getElementById('access-table');
        while(tb.rows.length>1)tb.deleteRow(1);
        if(!d||!d.records||d.records.length===0){
            var r=tb.insertRow(-1);r.className='tr';
            var c=r.insertCell(0);c.className='td';c.colSpan=7;
            c.style.cssText='text-align:center;color:#999;padding:20px';
            c.textContent='暂无访问记录';
            return;
        }
        for(var i=0;i<d.records.length;i++){
            var e=d.records[i];
            var r=tb.insertRow(-1);r.className='tr';
            var cells=[
                fmtTime(e.time),
                ipTag(e.client),
                '<strong>'+e.domain+'</strong>',
                '<code>'+e.method+'</code>',
                '<span title="'+(e.uri||'')+'">'+((e.uri||'').length>40?(e.uri||'').substr(0,40)+'...':e.uri||'')+'</span>',
                '<span style="color:'+statusColor(e.status)+'">'+e.status+'</span>',
                fmtSize(e.size)
            ];
            for(var j=0;j<cells.length;j++){
                var c=r.insertCell(j);c.className='td';c.innerHTML=cells[j];
                if(j===0)c.style.cssText='font-size:12px;white-space:nowrap';
                if(j===4)c.style.cssText='font-size:12px;max-width:250px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap';
            }
        }
    });
}
function schedAccess(){
    if(accessTimer)clearInterval(accessTimer);
    if(document.getElementById('access-auto').checked)accessTimer=setInterval(loadAccess,10000);
}
document.getElementById('access-auto').addEventListener('change',schedAccess);
document.getElementById('access-limit').addEventListener('change',loadAccess);
loadAccess();schedAccess();
</script>
]]
end

return m
