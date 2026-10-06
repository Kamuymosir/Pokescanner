#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

export WINEPREFIX="${WINEPREFIX:-$HOME/.mt5-traderx}"
export WINEARCH="${WINEARCH:-win64}"

MT5_DIR="${MT5_DIR:-$WINEPREFIX/drive_c/MT5Portable}"
TERMINAL_EXE="$MT5_DIR/terminal64.exe"

if [[ ! -f "$TERMINAL_EXE" ]]; then
  echo "terminal64.exe が見つかりません: $TERMINAL_EXE" >&2
  echo "先に setup_mt5.sh を実行してください。" >&2
  exit 1
fi

xvfb-run -a wine "$TERMINAL_EXE" /portable "$@"
