# shellcheck shell=bash
# Process management

p_top() { header "Live processes"; if has htop; then htop; else info "htop not installed — using top (press q to quit)"; top; fi; }
p_search() {
    header "Search processes"; local q; ask q "Name or part of it:"; need "$q" Name || { pause; return; }
    show_cmd pgrep -a -i -- "$q"; pgrep -a -i -- "$q" || warn "No process matches '$q'."; pause
}
p_protected() { # refuse PID 1, kernel threads and ourselves
    local pid="$1"
    (( pid == 1 || pid == $$ || pid == PPID )) && { err "PID $pid is protected (init / this shell)."; return 0; }
    [[ "$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')" == 2 ]] && { err "PID $pid is a kernel thread."; return 0; }
    return 1
}
p_kill_pid() {
    header "Kill by PID"; explain "SIGTERM (15) asks nicely; SIGKILL (9) cannot be ignored but gives no chance to clean up."
    local pid sig; ask pid "PID:"; valid_number "$pid" || { err "A PID is a number."; pause; return; }
    kill -0 "$pid" 2>/dev/null || { err "No such process (or no permission)."; pause; return; }
    p_protected "$pid" && { pause; return; }
    ps -o pid,user,%cpu,%mem,etime,cmd -p "$pid" | sed 's/^/  /'
    echo "  1) SIGTERM (polite)   2) SIGKILL (force)   3) SIGHUP (reload)   4) SIGSTOP (pause)   5) SIGCONT (resume)"
    ask sig "Signal:" 1
    local s; case "$sig" in 1) s=TERM;; 2) s=KILL;; 3) s=HUP;; 4) s=STOP;; 5) s=CONT;; *) err "Invalid."; pause; return;; esac
    confirm "Send SIG$s to PID $pid?" && { if kill -0 "$pid" 2>/dev/null && [[ "$(ps -o user= -p "$pid")" != "$(whoami)" ]]; then run_root "SIG$s → $pid" kill "-$s" "$pid"; else run "SIG$s → $pid" kill "-$s" "$pid"; fi; }
    pause
}
p_kill_name() {
    header "Kill by name"; local n; ask n "Exact process name:"; need "$n" Name || { pause; return; }
    [[ "$n" =~ ^[A-Za-z0-9._+-]+$ ]] || { err "Invalid name."; pause; return; }
    pgrep -a -x -- "$n" || { warn "No process named '$n'."; pause; return; }
    confirm_danger "ALL processes named '$n' will be terminated." && run_root "pkill $n" pkill -x -- "$n"; pause
}
p_tree() { header "Process tree"; if has pstree; then pstree -p | head -80; else ps -ejH | head -80; fi; pause; }
p_info() {
    header "Process details"; local pid; ask pid "PID:"; valid_number "$pid" && [[ -d /proc/$pid ]] || { err "No such process."; pause; return; }
    ps -o pid,ppid,user,stat,%cpu,%mem,etime,nlwp,cmd -p "$pid" | sed 's/^/  /'
    printf '  cwd: %s\n  exe: %s\n' "$(readlink "/proc/$pid/cwd" 2>/dev/null)" "$(readlink "/proc/$pid/exe" 2>/dev/null)"
    has lsof && { echo; info "Open network connections:"; ${SUDO[@]+"${SUDO[@]}"} lsof -a -i -p "$pid" 2>/dev/null | head -12 | sed 's/^/  /'; }
    pause
}
p_renice() {
    header "Change priority"; explain "nice: -20 = highest priority, 19 = lowest. Only root can lower the number."
    local pid n; ask pid "PID:"; valid_number "$pid" || { err "Number needed."; pause; return; }
    ask n "New nice value (-20..19):"; [[ "$n" =~ ^-?[0-9]+$ ]] && (( n >= -20 && n <= 19 )) || { err "Out of range."; pause; return; }
    run_root "renice $pid" renice -n "$n" -p "$pid"; pause
}
p_zombies() {
    header "Zombie processes"; explain "A zombie is a finished process whose parent has not collected its exit status. Kill the PARENT to clear it."
    local z; z="$(ps -eo pid,ppid,stat,comm | awk '$3 ~ /^Z/')"
    [[ -n "$z" ]] && printf '%s\n' "$z" | sed 's/^/  /' || ok "No zombies."; pause
}
p_top_mem() { header "Top memory users"; ps -eo pid,user:12,%mem,rss,comm --sort=-%mem | head -15 | sed 's/^/  /'; pause; }

process_menu() {
    menu "Process Management" "$Y" \
        "📈  Live monitor (top/htop)|p_top" "🔎  Search by name|p_search" "💀  Kill by PID / send signal|p_kill_pid" "💥  Kill by name|p_kill_name" \
        "🌳  Process tree|p_tree" "📇  Process details|p_info" "⏫  Change priority (renice)|p_renice" "🧟  Zombie processes|p_zombies" "🧠  Top memory users|p_top_mem"
}
register_module "🔧  Process Management" process_menu
