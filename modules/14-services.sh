# shellcheck shell=bash
# Service manager (systemd)

_svc_ok() { has systemctl && [[ -d /run/systemd/system ]] || { err "systemd is not running on this system."; return 1; }; }
sv_list()   { header "Running services"; _svc_ok || { pause; return; }; systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{printf "  %-40s %s\n",$1,$4}' | pager; pause; }
sv_failed() { header "Failed services"; _svc_ok || { pause; return; }; local o; o="$(systemctl --failed --no-pager --no-legend)"; [[ -n "$o" ]] && printf '%s\n' "$o" | sed 's/^/  /' || ok "No failed units."; pause; }
sv_enabled(){ header "Enabled at boot"; _svc_ok || { pause; return; }; systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend | awk '{print "  "$1}' | pager; pause; }
_sv_do() { # _sv_do verb "Title"
    header "$2"; _svc_ok || { pause; return; }; local u; ask u "Service name (e.g. nginx):"; need "$u" Service && valid_unit "$u" || { pause; return; }
    systemctl cat "$u" &>/dev/null || { err "No such unit: $u"; pause; return; }
    case "$1" in stop|disable) confirm "$1 '$u'?" || return ;; esac
    run_root "$1 $u" systemctl "$1" "$u"; systemctl status "$u" --no-pager -n 3 2>/dev/null | sed 's/^/  /'; pause
}
sv_start() { explain "start = run now. enable = also run at every boot."; _sv_do start "Start service"; }
sv_stop()    { _sv_do stop "Stop service"; }
sv_restart() { _sv_do restart "Restart service"; }
sv_reload()  { _sv_do reload "Reload configuration"; }
sv_enable()  { _sv_do enable "Enable at boot"; }
sv_disable() { _sv_do disable "Disable at boot"; }
sv_status()  { header "Service status"; _svc_ok || { pause; return; }; local u; ask u "Service name:"; valid_unit "$u" || { pause; return; }; systemctl status "$u" --no-pager | sed 's/^/  /'; pause; }
sv_logs()    { header "Service logs"; _svc_ok || { pause; return; }; local u; ask u "Service name:"; valid_unit "$u" || { pause; return; }; ${SUDO[@]+"${SUDO[@]}"} journalctl -u "$u" -n 60 --no-pager | pager; pause; }

service_menu() {
    menu "Service Manager" "$C" "🟢  Running services|sv_list" "🔴  Failed services|sv_failed" "🚀  Enabled at boot|sv_enabled" "📇  Status of a service|sv_status" "📜  Logs of a service|sv_logs" \
        "⏩  Start|sv_start" "🛑  Stop|sv_stop" "🔁  Restart|sv_restart" "🔁  Reload config|sv_reload" "✅  Enable at boot|sv_enable" "🚫  Disable at boot|sv_disable"
}
register_module "💻  Service Manager (systemd)" service_menu root
