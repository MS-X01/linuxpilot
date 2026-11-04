# shellcheck shell=bash
# core.sh — config, audit log, command runner, menu engine, module registry
LP_NAME="LinuxPilot"; LP_AUTHOR="MS-X01"; LP_AUTHOR_FULL="Mohammad Sadra Naderi"; LP_URL="https://github.com/MS-X01/linuxpilot"
LP_VERSION="$(cat "$LP_HOME/VERSION" 2>/dev/null || echo 5.0.0)"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/linuxpilot"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/linuxpilot"
CONFIG_FILE="$CONFIG_DIR/config"
LOG_FILE="$STATE_DIR/audit.log"

# defaults (overridden by config file / CLI flags)
AUDIT_ENABLED=true; CONFIRM_DANGEROUS=true; DRY_RUN=false; LEARN_MODE=false; EDITOR_CMD=""
CONFIG_KEYS=(AUDIT_ENABLED CONFIRM_DANGEROUS DRY_RUN LEARN_MODE EDITOR_CMD)

has() { command -v "$1" &>/dev/null; }
# req CMD "package hint" — friendly message when a tool is missing
req() { has "$1" || { warn "'$1' is not installed${2:+ (package: $2)}."; return 1; }; }

if (( EUID == 0 )); then SUDO=()
elif has sudo; then SUDO=(sudo)
else SUDO=(); NO_ROOT=1; fi

init_state() {
    mkdir -p "$CONFIG_DIR" "$STATE_DIR" 2>/dev/null
    # migrate log from v4 location
    [[ -f "$CONFIG_DIR/audit.log" && ! -f "$LOG_FILE" ]] && mv "$CONFIG_DIR/audit.log" "$LOG_FILE" 2>/dev/null
    [[ -f "$CONFIG_FILE" ]] || write_default_config
    load_config
    if [[ -f "$LOG_FILE" ]] && (( $(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0) > 1048576 )); then
        mv "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null
    fi
    touch "$LOG_FILE" 2>/dev/null
    return 0
}

write_default_config() {
    cat > "$CONFIG_FILE" <<'CFG'
# LinuxPilot configuration (key=value, no quotes)
AUDIT_ENABLED=true
CONFIRM_DANGEROUS=true
DRY_RUN=false
LEARN_MODE=false
EDITOR_CMD=
CFG
}

# The config file is parsed, never sourced — a bad file can't run code.
load_config() {
    local k v key
    while IFS='=' read -r k v; do
        [[ "$k" =~ ^[A-Z_]+$ ]] || continue
        for key in "${CONFIG_KEYS[@]}"; do
            if [[ "$k" == "$key" ]]; then printf -v "$k" '%s' "$v"; fi
        done
    done < "$CONFIG_FILE"
}

config_set() { # config_set KEY VALUE
    local tmp; tmp="$(mktemp)" || return 1
    grep -v "^$1=" "$CONFIG_FILE" > "$tmp" 2>/dev/null
    printf '%s=%s\n' "$1" "$2" >> "$tmp"
    cat "$tmp" > "$CONFIG_FILE"; rm -f "$tmp"; printf -v "$1" '%s' "$2"
}

audit() { # audit LEVEL "message"
    [[ "$AUDIT_ENABLED" == true ]] || return 0
    printf '[%s] [%s] [%s] %s\n' "$(date '+%F %T')" "${1:-INFO}" "$(whoami)" "$2" >> "$LOG_FILE" 2>/dev/null
    return 0
}

# ---- command runner: shows the real command, honours dry-run, logs result ----
_exec() {
    local desc="$1"; shift
    show_cmd "$*"
    if [[ "$DRY_RUN" == true ]]; then warn "Dry-run is ON — command was NOT executed."; audit DRYRUN "$desc [$*]"; return 0; fi
    local rc=0; "$@" || rc=$?
    if (( rc == 0 )); then ok "$desc"; audit INFO "$desc [$*]"
    else err "$desc failed (exit code $rc)"; audit ERROR "$desc failed rc=$rc [$*]"; fi
    return $rc
}
run() { _exec "$@"; }
run_root() {
    local desc="$1"; shift
    if (( EUID != 0 )) && [[ -n "${NO_ROOT:-}" ]]; then err "'$desc' needs root and sudo is not installed. Re-run as root."; return 1; fi
    (( EUID != 0 )) && printf '  %s🔒 Administrator rights needed — sudo may ask for your password.%s\n' "$Y" "$RST"
    _exec "$desc" "${SUDO[@]}" "$@"
}
# root_notice — call at the top of features that give fuller results as root
root_notice() { (( EUID == 0 )) || warn "Running without root: some checks are limited. For full results run:  sudo linuxpilot"; return 0; }
view_cmd() { show_cmd "$*"; "$@"; }   # read-only command: show it, run it

