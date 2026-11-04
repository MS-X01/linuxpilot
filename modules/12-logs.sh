# shellcheck shell=bash
# Log viewer

_log_file() { # first readable candidate
    local f; for f in "$@"; do [[ -r "$f" ]] && { echo "$f"; return 0; }; done
    for f in "$@"; do ${SUDO[@]+"${SUDO[@]}"} test -r "$f" 2>/dev/null && { echo "$f"; return 0; }; done; return 1
}
lg_show() { # lg_show "Title" file...
    local t="$1"; shift; header "$t"; local f; f="$(_log_file "$@")" || { warn "No such log here — try the Journal (systemd) entries."; pause; return; }
    info "$f (last 100 lines)"; ${SUDO[@]+"${SUDO[@]}"} tail -n 100 "$f" | pager; pause
}
lg_syslog() { lg_show "System log" /var/log/syslog /var/log/messages; }
lg_auth()   { lg_show "Authentication log" /var/log/auth.log /var/log/secure; }
lg_kern()   { lg_show "Kernel log file" /var/log/kern.log; }
lg_dmesg()  { header "Kernel ring buffer (dmesg)"; (dmesg --color=always 2>/dev/null || ${SUDO[@]+"${SUDO[@]}"} dmesg 2>/dev/null) | tail -80 | pager; pause; }
lg_journal() {
    header "Systemd journal"; has journalctl || { warn "No systemd journal."; pause; return; }
    echo "  1) last 100 lines   2) errors only (this boot)   3) one service   4) since a time"
    local c u t; ask c "Choice:" 1
    case "$c" in
        1) ${SUDO[@]+"${SUDO[@]}"} journalctl -n 100 --no-pager | pager ;;
        2) ${SUDO[@]+"${SUDO[@]}"} journalctl -p err -b --no-pager | pager ;;
        3) ask u "Unit (e.g. ssh, nginx):"; valid_unit "$u" && ${SUDO[@]+"${SUDO[@]}"} journalctl -u "$u" -n 100 --no-pager | pager ;;
        4) ask t "Since (e.g. '1 hour ago', 'yesterday', '2026-11-01'):"; [[ "$t" =~ ^[A-Za-z0-9\ :.-]+$ ]] && ${SUDO[@]+"${SUDO[@]}"} journalctl --since "$t" --no-pager | pager || err "Invalid time text." ;;
        *) err "Invalid." ;;
    esac; pause
}
lg_boot()   { header "Boot history"; has journalctl && ${SUDO[@]+"${SUDO[@]}"} journalctl --list-boots | tail -10 | sed 's/^/  /'; echo; last -x reboot shutdown -n 6 2>/dev/null | sed 's/^/  /'; pause; }
lg_search() {
    header "Search logs"; local t; ask t "Text to find:"; need "$t" Text || { pause; return; }
    if has journalctl; then ${SUDO[@]+"${SUDO[@]}"} journalctl --no-pager -g "$t" -n 100 2>/dev/null | pager
    else ${SUDO[@]+"${SUDO[@]}"} grep -rIF --color=always -- "$t" /var/log 2>/dev/null | head -100 | pager; fi; pause
}
lg_follow() {
    header "Follow a log live"; info "Press Ctrl+C to stop following."; local f; ask_path f "Log file:" "/var/log/syslog"
    [[ -e "$f" ]] || { err "Not found."; pause; return; }
    trap ':' INT; ${SUDO[@]+"${SUDO[@]}"} tail -n 20 -f "$f"; trap 'printf "\n"; warn "Interrupted — press 0 to go back or q to quit."' INT; echo; pause
}
lg_size() { header "Log disk usage"; ${SUDO[@]+"${SUDO[@]}"} du -sh /var/log 2>/dev/null | sed 's/^/  /'; has journalctl && journalctl --disk-usage 2>/dev/null | sed 's/^/  /'
    ${SUDO[@]+"${SUDO[@]}"} du -ah /var/log 2>/dev/null | sort -rh | head -8 | sed 's/^/  /'
    has journalctl && confirm "Shrink the journal to 200 MB?" && run_root "Vacuum journal" journalctl --vacuum-size=200M; pause; }

logs_menu() {
    menu "System Logs" "$Y" "📜  System log|lg_syslog" "🔐  Authentication log|lg_auth" "🧬  Kernel log|lg_kern" "🧠  dmesg|lg_dmesg" "📔  Systemd journal|lg_journal" \
        "🥾  Boot history|lg_boot" "🔎  Search logs|lg_search" "📡  Follow a log live|lg_follow" "📏  Log size & cleanup|lg_size"
}
register_module "📋  System Logs" logs_menu
