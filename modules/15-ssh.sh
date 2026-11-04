# shellcheck shell=bash
# SSH key manager

SSH_DIR="$HOME/.ssh"
ssh_list() {
    header "Your SSH keys"; [[ -d "$SSH_DIR" ]] || { warn "No ~/.ssh directory yet."; pause; return; }
    local f found=0; while IFS= read -r -d '' f; do found=1; printf '  %s\n    ' "$f"; ssh-keygen -lf "$f" 2>/dev/null || echo "(unreadable)"; done < <(find "$SSH_DIR" -maxdepth 1 -name '*.pub' -print0)
    (( found )) || info "No public keys found. Generate one first."; pause
}
ssh_gen() {
    header "Generate SSH key"; explain "ed25519 is modern, short and secure. A passphrase protects the key if your laptop is stolen."
    has ssh-keygen || { err "ssh-keygen not installed (package: openssh-client)."; pause; return; }
    local name email f; ask name "File name:" "id_ed25519"; [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || { err "Invalid name."; pause; return; }
    f="$SSH_DIR/$name"; [[ -e "$f" ]] && { err "$f already exists — refusing to overwrite."; pause; return; }
    ask email "Comment (e.g. you@example.com):" "$(whoami)@$(hostname)"; mkdir -p "$SSH_DIR"; chmod 700 "$SSH_DIR"
    run "Generate key" ssh-keygen -t ed25519 -a 100 -C "$email" -f "$f" && { echo; info "Public key (safe to share):"; cat "$f.pub"; }; pause
}
ssh_pub() { header "Show public key"; local f; ask_path f "Key file:" "$SSH_DIR/id_ed25519.pub"; require_path "$f" file || { pause; return; }; [[ "$f" == *.pub ]] || { err "Only .pub files are shown — never share the private key."; pause; return; }; cat "$f"; pause; }
ssh_copy() {
    header "Install key on a server"; explain "ssh-copy-id appends your public key to the server's ~/.ssh/authorized_keys so you can log in without a password."
    local t k; ask t "user@host:"; [[ "$t" =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9._:-]+$ ]] || { err "Use the form user@host."; pause; return; }
    ask_path k "Public key:" "$SSH_DIR/id_ed25519.pub"; require_path "$k" file || { pause; return; }; run "ssh-copy-id" ssh-copy-id -i "$k" "$t"; pause
}
ssh_auth() {
    header "authorized_keys"; local f="$SSH_DIR/authorized_keys"; [[ -f "$f" ]] || { info "No authorized_keys file."; pause; return; }
    info "Who can log in to THIS account with a key:"; while read -r l; do [[ -n "$l" && "$l" != \#* ]] && echo "$l" | ssh-keygen -lf - 2>/dev/null | sed 's/^/  /'; done < "$f"
    stat -c '  perms: %a (should be 600 or 644)' "$f"; pause
}
ssh_test() {
    header "Test SSH connection"; local t p; ask t "user@host:"; [[ "$t" =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9._:-]+$ ]] || { err "Use user@host."; pause; return; }
    ask p "Port:" 22; valid_port "$p" || { pause; return; }; view_cmd ssh -p "$p" -o BatchMode=yes -o ConnectTimeout=6 "$t" 'echo "connected as $(whoami) on $(hostname)"'; pause
}
ssh_agent() { header "ssh-agent"; if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then ssh-add -l 2>&1 | sed 's/^/  /'; else warn "No ssh-agent running. Start one with: eval \$(ssh-agent)"; fi; pause; }
ssh_fix() {
    header "Fix ~/.ssh permissions"; explain "SSH refuses keys when permissions are too open. This sets safe values."
    [[ -d "$SSH_DIR" ]] || { err "No ~/.ssh."; pause; return; }
    confirm "Set 700 on ~/.ssh and 600 on private keys?" || return
    run "chmod 700 ~/.ssh" chmod 700 "$SSH_DIR"
    local f; for f in "$SSH_DIR"/id_* "$SSH_DIR"/authorized_keys "$SSH_DIR"/config; do [[ -f "$f" ]] && { [[ "$f" == *.pub ]] && run "644 $f" chmod 644 "$f" || run "600 $f" chmod 600 "$f"; }; done; pause
}
ssh_menu() {
    menu "SSH Key Manager  🔑" "$G" "📋  List keys|ssh_list" "🆕  Generate key|ssh_gen" "👀  Show public key|ssh_pub" "📤  Install key on server|ssh_copy" \
        "🔓  authorized_keys|ssh_auth" "🔌  Test connection|ssh_test" "🧰  ssh-agent|ssh_agent" "🩹  Fix permissions|ssh_fix"
}
register_module "🔑  SSH Key Manager" ssh_menu