pager() { if [[ -t 1 ]] && has less; then less -RFX; else cat; fi; }
editor() { local e="${EDITOR_CMD:-${EDITOR:-}}"; if [[ -z "$e" ]]; then for e in nano vim vi; do has "$e" && break; done; fi; echo "$e"; }

# ---- module registry & menu engine ----
MAIN_ITEMS=()
# register_module "Label" function [root]   — "root" adds a [sudo] marker to the label
register_module() { local l="$1"; [[ "${3:-}" == root ]] && l+="  ${Y}[sudo]${RST}"; MAIN_ITEMS+=("$l|$2"); }

# menu "Title" COLOR "Label|function" ...
menu() {
    local title="$1" color="$2"; shift 2
    local -a labels=() funcs=(); local it i choice
    for it in "$@"; do labels+=("${it%|*}"); funcs+=("${it##*|}"); done
    while true; do
        if [[ "$title" == "__main__" ]]; then banner; printf '  %sMAIN MENU%s\n\n' "$BOLD$W" "$RST"; else header "$title"; fi
        for i in "${!labels[@]}"; do printf '  %s%3d%s  %s\n' "$color$BOLD" $((i+1)) "$RST" "${labels[i]}"; done
        echo; hr
        if [[ "$title" == "__main__" ]]; then
            printf '  %s  s%s  🔎 Search all features\n' "$C$BOLD" "$RST"
            printf '  %s  0%s  %sExit%s\n' "$R$BOLD" "$RST" "$R" "$RST"
            (( EUID != 0 )) && printf '\n  %s[sudo] = needs administrator rights (sudo will ask for your password)%s\n' "$DIM" "$RST"
            echo
        else printf '  %s  0%s  ← Back      %s(q = quit)%s\n\n' "$R$BOLD" "$RST" "$DIM" "$RST"; fi
        ask choice "→ Choose:"
        case "$choice" in
            "") continue ;;
            0|b|B) return 0 ;;
            q|Q) exit_app ;;
            s|S) if [[ "$title" == "__main__" ]]; then feature_search; else err "Type a number from the list."; sleep 1; fi ;;
            *[!0-9]*) err "Please type a number from the list."; sleep 1 ;;
            *) if (( choice >= 1 && choice <= ${#funcs[@]} )); then "${funcs[choice-1]}"
               else err "No such option: $choice"; sleep 1; fi ;;
        esac
    done
}

# feature_search — find any menu action by keyword and jump straight to it
feature_search() {
    header "Search all features"; info "Type a word, e.g.  port  |  user  |  backup  |  firewall"
    local q line label func n=0 pick; ask q "Search:"; need "$q" Search || { pause; return; }
    local -a rl=() rf=(); q="${q,,}"
    while IFS= read -r line; do
        label="${line%|*}"; label="${label#\"}"; func="${line##*|}"; func="${func%\"}"
        [[ "${label,,}" == *"$q"* ]] && declare -F "$func" >/dev/null && { rl+=("$label"); rf+=("$func"); }
    done < <(grep -hoE '"[^"|]+\|[A-Za-z_][A-Za-z0-9_]*"' "$LP_HOME"/modules/*.sh | awk '!seen[$0]++')
    (( ${#rl[@]} )) || { warn "Nothing matches '$q'."; pause; return; }
    echo; for n in "${!rl[@]}"; do (( n >= 15 )) && break; printf '  %s%3d%s  %s\n' "$C$BOLD" $((n+1)) "$RST" "${rl[n]}"; done
    echo; ask pick "Number to open (Enter = cancel):"; [[ "$pick" =~ ^[0-9]+$ ]] && (( pick >= 1 && pick <= ${#rl[@]} && pick <= 15 )) && "${rf[pick-1]}"
    return 0
}

exit_app() {
    audit INFO "Session ended"
    if [[ "${1:-}" != quiet ]]; then
        clear_screen; echo
        printf '%s' "$C$BOLD"
        printf '   ╭──────────────────────────────────────────╮\n'
        printf '   │     Thanks for using %-20s│\n' "$LP_NAME"
        printf '   │       Happy exploring Linux! 🐧          │\n'
        printf '   ╰──────────────────────────────────────────╯\n'
        printf '%s\n' "$RST"
    fi
    exit 0
}
