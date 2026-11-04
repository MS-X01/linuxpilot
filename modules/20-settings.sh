# shellcheck shell=bash
# Settings & About

_toggle() { # _toggle KEY label
    local cur="${!1}"; if [[ "$cur" == true ]]; then config_set "$1" false; else config_set "$1" true; fi
    ok "$2: ${!1}"; sleep 0.6
}
st_learn()   { _toggle LEARN_MODE "Learn mode (explains commands)"; }
st_dry()     { _toggle DRY_RUN "Dry-run (show, never execute)"; }
st_audit()   { _toggle AUDIT_ENABLED "Audit logging"; }
st_confirm() { _toggle CONFIRM_DANGEROUS "Type-yes confirmation for dangerous actions"; }
st_editor()  { header "Editor"; local e; ask e "Editor command (blank = auto):" "$(editor)"; [[ -z "$e" || "$e" =~ ^[A-Za-z0-9._-]+$ ]] || { err "Invalid."; pause; return; }; config_set EDITOR_CMD "$e"; ok "Saved."; pause; }
st_show()    { header "Current settings"; printf '  %-20s %s\n' Learn\ mode "$LEARN_MODE" Dry-run "$DRY_RUN" Audit "$AUDIT_ENABLED" Confirm\ danger "$CONFIRM_DANGEROUS" Editor "${EDITOR_CMD:-auto ($(editor))}"; echo; printf '  Config: %s\n  Log:    %s\n' "$CONFIG_FILE" "$LOG_FILE"; pause; }
st_reset()   { header "Reset settings"; confirm "Restore defaults?" && { write_default_config; load_config; AUDIT_ENABLED=true; CONFIRM_DANGEROUS=true; DRY_RUN=false; LEARN_MODE=false; EDITOR_CMD=""; ok "Defaults restored."; }; pause; }
about() {
    header "About"
    printf '%s\n' "${_TUX[@]}" | sed "s/^/  ${Y}/; s/\$/${RST}/"
    cat <<A
  ${BOLD}$LP_NAME v$LP_VERSION${RST} — a Linux toolkit for learners, sysadmins and power users.
  Author:  $LP_AUTHOR
  Project: $LP_URL
  License: MIT

  Tips:  ${G}linuxpilot --learn${RST}   explains every command it runs
         ${G}linuxpilot --how port${RST} searches the recipe book from the shell
         ${G}linuxpilot --doctor${RST}   health check, usable in scripts / cron
A
    pause
}
settings_menu() {
    menu "Settings  🔩" "$M" "🎓  Toggle Learn mode|st_learn" "🧪  Toggle Dry-run mode|st_dry" "📑  Toggle audit logging|st_audit" \
        "🚧  Toggle strict confirmations|st_confirm" "📝  Set editor|st_editor" "👀  Show settings|st_show" "🔁  Reset to defaults|st_reset" "📇  About|about"
}
register_module "🔩  Settings & About" settings_menu
