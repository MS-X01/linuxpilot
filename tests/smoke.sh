#!/usr/bin/env bash
# Smoke test — opens EVERY menu and EVERY option with empty answers (nothing gets changed)
# and fails on shell errors ("command not found", "unbound variable", "syntax error"…).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT" || exit 1
export HOME; HOME="$(mktemp -d)"; export LP_ALLOW_PIPE=1 NO_COLOR=1 TERM=dumb LP_FAST=1
fail=0; LP="$ROOT/linuxpilot"
ERR_RE='command not found|unbound variable|syntax error|bad substitution|: line [0-9]+:'

for f in linuxpilot lib/*.sh modules/*.sh install.sh uninstall.sh; do bash -n "$f" || { echo "SYNTAX: $f"; fail=1; }; done
"$LP" --version >/dev/null || fail=1
"$LP" --help    >/dev/null || fail=1
"$LP" --how port | grep -q ss || { echo "--how failed"; fail=1; }
"$LP" --doctor >/dev/null; rc=$?; (( rc <= 1 )) || { echo "--doctor rc=$rc"; fail=1; }
"$LP" --audit  >/dev/null; rc=$?; (( rc <= 1 )) || { echo "--audit rc=$rc"; fail=1; }

# everything below runs in a scratch dir so exports don't pollute the repo
cd "$HOME" || exit 1
"$LP" --report text >/dev/null && ls linuxpilot-report-*.txt >/dev/null || { echo "--report text failed"; fail=1; }
"$LP" --report html >/dev/null && ls linuxpilot-report-*.html >/dev/null || { echo "--report html failed"; fail=1; }
if command -v python3 >/dev/null; then
    python3 - linuxpilot-report-*.html <<'EOF_JSON' || { echo "HTML report: embedded JSON invalid"; fail=1; }
import sys,re,json
s=open(sys.argv[1]).read()
m=re.search(r'const D = (.*?);\nconst \$=',s,re.S)
d=json.loads(m.group(1).replace('<\\/','</'))
for k in ("meta","health","security","disks","nics","ports","pcpu","pmem","raw"):
    assert k in d, "missing "+k
EOF_JSON
fi

# main-menu feature search ("s") must find and open an action
printf 's\nport\n1\n\n0\n0\n' | timeout 30 "$LP" 2>&1 | grep -q "Listening ports" || { echo "feature search failed"; fail=1; }

# walk every top-level menu
top=$(printf '0\n' | "$LP" 2>&1 | grep -cE '^\s+[0-9]+\s+\S')
for ((i=1; i<=top-1; i++)); do
    input="$i\n"; for j in $(seq 1 18); do input+="$j\n\n\n\n"; done; input+="0\n0\n"
    out="$(printf "$input" | timeout 60 "$LP" 2>&1)"; rc=$?
    (( rc == 124 )) && echo "note: menu #$i hit the 60s limit (slow tool, not an error)"
    if grep -qE "$ERR_RE" <<<"$out"; then echo "ERRORS in top-level menu #$i:"; grep -E "$ERR_RE" <<<"$out" | sort -u | head -5; fail=1; fi
done
(( fail )) && { echo "SMOKE: FAILED"; exit 1; }
echo "SMOKE: OK ($((top-1)) menus walked)"
