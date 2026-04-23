#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

. "$SCRIPT_DIR/common.sh"

ACTION="${1:-}"
CONFIG_PATH="${2:-$DEFAULT_CONFIG_FILE}"
shift 2 || true

if [ -z "$ACTION" ]; then
  printf 'usage: %s <refresh|show|hide|status|config|doctor|watch-on|watch-off|list|edit|add|replace|change-priority|done|undone|remove|uninstall>\n' "$0" >&2
  exit 2
fi

load_config "$CONFIG_PATH"

mode="${MODE:-self-contained}"
backend="${RESOLVED_BACKEND:-$(resolve_backend)}"
SCREEN="${SCREEN:-all}"
DISPLAY_ORDER_PRIORITIES="${DISPLAY_ORDER_PRIORITIES:-true}"

show_status() {
  newest=""
  output_dir=$(dirname "$OUTPUT_FILE")
  if [ -d "$output_dir" ]; then
    newest=$(find "$output_dir" -maxdepth 1 -type f -name "$(basename "${OUTPUT_FILE%.*}")-*.${OUTPUT_FILE##*.}" | sort | tail -n 1)
  fi
  printf 'mode: %s\n' "$mode"
  printf 'todo file: %s\n' "$TODO_FILE"
  printf 'output file: %s\n' "$OUTPUT_FILE"
  printf 'backend: %s\n' "$BACKEND"
  printf 'detected backend: %s\n' "$backend"
  printf 'display priority ordering: %s\n' "$DISPLAY_ORDER_PRIORITIES"
  printf 'todo exists: %s\n' "$( [ -f "$TODO_FILE" ] && printf yes || printf no )"
  printf 'output dir exists: %s\n' "$( [ -d "$output_dir" ] && printf yes || printf no )"
  printf 'newest rendered wallpaper: %s\n' "${newest:-none}"
  if [ -f "$TODO_FILE" ]; then
    printf 'visible order preview:\n'
    /usr/bin/python3 "$PROJECT_DIR/scripts/edit_todo.py" --display-order-priorities "$DISPLAY_ORDER_PRIORITIES" list "$TODO_FILE" | sed -n '1,5p'
  fi
  if [ "$mode" = "self-contained" ]; then
    if systemctl --user is-active --quiet todo-wallpaper.path; then
      printf 'watcher: on\n'
    else
      printf 'watcher: off\n'
    fi
  fi
}

show_config() {
  printf 'config file: %s\n' "$CONFIG_PATH"
  printf 'mode: %s\n' "$mode"
  printf 'todo file: %s\n' "$TODO_FILE"
  printf 'output file: %s\n' "$OUTPUT_FILE"
  printf 'backend: %s\n' "$BACKEND"
  printf 'screen: %s\n' "$SCREEN"
  printf 'box position: %s\n' "$BOX_POSITION"
  printf 'display priority ordering: %s\n' "$DISPLAY_ORDER_PRIORITIES"
}

run_doctor() {
  printf 'todo file exists: %s\n' "$( [ -f "$TODO_FILE" ] && printf yes || printf no )"
  printf 'config file exists: %s\n' "$( [ -f "$CONFIG_PATH" ] && printf yes || printf no )"
  printf 'renderer available: %s\n' "$( [ -f "$PROJECT_DIR/scripts/render_todo_wallpaper.py" ] && printf yes || printf no )"
  printf 'apply helper available: %s\n' "$( [ -f "$PROJECT_DIR/scripts/apply_wallpaper.sh" ] && printf yes || printf no )"
  printf 'detected backend: %s\n' "$backend"
  printf 'python3: %s\n' "$(command -v python3 || printf missing)"
  printf 'systemctl --user: %s\n' "$(command -v systemctl || printf missing)"
}

