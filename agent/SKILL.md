# todo_wallpaper Agent Skill

Use this skill to manage a local todo_wallpaper runtime without relying on watcher, background service, or model-specific prompt handoff. The allowed control interface depends strictly on the installed `MODE`.

## Purpose

todo_wallpaper turns a markdown TODO list into a desktop wallpaper. The agent is the controller: it reads configuration, edits the configured TODO markdown, renders the wallpaper, and applies it through the installed runtime scripts.

## Runtime Contract

The runtime is expected to be installed under `INSTALL_DIR`, usually:

```text
~/.local/share/todo_wallpaper
```

The config is expected at:

```text
~/.config/todo_wallpaper/config.env
```

Always read the config first. It defines the supported paths and options:

- `MODE`
- `TODO_FILE`
- `OUTPUT_FILE`
- `BACKEND`
- `RESOLVED_BACKEND`
- `SCREEN`
- `BOX_POSITION`
- `DISPLAY_ORDER_PRIORITIES`
- `FONT_NAME`
- `WIDTH`
- `HEIGHT`
- `SCALE`
- `APPLY_WALLPAPER`
- `INSTALL_DIR`
- `CONFIG_DIR`

## Mode Detection

Read `~/.config/todo_wallpaper/config.env` before doing anything else. The `MODE` value controls which interface is allowed.

- `MODE=self-contained`: the installed `todo-wallpaper` CLI is the primary interface. Use it only after verifying `command -v todo-wallpaper` succeeds. If it is missing, stop and report that the self-contained install is incomplete.
- `MODE=agent-skill`: the CLI is intentionally not installed. Do not call `todo-wallpaper`. Use only the configured runtime scripts under `INSTALL_DIR`.

Do not switch interfaces silently. If the allowed interface is unavailable, report the missing piece and ask the user whether to reinstall or repair.

## Runtime Script Primitives

In `MODE=agent-skill`, use these installed scripts as the implementation source of truth:

```bash
$INSTALL_DIR/scripts/run_wallpaper_job.sh ~/.config/todo_wallpaper/config.env
$INSTALL_DIR/scripts/render_todo_wallpaper.py "$TODO_FILE" --output "$OUTPUT_FILE"
$INSTALL_DIR/scripts/apply_wallpaper.sh apply "$BACKEND" "$OUTPUT_FILE" "$SCREEN"
$INSTALL_DIR/scripts/edit_todo.py list "$TODO_FILE"
$INSTALL_DIR/uninstall.sh
```

Use `run_wallpaper_job.sh` for normal agent-skill refreshes because it applies the configured render options consistently.

## Self-Contained CLI Primitives

In `MODE=self-contained`, use the installed CLI after verifying it exists:

```bash
command -v todo-wallpaper
todo-wallpaper list
todo-wallpaper add -H "pay electricity bill"
todo-wallpaper done -n 2
todo-wallpaper refresh
todo-wallpaper status
```

Do not use the CLI in `MODE=agent-skill`.

## Persistent Discovery

Agent-skill installs also place an `AGENTS.md` file in `INSTALL_DIR`. Agents that automatically read project instructions can be started directly in the runtime directory:

```bash
cd ~/.local/share/todo_wallpaper
```

The `AGENTS.md` file is intentionally short. This `agent/SKILL.md` file is the detailed reference.

## Task Syntax

Preserve markdown checkbox task syntax:

```md
- [H] high priority task
- [M] medium priority task
- [ ] normal task
- [X] completed task
```

Checked tasks remain visible and render with strike-through styling.

## Agent Rules

- Treat `INSTALL_DIR` as runtime/tooling, not as the user's task repository.
- Edit only the configured `TODO_FILE` unless the user asks for another file.
- Keep the real TODO markdown outside the runtime directory when practical.
- Do not recreate renderer or wallpaper backend logic; use the installed scripts.
- Do not call `todo-wallpaper` unless `MODE=self-contained` and the CLI exists.
- Do not call runtime scripts directly for task edits in `MODE=self-contained` unless the user explicitly asks to bypass the CLI for debugging.
- Do not enable systemd units, watchers, cron jobs, or background automation unless the user explicitly asks.
- Do not install model-specific tooling or assume a specific AI provider/model.
- Before destructive cleanup, explain what `uninstall.sh` will remove and ask for confirmation.
- If wallpaper application fails, run or inspect the configured backend and report the specific missing command or session mismatch.

## Best Practices

- Keep changes small: edit only the specific task lines requested by the user.
- In agent-skill mode, prefer the configured `edit_todo.py` for line-numbered operations because it preserves numbering semantics and creates backups.
- In self-contained mode, prefer the `todo-wallpaper` CLI for line-numbered operations.
- If manually editing the TODO file, keep headings and non-task notes intact.
- Before marking/removing several tasks, list tasks first so line numbers match the current display order.
- After edits, run one refresh, not a refresh after every individual line change.
- Report the rendered output path after a successful refresh.
- If `APPLY_WALLPAPER=0`, explain that rendering succeeded but wallpaper application is disabled.
- If `BACKEND=none`, explain that no desktop wallpaper backend will be applied.
- If the TODO file is missing, ask whether to create it unless the user explicitly requested a new task file.
- If a command fails, report the exact failing primitive and stderr summary; do not silently fall back to reimplementing behavior.

## Safe Edit Examples

Agent-skill list tasks:

```bash
$INSTALL_DIR/scripts/edit_todo.py list "$TODO_FILE"
```

Agent-skill add a task by editing the markdown or by using the edit primitive:

```bash
$INSTALL_DIR/scripts/edit_todo.py add "$TODO_FILE" -H "pay electricity bill"
```

Agent-skill mark visible item 2 complete:

```bash
$INSTALL_DIR/scripts/edit_todo.py done "$TODO_FILE" -n 2
```

Agent-skill refresh once after edits:

```bash
$INSTALL_DIR/scripts/run_wallpaper_job.sh ~/.config/todo_wallpaper/config.env
```

## Troubleshooting

- If rendering fails, check `python3`, Pillow, `TODO_FILE`, and output directory permissions.
- If applying fails, check `BACKEND`, `RESOLVED_BACKEND`, `SCREEN`, and whether the backend command exists in the current desktop session.
- If the wallpaper appears cached/stale, run the normal refresh primitive again; it generates timestamped output files through `run_wallpaper_job.sh`.
- If task order looks unexpected, check `DISPLAY_ORDER_PRIORITIES`; when true, high priority tasks display before medium and normal tasks without rewriting markdown order.

## Common Flow

1. Read `~/.config/todo_wallpaper/config.env`.
2. Detect `MODE` and select the allowed interface.
3. Confirm `TODO_FILE` exists; create it only if the user wants a new TODO file.
4. Edit tasks using the allowed interface and existing priority syntax.
5. Refresh wallpaper once using the allowed interface.
6. Report the rendered wallpaper path or the concrete failure.
Self-contained equivalents:

```bash
todo-wallpaper list
todo-wallpaper add -H "pay electricity bill"
todo-wallpaper done -n 2
todo-wallpaper refresh
```
