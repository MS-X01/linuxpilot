# shellcheck shell=bash
# Permissions manager

pm_view()  { header "View permissions"; local p; ask_path p "Path:"; require_path "$p" || { pause; return; }; stat -c '  %A  (%a)  owner=%U  group=%G  %n' "$p"; [[ -d "$p" ]] && ls -lA "$p" | head -25 | sed 's/^/  /'; pause; }
pm_chmod() {
    header "chmod"; explain "Numbers: 4=read 2=write 1=execute, added per group. 755 = owner rwx, group r-x, others r-x."
    local p m; ask_path p "Path:"; require_path "$p" || { pause; return; }; stat -c '  Now: %A (%a)' "$p"
    ask m "New mode (e.g. 644, 755, u+x):"; [[ "$m" =~ ^[0-7]{3,4}$ || "$m" =~ ^[ugoa]*[-+=][rwxXst]+(,[ugoa]*[-+=][rwxXst]+)*$ ]] || { err "Invalid mode."; pause; return; }
    local -a opt=(); [[ -d "$p" ]] && confirm "Apply recursively?" && opt=(-R)
    [[ "$m" == *7 && "$m" =~ ^[0-7]+$ ]] && warn "Mode $m gives write access to everybody."
    if [[ -O "$p" ]]; then run "chmod $m" chmod "${opt[@]}" "$m" "$p"; else run_root "chmod $m" chmod "${opt[@]}" "$m" "$p"; fi; pause
}
pm_chown() {
    header "chown"; local p o; ask_path p "Path:"; require_path "$p" || { pause; return; }; ask o "New owner[:group]:"; [[ "$o" =~ ^[a-z_][a-z0-9_-]*(:[a-z_][a-z0-9_-]*)?$ ]] || { err "Invalid owner."; pause; return; }
    local -a opt=(); [[ -d "$p" ]] && confirm "Recursive?" && opt=(-R)
    run_root "chown $o" chown "${opt[@]}" "$o" "$p"; pause
}
pm_exec() { header "Make executable"; local p; ask_path p "File:"; require_path "$p" file || { pause; return; }; if [[ -O "$p" ]]; then run "chmod +x" chmod +x "$p"; else run_root "chmod +x" chmod +x "$p"; fi; pause; }
pm_calc() {
    header "Permission calculator"; explain "Type rwx letters and get the number — or a number and get the letters."
    local v; ask v "Enter 9 letters (rwxr-xr-x) or 3 digits (755):"
    if [[ "$v" =~ ^[r-][w-][x-][r-][w-][x-][r-][w-][x-]$ ]]; then
        local out="" i t; for i in 0 3 6; do t="${v:i:3}"; local n=0; [[ ${t:0:1} == r ]] && n=$((n+4)); [[ ${t:1:1} == w ]] && n=$((n+2)); [[ ${t:2:1} == x ]] && n=$((n+1)); out+="$n"; done; ok "$v = $out"
    elif [[ "$v" =~ ^[0-7]{3}$ ]]; then
        local out="" i d
        for i in 0 1 2; do d="${v:i:1}"; (( d&4 )) && out+=r || out+=-; (( d&2 )) && out+=w || out+=-; (( d&1 )) && out+=x || out+=-; done; ok "$v = $out"
    else err "Not a valid pattern."; fi; pause
}
pm_guide() {
    header "Permissions explained"
    cat <<G
  ${BOLD}-rwxr-xr--  1 alice dev  1024 Jan 1 file${RST}
   │└┬┘└┬┘└┬┘
   │ │  │  └─ others : r--  (read only)        = 4
   │ │  └──── group  : r-x  (read + execute)   = 5
   │ └─────── owner  : rwx  (everything)       = 7
   └───────── type   : -  file, d directory, l link

  r = 4 (read)   w = 2 (write)   x = 1 (execute / enter a folder)
  Common modes:  644 documents · 755 programs & folders · 600 private keys · 700 private folders
G
    pause
}
pm_world() { header "World-writable files"; explain "Anyone on the system can change these."; find "${HOME}" -xdev -type f -perm -0002 2>/dev/null | head -30 | sed 's/^/  /'; info "(scanned your home directory)"; pause; }

perms_menu() {
    menu "Permissions Manager" "$B" "👀  View permissions|pm_view" "🔧  chmod — change mode|pm_chmod" "👤  chown — change owner|pm_chown" "⏩  Make executable|pm_exec" \
        "🧮  Permission calculator|pm_calc" "📖  Permissions explained|pm_guide" "🌍  World-writable files|pm_world"
}
register_module "🔒  Permissions Manager" perms_menu
