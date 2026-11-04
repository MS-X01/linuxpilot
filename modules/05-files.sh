# shellcheck shell=bash
# Files & directories

f_ls()   { header "Directory listing"; local p; ask_path p "Path:" "$PWD"; require_path "$p" dir || { pause; return; }; ls -lAh --color=auto "$p" | pager; pause; }
f_tree() { header "Directory tree"; local p; ask_path p "Path:" "$PWD"; require_path "$p" dir || { pause; return; }
    if has tree; then tree -L 2 "$p" | pager; else find "$p" -maxdepth 2 | sed 's|[^/]*/|  |g' | head -80; info "(install 'tree' for a nicer view)"; fi; pause; }
f_touch() { header "Create file"; local p; ask_path p "File path:"; need "$p" Path || { pause; return; }
    [[ -e "$p" ]] && { warn "Already exists."; pause; return; }; run "Create $p" touch "$p"; pause; }
f_mkdir() { header "Create directory"; local p; ask_path p "Directory path:"; need "$p" Path || { pause; return; }; run "Create directory" mkdir -p "$p"; pause; }
f_rm() {
    header "Delete file"; explain "rm has NO recycle bin — deleted files are gone."
    local p; ask_path p "File to delete:"; require_path "$p" file || { pause; return; }
    confirm "Delete '$p'?" && run "Delete $p" rm -- "$p"; pause
}
f_rmdir() {
    header "Delete directory"; local p; ask_path p "Directory to delete:"; require_path "$p" dir || { pause; return; }
    case "$(readlink -f "$p")" in /|/etc|/usr|/var|/bin|/sbin|/lib*|/boot|/home|/root|/dev|/proc|/sys) err "Refusing to delete a critical system directory."; pause; return ;; esac
    [[ "$(readlink -f "$p")" == "$(readlink -f "$HOME")" ]] && { err "Refusing to delete your home directory."; pause; return; }
    info "Contains $(find "$p" -type f 2>/dev/null | wc -l) file(s), $(du -sh "$p" 2>/dev/null | cut -f1)"
    confirm_danger "Everything inside '$p' will be deleted recursively." && run "Delete $p" rm -rf -- "$p"; pause
}
f_cp() { header "Copy"; local s d; ask_path s "Source:"; require_path "$s" || { pause; return; }; ask_path d "Destination:"; need "$d" Destination || { pause; return; }
    [[ -e "$d" ]] && ! confirm "Destination exists — overwrite?" && return; run "Copy" cp -a -- "$s" "$d"; pause; }
f_mv() { header "Move / rename"; local s d; ask_path s "Source:"; require_path "$s" || { pause; return; }; ask_path d "New path:"; need "$d" Destination || { pause; return; }
    [[ -e "$d" ]] && ! confirm "Destination exists — overwrite?" && return; run "Move" mv -- "$s" "$d"; pause; }
f_view() { header "View file"; local p; ask_path p "File:"; require_path "$p" file || { pause; return; }
    info "$(file -b "$p" 2>/dev/null) — $(du -h "$p" | cut -f1)"; if file -b --mime "$p" 2>/dev/null | grep -q text; then pager < "$p"; else warn "Looks binary — not displaying."; fi; pause; }
f_edit() { header "Edit file"; local p e; ask_path p "File:"; need "$p" Path || { pause; return; }; e="$(editor)"
    [[ -n "$e" ]] || { err "No editor found. Install nano."; pause; return; }; explain "In nano: Ctrl+O saves, Ctrl+X exits."; "$e" "$p"; audit INFO "Edited $p"; }
