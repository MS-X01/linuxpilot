# shellcheck shell=bash
# Audit & Compliance — security audit with score, change detection (baseline diff),
# LinuxPilot activity log, and auditd helpers.

BASE_DIR="$STATE_DIR/baseline"
SEC_LOG=(); SEC_QUIET=""

# ─────────────────────────── 1. SECURITY AUDIT ───────────────────────────
# result format: "level|title|hint"   level = ok | warn | bad
_sec_rec() {
    SEC_LOG+=("$1|$2|${3:-}")
    [[ -n "$SEC_QUIET" ]] && return 0
    case "$1" in ok) ok "$2" ;; warn) warn "$2" ;; bad) err "$2" ;; esac
    [[ "$1" != ok && -n "${3:-}" ]] && printf '       %s↳ fix: %s%s\n' "$DIM" "$3" "$RST"
    return 0
}
_sshd_val() { # effective value of an sshd option (lower-case), '' if unknown
    local k="$1" v=""
    v="$(${SUDO[@]+"${SUDO[@]}"} sshd -T 2>/dev/null | awk -v k="${k,,}" '$1==k{print $2; exit}')"
    [[ -z "$v" && -r /etc/ssh/sshd_config ]] && v="$(grep -iE "^\s*$k\s" /etc/ssh/sshd_config 2>/dev/null | head -1 | awk '{print tolower($2)}')"
    printf '%s' "$v"
}
sec_score() { # prints 0-100
    local bad=0 w=0 e; for e in "${SEC_LOG[@]}"; do case "${e%%|*}" in bad) bad=$((bad+1)) ;; warn) w=$((w+1)) ;; esac; done
    local s=$(( 100 - bad*15 - w*5 )); (( s < 0 )) && s=0; echo "$s"
}
audit_security_run() {
    SEC_LOG=(); local v p
    # — network exposure —
    case "$(fw_detect)" in
        ufw) ${SUDO[@]+"${SUDO[@]}"} ufw status 2>/dev/null | grep -q "Status: active" && _sec_rec ok "Firewall (ufw) is active" || _sec_rec warn "Firewall (ufw) is not active, or could not be checked" "sudo ufw allow 22/tcp && sudo ufw enable" ;;
        firewalld) systemctl is-active --quiet firewalld && _sec_rec ok "Firewall (firewalld) is active" || _sec_rec warn "firewalld is not running" "sudo systemctl enable --now firewalld" ;;
        nft) _sec_rec warn "Only raw nftables found — verify rules manually" "sudo nft list ruleset" ;;
        *) _sec_rec warn "No firewall installed" "install ufw (Debian/Ubuntu) or firewalld (Fedora/RHEL)" ;;
    esac
    local ex; ex="$(ss -tuln 2>/dev/null | awk 'NR>1 && ($5 ~ /^0\.0\.0\.0:/ || $5 ~ /^\[::\]:/ || $5 ~ /^\*:/)' | wc -l)"
    (( ex > 6 )) && _sec_rec warn "$ex sockets listen on ALL interfaces" "review: Network → Listening ports; bind internal services to 127.0.0.1" || _sec_rec ok "$ex socket(s) listen on all interfaces"
    # — SSH —
    if [[ -r /etc/ssh/sshd_config ]] || has sshd; then
        v="$(_sshd_val PermitRootLogin)"; [[ "$v" == yes ]] && _sec_rec bad "SSH allows direct root login" "set 'PermitRootLogin no' in /etc/ssh/sshd_config, then restart ssh" || _sec_rec ok "SSH root login is not enabled (${v:-default})"
        v="$(_sshd_val PasswordAuthentication)"; [[ "$v" == no ]] && _sec_rec ok "SSH password login disabled (keys only)" || _sec_rec warn "SSH password authentication is enabled" "create a key (SSH menu), then set 'PasswordAuthentication no'"
        v="$(_sshd_val PermitEmptyPasswords)"; [[ "$v" == yes ]] && _sec_rec bad "SSH permits EMPTY passwords" "set 'PermitEmptyPasswords no'"
    fi
    # — accounts —
    v="$(awk -F: '$3==0 && $1!="root"{print $1}' /etc/passwd)"; [[ -n "$v" ]] && _sec_rec bad "Extra UID-0 (root-equivalent) accounts: $v" "investigate and remove: sudo userdel NAME" || _sec_rec ok "Only root has UID 0"
    v="$(${SUDO[@]+"${SUDO[@]}"} awk -F: '$2=="" {print $1}' /etc/shadow 2>/dev/null | paste -sd' ')"
    [[ -n "$v" ]] && _sec_rec bad "Accounts with EMPTY password: $v" "sudo passwd NAME  (or lock: sudo usermod -L NAME)" || _sec_rec ok "No accounts with empty passwords"
    v="$(${SUDO[@]+"${SUDO[@]}"} grep -rhE '^[^#].*NOPASSWD' /etc/sudoers /etc/sudoers.d 2>/dev/null | head -1)"
    [[ -n "$v" ]] && _sec_rec warn "sudo rules with NOPASSWD exist" "review with: sudo visudo" || _sec_rec ok "No NOPASSWD sudo rules"
    v="$(getent group sudo wheel admin 2>/dev/null | awk -F: '{print $4}' | tr ',' '\n' | sort -u | paste -sd' ')"
    _sec_rec ok "Admin group members: ${v:-none}"
    # — files —
    p="$(stat -c %a /etc/shadow 2>/dev/null)"; [[ -n "$p" ]] && { (( 8#$p <= 8#640 )) && _sec_rec ok "/etc/shadow permissions OK ($p)" || _sec_rec bad "/etc/shadow is too open ($p)" "sudo chmod 640 /etc/shadow"; }
    p="$(stat -c %a /etc/passwd 2>/dev/null)"; [[ -n "$p" ]] && { (( (8#$p & 2) == 0 )) && _sec_rec ok "/etc/passwd not world-writable ($p)" || _sec_rec bad "/etc/passwd is world-writable ($p)" "sudo chmod 644 /etc/passwd"; }
    v="$(find /etc -xdev -type f -perm -0002 2>/dev/null | head -3 | paste -sd' ')"; [[ -n "$v" ]] && _sec_rec bad "World-writable files in /etc: $v" "chmod o-w FILE" || _sec_rec ok "No world-writable files in /etc"
    v="$(find /home -maxdepth 1 -mindepth 1 -type d -perm -0007 2>/dev/null | head -3 | paste -sd' ')"; [[ -n "$v" ]] && _sec_rec warn "World-accessible home directories: $v" "chmod 750 DIR"
    # — kernel & mandatory access control —
    [[ "$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null)" == 2 ]] && _sec_rec ok "ASLR fully enabled" || _sec_rec warn "ASLR is not fully enabled" "sudo sysctl -w kernel.randomize_va_space=2"
    [[ "$(cat /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null)" == 1 ]] && _sec_rec ok "TCP SYN cookies enabled" || _sec_rec warn "TCP SYN cookies disabled" "sudo sysctl -w net.ipv4.tcp_syncookies=1"
    if has getenforce; then [[ "$(getenforce 2>/dev/null)" == Enforcing ]] && _sec_rec ok "SELinux is enforcing" || _sec_rec warn "SELinux is not enforcing" "sudo setenforce 1  (and set SELINUX=enforcing)"
    elif has aa-status && ${SUDO[@]+"${SUDO[@]}"} aa-status --enabled 2>/dev/null; then _sec_rec ok "AppArmor is enabled"
    else _sec_rec warn "No SELinux/AppArmor mandatory access control detected" "enable the one your distro ships"; fi
    # — maintenance —
    has fail2ban-client && _sec_rec ok "fail2ban is installed" || _sec_rec warn "fail2ban not installed (blocks brute-force logins)" "sudo apt install fail2ban"
    if dpkg -s unattended-upgrades &>/dev/null || rpm -q dnf-automatic &>/dev/null; then _sec_rec ok "Automatic security updates configured"
    else _sec_rec warn "No automatic update tool found" "sudo apt install unattended-upgrades (Debian) or dnf-automatic (RHEL)"; fi
    if has apt-get; then v="$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst.*[Ss]ecurity')"; (( v > 0 )) && _sec_rec warn "$v pending SECURITY update(s)" "sudo apt update && sudo apt upgrade"; fi
    [[ -f /var/run/reboot-required ]] && _sec_rec warn "Reboot required to finish updates" "sudo reboot"
    if has timedatectl && [[ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null)" == no ]]; then _sec_rec warn "Clock not synchronised (breaks logs/TLS)" "sudo timedatectl set-ntp true"; fi
}
audit_security() { audit_security_run; }
audit_security_screen() {
    header "Security Audit  🔰"; explain "Read-only checks of common weak spots. Nothing is changed. Every finding includes how to fix it."
    audit_security_run; local sc; sc="$(sec_score)"
    echo; hr; printf '  Security score  '; bar "$sc"; echo; hr
    if (( sc >= 90 )); then ok "Solid baseline."; elif (( sc >= 70 )); then warn "Decent, but fix the warnings."; else err "Needs attention — start with the red items."; fi
    audit INFO "Security audit run (score $sc)"; pause
}
au_sec_export() {
    header "Export security audit"; SEC_QUIET=1; audit_security_run; SEC_QUIET=""
    local out="$PWD/linuxpilot-security-audit-$(date +%F_%H%M%S).md" e lv t h icon
    {   printf '# Security audit — %s\n\n- Date: %s\n- Score: **%s / 100**\n- Tool: %s v%s\n\n| Status | Finding | How to fix |\n|---|---|---|\n' "$(hostname)" "$(date)" "$(sec_score)" "$LP_NAME" "$LP_VERSION"
        for e in "${SEC_LOG[@]}"; do lv="${e%%|*}"; t="${e#*|}"; h="${t#*|}"; t="${t%%|*}"
            case "$lv" in ok) icon="✅ OK" ;; warn) icon="🚧  Warning" ;; *) icon="❌ Problem" ;; esac
            printf '| %s | %s | %s |\n' "$icon" "${t//|/\\|}" "${h//|/\\|}"; done
    } > "$out"; ok "Saved: $out"; audit INFO "Security audit exported: $out"; pause
}

# ─────────────────────────── 2. CHANGE DETECTION ───────────────────────────
_collect_state() { # _collect_state DIR
    local d="$1" f; mkdir -p "$d"
    ss -tuln 2>/dev/null | awk 'NR>1{print $1, $5}' | sort -u > "$d/listening-ports.txt"
    awk -F: '{print $1":"$3":"$7}' /etc/passwd | sort > "$d/accounts.txt"
    getent group sudo wheel admin docker 2>/dev/null | sort > "$d/privileged-groups.txt"
    if [[ -n "${LP_FAST:-}" ]]; then : > "$d/suid-sgid-files.txt"   # tests skip the slow whole-disk scan
    else timeout 180 find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | sort > "$d/suid-sgid-files.txt"; fi
    has systemctl && systemctl list-unit-files --type=service --state=enabled --no-legend 2>/dev/null | awk '{print $1}' | sort > "$d/enabled-services.txt"
    for f in /etc/passwd /etc/group /etc/shadow /etc/sudoers /etc/ssh/sshd_config /etc/hosts /etc/fstab /etc/crontab; do
        [[ -e "$f" ]] && ${SUDO[@]+"${SUDO[@]}"} sha256sum "$f" 2>/dev/null
    done | awk '{print $2"  "substr($1,1,12)}' > "$d/config-hashes.txt"
    { ${SUDO[@]+"${SUDO[@]}"} find /home /root -maxdepth 3 -name authorized_keys -exec sha256sum {} + 2>/dev/null
      ${SUDO[@]+"${SUDO[@]}"} find /etc/cron.d /var/spool/cron -type f -exec sha256sum {} + 2>/dev/null; } | awk '{print $2"  "substr($1,1,12)}' | sort > "$d/ssh-keys-and-cron.txt"
    if has dpkg-query; then dpkg-query -W -f='${Package} ${Version}\n' 2>/dev/null | sort
    elif has rpm; then rpm -qa | sort; elif has pacman; then pacman -Q | sort; fi > "$d/installed-packages.txt"
}
au_base_save() {
    header "Save baseline snapshot  📸"; explain "Records ports, accounts, SUID files, services, key configs and packages so you can later see exactly what changed."
    [[ -d "$BASE_DIR/data" ]] && ! confirm "A baseline from $(cat "$BASE_DIR/when" 2>/dev/null) exists. Replace it?" && return
    info "Collecting (the SUID scan can take a little while)…"
    rm -rf "$BASE_DIR"; mkdir -p "$BASE_DIR"; _collect_state "$BASE_DIR/data"; date '+%F %T' > "$BASE_DIR/when"
    ok "Baseline saved ($(ls "$BASE_DIR/data" | wc -l) datasets) → $BASE_DIR"; audit INFO "Baseline snapshot saved"; pause
}
au_base_diff() {
    header "What changed since the baseline?  🔍"
    [[ -d "$BASE_DIR/data" ]] || { warn "No baseline yet. Create one first (Save baseline snapshot)."; pause; return; }
    info "Baseline taken: $(cat "$BASE_DIR/when")"; local cur; cur="$(mktemp -d)"; _collect_state "$cur"
    local f name total=0 n; echo
    for f in "$BASE_DIR"/data/*.txt; do
        name="$(basename "$f" .txt)"; [[ -f "$cur/$name.txt" ]] || continue
        if diff -q "$f" "$cur/$name.txt" >/dev/null; then ok "$name — unchanged"
        else
            n="$(diff "$f" "$cur/$name.txt" | grep -c '^[<>]')"; total=$((total+n)); warn "$name — $n change(s)"
            diff "$f" "$cur/$name.txt" | grep '^[<>]' | head -15 | while IFS= read -r l; do
                case "$l" in '>'*) printf '       %s+ %s%s\n' "$G" "${l#> }" "$RST" ;; *) printf '       %s- %s%s\n' "$R" "${l#< }" "$RST" ;; esac; done
        fi
    done
    rm -rf "$cur"; echo; hr
    (( total == 0 )) && ok "System matches the baseline." || warn "$total difference(s). Expected (you installed/changed something)? If yes, save a new baseline."
    audit INFO "Baseline compared: $total difference(s)"; pause
}

# ─────────────────────────── 3. ACTIVITY LOG ───────────────────────────
au_last()   { header "Last 40 actions"; tail -n 40 "$LOG_FILE" 2>/dev/null | sed 's/^/  /'; pause; }
au_errors() { header "Errors & warnings"; grep -E '\[(ERROR|WARN)\]' "$LOG_FILE" 2>/dev/null | tail -40 | sed 's/^/  /'; pause; }
au_search() { header "Search activity log"; local t; ask t "Text:"; need "$t" Text && grep -iF -- "$t" "$LOG_FILE" | tail -50 | sed 's/^/  /'; pause; }
au_filter() {
    header "Filter activity log"; local lv us dt
    ask lv "Level (INFO / WARN / ERROR / DRYRUN, blank = any):"; ask us "User (blank = any):"; ask dt "Date prefix (2026-11 or 2026-11-03, blank = any):"
    lv="${lv^^}"; [[ -z "$lv" || "$lv" =~ ^(INFO|WARN|ERROR|DRYRUN)$ ]] || { err "Unknown level."; pause; return; }
    [[ -z "$us" || "$us" =~ ^[A-Za-z0-9._-]+$ ]] || { err "Invalid user."; pause; return; }
    [[ -z "$dt" || "$dt" =~ ^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$ ]] || { err "Use YYYY, YYYY-MM or YYYY-MM-DD."; pause; return; }
    awk -v lv="$lv" -v us="$us" -v dt="$dt" '{ok=1; if(lv!="" && index($0,"["lv"]")==0) ok=0; if(us!="" && index($0,"["us"]")==0) ok=0; if(dt!="" && index($0,"["dt)!=1) ok=0; if(ok) print}' "$LOG_FILE" | tail -100 | sed 's/^/  /' | pager; pause
}
au_stats() {
    header "Activity statistics  📈"; [[ -s "$LOG_FILE" ]] || { info "Log is empty."; pause; return; }
    info "By level:"; grep -E '^\[' "$LOG_FILE" | awk '{l=$3; gsub(/[][]/,"",l); c[l]++} END{for(k in c) printf "    %-8s %d\n",k,c[k]}' | sort
    echo; info "Last 7 days:"; grep -E '^\[' "$LOG_FILE" | awk '{d=substr($1,2); c[d]++} END{for(k in c) print k, c[k]}' | sort | tail -7 | awk '{printf "    %s  %s %s\n",$1,$2,"█"}' 
    echo; info "Most frequent actions:"; grep -E '^\[' "$LOG_FILE" | awk '{print $5" "$6}' | sort | uniq -c | sort -rn | head -8 | sed 's/^/   /'
    echo; info "Sessions started: $(grep -c 'Session started' "$LOG_FILE")"; pause
}
au_export() {
    header "Export activity log"; echo "  1) CSV (Excel-ready)   2) plain text copy"; local c out; ask c "Format:" 1
    case "$c" in
        1) out="$PWD/linuxpilot-audit-$(date +%F).csv"
           sed -E 's/^\[([^]]*)\] \[([^]]*)\] \[([^]]*)\] (.*)$/\1\t\2\t\3\t\4/' "$LOG_FILE" | awk -F'\t' 'BEGIN{print "time,level,user,message"} NF>=4{gsub(/"/,"\"\"",$4); printf "%s,%s,%s,\"%s\"\n",$1,$2,$3,$4}' > "$out" ;;
        2) out="$PWD/linuxpilot-audit-$(date +%F).log"; cp "$LOG_FILE" "$out" ;;
        *) err "Invalid."; pause; return ;;
    esac; ok "Saved: $out"; pause
}
au_info() {
    header "Log info & integrity"; printf '  File:  %s\n  Size:  %s\n  Lines: %s\n' "$LOG_FILE" "$(du -h "$LOG_FILE" | cut -f1)" "$(wc -l < "$LOG_FILE")"
    local p; p="$(stat -c %a "$LOG_FILE")"; printf '  Mode:  %s\n' "$p"
    if [[ "$p" != 600 ]]; then warn "Log is readable by others — it records every command you run."; confirm "chmod 600?" && chmod 600 "$LOG_FILE" && ok "Fixed."; else ok "Permissions are private (600)."; fi
    [[ -f "$LOG_FILE.1" ]] && info "Rotated copy: $LOG_FILE.1 ($(du -h "$LOG_FILE.1" | cut -f1))"; pause
}
au_clear() { header "Clear activity log"; confirm_danger "The whole audit history will be erased." && { : > "$LOG_FILE"; ok "Cleared."; }; pause; }

# ─────────────────────────── 4. auditd (kernel audit framework) ───────────────────────────
AUDITD_RULES='-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
-w /etc/ssh/sshd_config -p wa -k sshd
-w /var/log/lastlog -p wa -k logins
-w /etc/cron.d/ -p wa -k cron'
ad_status() { header "auditd status"; req auditctl "auditd (Debian) / audit (RHEL, Arch)" || { pause; return; }; systemctl is-active auditd 2>/dev/null | sed 's/^/  service: /'; run_root "Audit status" auditctl -s; pause; }
ad_rules()  { header "Active audit rules"; req auditctl auditd || { pause; return; }; run_root "List rules" auditctl -l; pause; }
ad_sum()    { header "Audit summary"; req aureport auditd || { pause; return; }; run_root "Summary report" aureport --summary; echo; run_root "Authentication report" aureport -au --summary; pause; }
ad_logins() { header "Logins today"; req ausearch auditd || { pause; return; }; run_root "Login events" ausearch -m USER_LOGIN -ts today -i; pause; }
ad_sample() {
    header "Install sample watch rules"; req auditctl auditd || { pause; return; }; explain "Watches identity files, sudoers, sshd_config and cron; each change is logged with who did it (key names: identity, sudoers…)."
    printf '%s\n' "$AUDITD_RULES" | sed 's/^/    /'; confirm "Write /etc/audit/rules.d/linuxpilot.rules and load it?" || return
    if [[ "$DRY_RUN" == true ]]; then warn "Dry-run: nothing written."; pause; return; fi
    printf '%s\n' "$AUDITD_RULES" | run_root "Write rules file" tee /etc/audit/rules.d/linuxpilot.rules >/dev/null && run_root "Load rules" augenrules --load; pause
}
auditd_menu() { menu "auditd — kernel audit framework" "$B" "📇  Status|ad_status" "📜  Active rules|ad_rules" "📊  Summary report|ad_sum" "🔐  Logins today|ad_logins" "🧰  Install sample watch rules|ad_sample"; }

# ─────────────────────────── menus ───────────────────────────
audit_sec_menu()    { menu "Security Audit" "$R" "🔰  Run audit (score + how to fix)|audit_security_screen" "📤  Export as Markdown report|au_sec_export"; }
audit_change_menu() { menu "Change Detection" "$Y" "📸  Save baseline snapshot|au_base_save" "🔍  Compare with baseline (what changed?)|au_base_diff"; }
audit_log_menu()    { menu "LinuxPilot Activity Log" "$C" "🕓  Recent actions|au_last" "🚨  Errors & warnings|au_errors" "🔬  Filter (level / user / date)|au_filter" "🔎  Search|au_search" "📈  Statistics|au_stats" "📤  Export (CSV / text)|au_export" "🔒  Info & integrity|au_info" "🧹  Clear log|au_clear"; }
audit_menu() {
    menu "Audit & Compliance  📑" "$M" \
        "🔰  Security audit — score & fixes|audit_sec_menu" \
        "🔍  Change detection — baseline & diff|audit_change_menu" \
        "🧾  Activity log — everything LinuxPilot did|audit_log_menu" \
        "🧪  auditd — kernel-level auditing|auditd_menu"
}
register_module "📑  Audit & Compliance" audit_menu
