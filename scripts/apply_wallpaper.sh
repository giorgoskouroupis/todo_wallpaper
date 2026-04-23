#!/bin/sh

set -eu

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  printf 'usage: %s <apply|clear> <backend> <image-path> [screen]\n' "$0" >&2
  exit 2
fi

ACTION="$1"
BACKEND="$2"
IMAGE_PATH="$3"
SCREEN="${4:-all}"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_session_bus() {
  if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    return
  fi

  if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "${XDG_RUNTIME_DIR}/bus" ]; then
    DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
    export DBUS_SESSION_BUS_ADDRESS
  fi
}

detect_backend() {
  if [ -n "${SWAYSOCK:-}" ] && command_exists swaybg; then
    printf 'swaybg\n'
    return
  fi

  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command_exists hyprctl; then
    printf 'hyprpaper\n'
    return
  fi

  case "${XDG_CURRENT_DESKTOP:-}" in
    GNOME|*GNOME*)
      if command_exists gsettings; then
        printf 'gsettings\n'
        return
      fi
      ;;
  esac

  case "${XDG_CURRENT_DESKTOP:-}" in
    KDE|*KDE*)
      if command_exists plasma-apply-wallpaperimage; then
        printf 'plasma\n'
        return
      fi
      ;;
  esac

  if command_exists qs && { [ "${XDG_CURRENT_DESKTOP:-}" = "noctalia-shell" ] || [ -n "${NIRI_SOCKET:-}" ] || [ "${DESKTOP_SESSION:-}" = "niri" ]; }; then
    printf 'noctalia\n'
    return
  fi

  if [ -n "${DISPLAY:-}" ] && command_exists feh; then
    printf 'feh\n'
    return
  fi

  printf 'none\n'
}

do_detect() {
  BACKEND=$(detect_backend)
  printf '%s\n' "$BACKEND"
}

apply_noop() {
  printf 'wallpaper action skipped: %s\n' "$IMAGE_PATH"
}

clear_noop() {
  printf 'wallpaper clear skipped: %s\n' "$IMAGE_PATH"
}

apply_feh() {
  exec feh --bg-fill "$IMAGE_PATH"
}

clear_feh() {
  pkill -x feh >/dev/null 2>&1 || true
  if [ -n "${DISPLAY:-}" ]; then
    xsetroot -solid "#0C1220" 2>/dev/null || true
  fi
}

apply_swaybg() {
  pkill -x swaybg >/dev/null 2>&1 || true
  nohup swaybg -i "$IMAGE_PATH" -m fill >/dev/null 2>&1 &
}

clear_swaybg() {
  pkill -x swaybg >/dev/null 2>&1 || true
}

apply_gsettings() {
  ensure_session_bus
  IMAGE_URI=$(realpath "$IMAGE_PATH")
  gsettings set org.gnome.desktop.background picture-uri "file://$IMAGE_URI"
  gsettings set org.gnome.desktop.background picture-uri-dark "file://$IMAGE_URI" 2>/dev/null || true
}

clear_gsettings() {
  ensure_session_bus
  gsettings set org.gnome.desktop.background picture-uri ''
  gsettings set org.gnome.desktop.background picture-uri-dark '' 2>/dev/null || true
  gsettings set org.gnome.desktop.background picture-options 'none' 2>/dev/null || true
}

apply_plasma() {
  exec plasma-apply-wallpaperimage "$IMAGE_PATH"
}

clear_plasma() {
  plasma-apply-wallpaperimage --reset 2>/dev/null || true
}

apply_hyprpaper() {
  hyprctl hyprpaper preload "$IMAGE_PATH"
  exec hyprctl hyprpaper wallpaper "$SCREEN,$IMAGE_PATH"
}

clear_hyprpaper() {
  pkill -x hyprpaper >/dev/null 2>&1 || true
}

apply_noctalia() {
  IMAGE_URI=$(realpath "$IMAGE_PATH")
  exec qs -c noctalia-shell ipc call wallpaper set "file://$IMAGE_URI" "$SCREEN"
}

clear_noctalia() {
  BLANK_WALLPAPER="$HOME/Pictures/Wallpapers/black-default.png"
  if [ -f "$BLANK_WALLPAPER" ]; then
    IMAGE_URI=$(realpath "$BLANK_WALLPAPER")
    qs -c noctalia-shell ipc call wallpaper set "file://$IMAGE_URI" "$SCREEN" 2>/dev/null || true
  fi
}

if [ "$BACKEND" = "auto" ]; then
  BACKEND=$(detect_backend)
fi

case "$ACTION" in
  detect)
    do_detect
    ;;
  apply)
    case "$BACKEND" in
      none)
        apply_noop
        ;;
      feh)
        apply_feh
        ;;
      swaybg)
        apply_swaybg
        ;;
      gsettings)
        apply_gsettings
        ;;
      plasma)
        apply_plasma
        ;;
      hyprpaper)
        apply_hyprpaper
        ;;
      noctalia)
        apply_noctalia
        ;;
      *)
        printf 'unsupported backend: %s\n' "$BACKEND" >&2
        exit 1
        ;;
    esac
    ;;
  clear)
    case "$BACKEND" in
      none)
        clear_noop
        ;;
      feh)
        clear_feh
        ;;
      swaybg)
        clear_swaybg
        ;;
      gsettings)
        clear_gsettings
        ;;
      plasma)
        clear_plasma
        ;;
      hyprpaper)
        clear_hyprpaper
        ;;
      noctalia)
        clear_noctalia
        ;;
      *)
        printf 'unsupported backend: %s\n' "$BACKEND" >&2
        exit 1
        ;;
    esac
    ;;
esac