case "$ACTION" in
  refresh|show)
    "$PROJECT_DIR/scripts/run_wallpaper_job.sh" "$CONFIG_PATH"
    ;;
  hide)
    ensure_black_wallpaper
    "$PROJECT_DIR/scripts/apply_wallpaper.sh" apply "$backend" "$BLANK_WALLPAPER" "$SCREEN"
    ;;
  status)
    show_status
    ;;
  config)
    show_config
    ;;
  doctor)
    run_doctor
    ;;
  list)
    /usr/bin/python3 "$PROJECT_DIR/scripts/edit_todo.py" --display-order-priorities "$DISPLAY_ORDER_PRIORITIES" list "$TODO_FILE"
    ;;
  edit)
    editor="${EDITOR:-vi}"
    exec "$editor" "$TODO_FILE"
    ;;
  watch-on)
    if [ "$mode" != "self-contained" ]; then
      printf 'watcher is only available in self-contained mode\n' >&2
      exit 1
    fi
    systemctl --user enable --now todo-wallpaper.path
    ;;
  watch-off)
    if [ "$mode" != "self-contained" ]; then
      printf 'watcher is only available in self-contained mode\n' >&2
      exit 1
    fi
    systemctl --user disable --now todo-wallpaper.path >/dev/null 2>&1 || true
    systemctl --user stop todo-wallpaper.service >/dev/null 2>&1 || true
    ;;
  add)
    if [ "$#" -eq 0 ]; then
      printf 'usage: todo-wallpaper add [-n LINE] [-H|--high|-M|--medium|-N|--normal] <task text>\n' >&2
      exit 2
    fi
    /usr/bin/python3 "$PROJECT_DIR/scripts/edit_todo.py" --display-order-priorities "$DISPLAY_ORDER_PRIORITIES" add "$TODO_FILE" "$@"
    "$PROJECT_DIR/scripts/run_wallpaper_job.sh" "$CONFIG_PATH"
    ;;
  replace)
    if [ "$#" -eq 0 ]; then
      printf 'usage: todo-wallpaper replace -n LINE [-H|--high|-M|--medium|-N|--normal] <task text>\n' >&2
      exit 2
    fi
    /usr/bin/python3 "$PROJECT_DIR/scripts/edit_todo.py" --display-order-priorities "$DISPLAY_ORDER_PRIORITIES" replace "$TODO_FILE" "$@"
    "$PROJECT_DIR/scripts/run_wallpaper_job.sh" "$CONFIG_PATH"
    ;;
  change-priority)
    if [ "$#" -lt 3 ]; then
      printf 'usage: todo-wallpaper change-priority -n LINE (-H|--high|-M|--medium|-N|--normal|high|medium|normal)\n' >&2
      exit 2
    fi
    /usr/bin/python3 "$PROJECT_DIR/scripts/edit_todo.py" --display-order-priorities "$DISPLAY_ORDER_PRIORITIES" change-priority "$TODO_FILE" "$@"
    "$PROJECT_DIR/scripts/run_wallpaper_job.sh" "$CONFIG_PATH"
    ;;
  done)
    if [ "$#" -lt 2 ]; then
      printf 'usage: todo-wallpaper done -n LINE [-n LINE ...]\n' >&2
      exit 2
    fi
    /usr/bin/python3 "$PROJECT_DIR/scripts/edit_todo.py" --display-order-priorities "$DISPLAY_ORDER_PRIORITIES" done "$TODO_FILE" "$@"
    "$PROJECT_DIR/scripts/run_wallpaper_job.sh" "$CONFIG_PATH"
    ;;
  undone)
    if [ "$#" -lt 2 ]; then
      printf 'usage: todo-wallpaper undone -n LINE [-n LINE ...]\n' >&2
      exit 2
    fi
    /usr/bin/python3 "$PROJECT_DIR/scripts/edit_todo.py" --display-order-priorities "$DISPLAY_ORDER_PRIORITIES" undone "$TODO_FILE" "$@"
    "$PROJECT_DIR/scripts/run_wallpaper_job.sh" "$CONFIG_PATH"
    ;;
  remove)
    if [ "$#" -lt 2 ]; then
      printf 'usage: todo-wallpaper remove -n LINE [-n LINE ...]\n' >&2
      exit 2
    fi
    /usr/bin/python3 "$PROJECT_DIR/scripts/edit_todo.py" --display-order-priorities "$DISPLAY_ORDER_PRIORITIES" remove "$TODO_FILE" "$@"
    "$PROJECT_DIR/scripts/run_wallpaper_job.sh" "$CONFIG_PATH"
    ;;
  uninstall)
    exec "$PROJECT_DIR/uninstall.sh"
    ;;
  *)
    printf 'unsupported action: %s\n' "$ACTION" >&2
    exit 2
    ;;
esac
