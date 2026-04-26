# todo_wallpaper Agent Instructions

This directory is a todo_wallpaper runtime or source checkout. Use `agent/SKILL.md` as the full operating contract.

Start by reading:

```text
~/.config/todo_wallpaper/config.env
```

Then choose the interface strictly from `MODE`:

- `MODE=self-contained`: use the `todo-wallpaper` CLI only if `command -v todo-wallpaper` succeeds. If the CLI is missing, stop and report that the self-contained install is incomplete.
- `MODE=agent-skill`: do not call `todo-wallpaper`; it is intentionally not installed. Use only the configured runtime scripts.

Agent-skill primitives:

```bash
$INSTALL_DIR/scripts/run_wallpaper_job.sh ~/.config/todo_wallpaper/config.env
$INSTALL_DIR/scripts/edit_todo.py list "$TODO_FILE"
$INSTALL_DIR/scripts/apply_wallpaper.sh apply "$BACKEND" "$OUTPUT_FILE" "$SCREEN"
```

Rules:

- Edit the configured `TODO_FILE`, not runtime implementation files, unless the user asks to change the tool itself.
- Preserve task syntax: `[H]`, `[M]`, `[ ]`, and `[X]`.
- Refresh explicitly after task edits using the interface allowed by `MODE`.
- Do not enable watchers, systemd units, cron jobs, or background automation unless the user explicitly asks.
- Do not install or assume any model-specific provider/tooling.
- Use the installed scripts as source of truth for rendering and wallpaper application.
