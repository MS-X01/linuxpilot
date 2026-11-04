#!/usr/bin/env bash
# Removes LinuxPilot (your config and audit log are kept unless you pass --purge)
if [[ $EUID -eq 0 ]]; then PREFIX=/usr/local; else PREFIX="$HOME/.local"; fi
rm -rf "$PREFIX/share/linuxpilot" "$PREFIX/bin/linuxpilot" "$PREFIX/share/bash-completion/completions/linuxpilot"
if [[ "$1" == "--purge" ]]; then rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/linuxpilot" "${XDG_STATE_HOME:-$HOME/.local/state}/linuxpilot"; fi
echo "LinuxPilot removed from $PREFIX."
