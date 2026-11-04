# shellcheck shell=bash
# Disk management

d_lsblk()  { header "Block devices"; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,LABEL | sed 's/^/  /'; pause; }
d_mounts() { header "Mounted filesystems"; findmnt -rno TARGET,SOURCE,FSTYPE,OPTIONS 2>/dev/null | grep -Ev 'cgroup|proc|sysfs|devpts|tmpfs|mqueue|bpf|debugfs|tracefs' | { has column && column -t || cat; } | sed 's/^/  /' | pager; pause; }
d_largest() {
    header "Largest folders"; local p; ask_path p "Start path:" "/"; require_path "$p" dir || { pause; return; }
    info "Scanning (can take a minute)…"; ${SUDO[@]+"${SUDO[@]}"} timeout 90 du -xh --max-depth=2 "$p" 2>/dev/null | sort -rh | head -20 | sed 's/^/  /'; pause
}
d_io()    { header "Disk I/O"; if has iostat; then iostat -xz 1 3 | sed 's/^/  /'; else vmstat 1 5 | sed 's/^/  /'; info "Install sysstat for iostat."; fi; pause; }
d_smart() {
    header "Disk health (SMART)"; has smartctl || { warn "smartmontools not installed."; pause; return; }
    local d; ask d "Device (e.g. /dev/sda):"; [[ "$d" =~ ^/dev/[a-zA-Z0-9]+$ ]] && [[ -b "$d" ]] || { err "Not a block device."; pause; return; }
    run_root "SMART health" smartctl -H "$d"; pause
}
d_inodes() { header "Inode usage"; explain "Each file uses one inode. A disk can be 'full' with free space if inodes run out."; df -ih -x tmpfs -x devtmpfs | sed 's/^/  /'; pause; }
d_mount() {
    header "Mount a device"; lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT | sed 's/^/  /'; echo
    local dev mp; ask dev "Device (e.g. /dev/sdb1):"; [[ "$dev" =~ ^/dev/[a-zA-Z0-9]+$ && -b "$dev" ]] || { err "Not a block device."; pause; return; }
    ask_path mp "Mount point:" "/mnt/usb"; need "$mp" Mountpoint || { pause; return; }
    run_root "Create mount point" mkdir -p "$mp" && run_root "Mount $dev" mount "$dev" "$mp"; pause
}
d_umount() {
    header "Unmount"; findmnt -rno TARGET | grep -E '^/(mnt|media|run/media)' | sed 's/^/  /'; local mp; ask_path mp "Mount point:"; need "$mp" Path || { pause; return; }
    findmnt -n "$mp" &>/dev/null || { err "Nothing mounted there."; pause; return; }
    run_root "Unmount $mp" umount "$mp"; pause
}
disk_menu() {
    menu "Disk Management" "$Y" "💾  Block devices|d_lsblk" "🔗  Mounted filesystems|d_mounts" "📦  Largest folders|d_largest" "🧮  Inode usage|d_inodes" \
        "⚡  Disk I/O|d_io" "💚  SMART health|d_smart" "💽  Mount device|d_mount" "🔓  Unmount|d_umount"
}
register_module "💾  Disk Management" disk_menu
