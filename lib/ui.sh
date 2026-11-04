# shellcheck shell=bash
# ui.sh — colors, banner, headers, messages
if [[ ( -t 1 || -n "${LP_FORCE_COLOR:-}" ) && -z "${NO_COLOR:-}" ]]; then
    R=$'\033[0;31m'; G=$'\033[0;32m'; Y=$'\033[1;33m'; B=$'\033[0;34m'
    C=$'\033[0;36m'; M=$'\033[0;35m'; W=$'\033[1;37m'; DIM=$'\033[2m'
    BOLD=$'\033[1m'; RST=$'\033[0m'
else
    R=''; G=''; Y=''; B=''; C=''; M=''; W=''; DIM=''; BOLD=''; RST=''
fi

clear_screen() { [[ -t 1 ]] && clear; return 0; }
hr()  { printf '%s  %s%s\n' "$DIM" "──────────────────────────────────────────────────────────" "$RST"; }
dhr() { printf '%s  %s%s\n' "$C"   "══════════════════════════════════════════════════════════" "$RST"; }

ok()   { printf '  %s✔  %s%s\n' "$G$BOLD" "$*" "$RST"; }
err()  { printf '  %s✘  %s%s\n' "$R$BOLD" "$*" "$RST" >&2; }
warn() { printf '  %s⚠  %s%s\n' "$Y$BOLD" "$*" "$RST"; }
info() { printf '  %s●  %s%s\n' "$C" "$*" "$RST"; }
show_cmd() { local a=() x; for x in "$@"; do a+=("$(printf '%q' "$x")"); done; printf '  %s▶  $ %s%s%s\n' "$DIM" "$W" "${a[*]}" "$RST"; }
# explain: shown only in Learn Mode — tells beginners what a command does
explain() { [[ "${LEARN_MODE:-false}" == true ]] && printf '  %s💡 %s%s\n' "$C" "$*" "$RST"; return 0; }

distro_name() { ( . /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}" ); }

bar() { # bar PERCENT  -> colored usage bar
    local pct="${1:-0}" len=24 filled i out=""
    [[ "$pct" =~ ^[0-9]+$ ]] || pct=0; (( pct > 100 )) && pct=100
    filled=$(( pct * len / 100 ))
    for (( i=0; i<len; i++ )); do (( i < filled )) && out+="█" || out+="░"; done
    local col="$G"; (( pct > 60 )) && col="$Y"; (( pct > 85 )) && col="$R"
    printf '%s%s%s %3d%%' "$col" "$out" "$RST" "$pct"
}

header() { # header "Title"
    clear_screen
    printf '\n%s  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$C" "$RST"
    printf '  %s%s%s %s›%s %s%s%s\n' "$DIM" "$LP_NAME" "$RST" "$C" "$RST" "$BOLD$W" "$1" "$RST"
    printf '%s  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n\n' "$C" "$RST"
}

mapfile -t _TUX <<'TUX'
    .--.     
   |o_o |    
   |:_/ |    
  //   \ \   
 (|     | )  
/'\_   _/`\  
\___)=(___/  
TUX
mapfile -t _LOGO <<'LOGO'
 _     _                    ____  _ _       _   
| |   (_)_ __  _   ___  __ |  _ \(_) | ___ | |_ 
| |   | | '_ \| | | \ \/ / | |_) | | |/ _ \| __|
| |___| | | | | |_| |>  <  |  __/| | | (_) | |_ 
|_____|_|_| |_|\__,_/_/\_\ |_|   |_|_|\___/ \__|
LOGO

banner() {
    clear_screen; echo
    local i right
    for i in 0 1 2 3 4 5 6; do
        right=""
        case $i in
            0|1|2|3|4) right="${_LOGO[i]}" ;;
            5) right="v${LP_VERSION}  ·  by ${LP_AUTHOR}" ;;
            6) right="$(whoami)@$(hostname 2>/dev/null) · $(distro_name)" ;;
        esac
        printf '  %s%s%s%s%s%s\n' "$Y" "${_TUX[i]}" "$RST" "$C$BOLD" "$right" "$RST"
    done
    echo; dhr
    local flags=""
    if (( EUID == 0 )); then flags+=" ${R}[root]${RST}"; else flags+=" ${DIM}[user]${RST}"; fi
    [[ "${DRY_RUN:-false}"  == true ]] && flags+=" ${Y}[dry-run]${RST}"
    [[ "${LEARN_MODE:-false}" == true ]] && flags+=" ${G}[learn mode]${RST}"
    printf '  %s%s%s%s\n' "$DIM" "$(date '+%a %d %b %Y  %H:%M')" "$RST" "$flags"
    dhr; echo
}
