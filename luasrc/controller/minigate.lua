module("luci.controller.minigate", package.seeall)

function index()
    entry({"admin","services","minigate"}, alias("admin","services","minigate","general"), "MiniGate", 60).dependent=false
    entry({"admin","services","minigate","general"}, cbi("minigate/general"), "总览", 10)
    entry({"admin","services","minigate","ddns"}, cbi("minigate/ddns"), "动态DNS", 20)
    entry({"admin","services","minigate","acme"}, cbi("minigate/acme"), "SSL 证书", 30)
    entry({"admin","services","minigate","proxy"}, cbi("minigate/proxy"), "反向代理", 40)
    entry({"admin","services","minigate","log"}, template("minigate/log"), "日志", 50)
    entry({"admin","services","minigate","status"}, call("action_status")).leaf=true
    entry({"admin","services","minigate","get_log"}, call("action_get_log")).leaf=true
    entry({"admin","services","minigate","acme_install"}, call("action_acme_install")).leaf=true
    entry({"admin","services","minigate","acme_issue"}, call("action_acme_issue")).leaf=true
    entry({"admin","services","minigate","ddns_sync"}, call("action_ddns_sync")).leaf=true
end

function action_status()
    local uci=require"luci.model.uci".cursor()
    local pr=false
    local f=io.open("/var/run/minigate-nginx.pid","r")
    if f then local p=f:read("*l"); f:close()
        if p and tonumber(p) then pr=(os.execute("kill -0 "..p.." 2>/dev/null")==0) end
    end
    local al={}
    for _,lf in ipairs({"/var/log/minigate-ddns.log","/var/log/minigate-acme.log","/var/log/minigate-proxy.log"}) do
        local fh=io.open(lf,"r"); if fh then for l in fh:lines() do al[#al+1]=l end; fh:close() end
    end
    local st=#al-19; if st<1 then st=1 end
    local ll={}; for i=st,#al do ll[#ll+1]=al[i] end
    local ca=false; local cf=io.open("/etc/crontabs/root","r")
    if cf then local c=cf:read("*a"); cf:close(); ca=c:find("minigate")~=nil end
    local dl={}
    uci:foreach("minigate","ddns",function(s) dl[#dl+1]={name=s[".name"],enabled=s.enabled or"0",domain=s.domain or"",status=s.status or"unknown",status_msg=s.status_msg or"",last_ip=s.last_ip or"",last_update=s.last_update or"",next_sync=s.next_sync or""} end)

    -- 收集代理规则信息
    local proxy_rules = {}
    -- 获取通配符监听端口
    local wc_ports = {}
    uci:foreach("minigate","proxy_wildcard",function(s)
        if (s.enabled == "1" or s.enabled == true) and s.domain then
            local base = (s.domain or ""):gsub("^%*%.","")
            local ssl_val = tostring(s.ssl or "0")
            wc_ports[base] = {port=s.listen_port or "443", ssl=ssl_val}
        end
    end)
    -- 子域名规则
    uci:foreach("minigate","subproxy",function(s)
        local parent = s.parent_domain or ""
        local prefix = s.prefix or ""
        local taddr = s.target_addr or ""
        local tport = s.target_port or "80"
        if prefix ~= "" and parent ~= "" then
            local wc = wc_ports[parent] or {}
            local lport = wc.port or "443"
            local ssl_val = wc.ssl or "0"
            local scheme = (ssl_val == "1" or ssl_val == "true") and "https" or "http"
            proxy_rules[#proxy_rules+1] = {domain=prefix.."."..parent, target=taddr..":"..tport, listen_port=lport, scheme=scheme}
        end
    end)
    -- 普通代理规则
    uci:foreach("minigate","proxy",function(s)
        if (s.enabled == "1" or s.enabled == true) and s.domain and s.target_addr then
            local ssl_val = tostring(s.ssl or "0")
            local scheme = (ssl_val == "1" or ssl_val == "true") and "https" or "http"
            proxy_rules[#proxy_rules+1] = {domain=s.domain, target=(s.target_addr or "")..":"..(s.target_port or "80"), listen_port=s.listen_port or "443", scheme=scheme}
        end
    end)

    luci.http.prepare_content("application/json")
    luci.http.write_json({enabled=uci:get("minigate","global","enabled")or"0",proxy_running=pr,cron_active=ca,recent_log=table.concat(ll,"\n"),ddns_list=dl,proxy_rules=proxy_rules,
        acme={enabled=uci:get("minigate","acme","enabled")or"0",status=uci:get("minigate","acme","status")or"unknown",last_domain=uci:get("minigate","acme","last_domain")or"",last_issue=uci:get("minigate","acme","last_issue")or"",cert_expiry=uci:get("minigate","acme","cert_expiry")or""}})
end

function action_get_log()
    local sys=require"luci.sys"; local s=luci.http.formvalue("source")or"all"
    local fs={ddns="/var/log/minigate-ddns.log",acme="/var/log/minigate-acme.log",proxy="/var/log/minigate-proxy.log /var/log/minigate-nginx-error.log"}
    local cmd=s=="all"and"cat /var/log/minigate-*.log 2>/dev/null|tail -200"or"cat "..(fs[s]or"").." 2>/dev/null|tail -200"
    luci.http.prepare_content("application/json"); luci.http.write_json({log=sys.exec(cmd)or""})
end

function action_acme_install()
    local sys=require"luci.sys"; sys.call("/bin/sh /usr/lib/minigate/acme.sh install 2>&1")
    local fs=require"nixio.fs"; local ok=fs.access("/etc/minigate/acme/data/acme.sh")and fs.access("/etc/minigate/acme/data/dnsapi/dns_cf.sh")
    luci.http.prepare_content("application/json"); luci.http.write_json({success=ok,message=ok and"安装成功"or"安装失败"})
end

function action_acme_issue()
    local sys=require"luci.sys"; local d=luci.http.formvalue("domain")or""
    local cmd="/bin/sh /usr/lib/minigate/acme.sh issue"; if d~=""then cmd=cmd.." '"..d.."'"end
    sys.call(cmd.." 2>&1")
    local uci=require"luci.model.uci".cursor(); local st=uci:get("minigate","acme","status")or"unknown"
    luci.http.prepare_content("application/json"); luci.http.write_json({success=(st=="ok"),message=(st=="ok")and"签发成功！"or"签发失败，查看日志"})
end

function action_ddns_sync()
    local sys=require"luci.sys"; local sec=luci.http.formvalue("section")or""
    if sec~=""then sys.call("/bin/sh /usr/lib/minigate/ddns.sh single '"..sec.."' 2>&1")
    else sys.call("/bin/sh /usr/lib/minigate/ddns.sh force 2>&1") end
    local uci=require"luci.model.uci".cursor()
    local st=sec~=""and(uci:get("minigate",sec,"status")or"unknown")or"done"
    local ip=sec~=""and(uci:get("minigate",sec,"last_ip")or"")or""
    luci.http.prepare_content("application/json"); luci.http.write_json({success=(st=="ok"),status=st,ip=ip})
end
