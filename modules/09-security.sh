# shellcheck shell=bash
# Security & firewall (defensive tools only)

fw_detect() { if has ufw; then echo ufw; elif has firewall-cmd; then echo firewalld; elif has nft; then echo nft; else echo none; fi; }
_fw_need() { FW="$(fw_detect)"; [[ "$FW" == ufw || "$FW" == firewalld ]] || { err "Supported firewalls: ufw, firewalld. Install one (e.g. apt install ufw)."; return 1; }; }

sec_fw_status() {
    header "Firewall status"; FW="$(fw_detect)"; info "Detected: $FW"; echo
    case "$FW" in
        ufw) run_root "ufw status" ufw status verbose ;;
        firewalld) run_root "firewalld state" firewall-cmd --list-all ;;
        nft) run_root "nft ruleset" nft list ruleset | head -60 ;;
        *) warn "No firewall tool found." ;;
    esac; pause
}
sec_fw_toggle() {
    header "Enable / disable firewall"; _fw_need || { pause; return; }
    echo "  1) enable   2) disable"; local c; ask c "Choice:"
    case "$FW:$c" in
        ufw:1) warn "Make sure SSH is allowed first or you may lock yourself out of a remote server!"
               confirm "Allow SSH (22/tcp) before enabling?" && run_root "Allow SSH" ufw allow 22/tcp
               confirm "Enable ufw?" && run_root "Enable ufw" ufw --force enable ;;
        ufw:2) confirm_danger "The firewall will be switched OFF." && run_root "Disable ufw" ufw disable ;;
        firewalld:1) run_root "Start firewalld" systemctl enable --now firewalld ;;
        firewalld:2) confirm_danger "firewalld will be stopped." && run_root "Stop firewalld" systemctl disable --now firewalld ;;
        *) err "Invalid." ;;
    esac; pause
}
_fw_rule() { # _fw_rule allow|deny
    header "Firewall: $1 a port"; _fw_need || { pause; return; }
    local p proto; ask p "Port (e.g. 80):"; valid_port "$p" || { pause; return; }; ask proto "Protocol (tcp/udp):" tcp
    [[ "$proto" == tcp || "$proto" == udp ]] || { err "tcp or udp."; pause; return; }
    case "$FW:$1" in
        ufw:allow) run_root "Allow $p/$proto" ufw allow "$p/$proto" ;;
        ufw:deny)  run_root "Deny $p/$proto" ufw deny "$p/$proto" ;;
        firewalld:allow) run_root "Open $p/$proto" firewall-cmd --permanent --add-port="$p/$proto" && run_root "Reload" firewall-cmd --reload ;;
        firewalld:deny)  run_root "Close $p/$proto" firewall-cmd --permanent --remove-port="$p/$proto" && run_root "Reload" firewall-cmd --reload ;;
    esac; pause
}
sec_allow() { _fw_rule allow; }
sec_deny()  { _fw_rule deny; }
sec_fw_reset() {
    header "Reset firewall"; _fw_need || { pause; return; }
    [[ "$FW" == ufw ]] || { warn "Reset is only implemented for ufw."; pause; return; }
    confirm_danger "ALL ufw rules will be deleted." && run_root "Reset ufw" ufw --force reset; pause
}
sec_failed() {
    header "Failed login attempts"; explain "Many failures from one IP usually means an automated password-guessing bot."
    if has journalctl; then ${SUDO[@]+"${SUDO[@]}"} journalctl -q _COMM=sshd --since "7 days ago" 2>/dev/null | grep -i "failed password" | tail -25 | sed 's/^/  /'; fi
    [[ -r /var/log/auth.log ]] && grep -i "failed password" /var/log/auth.log | tail -15 | sed 's/^/  /'
    echo; info "Top offending IPs (last 7 days):"
    ${SUDO[@]+"${SUDO[@]}"} journalctl -q _COMM=sshd --since "7 days ago" 2>/dev/null | grep -i "failed password" | grep -oE 'from [0-9a-fA-F.:]+' | sort | uniq -c | sort -rn | head -5 | sed 's/^/  /'
    echo; info "lastb (bad logins):"; ${SUDO[@]+"${SUDO[@]}"} lastb -n 8 2>/dev/null | sed 's/^/  /'; pause
}
sec_sudo_log() { header "Sudo activity"; ${SUDO[@]+"${SUDO[@]}"} journalctl -q _COMM=sudo -n 25 --no-pager 2>/dev/null | sed 's/^/  /'; [[ -r /var/log/auth.log ]] && grep sudo /var/log/auth.log | tail -15 | sed 's/^/  /'; pause; }
sec_ssh_cfg() {
    header "SSH server configuration"; local cfg=/etc/ssh/sshd_config
    [[ -r $cfg ]] || { warn "No sshd_config here (SSH server not installed?)."; pause; return; }
    grep -E '^\s*(Port|PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|X11Forwarding|MaxAuthTries|AllowUsers)\b' "$cfg" | sed 's/^/  /'
    echo; explain "Good practice: PermitRootLogin no, PasswordAuthentication no (keys only), and a non-default Port is optional."
    pause
}
sec_last() { header "Last logins"; last -n 20 | sed 's/^/  /'; pause; }
sec_suid() { header "SUID/SGID binaries"; explain "SUID programs run with their owner's rights (often root). Unexpected ones are a classic sign of compromise."; find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | head -40 | sed 's/^/  /'; pause; }
sec_f2b() { header "Fail2ban"; if has fail2ban-client; then run_root "fail2ban status" fail2ban-client status; else warn "fail2ban is not installed. It automatically bans IPs that fail logins repeatedly."; fi; pause; }

sec_audit() { audit_security_screen; }   # implemented in 19-audit.sh

security_menu() {
    menu "Security & Firewall  🔰" "$R" \
        "✅  Quick security audit (read-only)|sec_audit" "🧱  Firewall status|sec_fw_status" "🔛  Enable / disable firewall|sec_fw_toggle" \
        "🟢  Allow a port|sec_allow" "🔴  Block a port|sec_deny" "💣  Reset firewall (ufw)|sec_fw_reset" \
        "🚫  Failed login attempts|sec_failed" "🧾  Sudo activity|sec_sudo_log" "🔐  SSH server settings|sec_ssh_cfg" \
        "🕓  Last logins|sec_last" "🚧  SUID / SGID files|sec_suid" "🥾  Fail2ban status|sec_f2b"
}
register_module "🔰  Security & Firewall" security_menu root
