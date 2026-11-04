# shellcheck shell=bash
# System report — plain text, or a standalone HTML dashboard (data/report.html)

# ───────── JSON helpers (pure bash + awk, no jq needed) ─────────
_js_str() { # stdin text → one JSON string
    tr -d '\000-\010\013-\037' | awk 'BEGIN{ORS="";printf "\""} {gsub(/\\/,"\\\\");gsub(/"/,"\\\"");gsub(/\t/,"\\t");printf "%s\\n",$0} END{printf "\""}'
}
_js_s()  { printf '%s' "$1" | _js_str | sed 's/\\n"$/"/'; }          # scalar (no trailing \n)
_js_n()  { local v="${1//[^0-9.]/}"; printf '%s' "${v:-0}"; }          # number, default 0
_tsv_json() { # stdin TSV → [["a","b"],…]
    awk -F'\t' 'BEGIN{printf "["} {if(NR>1)printf ","; printf "["; for(i=1;i<=NF;i++){s=$i;gsub(/\\/,"\\\\",s);gsub(/"/,"\\\"",s);gsub(/[\001-\037]/,"",s); if(i>1)printf ","; printf "\"%s\"",s} printf "]"} END{printf "]"}'
}
_rows() { _tsv_json; }
_raw_cmd() { # _raw_cmd key command… → "key":"output"
    local k="$1"; shift; printf '%s:' "$(_js_s "$k")"; "$@" 2>&1 | head -80 | sed 's/\x1b\[[0-9;]*m//g' | _js_str
}

