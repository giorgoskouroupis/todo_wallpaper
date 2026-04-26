#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$PROJECT_DIR/scripts/common.sh"

MODE="self-contained"
BACKEND="auto"
SCREEN="all"
TODO_FILE="$DEFAULT_INSTALL_DIR/TODO.md"
OUTPUT_FILE="$HOME/Pictures/Wallpapers/TODO/todo-wallpaper.png"
BOX_POSITION="right"
DISPLAY_ORDER_PRIORITIES="true"
FONT_NAME=""
WIDTH=""
HEIGHT=""
SCALE="3.0"
APPLY_WALLPAPER="1"
ENABLE_WATCHER="1"
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
CONFIG_DIR="$DEFAULT_CONFIG_DIR"
UNIT_DIR="$DEFAULT_UNIT_DIR"
BIN_DIR="$HOME/.local/bin"
INSTALLED_ITEMS=""
TODO_FILE_SET="0"

usage() {
  printf '%s\n' 'todo_wallpaper installer'
  printf '\n'
  printf 'usage: %s [options]\n' "$0"
  printf '\n'
  printf '%s\n' 'modes:'
  printf '%s\n' '  default      self-contained install with local command and optional watcher'
  printf '%s\n' '  --agent-skill install runtime plus model-agnostic agent skill, without CLI or watcher'
  printf '\n'
  printf '%s\n' 'options:'
  printf '%s\n' '  --agent-skill              install runtime plus model-agnostic agent skill instead of self-contained mode'
  printf '%s\n' '  --backend NAME             wallpaper backend to use; default: auto'
  printf '%s\n' '  --screen NAME              target screen; default: all'
  printf '  --todo-file PATH           todo markdown path; default: runtime TODO.md in self-contained mode, ~/TODO.md in agent-skill mode\n'
  printf '  --output-file PATH         rendered wallpaper path; default: %s\n' "$HOME/Pictures/Wallpapers/TODO/todo-wallpaper.png"
  printf '%s\n' '  --box-position POS         left, center, or right; default: right'
  printf '%s\n' '  --font NAME                optional preferred font name override'
  printf '%s\n' '  --width PX                 force output width instead of auto-detecting monitor size'
  printf '%s\n' '  --height PX                force output height instead of auto-detecting monitor size'
  printf '%s\n' '  --scale VALUE              internal render scale; default: 3.0'
  printf '%s\n' '  --render-only              render wallpapers but do not apply them'
  printf '%s\n' '  --no-enable                do not enable the self-contained watcher after install'
  printf '%s\n' '  -h, --help                 show this help'
  printf '\n'
  printf '%s\n' 'notes:'
  printf '%s\n' '  - priorities use markdown checkbox markers such as [H], [M], and [ ]'
  printf '%s\n' '  - display ordering by priority is enabled by default through DISPLAY_ORDER_PRIORITIES=true'
  printf '%s\n' '  - self-contained mode installs the todo-wallpaper command under ~/.local/bin'
  printf '%s\n' '  - agent-skill mode installs only runtime scripts, config, and a model-agnostic skill file'
}

record_installed() {
  INSTALLED_ITEMS="${INSTALLED_ITEMS}${INSTALLED_ITEMS:+
}$1"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --agent-skill)
      MODE="agent-skill"
      ENABLE_WATCHER="0"
      shift
      ;;
    --backend)
      BACKEND="$2"
      shift 2
      ;;
    --screen)
      SCREEN="$2"
      shift 2
      ;;
    --todo-file)
      TODO_FILE="$2"
      TODO_FILE_SET="1"
      shift 2
      ;;
    --output-file)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --box-position)
      BOX_POSITION="$2"
      shift 2
      ;;
    --font)
      FONT_NAME="$2"
      shift 2
      ;;
    --width)
      WIDTH="$2"
      shift 2
      ;;
    --height)
      HEIGHT="$2"
      shift 2
      ;;
    --scale)
      SCALE="$2"
      shift 2
      ;;
    --render-only)
      APPLY_WALLPAPER="0"
      shift
      ;;
    --no-enable)
      ENABLE_WATCHER="0"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$BOX_POSITION" in
  left|center|right) ;;
  *)
    printf 'invalid box position: %s\n' "$BOX_POSITION" >&2
    exit 2
    ;;
esac

if [ "$MODE" = "agent-skill" ] && [ "$TODO_FILE_SET" = "0" ]; then
  TODO_FILE="$HOME/TODO.md"
fi

ensure_pillow
detect_system_details
if [ "$MODE" = "self-contained" ]; then
  ensure_black_wallpaper
  mkdir -p "$(dirname "$TODO_FILE")" "$(dirname "$OUTPUT_FILE")" "$CONFIG_DIR" "$UNIT_DIR" "$INSTALL_DIR/scripts"
else
  mkdir -p "$(dirname "$TODO_FILE")" "$(dirname "$OUTPUT_FILE")" "$CONFIG_DIR" "$INSTALL_DIR/scripts"
fi

