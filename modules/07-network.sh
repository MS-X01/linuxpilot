# shellcheck shell=bash
# Network tools

n_ifaces() { header "Interfaces"; req ip iproute2 || { pause; return; }; if has ip; then ip -br link | sed 's/^/  /'; else ifconfig -a; fi; pause; }
n_ips()    { header "IP addresses"; req ip iproute2 || { pause; return; }; ip -br addr 2>/dev/null | sed 's/^/  /'; echo; info "Default gateway: $(ip route 2>/dev/null | awk '/^default/{print $3" via "$5; exit}')"; pause; }
n_listen() {
    header "Listening ports"; explain "Shows which programs accept connections. Anything on 0.0.0.0 or :: is reachable from the network."
    if has ss; then ${SUDO[@]+"${SUDO[@]}"} ss -tulpn | sed 's/^/  /' | pager; else netstat -tulpn 2>/dev/null | pager; fi; pause
}
n_conns() { header "Active connections"; req ss iproute2 || { pause; return; }; ss -tn state established 2>/dev/null | sed 's/^/  /' | head -40; echo; info "Established: $(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)"; pause; }
n_ping() {
    header "Ping"; req ping iputils-ping || { pause; return; }; local h c; ask h "Host:" "1.1.1.1"; valid_host "$h" || { pause; return; }; ask c "Count:" 4; valid_number "$c" || c=4
    (( c > 50 )) && c=50; view_cmd ping -c "$c" "$h"; pause
}
n_dns() {
    header "DNS lookup"; local h; ask h "Domain:"; need "$h" Domain && valid_host "$h" || { pause; return; }
    if has dig; then dig +short "$h" A "$h" AAAA | sed 's/^/  /'; echo; dig +short MX "$h" | sed 's/^/  MX /'; dig +short NS "$h" | sed 's/^/  NS /'
    elif has host; then host "$h"; elif has nslookup; then nslookup "$h"; else getent hosts "$h"; warn "Install dnsutils/bind-utils for dig."; fi; pause
}
n_trace() { header "Traceroute"; local h; ask h "Host:" "1.1.1.1"; valid_host "$h" || { pause; return; }
    if has mtr; then view_cmd mtr -rwc 5 "$h"; elif has traceroute; then view_cmd traceroute "$h"; elif has tracepath; then view_cmd tracepath "$h"; else warn "Install traceroute or mtr."; fi; pause; }
n_routes() { header "Routing table"; req ip iproute2 || { pause; return; }; ip route | sed 's/^/  /'; pause; }
n_bw() {
    header "Bandwidth (3 second sample)"; req ip iproute2 || { pause; return; }
    local ifc; ifc="$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')"; [[ -n "$ifc" ]] || { err "No default interface."; pause; return; }
    local rx1 tx1 rx2 tx2
    rx1=$(<"/sys/class/net/$ifc/statistics/rx_bytes"); tx1=$(<"/sys/class/net/$ifc/statistics/tx_bytes"); info "Measuring $ifc …"; sleep 3
    rx2=$(<"/sys/class/net/$ifc/statistics/rx_bytes"); tx2=$(<"/sys/class/net/$ifc/statistics/tx_bytes")
    printf '  ↓ Download: %d KB/s\n  ↑ Upload:   %d KB/s\n' $(( (rx2-rx1)/3072 )) $(( (tx2-tx1)/3072 )); pause
}
n_pubip() {
    header "Public IP"; has curl || { err "curl is required."; pause; return; }
    warn "This contacts an external service (ifconfig.me)."; confirm "Continue?" || return
    local ip; ip="$(curl -fsS --max-time 8 https://ifconfig.me 2>/dev/null)"; [[ -n "$ip" ]] || { err "Could not reach the internet."; pause; return; }
    ok "Public IP: $ip"; pause
}
n_arp() { header "Neighbours (ARP)"; req ip iproute2 || { pause; return; }; ip neigh | sed 's/^/  /'; pause; }
n_port() {
    header "Is a port open?"; explain "Tries to open a TCP connection with bash's built-in /dev/tcp."
    local h p; ask h "Host:"; valid_host "$h" || { pause; return; }; ask p "Port:"; valid_port "$p" || { pause; return; }
    if timeout 4 bash -c "exec 3<>/dev/tcp/$h/$p" 2>/dev/null; then ok "$h:$p is OPEN"; else warn "$h:$p is closed, filtered or unreachable"; fi; pause
}
n_http() {
    header "HTTP check"; has curl || { err "curl is required."; pause; return; }
    local u; ask u "URL:" "https://example.com"; [[ "$u" =~ ^https?://[A-Za-z0-9._:/?=\&%~#+-]+$ ]] || { err "Enter a valid http(s) URL."; pause; return; }
    curl -sS -o /dev/null -L --max-time 10 -w '  Status: %{http_code}\n  Time:   %{time_total}s\n  IP:     %{remote_ip}\n  Final:  %{url_effective}\n' "$u"; pause
}
n_wifi() { header "Wi-Fi networks"; if has nmcli; then nmcli -f SSID,SIGNAL,SECURITY dev wifi list | sed 's/^/  /'; else warn "nmcli (NetworkManager) not found."; fi; pause; }

network_menu() {
    menu "Network Tools" "$G" \
        "🔌  Interfaces|n_ifaces" "🔖  IP addresses & gateway|n_ips" "👂  Listening ports|n_listen" "🔗  Active connections|n_conns" \
        "📡  Ping|n_ping" "🔤  DNS lookup|n_dns" "🚦  Traceroute|n_trace" "🧭  Routing table|n_routes" "📶  Bandwidth sample|n_bw" \
        "🌍  Public IP|n_pubip" "👀  ARP neighbours|n_arp" "🚪  Is this port open?|n_port" "🌐  HTTP check|n_http" "📶  Wi-Fi networks|n_wifi"
}
register_module "🌐  Network Tools" network_menu
