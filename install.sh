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
OPENCODE_BIN="${OPENCODE_BIN:-opencode}"
INSTALLED_ITEMS=""

usage() {
  printf '%s\n' 'todo_wallpaper installer'
  printf '\n'
  printf 'usage: %s [options]\n' "$0"
  printf '\n'
  printf '%s\n' 'modes:'
  printf '%s\n' '  default      self-contained install with local command and optional watcher'
  printf '%s\n' '  --opencode   minimal bootstrap plus OpenCode handoff'
  printf '\n'
  printf '%s\n' 'options:'
  printf '%s\n' '  --opencode                 install the OpenCode bootstrap flow instead of self-contained mode'
  printf '%s\n' '  --backend NAME             wallpaper backend to use; default: auto'
  printf '%s\n' '  --screen NAME              target screen; default: all'
  printf '  --todo-file PATH           todo markdown path; default: %s\n' "$DEFAULT_INSTALL_DIR/TODO.md"
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
  printf '%s\n' '  - OpenCode mode installs only the runtime toolkit and prints a first prompt suggestion'
}

resolve_opencode_bin() {
  if command -v "$OPENCODE_BIN" >/dev/null 2>&1; then
    command -v "$OPENCODE_BIN"
    return
  fi
  if [ -x "$HOME/.opencode/bin/opencode" ]; then
    printf '%s\n' "$HOME/.opencode/bin/opencode"
    return
  fi
  printf '\n'
}

install_opencode() {
  if ! command -v curl >/dev/null 2>&1; then
    printf 'OpenCode CLI is missing, and curl is not available for automatic install.\n' >&2
    printf 'Install OpenCode first, then re-run: %s --opencode\n' "$0" >&2
    exit 1
  fi
  printf 'OpenCode CLI not found. Installing it now...\n'
  curl -fsSL https://opencode.ai/install | bash
}

record_installed() {
  INSTALLED_ITEMS="${INSTALLED_ITEMS}${INSTALLED_ITEMS:+
}$1"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --opencode)
      MODE="opencode"
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

ensure_pillow
detect_system_details
ensure_black_wallpaper
mkdir -p "$(dirname "$TODO_FILE")" "$(dirname "$OUTPUT_FILE")" "$CONFIG_DIR" "$UNIT_DIR" "$INSTALL_DIR/scripts"

cp "$PROJECT_DIR/scripts/common.sh" "$INSTALL_DIR/scripts/common.sh"
cp "$PROJECT_DIR/scripts/edit_todo.py" "$INSTALL_DIR/scripts/edit_todo.py"
cp "$PROJECT_DIR/scripts/run_wallpaper_job.sh" "$INSTALL_DIR/scripts/run_wallpaper_job.sh"
cp "$PROJECT_DIR/scripts/render_todo_wallpaper.py" "$INSTALL_DIR/scripts/render_todo_wallpaper.py"
cp "$PROJECT_DIR/scripts/apply_wallpaper.sh" "$INSTALL_DIR/scripts/apply_wallpaper.sh"
cp "$PROJECT_DIR/.todo-wallpaper.env.example" "$INSTALL_DIR/.todo-wallpaper.env.example"
cp "$PROJECT_DIR/uninstall.sh" "$INSTALL_DIR/uninstall.sh"
cp "$PROJECT_DIR/OPENCODE_HANDOFF.md" "$INSTALL_DIR/OPENCODE_HANDOFF.md"
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
record_installed "$INSTALL_DIR/OPENCODE_HANDOFF.md"

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
else
  OPENCODE_PATH=$(resolve_opencode_bin)
  if [ -z "$OPENCODE_PATH" ]; then
    install_opencode
    OPENCODE_PATH=$(resolve_opencode_bin)
  fi
  if [ -z "$OPENCODE_PATH" ]; then
    printf 'OpenCode CLI is still missing after install attempt.\n' >&2
    exit 1
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
if [ "$MODE" = "opencode" ]; then
  printf '\n'
  printf 'OpenCode prompt:\n\n'
  printf '%s\n' "I installed todo_wallpaper in $INSTALL_DIR using --opencode. I am now using OpenCode inside that installed runtime directory. Treat $INSTALL_DIR as the local runtime toolkit for this wallpaper workflow, not as the user's task repository. Before doing anything else, read ~/.config/todo_wallpaper/config.env and summarize the current setup: mode, configured TODO file path, configured wallpaper output path, configured box position, configured backend, and the backend/session you actually detect on this machine. Use only the local scripts in $INSTALL_DIR as the supported primitives: scripts/render_todo_wallpaper.py for rendering, scripts/apply_wallpaper.sh for wallpaper apply or clear, scripts/run_wallpaper_job.sh for the render-and-apply flow, and uninstall.sh for cleanup. Keep the real TODO markdown outside this runtime directory unless I explicitly ask otherwise. Respect the priority syntax already supported by the renderer: markdown checkboxes like [H], [M], or [ ] at the start of a task, for example '- [H] urgent task' and '- [M] important task'. Do not treat this as the self-contained watcher flow unless the config says so. After you inspect the config and local scripts, explain clearly what is already installed, what is safe to change, what commands or actions are available from this setup, and what the next sensible step is. If I already asked for an action, carry it out using this installed runtime instead of re-deriving the architecture."
fi
