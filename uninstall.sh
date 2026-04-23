#!/bin/sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$PROJECT_DIR/scripts/common.sh"

KEEP_OUTPUT=0
KEEP_TODO=0
REMOVE_BLACK=0
REMOVED_ITEMS=""
KEPT_ITEMS=""

remove_if_exists() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    rm -rf "$1"
    REMOVED_ITEMS="${REMOVED_ITEMS}${REMOVED_ITEMS:+
}$1"
  fi
}

remove_parent_if_empty() {
  if [ -d "$1" ]; then
    if rmdir "$1" >/dev/null 2>&1; then
      REMOVED_ITEMS="${REMOVED_ITEMS}${REMOVED_ITEMS:+
}$1"
    fi
  fi
}

record_kept() {
  KEPT_ITEMS="${KEPT_ITEMS}${KEPT_ITEMS:+
}$1"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --keep-output)
      KEEP_OUTPUT=1
      shift
      ;;
    --keep-todo)
      KEEP_TODO=1
      shift
      ;;
    --purge)
      REMOVE_BLACK=1
      shift
      ;;
    -h|--help)
      printf 'usage: %s [--keep-output] [--keep-todo] [--purge]\n' "$0"
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

INSTALL_ROOT="$DEFAULT_INSTALL_DIR"
CONFIG_ROOT="$DEFAULT_CONFIG_DIR"
UNIT_ROOT="$DEFAULT_UNIT_DIR"
BLACK_FILE="$HOME/Pictures/Wallpapers/black-default.png"

if [ -f "$DEFAULT_CONFIG_FILE" ]; then
  load_config "$DEFAULT_CONFIG_FILE"
  INSTALL_ROOT="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
  CONFIG_ROOT="${CONFIG_DIR:-$DEFAULT_CONFIG_DIR}"
  UNIT_ROOT="${UNIT_DIR:-$DEFAULT_UNIT_DIR}"
  backend="${RESOLVED_BACKEND:-$(resolve_backend)}"
  ensure_black_wallpaper
  "$PROJECT_DIR/scripts/apply_wallpaper.sh" apply "$backend" "$BLANK_WALLPAPER" "${SCREEN:-all}" >/dev/null 2>&1 || true

  if [ "${MODE:-}" = "self-contained" ]; then
    systemctl --user disable --now todo-wallpaper.path >/dev/null 2>&1 || true
    systemctl --user stop todo-wallpaper.service >/dev/null 2>&1 || true
    remove_if_exists "$UNIT_ROOT/todo-wallpaper.service"
    remove_if_exists "$UNIT_ROOT/todo-wallpaper.path"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
  fi

  if [ "$KEEP_OUTPUT" -ne 1 ] && [ -n "${OUTPUT_FILE:-}" ]; then
    remove_if_exists "$OUTPUT_FILE"
    output_dir=$(dirname "$OUTPUT_FILE")
    stem=$(basename "${OUTPUT_FILE%.*}")
    ext=${OUTPUT_FILE##*.}
    for generated_file in "$output_dir"/"$stem"-*."$ext"; do
      [ -e "$generated_file" ] || continue
      remove_if_exists "$generated_file"
    done
    remove_if_exists "$output_dir"
  elif [ -n "${OUTPUT_FILE:-}" ]; then
    record_kept "$OUTPUT_FILE and generated wallpapers"
  fi

  if [ "$KEEP_TODO" -ne 1 ] && [ -n "${TODO_FILE:-}" ]; then
    remove_if_exists "$TODO_FILE"
    remove_parent_if_empty "$(dirname "$TODO_FILE")"
  elif [ -n "${TODO_FILE:-}" ]; then
    record_kept "$TODO_FILE"
  fi
fi

remove_if_exists "$DEFAULT_CONFIG_FILE"
remove_if_exists "$DEFAULT_STATE_FILE"
remove_if_exists "$HOME/.local/bin/todo-wallpaper"
remove_if_exists "$HOME/.local/bin/todoctl"
remove_if_exists "$INSTALL_ROOT"
remove_parent_if_empty "$CONFIG_ROOT"
remove_parent_if_empty "$UNIT_ROOT"

if [ "$REMOVE_BLACK" -eq 1 ]; then
  remove_if_exists "$BLACK_FILE"
  remove_parent_if_empty "$(dirname "$BLACK_FILE")"
else
  record_kept "$BLACK_FILE"
fi

printf 'Removed todo_wallpaper state\n'
if [ -n "$REMOVED_ITEMS" ]; then
  printf 'Removed:\n'
  printf ' - %s\n' "$REMOVED_ITEMS"
fi
if [ -n "$KEPT_ITEMS" ]; then
  printf 'Kept:\n'
  printf ' - %s\n' "$KEPT_ITEMS"
fi
