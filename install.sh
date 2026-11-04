#!/usr/bin/env bash
# LinuxPilot installer.  sudo ./install.sh  → /usr/local   |   ./install.sh  → ~/.local
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
if [[ $EUID -eq 0 ]]; then PREFIX=/usr/local; else PREFIX="$HOME/.local"; fi
SHARE="$PREFIX/share/linuxpilot"; BIN="$PREFIX/bin"
echo "Installing LinuxPilot to $SHARE"
mkdir -p "$SHARE" "$BIN"
rm -rf "$SHARE"; mkdir -p "$SHARE"
cp -r "$SRC"/linuxpilot "$SRC"/lib "$SRC"/modules "$SRC"/data "$SRC"/completions "$SRC"/VERSION "$SHARE"/
COMP="$PREFIX/share/bash-completion/completions"; mkdir -p "$COMP"; cp "$SRC/completions/linuxpilot.bash" "$COMP/linuxpilot"
chmod +x "$SHARE/linuxpilot"
ln -sf "$SHARE/linuxpilot" "$BIN/linuxpilot"
[[ -d /etc/bash_completion.d && $EUID -eq 0 ]] && cp "$SRC/completions/linuxpilot.bash" /etc/bash_completion.d/linuxpilot
echo "Done. Run:  linuxpilot"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "Note: add $BIN to your PATH (e.g. echo 'export PATH=\"$BIN:\$PATH\"' >> ~/.bashrc)";; esac
