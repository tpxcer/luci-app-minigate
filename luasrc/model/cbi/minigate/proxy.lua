local m, s, o
local sys = require "luci.sys"
local uc = require "luci.model.uci".cursor()

m = Map("minigate", translate("MiniGate - Reverse Proxy"), translate("Changes take effect automatically after save."))

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

s = m:section(TypedSection, "proxy_wildcard", translate("Wildcard domains"),
    translate("Configure listening port and HTTPS. Forwarding is controlled by subdomain rules."))
s.anonymous = true
s.addremove = true
s.template = "cbi/tblsection"

o = s:option(Value, "name", translate("Name"))
o.rmempty = true
o.placeholder = translate("e.g. my-site")

o = s:option(ListValue, "enabled", translate("Enable"))
o:value("1", translate("Enabled"))
o:value("0", translate("Disabled"))
o.default = "1"
o.rmempty = false

o = s:option(ListValue, "domain", translate("Domain"))
o:value("", "-- " .. translate("Select") .. " --")
for _, d in ipairs(wildcard_domains) do
    local label = d
    if ddns_ok[d] then label = d .. " ✓" end
    o:value(d, label)
end
o.rmempty = true

o = s:option(Value, "listen_port", translate("Listen port"))
o.datatype = "port"
o.default = "2000"
o.rmempty = true

o = s:option(ListValue, "ssl", "HTTPS")
o:value("1", translate("Enabled"))
o:value("0", translate("Disabled"))
o.default = "1"
o.rmempty = false

s = m:section(TypedSection, "subproxy", translate("Subdomain rules"))
s.anonymous = true
s.addremove = true
s.sortable = true
s.template = "cbi/tblsection"

o = s:option(ListValue, "parent_domain", translate("Parent domain"))
o:value("", "--")
for _, d in ipairs(wildcard_domains) do
    local base = d:gsub("^%*%.", "")
    o:value(base, d)
end
o.rmempty = false

o = s:option(Value, "prefix", translate("Prefix"))
o.rmempty = false
o.placeholder = "app"

o = s:option(Value, "target_addr", translate("Target address"))
o.rmempty = false
o.placeholder = "192.168.1.100"

o = s:option(Value, "target_port", translate("Port"))
o.datatype = "port"
o.default = "80"
o.rmempty = false

o = s:option(DummyValue, "_final", translate("Resolved domain"))
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

s = m:section(TypedSection, "proxy", translate("Proxy rules"),
    translate("Reverse proxy for non-wildcard domains."))
s.anonymous = true
s.addremove = true
s.template = "cbi/tblsection"
s.sortable = true

o = s:option(Value, "name", translate("Name"))
o.rmempty = true
o.placeholder = translate("e.g. my-site")

o = s:option(ListValue, "enabled", translate("Enable"))
o:value("1", translate("Enabled"))
o:value("0", translate("Disabled"))
o.default = "1"
o.rmempty = false

o = s:option(ListValue, "domain", translate("Domain"))
o:value("", "-- " .. translate("Select") .. " --")
for _, d in ipairs(normal_domains) do
    local label = d
    if ddns_ok[d] then label = d .. " ✓" end
    o:value(d, label)
end
o.rmempty = true

o = s:option(Value, "listen_port", translate("Port"))
o.datatype = "port"
o.default = "443"
o.rmempty = true

o = s:option(Value, "target_addr", translate("Target address"))
o.rmempty = true
o.placeholder = "192.168.1.100"

o = s:option(Value, "target_port", translate("Target port"))
o.datatype = "port"
o.default = "80"
o.rmempty = true

o = s:option(ListValue, "ssl", "HTTPS")
o:value("1", translate("Enabled"))
o:value("0", translate("Disabled"))
o.default = "1"
o.rmempty = false

o = s:option(ListValue, "websocket", "WS")
o:value("0", translate("Disabled"))
o:value("1", translate("Enabled"))
o.default = "0"
o.rmempty = false

end -- normal_domains

return m