cp "$PROJECT_DIR/scripts/common.sh" "$INSTALL_DIR/scripts/common.sh"
cp "$PROJECT_DIR/scripts/edit_todo.py" "$INSTALL_DIR/scripts/edit_todo.py"
cp "$PROJECT_DIR/scripts/run_wallpaper_job.sh" "$INSTALL_DIR/scripts/run_wallpaper_job.sh"
cp "$PROJECT_DIR/scripts/render_todo_wallpaper.py" "$INSTALL_DIR/scripts/render_todo_wallpaper.py"
cp "$PROJECT_DIR/scripts/apply_wallpaper.sh" "$INSTALL_DIR/scripts/apply_wallpaper.sh"
cp "$PROJECT_DIR/.todo-wallpaper.env.example" "$INSTALL_DIR/.todo-wallpaper.env.example"
cp "$PROJECT_DIR/uninstall.sh" "$INSTALL_DIR/uninstall.sh"
cp "$PROJECT_DIR/AGENTS.md" "$INSTALL_DIR/AGENTS.md"
mkdir -p "$INSTALL_DIR/agent"
cp "$PROJECT_DIR/agent/SKILL.md" "$INSTALL_DIR/agent/SKILL.md"
chmod +x \
  "$INSTALL_DIR/scripts/common.sh" \
  "$INSTALL_DIR/scripts/edit_todo.py" \
  "$INSTALL_DIR/scripts/run_wallpaper_job.sh" \
  "$INSTALL_DIR/scripts/render_todo_wallpaper.py" \
  "$INSTALL_DIR/scripts/apply_wallpaper.sh" \
  "$INSTALL_DIR/uninstall.sh"
record_installed "$INSTALL_DIR/scripts/common.sh"
record_installed "$INSTALL_DIR/scripts/edit_todo.py"
record_installed "$INSTALL_DIR/scripts/run_wallpaper_job.sh"
record_installed "$INSTALL_DIR/scripts/render_todo_wallpaper.py"
record_installed "$INSTALL_DIR/scripts/apply_wallpaper.sh"
record_installed "$INSTALL_DIR/.todo-wallpaper.env.example"
record_installed "$INSTALL_DIR/uninstall.sh"
record_installed "$INSTALL_DIR/AGENTS.md"
record_installed "$INSTALL_DIR/agent/SKILL.md"

if [ ! -f "$TODO_FILE" ]; then
  printf '# TODO\n\n- [ ] replace this with your real tasks\n' > "$TODO_FILE"
  record_installed "$TODO_FILE"
fi

RESOLVED_BACKEND=$(resolve_backend)
write_config "$DEFAULT_CONFIG_FILE"
record_installed "$DEFAULT_CONFIG_FILE"

if [ "$MODE" = "self-contained" ]; then
  mkdir -p "$BIN_DIR"
  cp "$PROJECT_DIR/scripts/manage_mode.sh" "$INSTALL_DIR/scripts/manage_mode.sh"
  cp "$PROJECT_DIR/todo-wallpaper" "$INSTALL_DIR/todo-wallpaper"
  chmod +x \
    "$INSTALL_DIR/scripts/manage_mode.sh" \
    "$INSTALL_DIR/todo-wallpaper"
  ln -sf "$INSTALL_DIR/todo-wallpaper" "$BIN_DIR/todo-wallpaper"
  record_installed "$INSTALL_DIR/scripts/manage_mode.sh"
  record_installed "$INSTALL_DIR/todo-wallpaper"
  record_installed "$BIN_DIR/todo-wallpaper"
  service_file="$UNIT_DIR/todo-wallpaper.service"
  path_file="$UNIT_DIR/todo-wallpaper.path"
  printf '%s\n' '[Unit]' > "$service_file"
  printf '%s\n' 'Description=Render and apply TODO wallpaper' >> "$service_file"
  printf '%s\n' '' >> "$service_file"
  printf '%s\n' '[Service]' >> "$service_file"
  printf '%s\n' 'Type=oneshot' >> "$service_file"
  printf '%s\n' "ExecStart=$INSTALL_DIR/scripts/run_wallpaper_job.sh $DEFAULT_CONFIG_FILE" >> "$service_file"

  printf '%s\n' '[Unit]' > "$path_file"
  printf '%s\n' 'Description=Watch TODO file for todo_wallpaper refresh' >> "$path_file"
  printf '%s\n' '' >> "$path_file"
  printf '%s\n' '[Path]' >> "$path_file"
  printf '%s\n' "PathChanged=$TODO_FILE" >> "$path_file"
  printf '%s\n' "PathModified=$TODO_FILE" >> "$path_file"
  printf '%s\n' 'Unit=todo-wallpaper.service' >> "$path_file"
  printf '%s\n' '' >> "$path_file"
  printf '%s\n' '[Install]' >> "$path_file"
  printf '%s\n' 'WantedBy=default.target' >> "$path_file"

  systemctl --user daemon-reload
  record_installed "$service_file"
  record_installed "$path_file"
fi

if [ "$MODE" = "self-contained" ]; then
  "$PROJECT_DIR/scripts/run_wallpaper_job.sh" "$DEFAULT_CONFIG_FILE"
  if [ "$ENABLE_WATCHER" = "1" ]; then
    systemctl --user enable --now todo-wallpaper.path
  fi
fi

printf 'Installed todo_wallpaper\n'
printf 'Mode: %s\n' "$MODE"
printf 'Todo file: %s\n' "$TODO_FILE"
printf 'Output file: %s\n' "$OUTPUT_FILE"
printf 'Backend: %s\n' "$BACKEND"
printf 'Detected backend: %s\n' "$RESOLVED_BACKEND"
printf 'Priority syntax: use [H], [M], or [ ] in markdown checkboxes, for example "- [H] urgent task"\n'
printf 'Display priority ordering: %s\n' "$DISPLAY_ORDER_PRIORITIES"
if [ -n "$INSTALLED_ITEMS" ]; then
  printf 'Installed items:\n'
  printf ' - %s\n' "$INSTALLED_ITEMS"
fi
if [ "$MODE" = "agent-skill" ]; then
  printf '\n'
  printf 'Agent instructions: %s\n' "$INSTALL_DIR/AGENTS.md"
  printf 'Agent skill: %s\n' "$INSTALL_DIR/agent/SKILL.md"
  printf 'Agent refresh command: %s/scripts/run_wallpaper_job.sh %s\n' "$INSTALL_DIR" "$DEFAULT_CONFIG_FILE"
fi
