# shellcheck shell=bash
# Learn module — beginner-friendly help: recipes, cheat sheets, explain-a-command

# docs_format: colorize a stream of doc blocks
docs_format() {
    local l
    while IFS= read -r l; do
        case "$l" in
            '## '*) printf '\n  %s%s%s\n' "$BOLD$Y" "${l#'## '}" "$RST" ;;
            '@ '*)  ;;
            '$ '*)  printf '    %s%s%s\n' "$G" "$l" "$RST" ;;
            '# '*)  printf '    %s%s%s\n' "$DIM" "${l#'# '}" "$RST" ;;
            *)      printf '  %s\n' "$l" ;;
        esac
    done
}

# docs_search FILE "words" — show every block that contains ALL the words
docs_search() {
    local out
    out="$(awk -v q="$2" '
        function emit(  i, ok, t) { if (blk == "") return; t = tolower(blk); ok = 1
            for (i = 1; i <= n; i++) if (index(t, w[i]) == 0) { ok = 0; break }
            if (ok) { print blk; found = 1 } }
        BEGIN { n = split(tolower(q), w, " ") }
        /^## / { emit(); blk = $0; next }
        { blk = blk "\n" $0 }
        END { emit(); if (!found) exit 1 }' "$1")" || { warn "No recipe matches '$2'. Try fewer or different words."; return 1; }
    printf '%s\n' "$out" | docs_format
}

# docs_browser FILE "Title" — numbered list of "## " sections
docs_browser() {
    local file="$1" title="$2" choice i; local -a titles
    while true; do
        header "$title"
        mapfile -t titles < <(grep '^## ' "$file" | sed 's/^## //')
        for i in "${!titles[@]}"; do printf '  %s%3d%s  %s\n' "$C$BOLD" $((i+1)) "$RST" "${titles[i]}"; done
        echo; ask choice "Number to open (0 = back):"
        case "$choice" in
            ""|0) return 0 ;;
            *[!0-9]*) err "Type a number."; sleep 1 ;;
            *) if (( choice >= 1 && choice <= ${#titles[@]} )); then
                   header "${titles[choice-1]}"
                   awk -v n="$choice" '/^## /{c++} c==n' "$file" | docs_format; pause
               fi ;;
        esac
    done
}

learn_search() {
    header "How do I…?"
    info "Type a few keywords, e.g.  port  |  disk full  |  add user  |  firewall"
    local q; ask q "Search:"; need "$q" Search || { pause; return; }
    docs_search "$LP_HOME/data/recipes.txt" "$q"; pause
}
learn_recipes()  { docs_browser "$LP_HOME/data/recipes.txt" "All recipes"; }
learn_cheats()   { docs_browser "$LP_HOME/data/cheatsheet.txt" "Cheat sheets"; }
learn_gloss()    { docs_browser "$LP_HOME/data/glossary.txt" "Glossary"; }
learn_fs()       { header "Filesystem tour"; docs_format < "$LP_HOME/data/filesystem.txt"; pause; }

# explain a command WITHOUT running it (only reads man pages / help)
learn_explain() {
    header "Explain a command"
    local c; ask c "Command name (e.g. grep, chmod, tar):"; need "$c" Command || { pause; return; }
    [[ "$c" =~ ^[A-Za-z0-9._+-]+$ ]] || { err "Just the command name, please."; pause; return; }
    echo
    if type -t "$c" &>/dev/null; then
        info "Type / location:"; type -a "$c" | sed 's/^/    /'
    else warn "'$c' is not installed or not a known command."; fi
    if has whatis; then echo; info "One-line summary:"; whatis "$c" 2>/dev/null | sed 's/^/    /'; fi
    if has tldr && tldr "$c" &>/dev/null; then echo; info "Practical examples (tldr):"; tldr "$c" | sed 's/^/    /'
    elif [[ "$(type -t "$c")" == builtin ]]; then echo; help "$c" 2>/dev/null | head -25 | sed 's/^/    /'
    elif has man && man -w "$c" &>/dev/null; then echo; info "Start of the manual (man $c):"; env MANPAGER=cat man "$c" 2>/dev/null | col -bx | sed -n '1,40p' | sed 's/^/    /'
    fi
    pause
}

learn_menu() {
    menu "Linux Academy  🎓" "$G" \
        "🔎  How do I…?  (search task recipes)|learn_search" \
        "📖  Browse all recipes|learn_recipes" \
        "🧾  Command cheat sheets|learn_cheats" \
        "❓  Explain a command|learn_explain" \
        "🌲  Filesystem tour  (what is /etc, /var …)|learn_fs" \
        "📚  Glossary|learn_gloss"
}
register_module "🎓  Linux Academy  — learn how things work (start here!)" learn_menu
