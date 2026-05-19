local m,s,o
local sys=require"luci.sys"
local fs=require"nixio.fs"
local uc=require"luci.model.uci".cursor()

local dd={}
uc:foreach("minigate","ddns",function(sec) if sec.domain and sec.domain~=""then dd[#dd+1]=sec.domain end end)

m=Map("minigate", translate("MiniGate - SSL Certificate"), translate("Automatic ACME (Let's Encrypt) certificate issuance. Domain and token are auto-linked from Dynamic DNS."))

s=m:section(NamedSection,"acme","acme", translate("ACME Settings")); s.anonymous=true

o=s:option(Flag,"enabled", translate("Enable ACME")); o.rmempty=false

o=s:option(Value,"email", translate("Account email")); o.placeholder="admin@example.com"; o.rmempty=true
o.description= translate("Optional.")

o=s:option(ListValue,"key_type", translate("Key type"))
o:value("ec-256","ECC P-256 (" .. translate("recommended") .. ")"); o:value("ec-384","ECC P-384"); o:value("rsa-2048","RSA 2048"); o:value("rsa-4096","RSA 4096")
o.default="ec-256"

o=s:option(Flag,"staging", translate("Staging mode")); o.rmempty=false; o.default="1"
o.description= translate("Disable for production use.")

o=s:option(DummyValue,"_certs", translate("Issued certificates")); o.rawhtml=true
o.cfgvalue=function()
    local t_domain  = translate("Domain")
    local t_expires = translate("Expires")
    local t_path    = translate("Path")
    local t_nocerts = translate("No certificates found.")
    local cd="/etc/minigate/certs"
    local h='<table class="table"><tr class="tr table-titles"><th class="th">'..t_domain..'</th><th class="th">'..t_expires..'</th><th class="th">'..t_path..'</th></tr>'
    local found=false
    if fs.dir(cd)then
        for entry in fs.dir(cd)do
            local fp=cd.."/"..entry
            -- lstat 返回 table，检查 type 字段
            local st=fs.lstat(fp)
            if entry~="_default" and st and st.type=="dir"then
                local cert=fp.."/fullchain.pem"
                if fs.access(cert)then
                    found=true
                    local exp=""
                    local f=io.popen("openssl x509 -in '"..cert.."' -noout -enddate 2>/dev/null")
                    if f then local l=f:read("*l"); if l then exp=l:gsub("notAfter=","") end; f:close() end
                    local dn=entry:gsub("_wildcard_%.", "*.")
                    h=h..'<tr class="tr"><td class="td"><strong>'..dn..'</strong></td><td class="td">'..exp..'</td><td class="td"><code>'..fp..'/</code></td></tr>'
                end
            end
        end
    end
    if not found then h=h..'<tr class="tr"><td class="td" colspan="3" style="text-align:center;color:#999;padding:15px">'..t_nocerts..'</td></tr>' end
    return h..'</table>'
end

o=s:option(DummyValue,"_ast", translate("acme.sh status")); o.rawhtml=true
o.cfgvalue=function()
    local t_installed   = translate("Installed")
    local t_dnsmissing  = translate("DNS plugin missing")
    local t_notinstalled= translate("Not installed")
    if fs.access("/etc/minigate/acme/data/acme.sh")and fs.access("/etc/minigate/acme/data/dnsapi/dns_cf.sh")then return'<span style="color:#4caf50">&#10003; '..t_installed..'</span>'
    elseif fs.access("/etc/minigate/acme/data/acme.sh")then return'<span style="color:#ff9800">&#9888; '..t_dnsmissing..'</span>'
    else return'<span style="color:#f44336">&#10007; '..t_notinstalled..'</span>'end
end

s=m:section(NamedSection,"acme","acme", translate("Actions")); s.anonymous=true
o=s:option(DummyValue,"_act"," "); o.rawhtml=true
o.cfgvalue=function()
    local iu=luci.dispatcher.build_url("admin/services/minigate/acme_install")
    local su=luci.dispatcher.build_url("admin/services/minigate/acme_issue")
    local t_dl_install   = translate("Download and install acme.sh")
    local t_issue_domain = translate("Issue domain:")
    local t_cfg_ddns     = translate("Configure Dynamic DNS first")
    local t_issue_renew  = translate("Issue / Renew")
    local t_processing   = translate("Processing...")
    local t_dl_ing       = translate("Downloading and installing (about 30 seconds)...")
    local t_sel_domain   = translate("Please select a domain")
    local t_timeout      = translate("Timeout")
    local t_failed       = translate("Failed")
    local t_issuing = translate("Issuing") .. " "
    local opts=""
    for _,d in ipairs(dd)do opts=opts..'<option value="'..d..'">'..d..'</option>' end
    local sel_opts = opts~="" and opts or ('<option value="">'..t_cfg_ddns..'</option>')
    return [[
<div style="margin-bottom:15px">
<button class="cbi-button cbi-button-reload" id="bi" onclick="doI()" style="min-width:220px">]] .. t_dl_install .. [[</button>
</div>
<div style="display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-bottom:10px">
<label>]] .. t_issue_domain .. [[</label>
<select id="sd" style="padding:5px 10px;border-radius:4px;border:1px solid #ccc;min-width:250px">
]] .. sel_opts .. [[
</select>
<button class="cbi-button cbi-button-apply" id="bs" onclick="doS()">]] .. t_issue_renew .. [[</button>
</div>
<div id="ap" style="margin-top:12px;display:none">
  <div style="background:#f0f0f0;border-radius:4px;padding:10px 15px;font-size:13px">
    <span style="display:inline-block;animation:sp 1s linear infinite;margin-right:8px">&#9203;</span>
    <span id="am">]] .. t_processing .. [[</span>
  </div>
</div>
<div id="ar" style="margin-top:12px;display:none">
  <div id="ai" style="border-radius:4px;padding:10px 15px;font-size:13px"></div>
</div>
<style>@keyframes sp{from{transform:rotate(0deg)}to{transform:rotate(360deg)}}</style>
<script type="text/javascript">
function sP(m){document.getElementById('ap').style.display='block';document.getElementById('ar').style.display='none';document.getElementById('am').textContent=m}
function sR(ok,m){document.getElementById('ap').style.display='none';document.getElementById('ar').style.display='block';var e=document.getElementById('ai');e.style.background=ok?'#e8f5e9':'#ffebee';e.style.color=ok?'#2e7d32':'#c62828';e.textContent=m}
function doI(){document.getElementById('bi').disabled=true;sP(']] .. t_dl_ing .. [[');XHR.get(']] .. iu .. [[',null,function(x,d){document.getElementById('bi').disabled=false;d?sR(d.success,d.message):sR(false,']] .. t_failed .. [[');if(d&&d.success)setTimeout(function(){location.reload()},2000)})}
function doS(){var d=document.getElementById('sd').value;if(!d){sR(false,']] .. t_sel_domain .. [[');return}document.getElementById('bs').disabled=true;sP(']] .. t_issuing .. [['+d+' (~2min)');XHR.get(']] .. su .. [[',{domain:d},function(x,r){document.getElementById('bs').disabled=false;r?sR(r.success,r.message):sR(false,']] .. t_timeout .. [[');if(r&&r.success)setTimeout(function(){location.reload()},2000)})}
</script>
]] end

return m
