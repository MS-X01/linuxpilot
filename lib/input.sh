# shellcheck shell=bash
# input.sh — prompts and validation (no namerefs, EOF/Ctrl+C safe)

# ask VAR "Prompt" [default]
ask() {
    local __var="$1" __prompt="$2" __def="${3:-}" __r rc
    if [[ -n "$__def" ]]; then
        printf '  %s%s%s %s[%s]%s ' "$W" "$__prompt" "$RST" "$DIM" "$__def" "$RST"
    else
        printf '  %s%s%s ' "$W" "$__prompt" "$RST"
    fi
    IFS= read -r __r; rc=$?
    if (( rc > 128 )); then __r=""; echo               # Ctrl+C → empty answer
    elif (( rc != 0 )); then echo; exit_app quiet; fi   # EOF → leave cleanly
    [[ -z "$__r" ]] && __r="$__def"
    printf -v "$__var" '%s' "$__r"
}

ask_secret() {
    local __var="$1" __r
    printf '  %s%s%s ' "$W" "$2" "$RST"
    IFS= read -rs __r || true; echo
    printf -v "$__var" '%s' "$__r"
}

# confirm "Question"  → returns 0 on yes (default: no)
confirm() {
    local a; printf '  %s?  %s %s[y/N]%s ' "$Y$BOLD" "${1:-Are you sure?}" "$DIM" "$RST"
    IFS= read -r a || { echo; return 1; }
    [[ "$a" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# confirm_danger "What will happen" → asks to type 'yes' (unless disabled in settings)
confirm_danger() {
    warn "$1"
    if [[ "${CONFIRM_DANGEROUS:-true}" == true ]]; then
        local a; printf '  %s?  Type %syes%s%s to continue:%s ' "$Y$BOLD" "$W" "$RST" "$Y$BOLD" "$RST"
        IFS= read -r a || { echo; return 1; }
        [[ "$a" == "yes" ]]
    else
        confirm "Continue?"
    fi
}

pause() { local _; printf '\n  %sPress %s[Enter]%s%s to continue…%s' "$DIM" "$W" "$RST" "$DIM" "$RST"; IFS= read -r _ || true; }

need() { [[ -n "$1" ]] || { err "${2:-Input} cannot be empty."; return 1; }; }
valid_username() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || { err "Invalid username (a-z, 0-9, _ or -, max 32)."; return 1; }; }
valid_number()   { [[ "$1" =~ ^[0-9]+$ ]]; }
valid_port()     { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )) || { err "Port must be 1-65535."; return 1; }; }
valid_host()     { [[ "$1" =~ ^[A-Za-z0-9._:-]+$ ]] || { err "Invalid host name / address."; return 1; }; }
valid_pkg()      { [[ "$1" =~ ^[A-Za-z0-9_.+:@-]+$ ]] || { err "Invalid package name."; return 1; }; }
valid_unit()     { [[ "$1" =~ ^[A-Za-z0-9_.@:-]+$ ]] || { err "Invalid unit name."; return 1; }; }
require_path() {
    case "${2:-any}" in
        file) [[ -f "$1" ]] || { err "File not found: $1"; return 1; } ;;
        dir)  [[ -d "$1" ]] || { err "Directory not found: $1"; return 1; } ;;
        *)    [[ -e "$1" ]] || { err "Path not found: $1"; return 1; } ;;
    esac
}
expand_path() { local p="$1"; [[ "$p" == "~" ]] && p="$HOME"; [[ "$p" == "~/"* ]] && p="$HOME/${p#\~/}"; printf '%s' "$p"; }
ask_path() { # ask_path VAR "Prompt" [default]
    local __v="$1" __t; ask __t "$2" "${3:-}"; printf -v "$__v" '%s' "$(expand_path "$__t")"
}
pick_user() { # pick_user VAR "Prompt" — validates the account exists
    local __v="$1" __u; ask __u "${2:-Username:}"; need "$__u" Username || return 1
    id "$__u" &>/dev/null || { err "User '$__u' not found."; return 1; }
    printf -v "$__v" '%s' "$__u"
}
