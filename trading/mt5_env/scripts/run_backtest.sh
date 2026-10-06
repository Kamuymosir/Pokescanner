#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PREFIX_DEFAULT="$HOME/.mt5-traderx"
INSTALL_DEFAULT="$PREFIX_DEFAULT/drive_c/MT5Portable"
CONFIG_DEFAULT="$BASE_DIR/config/tester.ini"
REPORT_DEFAULT="$BASE_DIR/reports/traderx-report"

WINEPREFIX="${WINEPREFIX:-$PREFIX_DEFAULT}"
INSTALL_DIR="${MT5_INSTALL_DIR:-$INSTALL_DEFAULT}"
CONFIG_PATH="${1:-$CONFIG_DEFAULT}"
REPORT_PATH="${2:-$REPORT_DEFAULT}"

TERMINAL_EXE="$INSTALL_DIR/terminal64.exe"

if [[ ! -f "$TERMINAL_EXE" ]]; then
  echo "MT5 terminal not found: $TERMINAL_EXE" >&2
  exit 1
fi

mkdir -p "$(dirname "$REPORT_PATH")"

TMP_CONFIG="$(mktemp)"
trap 'rm -f "$TMP_CONFIG"' EXIT
sed "s|__REPORT_PATH__|$REPORT_PATH|g" "$CONFIG_PATH" > "$TMP_CONFIG"

export WINEPREFIX
export WINEARCH=win64

# MetaTrader cannot run two copies from the same directory.
pkill -f '/home/ubuntu/.mt5-traderx/drive_c/MT5Portable/terminal64.exe' 2>/dev/null || true
pkill -f 'C:\\MT5Portable\\terminal64.exe' 2>/dev/null || true
sleep 2

echo "Running Strategy Tester with config: $CONFIG_PATH"
echo "Resolved tester config:"
sed -n '1,200p' "$TMP_CONFIG"
cp "$TMP_CONFIG" "$BASE_DIR/logs/last-run-backtest.ini"
xvfb-run -a wine "$TERMINAL_EXE" /portable /config:"$(winepath -w "$TMP_CONFIG")"
