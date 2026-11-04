# shellcheck shell=bash
# Health module — one-screen "doctor" for the whole machine

HEALTH_ERR=0; HEALTH_WARN=0; HEALTH_LOG=(); HEALTH_QUIET=""
# every result is recorded as "level|text" (used by the HTML report) and printed unless HEALTH_QUIET is set
_h_ok()   { HEALTH_LOG+=("ok|$1");   [[ -n "$HEALTH_QUIET" ]] || ok "$1"; }
_h_warn() { HEALTH_LOG+=("warn|$1"); [[ -n "$HEALTH_QUIET" ]] || warn "$1"; HEALTH_WARN=$((HEALTH_WARN+1)); }
_h_err()  { HEALTH_LOG+=("err|$1");  [[ -n "$HEALTH_QUIET" ]] || err "$1";  HEALTH_ERR=$((HEALTH_ERR+1)); }

cpu_pct() { # sample /proc/stat for 0.4s
    local _ u1 n1 s1 i1 w1 q1 z1 u2 n2 s2 i2 w2 q2 z2 t1 t2
    read -r _ u1 n1 s1 i1 w1 q1 z1 _ < /proc/stat; sleep 0.4
    read -r _ u2 n2 s2 i2 w2 q2 z2 _ < /proc/stat
    t1=$((u1+n1+s1+i1+w1+q1+z1)); t2=$((u2+n2+s2+i2+w2+q2+z2))
    local dt=$((t2-t1)) di=$(( (i2+w2)-(i1+w1) ))
    (( dt > 0 )) && echo $(( (dt-di)*100/dt )) || echo 0
}
mem_pct()  { free -m | awk '/^Mem:/{ if ($2>0) printf "%d", ($2-$7)*100/$2; else print 0 }'; }
swap_pct() { free -m | awk '/^Swap:/{ if ($2>0) printf "%d", $3*100/$2; else print 0 }'; }

health_run() {
    HEALTH_ERR=0; HEALTH_WARN=0; HEALTH_LOG=()
    local pct line cores load
    # disks
    while read -r pct line; do
        pct="${pct%\%}"
        if   (( pct >= 95 )); then _h_err  "Disk $line is ${pct}% full"
        elif (( pct >= 85 )); then _h_warn "Disk $line is ${pct}% full"
        else _h_ok "Disk $line: ${pct}% used"; fi
    done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null | awk 'NR>1{print $5, $6}')
    # inodes
    while read -r pct line; do
        pct="${pct%\%}"; [[ "$pct" =~ ^[0-9]+$ ]] || continue
        (( pct >= 90 )) && _h_warn "Inodes on $line at ${pct}% (too many small files)"
    done < <(df -Pi -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | awk 'NR>1{print $5, $6}')
    # memory / swap
    pct="$(mem_pct)"; if (( pct >= 90 )); then _h_warn "Memory in use: ${pct}%"; else _h_ok "Memory in use: ${pct}%"; fi
    pct="$(swap_pct)"; (( pct >= 50 )) && _h_warn "Swap in use: ${pct}% (system is short on RAM)"
    # load
    cores="$(nproc 2>/dev/null || echo 1)"; read -r load _ < /proc/loadavg
    if awk -v l="$load" -v c="$cores" 'BEGIN{exit !(l > c*1.5)}'; then _h_warn "Load average $load is high for $cores core(s)"
    else _h_ok "Load average $load ($cores core(s))"; fi
    # services
    if has systemctl && [[ -d /run/systemd/system ]]; then
        local failed; failed="$(systemctl --failed --no-legend 2>/dev/null | wc -l)"
        if (( failed > 0 )); then _h_err "$failed failed systemd unit(s) — see Services → Failed units"; else _h_ok "No failed services"; fi
        local sync; sync="$(timedatectl show -p NTPSynchronized --value 2>/dev/null)"
        [[ "$sync" == no ]] && _h_warn "Clock is not synchronized (NTP)"
    fi
    # zombies, reboot, updates
    local z; z="$(ps -eo stat= | grep -c '^Z')"; (( z > 0 )) && _h_warn "$z zombie process(es)"
    [[ -f /var/run/reboot-required ]] && _h_warn "A reboot is required (kernel/library update)"
    if has apt-get; then
        local up; up="$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst')"
        (( up > 0 )) && _h_warn "$up package update(s) available (apt)"
    fi
    local days; days=$(( $(cut -d. -f1 /proc/uptime) / 86400 ))
    (( days > 90 )) && _h_warn "Up for $days days — consider a reboot after updates" || _h_ok "Uptime: $days day(s)"
    [[ -n "$HEALTH_QUIET" ]] && return $(( HEALTH_ERR > 0 ))
    echo
    if (( HEALTH_ERR > 0 )); then err "Result: $HEALTH_ERR problem(s), $HEALTH_WARN warning(s)"; return 1
    elif (( HEALTH_WARN > 0 )); then warn "Result: healthy, but $HEALTH_WARN warning(s)"; return 0
    else ok "Result: everything looks healthy ✨"; return 0; fi
}

health_screen() { header "System Health Check  🩺"; explain "Reads disks, memory, load, services and updates — changes nothing."; health_run; pause; }
register_module "🩺  Health Check  — is my system OK? (one screen)" health_screen
