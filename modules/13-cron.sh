# shellcheck shell=bash
# Cron manager

cr_list() { header "Your crontab"; req crontab "cron / cronie" || { pause; return; }; crontab -l 2>/dev/null | sed 's/^/  /' || true; crontab -l &>/dev/null || info "(empty)"; pause; }
cr_add() {
    header "Add cron job"; req crontab "cron / cronie" || { pause; return; }; explain "A cron line is: minute hour day-of-month month day-of-week command."
    echo "  1) every minute   2) every hour   3) daily at a time   4) weekly   5) monthly   6) at reboot   7) custom"
    local c sched hh mm dow cmd; ask c "Schedule:"
    case "$c" in
        1) sched="* * * * *" ;; 2) sched="0 * * * *" ;; 6) sched="@reboot" ;;
        3) ask hh "Hour (0-23):" 2; ask mm "Minute (0-59):" 0; valid_number "$hh" && valid_number "$mm" && (( hh<24 && mm<60 )) || { err "Invalid time."; pause; return; }; sched="$mm $hh * * *" ;;
        4) ask dow "Day of week (0=Sun … 6=Sat):" 0; ask hh "Hour:" 2; valid_number "$dow" && valid_number "$hh" && (( dow<7 && hh<24 )) || { err "Invalid."; pause; return; }; sched="0 $hh * * $dow" ;;
        5) ask hh "Hour:" 2; valid_number "$hh" && (( hh<24 )) || { err "Invalid."; pause; return; }; sched="0 $hh 1 * *" ;;
        7) ask sched "5 fields (e.g. */15 * * * *):"; [[ "$(wc -w <<<"$sched")" -eq 5 || "$sched" == @* ]] || { err "Need exactly 5 fields."; pause; return; } ;;
        *) err "Invalid."; pause; return ;;
    esac
    ask cmd "Command (full paths are safest):"; need "$cmd" Command || { pause; return; }
    info "New line:  $sched $cmd"; confirm "Add to your crontab?" || return
    [[ "$DRY_RUN" == true ]] && { warn "Dry-run: not added."; pause; return; }
    ( crontab -l 2>/dev/null; printf '%s %s\n' "$sched" "$cmd" ) | crontab - && { ok "Added."; audit INFO "cron add: $sched $cmd"; } || err "Failed."; pause
}
cr_remove() {
    header "Remove cron job"; req crontab "cron / cronie" || { pause; return; }; crontab -l &>/dev/null || { info "No crontab."; pause; return; }
    crontab -l | grep -vn '^\s*#' | grep -v '^[0-9]*:\s*$' | sed 's/^/  /'
    local n; ask n "Line number to remove:"; valid_number "$n" || { err "Number needed."; pause; return; }
    local line; line="$(crontab -l | sed -n "${n}p")"; [[ -n "$line" ]] || { err "No such line."; pause; return; }
    info "Removing: $line"; confirm "Remove?" || return
    crontab -l | sed "${n}d" | crontab - && { ok "Removed."; audit WARN "cron remove: $line"; }; pause
}
cr_edit() { header "Edit crontab"; req crontab "cron / cronie" || { pause; return; }; explain "Opens your crontab in an editor. Saving installs it."; EDITOR="$(editor)" crontab -e; pause; }
cr_root() { header "Root crontab"; ${SUDO[@]+"${SUDO[@]}"} crontab -l 2>/dev/null | sed 's/^/  /'; pause; }
cr_system() { header "System cron"; ls -l /etc/cron.d /etc/cron.daily /etc/cron.hourly 2>/dev/null | sed 's/^/  /'; cat /etc/crontab 2>/dev/null | sed 's/^/  /'; pause; }
cr_timers() { header "Systemd timers"; has systemctl && systemctl list-timers --all --no-pager | head -25 | sed 's/^/  /'; pause; }
cr_guide() {
    header "Cron cheat sheet"
    cat <<G
  ${BOLD}*  *  *  *  *   command${RST}
  │  │  │  │  └─ day of week (0-6, Sun=0)
  │  │  │  └──── month (1-12)
  │  │  └─────── day of month (1-31)
  │  └────────── hour (0-23)
  └───────────── minute (0-59)

  ${G}*/5 * * * *${RST}     every 5 minutes        ${G}30 2 * * *${RST}    daily at 02:30
  ${G}0 9 * * 1-5${RST}     weekdays at 09:00      ${G}@reboot${RST}       once at startup
G
    pause
}
cron_menu() {
    menu "Cron Job Manager" "$M" "📋  My jobs|cr_list" "➕  Add job (guided)|cr_add" "➖  Remove job|cr_remove" "📝  Edit crontab in editor|cr_edit" \
        "👑  Root crontab|cr_root" "🌲  System cron|cr_system" "⌛  Systemd timers|cr_timers" "📖  Cheat sheet|cr_guide"
}
register_module "⏰  Cron Jobs & Timers" cron_menu
