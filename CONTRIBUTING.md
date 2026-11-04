# Contributing

A new feature is one file in `modules/`, named `NN-name.sh` (the number sets the menu order).

```bash
# shellcheck shell=bash
my_action() { header "Title"; explain "What this does, for beginners."; run_root "Do it" some-command; pause; }
my_menu()   { menu "My Module" "$C" "Do the thing|my_action"; }
register_module "My Module" my_menu          # add  root  as a third word if it mostly needs sudo
```

Guidelines
- Use `run` / `run_root` for anything that changes the system (they show the command, log it and respect dry-run).
- Validate input with the `valid_*` helpers and confirm destructive actions with `confirm_danger`.
- End each action with `pause`.
- Before a pull request run `bash tests/smoke.sh` and ShellCheck.
