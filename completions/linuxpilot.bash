# bash completion for linuxpilot — install: cp to /etc/bash_completion.d/linuxpilot
_linuxpilot() {
    local cur="${COMP_WORDS[COMP_CWORD]}" prev="${COMP_WORDS[COMP_CWORD-1]}"
    case "$prev" in --report) COMPREPLY=( $(compgen -W "text html" -- "$cur") ); return ;; esac
    COMPREPLY=( $(compgen -W "--help --version --learn --dry-run --no-color --doctor --audit --report --how" -- "$cur") )
}
complete -F _linuxpilot linuxpilot