report_json() {
    local mt ma mc mb st sf mf temp="" z load1 load5 load15 pk="" up=""
    read -r mt ma mc mb st sf mf < <(awk '/^MemFree/{m=$2}/^MemTotal/{t=$2}/^MemAvailable/{a=$2}/^Cached/{c=$2}/^Buffers/{b=$2}/^SwapTotal/{s=$2}/^SwapFree/{f=$2}END{print t+0,a+0,c+0,b+0,s+0,f+0,m+0}' /proc/meminfo)
    read -r load1 load5 load15 _ < /proc/loadavg
    for z in /sys/class/thermal/thermal_zone*/temp; do [[ -r "$z" ]] && { local t; t=$(( $(cat "$z") / 1000 )); [[ -z "$temp" || t -gt temp ]] && temp="$t"; }; done
    if   has dpkg-query; then pk="$(dpkg-query -f '.\n' -W 2>/dev/null | wc -l)"; up="$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst')"
    elif has rpm; then pk="$(rpm -qa 2>/dev/null | wc -l)"; elif has pacman; then pk="$(pacman -Q 2>/dev/null | wc -l)"; fi
    local cpum; cpum="$(awk -F': ' '/model name|Model name|Hardware/{print $2; exit}' /proc/cpuinfo)"; [[ -z "$cpum" ]] && cpum="$(lscpu 2>/dev/null | awk -F': +' '/Model name/{print $2; exit}')"
    local booted; booted="$(uptime -s 2>/dev/null)"
    printf '{"meta":{"is_root":%s,' "$( (( EUID == 0 )) && echo true || echo false)"
    printf '"host":%s,"os":%s,"kernel":%s,"arch":%s,"user":%s,"shell":%s,"tz":%s,"virt":%s,' \
        "$(_js_s "$(hostname)")" "$(_js_s "$(distro_name)")" "$(_js_s "$(uname -r)")" "$(_js_s "$(uname -m)")" "$(_js_s "$(whoami)")" "$(_js_s "${SHELL:-bash}")" \
        "$(_js_s "$(cat /etc/timezone 2>/dev/null || date +%Z)")" "$(_js_s "$(systemd-detect-virt 2>/dev/null)")"
    printf '"uptime_s":%s,"boot":%s,"generated":%s,"lp_version":%s,' "$(_js_n "$(cut -d. -f1 /proc/uptime)")" "$(_js_s "$booted")" "$(_js_s "$(date '+%F %T %Z')")" "$(_js_s "$LP_VERSION")"
    printf '"cpu_model":%s,"cores":%s,"cpu_pct":%s,"load":[%s,%s,%s],' "$(_js_s "$cpum")" "$(_js_n "$(nproc)")" "$(_js_n "$(cpu_pct)")" "$(_js_n "$load1")" "$(_js_n "$load5")" "$(_js_n "$load15")"
    printf '"mem_total_kb":%s,"mem_avail_kb":%s,"mem_cached_kb":%s,"mem_buffers_kb":%s,"mem_free_kb":%s,"swap_total_kb":%s,"swap_free_kb":%s,' "$mt" "$ma" "$mc" "$mb" "$mf" "$st" "$sf"
    printf '"procs":%s,"users_n":%s,"svc_running":%s,"pkgs":%s,"updates":%s,"temp_c":%s},' \
        "$(_js_n "$(ps -e --no-headers 2>/dev/null | wc -l)")" "$(_js_n "$(who | wc -l)")" \
        "$(_js_n "$( { has systemctl && systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l; } || echo 0)")" \
        "$(_js_n "$pk")" "$(_js_s "$up")" "$(_js_s "$temp")"

    # health + security (quiet mode → recorded only)
    HEALTH_QUIET=1; health_run >/dev/null 2>&1; HEALTH_QUIET=""
    SEC_QUIET=1; audit_security_run >/dev/null 2>&1; SEC_QUIET=""
    printf '"health":%s,' "$(for e in "${HEALTH_LOG[@]}"; do printf '%s\t%s\n' "${e%%|*}" "${e#*|}"; done | _rows)"
    printf '"security":%s,' "$(for e in "${SEC_LOG[@]}"; do t="${e#*|}"; printf '%s\t%s\t%s\n' "${e%%|*}" "${t%%|*}" "${t#*|}"; done | _rows)"

    printf '"disks":%s,' "$(df -P -T -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null | awk 'NR>1{gsub("%","",$6);print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7}' | _rows)"
    printf '"blk":%s,' "$(lsblk -P -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null | sed -E 's/[A-Z]+="([^"]*)" ?/\1\t/g' | sed 's/\t$//' | _rows)"

    local nics="" i st mac a4 a6
    for i in /sys/class/net/*; do i="${i##*/}"; [[ "$i" == lo ]] && continue
        st="$(cat "/sys/class/net/$i/operstate" 2>/dev/null)"; [[ "$st" == unknown ]] && st=up; mac="$(cat "/sys/class/net/$i/address" 2>/dev/null)"
        a4="$(ip -o -4 addr show dev "$i" 2>/dev/null | awk '{print $4}' | paste -sd' ')"; a6="$(ip -o -6 addr show dev "$i" scope global 2>/dev/null | awk '{print $4}' | paste -sd' ')"
        nics+="$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s' "$i" "$st" "$mac" "$a4" "$a6" "$(cat "/sys/class/net/$i/statistics/rx_bytes" 2>/dev/null)" "$(cat "/sys/class/net/$i/statistics/tx_bytes" 2>/dev/null)")"$'\n'
    done
    printf '"nics":%s,' "$(printf '%s' "$nics" | sed '/^$/d' | _rows)"
    printf '"ports":%s,' "$(${SUDO[@]+"${SUDO[@]}"} ss -tulnp 2>/dev/null | awk 'NR>1{l=$5; p=l; sub(/.*:/,"",p); a=l; sub(/:[^:]*$/,"",a); gsub(/[\[\]]/,"",a); pr=""; if(match($0,/users:\(\("[^"]+"/)) pr=substr($0,RSTART+9,RLENGTH-9); print $1"\t"a"\t"p"\t"pr}' | sort -u | _rows)"

    local ps_fmt='pid,user:16,%cpu,%mem,rss,etime,comm'
    printf '"pcpu":%s,' "$(ps -eo "$ps_fmt" --no-headers --sort=-%cpu 2>/dev/null | head -12 | awk '{print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7}' | _rows)"
    printf '"pmem":%s,' "$(ps -eo "$ps_fmt" --no-headers --sort=-%mem 2>/dev/null | head -12 | awk '{print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7}' | _rows)"
    printf '"failed":%s,' "$( { has systemctl && systemctl --failed --no-legend --plain 2>/dev/null; } | awk '{d="";for(i=5;i<=NF;i++)d=d" "$i;print $1"\t"$3"/"$4"\t"d}' | _rows)"
    printf '"docker":%s,' "$( { has docker && { docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || ${SUDO[@]+"${SUDO[@]}"} docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null; }; } | _rows)"
    printf '"errors":%s,' "$( { has journalctl && ${SUDO[@]+"${SUDO[@]}"} journalctl -p err -n 25 --no-pager -o short-iso 2>/dev/null; } | grep -v '^-- ' | _rows)"
    printf '"who":%s,' "$(who | awk '{h=$NF; if(h !~ /^\(/)h=""; gsub(/[()]/,"",h); print $1"\t"$2"\t"$3" "$4"\t"h}' | _rows)"
    printf '"accounts":%s,' "$(awk -F: '$3>=1000 && $3!=65534{print $1"\t"$3"\t"$6"\t"$7}' /etc/passwd | _rows)"
    printf '"last":%s,' "$( { last -n 10 -w 2>/dev/null | grep -v -e '^$' -e 'wtmp begins'; } | _rows)"
    printf '"pci":%s,' "$( { has lspci && lspci 2>/dev/null | head -30; } | _rows)"
    printf '"usb":%s,' "$( { has lsusb && lsusb 2>/dev/null; } | _rows)"
    printf '"raw":{'
    _raw_cmd "uptime" uptime; printf ','
    _raw_cmd "free -h" free -h; printf ','
    _raw_cmd "df -hT" df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay; printf ','
    _raw_cmd "ip -br addr" ip -br addr; printf ','
    _raw_cmd "ss -tuln" ss -tuln; printf ','
    _raw_cmd "ps aux --sort=-%cpu | head" bash -c 'ps aux --sort=-%cpu | head -15'; printf ','
    _raw_cmd "lscpu" lscpu; printf ','
    _raw_cmd "uname -a" uname -a
    printf '}}\n'
}

# ───────── plain-text report ─────────
_sec() { printf '\n===== %s =====\n' "$1"; }
report_body() {
    printf '%s report — %s\nHost: %s   User: %s\n' "$LP_NAME" "$(date)" "$(hostname)" "$(whoami)"
    _sec "System";   printf 'OS: %s\nKernel: %s\nUptime: %s\n' "$(distro_name)" "$(uname -r)" "$(uptime -p 2>/dev/null)"
    _sec "CPU";      lscpu 2>/dev/null | grep -E 'Model name|^CPU\(s\)|Architecture'; echo "Load: $(cut -d' ' -f1-3 /proc/loadavg)"
    _sec "Memory";   free -h
    _sec "Disks";    df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay
    _sec "Network";  ip -br addr 2>/dev/null
    _sec "Listening ports"; ss -tuln 2>/dev/null
    _sec "Top processes"; ps -eo pid,user:12,%cpu,%mem,comm --sort=-%cpu | head -11
    _sec "Logged-in users"; who
    _sec "Failed services"; systemctl --failed --no-pager --no-legend 2>/dev/null || echo "(systemd not available)"
    HEALTH_QUIET=1; health_run >/dev/null 2>&1; HEALTH_QUIET=""
    _sec "Health checks"; printf '%s\n' "${HEALTH_LOG[@]}" | sed 's/|/  /'
    SEC_QUIET=1; audit_security_run >/dev/null 2>&1; SEC_QUIET=""
    _sec "Security audit (score $(sec_score)/100)"; printf '%s\n' "${SEC_LOG[@]}" | awk -F'|' '{printf "%-5s %s%s\n",$1,$2,($3!=""?"   -> fix: "$3:"")}'
}

report_write() { # report_write text|html
    local fmt="${1:-text}" out ts; ts="$(date +%F_%H%M%S)"
    [[ "$fmt" == text || "$fmt" == html ]] || { err "Format must be text or html."; return 1; }
    local -a SUDO=("${SUDO[@]}"); (( EUID != 0 )) && has sudo && SUDO=(sudo -n)   # never prompt for a password inside a report
    if [[ "$fmt" == text ]]; then
        out="$PWD/linuxpilot-report-${ts}.txt"; report_body 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$out"
    else
        out="$PWD/linuxpilot-report-${ts}.html"; local tpl="$LP_HOME/data/report.html" json
        [[ -f "$tpl" ]] || { err "Template missing: $tpl"; return 1; }
        root_notice; info "Collecting data (about 5 seconds)…"
        json="$(report_json | sed 's#</#<\\/#g; s/<!--/<\\!--/g')"
        local content; content="$(cat "$tpl")"
        { printf '%s' "${content%%__LP_DATA__*}"; printf '%s' "$json"; printf '%s\n' "${content#*__LP_DATA__}"; } > "$out"
    fi
    ok "Report saved: $out"; audit INFO "Report written: $out"
    [[ "$fmt" == html ]] && info "Open it in any browser:  xdg-open '$out'"
    return 0
}
rp_text() { header "Export report"; report_write text; pause; }
rp_html() { header "Export report"; report_write html; pause; }
rp_show() { header "System report"; report_body 2>&1 | pager; pause; }
report_menu() { menu "System Report" "$B" "🌐  Interactive HTML dashboard|rp_html" "📝  Plain text file|rp_text" "👀  Show on screen|rp_show"; }
register_module "📄  System Report (HTML dashboard / txt)" report_menu
