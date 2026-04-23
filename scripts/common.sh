#!/bin/sh

set -eu

PROJECT_DIR="${PROJECT_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
RUNTIME_NAME="todo_wallpaper"
DEFAULT_INSTALL_DIR="$HOME/.local/share/$RUNTIME_NAME"
DEFAULT_CONFIG_DIR="$HOME/.config/$RUNTIME_NAME"
DEFAULT_UNIT_DIR="$HOME/.config/systemd/user"
DEFAULT_CONFIG_FILE="$DEFAULT_CONFIG_DIR/config.env"
DEFAULT_STATE_FILE="$DEFAULT_CONFIG_DIR/state.env"

shell_quote() {
  printf "%s" "$1" | sed "s/'/'\\''/g; 1s/^/'/; \$s/\$/'/"
}

load_config() {
  CONFIG_FILE="${1:-$DEFAULT_CONFIG_FILE}"
  if [ ! -f "$CONFIG_FILE" ]; then
    printf 'missing config file: %s\n' "$CONFIG_FILE" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
}

write_config() {
  CONFIG_FILE="${1:-$DEFAULT_CONFIG_FILE}"
  mkdir -p "$(dirname "$CONFIG_FILE")"
  : > "$CONFIG_FILE"
  for key in \
    MODE TODO_FILE OUTPUT_FILE BACKEND SCREEN BOX_POSITION DISPLAY_ORDER_PRIORITIES FONT_NAME WIDTH HEIGHT SCALE \
    APPLY_WALLPAPER ENABLE_WATCHER INSTALL_DIR CONFIG_DIR UNIT_DIR RESOLVED_BACKEND \
    BLANK_WALLPAPER OS_ID OS_VERSION_ID DESKTOP_ENVIRONMENT SESSION_TYPE
  do
    eval "value=\${$key-}"
    printf '%s=%s\n' "$key" "$(shell_quote "${value:-}")" >> "$CONFIG_FILE"
  done
}

ensure_demo_removed_from_real_paths() {
  case "${TODO_FILE:-}" in
    "$PROJECT_DIR/TODO-demo.md")
      printf 'refusing to use repo demo file as the real todo file: %s\n' "$TODO_FILE" >&2
      exit 1
      ;;
  esac
}

detect_system_details() {
  OS_ID="unknown"
  OS_VERSION_ID="unknown"
  if [ -f /etc/os-release ]; then
    OS_ID=$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"' | head -n 1)
    OS_VERSION_ID=$(sed -n 's/^VERSION_ID=//p' /etc/os-release | tr -d '"' | head -n 1)
  fi
  DESKTOP_ENVIRONMENT="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-unknown}}"
  SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
}

run_privileged() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return
  fi
  if command -v doas >/dev/null 2>&1; then
    doas "$@"
    return
  fi
  return 1
}

try_install_pillow_package() {
  if command -v apt-get >/dev/null 2>&1; then
    run_privileged apt-get update && run_privileged apt-get install -y python3-pil
    return
  fi
  if command -v pacman >/dev/null 2>&1; then
    run_privileged pacman -Sy --noconfirm python-pillow
    return
  fi
  if command -v dnf >/dev/null 2>&1; then
    run_privileged dnf install -y python3-pillow
    return
  fi
  if command -v zypper >/dev/null 2>&1; then
    run_privileged zypper --non-interactive install python3-Pillow
    return
  fi
  return 1
}

ensure_pillow() {
  if python3 -c 'import PIL' >/dev/null 2>&1; then
    return
  fi
  if try_install_pillow_package && python3 -c 'import PIL' >/dev/null 2>&1; then
    return
  fi
  if python3 -m pip --version >/dev/null 2>&1; then
    python3 -m pip install --user pillow
    python3 -c 'import PIL' >/dev/null 2>&1 && return
  fi
  if python3 -m ensurepip --version >/dev/null 2>&1; then
    python3 -m ensurepip --user >/dev/null 2>&1 || python3 -m ensurepip --upgrade --user >/dev/null 2>&1
    if python3 -m pip --version >/dev/null 2>&1; then
      python3 -m pip install --user pillow
      python3 -c 'import PIL' >/dev/null 2>&1 && return
    fi
  fi
  if command -v pip3 >/dev/null 2>&1; then
    pip3 install --user pillow
    python3 -c 'import PIL' >/dev/null 2>&1 && return
  fi
  printf 'Pillow is required but could not be installed automatically.\n' >&2
  exit 1
}

ensure_black_wallpaper() {
  BLANK_WALLPAPER="$HOME/Pictures/Wallpapers/black-default.png"
  width="${WIDTH:-1920}"
  height="${HEIGHT:-1080}"
  python3 - "$BLANK_WALLPAPER" "$width" "$height" <<'PY'
from pathlib import Path
import sys
from PIL import Image

output = Path(sys.argv[1]).expanduser()
width = max(1, int(sys.argv[2] or "1920"))
height = max(1, int(sys.argv[3] or "1080"))
output.parent.mkdir(parents=True, exist_ok=True)
if not output.exists():
    Image.new("RGB", (width, height), "black").save(output, format="PNG")
PY
}

resolve_backend() {
  backend="${BACKEND:-auto}"
  if [ "$backend" = "auto" ]; then
    "$PROJECT_DIR/scripts/apply_wallpaper.sh" detect auto "${OUTPUT_FILE:-/tmp/none}" "${SCREEN:-all}"
  else
    printf '%s\n' "$backend"
  fi
}

ensure_default_config() {
  if [ -f "$DEFAULT_CONFIG_FILE" ]; then
    return
  fi
  mkdir -p "$DEFAULT_CONFIG_DIR"
  if [ -f "$DEFAULT_INSTALL_DIR/.todo-wallpaper.env.example" ]; then
    cp "$DEFAULT_INSTALL_DIR/.todo-wallpaper.env.example" "$DEFAULT_CONFIG_FILE"
    return
  fi
  cp "$PROJECT_DIR/.todo-wallpaper.env.example" "$DEFAULT_CONFIG_FILE"
}
