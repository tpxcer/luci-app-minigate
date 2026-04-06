#!/bin/sh
LOGFILE="/var/log/minigate-ddns.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [DDNS] $*" >> "$LOGFILE"; }
trim_log() { [ -f "$LOGFILE" ] && [ "$(wc -l < "$LOGFILE")" -gt 300 ] && { tail -n 150 "$LOGFILE" > "${LOGFILE}.tmp"; mv "${LOGFILE}.tmp" "$LOGFILE"; }; }

get_ip_iface() {
    local ip=""
    ip=$(ubus call network.interface.${1:-wan} status 2>/dev/null | jsonfilter -e '@["ipv4-address"][0].address' 2>/dev/null)
    [ -z "$ip" ] && ip=$(ifstatus "${1:-wan}" 2>/dev/null | jsonfilter -e '@["ipv4-address"][0].address' 2>/dev/null)
    echo "$ip" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
}

get_ip_url() {
    local ip=""
    ip=$(curl -s --connect-timeout 5 "$1" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -z "$ip" ] && ip=$(wget -qO- "$1" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo "$ip"
}

cf_update() {
    local zone_id="$1" token="$2" domain="$3" ip="$4"
    local resp rid
    resp=$(curl -s --connect-timeout 10 -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
        "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=A&name=${domain}" 2>/dev/null)
    rid=$(echo "$resp" | jsonfilter -e '$.result[0].id' 2>/dev/null)
    if [ -n "$rid" ]; then
        resp=$(curl -s --connect-timeout 10 -X PUT -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
            -d "{\"type\":\"A\",\"name\":\"$domain\",\"content\":\"$ip\",\"ttl\":120,\"proxied\":false}" \
            "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${rid}" 2>/dev/null)
    else
        resp=$(curl -s --connect-timeout 10 -X POST -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
            -d "{\"type\":\"A\",\"name\":\"$domain\",\"content\":\"$ip\",\"ttl\":120,\"proxied\":false}" \
            "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" 2>/dev/null)
    fi
    echo "$resp" | jsonfilter -e '$.success' 2>/dev/null
}

calc_next() {
    local interval="${1:-300}"
    local now=$(date +%s)
    local next=$((now + interval))
    date -d "@${next}" '+%H:%M:%S' 2>/dev/null || echo "${interval}秒后"
}

update_one() {
    local sec="$1" force="$2"
    local enabled=$(uci -q get minigate.${sec}.enabled)
    [ "$enabled" = "1" ] || return 0

    local domain=$(uci -q get minigate.${sec}.domain)
    local zone_id=$(uci -q get minigate.${sec}.cf_zone_id)
    local token=$(uci -q get minigate.${sec}.cf_api_token)
    local ip_source=$(uci -q get minigate.${sec}.ip_source)
    local iface=$(uci -q get minigate.${sec}.interface)
    local ip_url=$(uci -q get minigate.${sec}.ip_url)
    local interval=$(uci -q get minigate.${sec}.check_interval); interval=${interval:-300}

    [ -z "$domain" ] || [ -z "$zone_id" ] || [ -z "$token" ] && {
        log "$domain: 配置不完整"
        uci -q set minigate.${sec}.status="error"; uci -q set minigate.${sec}.status_msg="配置不完整"
        return 1
    }

    local ip=""
    case "$ip_source" in url) ip=$(get_ip_url "$ip_url");; *) ip=$(get_ip_iface "$iface");; esac

    if [ -z "$ip" ]; then
        log "$domain: 获取IP失败"; uci -q set minigate.${sec}.status="error"; uci -q set minigate.${sec}.status_msg="获取IP失败"; return 1
    fi

    local cache="/tmp/minigate_ddns_${sec}.cache"
    local cached=$(cat "$cache" 2>/dev/null)
    local next_time=$(calc_next "$interval")

    if [ "$force" = "1" ] || [ "$ip" != "$cached" ]; then
        log "$domain: ${cached:-无} -> $ip"
        local result=$(cf_update "$zone_id" "$token" "$domain" "$ip")
        if [ "$result" = "true" ]; then
            log "$domain: 同步成功"
            echo "$ip" > "$cache"
            uci -q set minigate.${sec}.status="ok"
            uci -q set minigate.${sec}.status_msg="已同步 $ip"
            uci -q set minigate.${sec}.last_ip="$ip"
            uci -q set minigate.${sec}.last_update="$(date '+%Y-%m-%d %H:%M:%S')"
            uci -q set minigate.${sec}.next_sync="$next_time"
        else
            log "$domain: 同步失败"; uci -q set minigate.${sec}.status="error"; uci -q set minigate.${sec}.status_msg="API调用失败"
        fi
    else
        log "$domain: 地址一致($ip)，未修改"
        uci -q set minigate.${sec}.status="ok"
        uci -q set minigate.${sec}.status_msg="地址一致，未修改"
        uci -q set minigate.${sec}.last_ip="$ip"
        uci -q set minigate.${sec}.next_sync="$next_time"
    fi
}

main() {
    # 检查全局开关
    local gen=$(uci -q get minigate.global.enabled)
    if [ "$gen" != "1" ]; then
        log "全局未启用，跳过 DDNS"
        return 0
    fi

    local force=0; [ "$1" = "force" ] && force=1
    log "--- 开始同步 ---"
    local sections=$(uci -q show minigate | grep '=ddns$' | cut -d. -f2 | cut -d= -f1)
    local c=0
    for sec in $sections; do update_one "$sec" "$force"; c=$((c + 1)); done
    [ "$c" = "0" ] && log "无 DDNS 记录"
    uci commit minigate
    log "--- 同步完成 ($c 条) ---"
    trim_log
}

# 手动单条同步（不检查全局开关）
if [ "$1" = "single" ] && [ -n "$2" ]; then
    log "手动同步: $2"
    update_one "$2" "1"
    uci commit minigate
    trim_log
    exit 0
fi

main "$@"
