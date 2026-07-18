#!/usr/bin/env bash
# Launch mpv with the VR-reversal 360plugin enabled.
#
# Usage:
#   vr-reversal.sh [-p|--player MPV_BINARY] [--hwdec MODE|--no-hwdec] [video ...]
#
# Any argument that is not one of the options above is passed through to mpv,
# so videos, playlists and extra mpv flags all work as usual.
#
# The player binary defaults to "mpv" on PATH; override it with -p/--player
# or the MPV_BIN environment variable (e.g. a flatpak wrapper or custom build).
#
# GPU decode acceleration is enabled automatically (hwdec=auto-copy) when a
# render device is detected. Only *decoding* is offloaded to the GPU: the v360
# reprojection itself is a CPU libavfilter, so copy-back mode is required.
# This works headless (VNC/ssh sessions) too, since NVDEC/VAAPI do not need
# the X display for decoding.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLAYER=${MPV_BIN:-mpv}
HWDEC=detect

args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--player)
            [[ $# -ge 2 ]] || { echo "error: $1 requires an argument" >&2; exit 1; }
            PLAYER=$2; shift 2 ;;
        --hwdec)
            [[ $# -ge 2 ]] || { echo "error: --hwdec requires an argument" >&2; exit 1; }
            HWDEC=$2; shift 2 ;;
        --no-hwdec)
            HWDEC=no; shift ;;
        -h|--help)
            sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)
            args+=("$1"); shift ;;
    esac
done

command -v "$PLAYER" >/dev/null 2>&1 || {
    echo "error: player '$PLAYER' not found in PATH" >&2; exit 1; }

if [[ $HWDEC == detect ]]; then
    HWDEC=no
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
        HWDEC=auto-copy
    elif compgen -G '/dev/dri/renderD*' >/dev/null 2>&1; then
        HWDEC=auto-copy
    fi
fi

opts="360plugin-enabled=yes,360plugin-hwdec=$HWDEC"

# With no video arguments, open an idle window so files can be drag-and-dropped.
if [[ ${#args[@]} -eq 0 ]]; then
    args=(--force-window --idle=once)
fi

exec "$PLAYER" --script="$SCRIPT_DIR/360plugin.lua" --script-opts="$opts" "${args[@]}"
