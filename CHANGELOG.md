# Changelog

## 5.2.0
- Dashboard: new colour scheme (dark and light), new logo, "Needs attention" list, notice when generated without root.
- Menus now mark sections that need administrator rights with `[sudo]`; actions that use sudo say so first; audit and report warn when run without root.
- New: press `s` in the main menu to search every feature by keyword.
- Cleaner README, author and repository links updated.

## 5.1.0
- **HTML report is now a real dashboard**: score rings, gauges, sortable/filterable tables, exposure badges, dark/light theme, JSON export, raw-output section. Single self-contained file.
- **Audit & Compliance** module: ~20-check security audit with score and fix hints (+ Markdown export), baseline snapshot & diff, activity-log filter/stats/CSV export, auditd helpers. New `--audit` CLI flag.
- Modules renumbered 01-20 in menu order. Bash completion. README rewritten with banner, screenshots and tested matrix.
- Health/Security results are now recorded data, reused by reports.

## 5.1.0 — audit, dashboard, tidy modules, new README

(see below — this release also includes everything from the 5.0.0 modular rewrite)

## 5.0.0 — modular rewrite
- Split the 2,500-line single file into `lib/` (core, ui, input) and drop-in `modules/`.
- **Fixed the root cause of "features don't work":** `set -e` killed the script whenever any command returned non-zero (a cancelled prompt, an empty grep…). Error handling is now explicit.
- Config file is parsed, not `source`d. No more nameref prompts (Ctrl+C / EOF safe). No more lock file.
- New: Linux Academy (how-do-I recipes, cheat sheets, explain-a-command, filesystem tour, glossary), Learn Mode, Dry-run mode.
- New: Health Check (`--doctor`), Quick Security Audit, Backup, Docker helper, sudo grant/revoke, firewalld support, permission calculator, tool bundles.
- New CLI: `--how`, `--doctor`, `--report [text|html]`, `--learn`, `--dry-run`, `--no-color`.
- New: installer/uninstaller, bash completion, smoke test, GitHub Actions CI.
- **Audit & Compliance module:** security audit with 0-100 score and fix hints (+ Markdown export, `--audit`), baseline snapshot & diff, filterable activity log with stats / CSV export / integrity check, auditd helpers.
- **HTML report is now a designed standalone dashboard** (gauges, sortable tables, port exposure badges, health & security scores, dark/light, print, JSON export, mobile) instead of command output in a `<pre>`.
- Modules renumbered 01–20 (contiguous, one per menu entry); consistent emoji widths in menus.
