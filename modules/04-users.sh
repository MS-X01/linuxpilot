# shellcheck shell=bash
# User & group management

u_list_inline() { printf '  %sUsers: %s%s\n\n' "$DIM" "$(awk -F: '$3>=1000 && $3!=65534 {printf "%s ", $1}' /etc/passwd)" "$RST"; }
u_list() {
    header "All human users"
    printf '  %s%-18s %-7s %-7s %-24s %s%s\n' "$BOLD" USER UID GID HOME SHELL "$RST"; hr
    awk -F: '$3>=1000 && $3!=65534 {printf "  %-18s %-7s %-7s %-24s %s\n",$1,$3,$4,$6,$7}' /etc/passwd
    echo; info "Also: root (UID 0) and system accounts below UID 1000."; pause
}
u_create() {
    header "Create user"; explain "useradd makes the account; -m creates /home/NAME; -s picks the login shell."
    local name sh comment
    ask name "Username:"; need "$name" Username && valid_username "$name" || { pause; return; }
    id "$name" &>/dev/null && { warn "User '$name' already exists."; pause; return; }
    ask sh "Shell:" "/bin/bash"; [[ -x "$sh" ]] || { warn "$sh not found. Valid shells:"; grep -v '^#' /etc/shells; pause; return; }
    ask comment "Full name (optional):"
    local -a args=(-m -s "$sh"); [[ -n "$comment" ]] && args+=(-c "$comment")
    confirm "Create '$name'?" || return
    if run_root "Create user $name" useradd "${args[@]}" "$name"; then
        confirm "Set a password now?" && run_root "Set password for $name" passwd "$name"
    fi
    pause
}
u_delete() {
    header "Delete user"; u_list_inline
    local name; pick_user name || { pause; return; }
    [[ "$name" == root || "$name" == "$(whoami)" ]] && { err "Refusing to delete root or yourself."; pause; return; }
    local -a args=()
    confirm "Also delete home directory & mail?" && args=(-r)
    confirm_danger "This permanently deletes the account '$name'." || { info "Cancelled."; pause; return; }
    run_root "Delete user $name" userdel "${args[@]}" "$name"; audit WARN "User deleted: $name"; pause
}
u_passwd() { header "Change password"; local n; pick_user n || { pause; return; }; run_root "Change password of $n" passwd "$n"; pause; }
u_modify() {
    header "Modify user"; local n; pick_user n || { pause; return; }
    echo "  1) shell   2) comment (full name)   3) rename login   4) home directory"
    local c v; ask c "Choice:"
    case "$c" in
        1) ask v "New shell:"; [[ -x "$v" ]] || { err "$v is not executable."; pause; return; }; run_root "Set shell" usermod -s "$v" "$n" ;;
        2) ask v "New comment:"; run_root "Set comment" usermod -c "$v" "$n" ;;
        3) ask v "New username:"; valid_username "$v" && run_root "Rename user" usermod -l "$v" "$n" ;;
        4) ask v "New home path:"; [[ "$v" == /* ]] && confirm "Move existing files too?" && run_root "Move home" usermod -m -d "$v" "$n" ;;
        *) err "Invalid choice." ;;
    esac; pause
}
u_add_group() {
    header "Add user to group"; explain "usermod -aG appends the group. Without -a the user would LOSE all other groups."
    local n g; pick_user n || { pause; return; }; ask g "Group:"; need "$g" Group || { pause; return; }
    getent group "$g" &>/dev/null || { err "Group '$g' does not exist."; pause; return; }
    run_root "Add $n to $g" usermod -aG "$g" "$n"; pause
}
u_del_group() {
    header "Remove user from group"; local n g; pick_user n || { pause; return; }
    info "Groups: $(id -nG "$n")"; ask g "Group to remove:"; need "$g" Group || { pause; return; }
    has gpasswd && run_root "Remove $n from $g" gpasswd -d "$n" "$g" || err "gpasswd not available."; pause
}
u_info() {
    header "User details"; local n; pick_user n || { pause; return; }
    id "$n" | sed 's/^/  /'; getent passwd "$n" | awk -F: '{printf "  Home:  %s\n  Shell: %s\n  Info:  %s\n",$6,$7,$5}'
    echo; ${SUDO[@]+"${SUDO[@]}"} chage -l "$n" 2>/dev/null | sed 's/^/  /'; last -n 3 "$n" 2>/dev/null | sed 's/^/  /'; pause
}
u_list_groups() { header "Groups"; getent group | awk -F: '$3>=1000 || $1 ~ /^(sudo|wheel|docker|adm)$/ {printf "  %-18s GID %-6s %s\n",$1,$3,$4}'; pause; }
u_create_group() { header "Create group"; local g; ask g "Group name:"; need "$g" Group && valid_username "$g" && run_root "Create group $g" groupadd "$g"; pause; }
u_delete_group() {
    header "Delete group"; local g; ask g "Group name:"; need "$g" Group || { pause; return; }
    getent group "$g" &>/dev/null || { err "No such group."; pause; return; }
    confirm_danger "Group '$g' will be removed." && run_root "Delete group $g" groupdel "$g"; pause
}
u_who() { header "Who is logged in"; w | sed 's/^/  /'; echo; info "Recent logins:"; last -n 8 | sed 's/^/  /'; pause; }
u_lock()   { header "Lock account"; local n; pick_user n || { pause; return; }; [[ "$n" == root ]] && ! confirm_danger "Locking root!" && return; run_root "Lock $n" usermod -L "$n"; pause; }
u_unlock() { header "Unlock account"; local n; pick_user n || { pause; return; }; run_root "Unlock $n" usermod -U "$n"; pause; }
u_expiry() {
    header "Password / account expiry"; local n d; pick_user n || { pause; return; }
    ${SUDO[@]+"${SUDO[@]}"} chage -l "$n" | sed 's/^/  /'
    echo "  1) force password change at next login   2) set max password age   3) set account expiry date"
    local c; ask c "Choice (Enter = none):"
    case "$c" in
        1) run_root "Expire password" chage -d 0 "$n" ;;
        2) ask d "Max days:"; valid_number "$d" && run_root "Set max age" chage -M "$d" "$n" ;;
        3) ask d "Date (YYYY-MM-DD, or -1 = never):"; run_root "Set expiry" chage -E "$d" "$n" ;;
    esac; pause
}
u_sudo() {
    header "Grant / revoke sudo"; explain "Membership in the 'sudo' (Debian) or 'wheel' (Fedora/Arch) group gives admin rights."
    local n g=sudo; pick_user n || { pause; return; }
    getent group sudo &>/dev/null || g=wheel
    echo "  1) grant   2) revoke   (group: $g)"; local c; ask c "Choice:"
    case "$c" in
        1) run_root "Grant sudo to $n" usermod -aG "$g" "$n" ;;
        2) [[ "$n" == "$(whoami)" ]] && ! confirm_danger "You are removing your OWN admin rights." && return
           run_root "Revoke sudo from $n" gpasswd -d "$n" "$g" ;;
    esac; pause
}
user_menu() {
    menu "User Management" "$M" \
        "📋  List users|u_list" "➕  Create user|u_create" "🚮  Delete user|u_delete" "🔑  Change password|u_passwd" \
        "📝  Modify user|u_modify" "👑  Grant / revoke sudo|u_sudo" "➕  Add user to group|u_add_group" "➖  Remove user from group|u_del_group" \
        "📇  User details|u_info" "👥  List groups|u_list_groups" "🆕  Create group|u_create_group" "❌  Delete group|u_delete_group" \
        "🟢  Who is logged in|u_who" "🔒  Lock account|u_lock" "🔓  Unlock account|u_unlock" "📅  Password / account expiry|u_expiry"
}
register_module "👤  User Management" user_menu root
