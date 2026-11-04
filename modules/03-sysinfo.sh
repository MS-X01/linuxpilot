# shellcheck shell=bash
# System information

si_dashboard() {
    header "System Dashboard  📊"
    local cpu mem disk swap load
    cpu="$(cpu_pct)"; mem="$(mem_pct)"; swap="$(swap_pct)"
    disk="$(df -P / | awk 'NR==2{gsub("%","",$5); print $5}')"; read -r load _ < /proc/loadavg
    printf '  %-8s ' "CPU";  bar "$cpu";  echo
    printf '  %-8s ' "Memory"; bar "$mem"; echo
    printf '  %-8s ' "Swap";   bar "$swap"; echo
    printf '  %-8s ' "Disk /"; bar "$disk"; echo
    echo; hr
    printf '  %sHost%s      %s\n' "$DIM" "$RST" "$(hostname)"
    printf '  %sOS%s        %s\n' "$DIM" "$RST" "$(distro_name)"
    printf '  %sKernel%s    %s\n' "$DIM" "$RST" "$(uname -r)"
    printf '  %sUptime%s    %s\n' "$DIM" "$RST" "$(uptime -p 2>/dev/null)"
    printf '  %sLoad%s      %s  (%s cores)\n' "$DIM" "$RST" "$load" "$(nproc)"
    printf '  %sUsers%s     %s logged in\n' "$DIM" "$RST" "$(who | wc -l)"
    echo; info "Top 5 by CPU:"; ps -eo pid,user:12,%cpu,%mem,comm --sort=-%cpu | head -6 | sed 's/^/    /'
    pause
}
si_cpu()  { header "CPU"; lscpu 2>/dev/null | grep -E 'Model name|Architecture|^CPU\(s\)|Thread|Core|Socket|MHz|L2|L3|Virtualization' | sed 's/^/  /' || grep -m1 'model name' /proc/cpuinfo; echo; info "Load: $(cut -d' ' -f1-3 /proc/loadavg)"; pause; }
si_mem()  { header "Memory"; explain "'available' is what programs can really use; cache is reclaimed on demand."; free -h | sed 's/^/  /'; pause; }
si_disk() { header "Disk usage"; df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay | sed 's/^/  /'; pause; }
si_os()   { header "Operating system"; sed 's/^/  /' /etc/os-release 2>/dev/null; echo; printf '  Kernel: %s\n  Arch:   %s\n' "$(uname -r)" "$(uname -m)"; has hostnamectl && hostnamectl 2>/dev/null | sed 's/^/  /'; pause; }
si_uptime() { header "Uptime & boot"; printf '  %s\n  Since: %s\n' "$(uptime -p 2>/dev/null)" "$(uptime -s 2>/dev/null)"; echo; last reboot -n 5 2>/dev/null | sed 's/^/  /'; pause; }
si_hw() {
    header "Hardware"
    if has lspci; then info "PCI devices:"; lspci 2>/dev/null | head -15 | sed 's/^/  /'; else warn "lspci missing (package: pciutils)"; fi
    echo; if has lsusb; then info "USB devices:"; lsusb 2>/dev/null | sed 's/^/  /'; fi
    echo; has lsblk && { info "Block devices:"; lsblk | sed 's/^/  /'; }
    pause
}
si_temp() {
    header "Temperatures"
    if has sensors; then sensors 2>/dev/null | sed 's/^/  /'
    elif compgen -G "/sys/class/thermal/thermal_zone*/temp" >/dev/null; then
        local z; for z in /sys/class/thermal/thermal_zone*; do printf '  %-14s %s°C\n' "$(cat "$z/type" 2>/dev/null)" "$(( $(cat "$z/temp") / 1000 ))"; done
    else warn "No sensors found (install lm-sensors, then run: sudo sensors-detect)"; fi
    pause
}
si_battery() {
    header "Battery"
    if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
        local b; for b in /sys/class/power_supply/BAT*; do
            printf '  %s: %s%%  (%s)\n' "$(basename "$b")" "$(cat "$b/capacity")" "$(cat "$b/status")"; done
    else info "No battery (desktop or VM)."; fi
    pause
}
si_env() { header "Environment"; env | sort | grep -Ev 'KEY|TOKEN|SECRET|PASS' | pager; pause; }
si_modules() { header "Kernel modules"; lsmod 2>/dev/null | head -40 | sed 's/^/  /'; pause; }
si_top5() { header "Heaviest processes"; info "By memory:"; ps -eo pid,user:12,%mem,%cpu,comm --sort=-%mem | head -8 | sed 's/^/  /'; pause; }

sysinfo_menu() {
    menu "System Information" "$C" \
        "📊  Dashboard (CPU / RAM / disk bars)|si_dashboard" \
        "🧠  CPU|si_cpu" "🧮  Memory|si_mem" "💽  Disk usage|si_disk" \
        "🐧  OS & kernel|si_os" "⏳  Uptime & reboots|si_uptime" \
        "🔌  Hardware (PCI / USB / block)|si_hw" "🔥  Temperatures|si_temp" \
        "🔋  Battery|si_battery" "🏆  Heaviest processes|si_top5" \
        "🌍  Environment variables|si_env" "🧩  Kernel modules|si_modules"
}
register_module "📊  System Information" sysinfo_menu
