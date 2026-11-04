# shellcheck shell=bash
# Backup helper (tar.gz snapshots with rotation)

BACKUP_DIR="${LP_BACKUP_DIR:-$HOME/linuxpilot-backups}"
bk_create() {
    header "Create backup"; explain "Makes a compressed tar.gz snapshot with the date in its name."
    local src name out; ask_path src "Folder or file to back up:"; require_path "$src" || { pause; return; }
    mkdir -p "$BACKUP_DIR"; name="$(basename "$(readlink -f "$src")")"; out="$BACKUP_DIR/${name}-$(date +%F_%H%M%S).tar.gz"
    info "Destination: $out"; confirm "Start backup?" || return
    run "Backup $src" tar -czf "$out" -C "$(dirname "$(readlink -f "$src")")" "$name" && info "Size: $(du -h "$out" 2>/dev/null | cut -f1)"; pause
}
bk_list() { header "Your backups"; ls -lh "$BACKUP_DIR" 2>/dev/null | sed 's/^/  /' || true; [[ -d "$BACKUP_DIR" ]] || info "No backups yet ($BACKUP_DIR)."; pause; }
bk_restore() {
    header "Restore backup"; ls -1 "$BACKUP_DIR" 2>/dev/null | sed 's/^/  /'; local f d; ask f "Backup file name:"; [[ "$f" =~ ^[A-Za-z0-9._-]+\.tar\.gz$ && -f "$BACKUP_DIR/$f" ]] || { err "Backup not found."; pause; return; }
    ask_path d "Restore into:" "$HOME/restored"; mkdir -p "$d"; info "Contents:"; tar -tzf "$BACKUP_DIR/$f" | head -10 | sed 's/^/    /'
    confirm "Extract into $d?" && run "Restore" tar -xzf "$BACKUP_DIR/$f" -C "$d"; pause
}
bk_rotate() {
    header "Delete old backups"; local n; ask n "Keep the newest N backups:" 5; valid_number "$n" || { err "Number needed."; pause; return; }
    local -a old; mapfile -t old < <(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -n +$((n+1)))
    (( ${#old[@]} )) || { ok "Nothing to delete."; pause; return; }; printf '  %s\n' "${old[@]}"
    confirm_danger "${#old[@]} backup(s) will be deleted." && run "Rotate backups" rm -f -- "${old[@]}"; pause
}
backup_menu() { menu "Backup  💾" "$G" "🆕  Create backup|bk_create" "📋  List backups|bk_list" "🔁  Restore backup|bk_restore" "🧹  Delete old backups|bk_rotate"; }
register_module "💿  Backup (tar snapshots)" backup_menu
