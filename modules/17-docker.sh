# shellcheck shell=bash
# Docker helper (shown only if docker is installed)

_dk() { if docker info &>/dev/null; then docker "$@"; else ${SUDO[@]+"${SUDO[@]}"} docker "$@"; fi; }
dk_ps()     { header "Containers"; view_cmd _dk ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}' | sed 's/^/  /'; pause; }
dk_images() { header "Images"; _dk images | sed 's/^/  /'; pause; }
dk_stats()  { header "Resource usage"; _dk stats --no-stream | sed 's/^/  /'; pause; }
_dk_name()  { local n; ask n "Container name or ID:"; [[ "$n" =~ ^[A-Za-z0-9_.-]+$ ]] || { err "Invalid name."; return 1; }; DKN="$n"; }
dk_logs()   { header "Container logs"; _dk_name && _dk logs --tail 80 "$DKN" 2>&1 | pager; pause; }
dk_start()  { header "Start container"; _dk_name && run "Start $DKN" _dk start "$DKN"; pause; }
dk_stop()   { header "Stop container"; _dk_name && run "Stop $DKN" _dk stop "$DKN"; pause; }
dk_restart(){ header "Restart container"; _dk_name && run "Restart $DKN" _dk restart "$DKN"; pause; }
dk_shell()  { header "Shell in container"; _dk_name && { info "Type 'exit' to return."; _dk exec -it "$DKN" sh -c 'command -v bash >/dev/null && exec bash || exec sh'; }; }
dk_prune()  { header "Clean up Docker"; explain "Removes stopped containers, unused networks and dangling images."; confirm_danger "Unused Docker objects will be deleted." && run "docker system prune" _dk system prune -f; pause; }
dk_disk()   { header "Docker disk usage"; _dk system df | sed 's/^/  /'; pause; }
docker_menu() {
    menu "Docker  🐳" "$C" "📋  Containers|dk_ps" "📀  Images|dk_images" "📈  Resource usage|dk_stats" "📜  Logs|dk_logs" "⏩  Start|dk_start" "🛑  Stop|dk_stop" \
        "🔁  Restart|dk_restart" "💻  Shell inside container|dk_shell" "💽  Disk usage|dk_disk" "🧹  Prune unused|dk_prune"
}
has docker && register_module "🐳  Docker" docker_menu