f_find() {
    header "Find files"; local d n; ask_path d "Search in:" "$PWD"; require_path "$d" dir || { pause; return; }
    echo "  1) by name   2) bigger than…   3) changed in last N days   4) by owner"
    local c; ask c "Choice:"
    case "$c" in
        1) ask n "Name pattern (e.g. *.log):"; need "$n" Pattern && { show_cmd find "$d" -iname "$n"; find "$d" -iname "$n" 2>/dev/null | head -100 | pager; } ;;
        2) ask n "Size (e.g. 100M, 1G):"; [[ "$n" =~ ^[0-9]+[kMG]$ ]] && { show_cmd find "$d" -type f -size "+$n"; find "$d" -type f -size "+$n" -exec ls -lh {} + 2>/dev/null | head -50 | pager; } || err "Use a form like 100M." ;;
        3) ask n "Days:"; valid_number "$n" && { show_cmd find "$d" -type f -mtime "-$n"; find "$d" -type f -mtime "-$n" 2>/dev/null | head -100 | pager; } || err "Number needed." ;;
        4) ask n "Owner:"; id "$n" &>/dev/null && find "$d" -user "$n" 2>/dev/null | head -100 | pager || err "No such user." ;;
        *) err "Invalid choice." ;;
    esac; pause
}
f_grep() {
    header "Search inside files"; local d t; ask_path d "Search in:" "$PWD"; require_path "$d" || { pause; return; }
    ask t "Text:"; need "$t" Text || { pause; return; }
    show_cmd grep -rnIF --color=always -- "$t" "$d"; grep -rnIF --color=always -- "$t" "$d" 2>/dev/null | head -200 | pager; pause
}
f_stat() { header "File details"; local p; ask_path p "Path:"; require_path "$p" || { pause; return; }; stat "$p" | sed 's/^/  /'; file "$p" | sed 's/^/  /'; pause; }
f_ln() { header "Symbolic link"; explain "A symlink is a shortcut: LINK points to TARGET."; local t l; ask_path t "Target:"; require_path "$t" || { pause; return; }; ask_path l "Link path:"; need "$l" Link || { pause; return; }; run "Create symlink" ln -s -- "$t" "$l"; pause; }
f_du() { header "Folder sizes"; local d; ask_path d "Folder:" "$PWD"; require_path "$d" dir || { pause; return; }; du -h --max-depth=1 "$d" 2>/dev/null | sort -rh | head -25 | sed 's/^/  /'; pause; }
f_archive() {
    header "Create archive"; local s o; ask_path s "File or folder to archive:"; require_path "$s" || { pause; return; }
    echo "  1) .tar.gz   2) .zip   3) .tar.xz"; local c; ask c "Format:" 1; o="$(basename "$s")"
    case "$c" in
        1) run "Create $o.tar.gz" tar -czf "$o.tar.gz" -C "$(dirname "$s")" "$o" ;;
        2) has zip && run "Create $o.zip" zip -rq "$o.zip" "$s" || err "zip is not installed." ;;
        3) run "Create $o.tar.xz" tar -cJf "$o.tar.xz" -C "$(dirname "$s")" "$o" ;;
        *) err "Invalid choice." ;;
    esac; info "Created in: $PWD"; pause
}
f_extract() {
    header "Extract archive"; local a d; ask_path a "Archive:"; require_path "$a" file || { pause; return; }
    ask_path d "Extract into:" "$PWD"; mkdir -p "$d"
    case "$a" in
        *.tar.gz|*.tgz) run "Extract" tar -xzf "$a" -C "$d" ;; *.tar.xz) run "Extract" tar -xJf "$a" -C "$d" ;;
        *.tar.bz2)      run "Extract" tar -xjf "$a" -C "$d" ;; *.tar)    run "Extract" tar -xf "$a" -C "$d" ;;
        *.zip) has unzip && run "Extract" unzip -q "$a" -d "$d" || err "unzip not installed." ;;
        *.gz)  run "Extract" gunzip -k "$a" ;;
        *) err "Unknown archive type." ;;
    esac; pause
}
f_cd() { header "Change working directory"; local p; ask_path p "New directory:"; require_path "$p" dir || { pause; return; }; cd "$p" && ok "Now in $PWD"; pause; }

file_menu() {
    menu "Files & Directories" "$B" \
        "📂  List directory|f_ls" "🌳  Directory tree|f_tree" "📏  Folder sizes|f_du" "📄  Create file|f_touch" "📁  Create directory|f_mkdir" \
        "🚮  Delete file|f_rm" "🧨  Delete directory|f_rmdir" "📋  Copy|f_cp" "🚚  Move / rename|f_mv" \
        "👀  View file|f_view" "📝  Edit file|f_edit" "🔎  Find files|f_find" "🔍  Search inside files|f_grep" \
        "📇  File details|f_stat" "🔗  Symbolic link|f_ln" "📦  Create archive|f_archive" "📤  Extract archive|f_extract" "👉  Change working directory|f_cd"
}
register_module "📁  Files & Directories" file_menu
