# shellcheck shell=bash
# Package manager (apt / dnf / yum / pacman / zypper)

detect_pkg() { local p; for p in apt dnf yum pacman zypper; do has "$p" && { echo "$p"; return; }; done; echo unknown; }
PKG="$(detect_pkg)"

_pkg() { # _pkg ACTION [args]  → run the right command for this distro
    local a="$1"; shift
    case "$PKG:$a" in
        apt:update) run_root "Refresh package lists" apt-get update ;;
        apt:upgrade) run_root "Upgrade packages" apt-get upgrade -y ;;
        apt:install) run_root "Install $*" apt-get install -y "$@" ;;
        apt:remove) run_root "Remove $*" apt-get remove -y "$@" ;;
        apt:autoremove) run_root "Remove unused packages" apt-get autoremove -y ;;
        apt:clean) run_root "Clean cache" apt-get clean ;;
        apt:search) view_cmd apt-cache search "$@" | head -40 ;;
        apt:info) view_cmd apt-cache show "$@" | head -40 ;;
        apt:list) dpkg-query -W -f='${Package} ${Version}\n' | pager ;;
        apt:upgradable) apt list --upgradable 2>/dev/null | pager ;;
        dnf:update|yum:update) run_root "Refresh metadata" "$PKG" makecache ;;
        dnf:upgrade|yum:upgrade) run_root "Upgrade packages" "$PKG" upgrade -y ;;
        dnf:install|yum:install) run_root "Install $*" "$PKG" install -y "$@" ;;
        dnf:remove|yum:remove) run_root "Remove $*" "$PKG" remove -y "$@" ;;
        dnf:autoremove|yum:autoremove) run_root "Remove unused packages" "$PKG" autoremove -y ;;
        dnf:clean|yum:clean) run_root "Clean cache" "$PKG" clean all ;;
        dnf:search|yum:search) view_cmd "$PKG" search "$@" | head -40 ;;
        dnf:info|yum:info) view_cmd "$PKG" info "$@" ;;
        dnf:list|yum:list) rpm -qa | sort | pager ;;
        dnf:upgradable|yum:upgradable) "$PKG" check-update | pager ;;
        pacman:update) run_root "Sync databases" pacman -Sy ;;
        pacman:upgrade) run_root "Full upgrade" pacman -Syu --noconfirm ;;
        pacman:install) run_root "Install $*" pacman -S --noconfirm "$@" ;;
        pacman:remove) run_root "Remove $*" pacman -Rs --noconfirm "$@" ;;
        pacman:autoremove) run_root "Remove orphans" bash -c 'pacman -Qtdq | pacman -Rns --noconfirm -' ;;
        pacman:clean) run_root "Clean cache" pacman -Sc --noconfirm ;;
        pacman:search) view_cmd pacman -Ss "$@" | head -40 ;;
        pacman:info) view_cmd pacman -Si "$@" ;;
        pacman:list) pacman -Q | pager ;;
        pacman:upgradable) pacman -Qu | pager ;;
        zypper:update) run_root "Refresh repos" zypper refresh ;;
        zypper:upgrade) run_root "Upgrade packages" zypper update -y ;;
        zypper:install) run_root "Install $*" zypper install -y "$@" ;;
        zypper:remove) run_root "Remove $*" zypper remove -y "$@" ;;
        zypper:autoremove) warn "zypper has no autoremove." ;;
        zypper:clean) run_root "Clean cache" zypper clean ;;
        zypper:search) view_cmd zypper search "$@" | head -40 ;;
        zypper:info) view_cmd zypper info "$@" ;;
        zypper:list) rpm -qa | sort | pager ;;
        zypper:upgradable) zypper list-updates | pager ;;
        *) err "Unsupported package manager: $PKG" ;;
    esac
}
_pkg_name() { local n; ask n "Package name:"; need "$n" Package && valid_pkg "$n" && PNAME="$n"; }

pk_update()  { header "Update package lists"; explain "Downloads the newest list of available software. Does not install anything yet."; _pkg update; pause; }
pk_upgrade() { header "Upgrade system"; explain "Installs all available updates."; confirm "Upgrade ALL packages?" && _pkg upgrade; pause; }
pk_install() { header "Install package"; _pkg_name && confirm "Install '$PNAME'?" && _pkg install "$PNAME"; pause; }
pk_remove()  { header "Remove package"; _pkg_name && confirm_danger "'$PNAME' will be removed." && _pkg remove "$PNAME"; pause; }
pk_search()  { header "Search packages"; _pkg_name && _pkg search "$PNAME"; pause; }
pk_info()    { header "Package info"; _pkg_name && _pkg info "$PNAME"; pause; }
pk_list()    { header "Installed packages"; _pkg list; pause; }
pk_clean()   { header "Clean cache"; _pkg clean; pause; }
pk_auto()    { header "Remove unused dependencies"; confirm "Run autoremove?" && _pkg autoremove; pause; }
pk_upgradable() { header "Available updates"; _pkg upgradable; pause; }
pk_which() {
    header "Which package owns a file?"; local f; ask f "Path or command:"; need "$f" Path || { pause; return; }
    [[ "$f" != /* ]] && f="$(command -v "$f" 2>/dev/null || echo "$f")"
    case "$PKG" in apt) dpkg -S "$f" ;; dnf|yum|zypper) rpm -qf "$f" ;; pacman) pacman -Qo "$f" ;; esac 2>&1 | sed 's/^/  /'; pause
}
pk_bundle() {
    header "Install a starter tool bundle"
    echo "  1) Essentials  — curl wget git vim nano htop tmux tree unzip"
    echo "  2) Network     — mtr nmap tcpdump whois traceroute + DNS tools"
    echo "  3) Monitoring  — htop iotop ncdu lm-sensors"
    local c; ask c "Choice:"; local -a pk
    case "$c" in
        1) pk=(curl wget git vim nano htop tmux tree unzip) ;;
        2) pk=(mtr nmap tcpdump whois traceroute); case "$PKG" in apt) pk+=(dnsutils) ;; pacman) pk+=(bind) ;; *) pk+=(bind-utils) ;; esac ;;
        3) pk=(htop iotop ncdu); case "$PKG" in apt|zypper) pk+=(lm-sensors) ;; pacman) pk+=(lm_sensors) ;; *) pk+=(lm_sensors) ;; esac ;;
        *) err "Invalid."; pause; return ;;
    esac
    info "Will install: ${pk[*]}"; confirm "Proceed?" && _pkg install "${pk[@]}"; pause
}

package_menu() {
    if [[ "$PKG" == unknown ]]; then header "Package Manager"; err "No supported package manager found."; pause; return; fi
    menu "Package Manager  [$PKG]" "$M" \
        "🔄  Update package lists|pk_update" "🆙  Upgrade all packages|pk_upgrade" "📥  Install package|pk_install" "📤  Remove package|pk_remove" \
        "🔍  Search|pk_search" "📇  Package info|pk_info" "📜  Installed packages|pk_list" "🆕  Available updates|pk_upgradable" \
        "🧹  Clean cache|pk_clean" "🔁  Remove unused dependencies|pk_auto" "🧭  Which package owns this file?|pk_which" "🎁  Starter tool bundles|pk_bundle"
}
register_module "📦  Package Manager" package_menu root
