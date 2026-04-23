#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

. "$SCRIPT_DIR/common.sh"

load_config "${1:-$DEFAULT_CONFIG_FILE}"

BOX_POSITION="${BOX_POSITION:-right}"
DISPLAY_ORDER_PRIORITIES="${DISPLAY_ORDER_PRIORITIES:-true}"
SCREEN="${SCREEN:-all}"
SCALE="${SCALE:-3.0}"
APPLY_WALLPAPER="${APPLY_WALLPAPER:-1}"

OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
OUTPUT_BASE=${OUTPUT_FILE%.*}
OUTPUT_EXT=${OUTPUT_FILE##*.}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RENDER_OUTPUT="${OUTPUT_BASE}-${TIMESTAMP}.${OUTPUT_EXT}"

mkdir -p "$OUTPUT_DIR"

set -- /usr/bin/python3 "$PROJECT_DIR/scripts/render_todo_wallpaper.py" "$TODO_FILE" --output "$RENDER_OUTPUT" --box-position "$BOX_POSITION" --display-order-priorities "$DISPLAY_ORDER_PRIORITIES"

if [ -n "${WIDTH:-}" ]; then
  set -- "$@" --width "$WIDTH"
fi
if [ -n "${HEIGHT:-}" ]; then
  set -- "$@" --height "$HEIGHT"
fi
if [ -n "${SCALE:-}" ]; then
  set -- "$@" --scale "$SCALE"
fi
if [ -n "${FONT_NAME:-}" ]; then
  set -- "$@" --font "$FONT_NAME"
fi

RENDERED_OUTPUT=$($@)
RENDERED_OUTPUT=$(printf '%s\n' "$RENDERED_OUTPUT" | tail -n 1)

if [ -z "$RENDERED_OUTPUT" ] || [ ! -f "$RENDERED_OUTPUT" ]; then
  printf 'render failed or returned missing file: %s\n' "${RENDERED_OUTPUT:-}" >&2
  exit 1
fi

BACKEND_TO_USE="${RESOLVED_BACKEND:-$(resolve_backend)}"

if [ "$APPLY_WALLPAPER" = "1" ]; then
  "$PROJECT_DIR/scripts/apply_wallpaper.sh" apply "$BACKEND_TO_USE" "$RENDERED_OUTPUT" "$SCREEN"
fi

for candidate in "$OUTPUT_DIR"/"$(basename "${OUTPUT_BASE}")"-*."$OUTPUT_EXT"; do
  [ -e "$candidate" ] || continue
  [ "$candidate" = "$RENDERED_OUTPUT" ] && continue
  rm -f "$candidate"
done

printf '%s\n' "$RENDERED_OUTPUT"
