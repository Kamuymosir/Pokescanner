#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFIX="${MT5_WINEPREFIX:-$HOME/.mt5-traderx}"
MT5_DIR="${MT5_INSTALL_DIR:-$PREFIX/drive_c/MT5Portable}"
METAEDITOR_EXE="$MT5_DIR/MetaEditor64.exe"
EXPERT_NAME="${1:-TraderXRangeBurstEA}"
SOURCE_RELATIVE="MQL5/Experts/${EXPERT_NAME}.mq5"
SOURCE_FILE="$MT5_DIR/$SOURCE_RELATIVE"
LOG_DIR="$ROOT_DIR/mt5_env/logs"
LOG_FILE_LINUX="$LOG_DIR/compile-${EXPERT_NAME}.log"
LOG_FILE_UTF8="$LOG_DIR/compile-${EXPERT_NAME}.utf8.log"
SYNC_SCRIPT="$ROOT_DIR/mt5_env/scripts/sync_ea.sh"

mkdir -p "$LOG_DIR"

if [[ ! -f "$METAEDITOR_EXE" ]]; then
  echo "MetaEditor not found: $METAEDITOR_EXE" >&2
  exit 1
fi

if [[ -x "$SYNC_SCRIPT" ]]; then
  "$SYNC_SCRIPT" "$ROOT_DIR/mt5/${EXPERT_NAME}.mq5" "${EXPERT_NAME}.mq5"
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "Source file not found in MT5 directory: $SOURCE_FILE" >&2
  echo "Run sync_ea.sh first." >&2
  exit 1
fi

WIN_SOURCE="$(WINEPREFIX="$PREFIX" winepath -w "$SOURCE_FILE")"
WIN_LOG="$(WINEPREFIX="$PREFIX" winepath -w "$LOG_FILE_LINUX")"

rm -f "$LOG_FILE_LINUX" "$LOG_FILE_UTF8"

WINEPREFIX="$PREFIX" timeout 180s xvfb-run -a \
  wine "$METAEDITOR_EXE" /portable "/compile:$WIN_SOURCE" "/log:$WIN_LOG" || true

if [[ ! -f "$LOG_FILE_LINUX" ]]; then
  echo "Compile log not generated: $LOG_FILE_LINUX" >&2
  exit 1
fi

python3 - "$LOG_FILE_LINUX" "$LOG_FILE_UTF8" <<'PY'
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
raw = src.read_bytes()

for encoding in ("utf-16", "utf-16le", "utf-8", "cp1252"):
    try:
        text = raw.decode(encoding)
        break
    except UnicodeDecodeError:
        continue
else:
    text = raw.decode("utf-8", errors="replace")

dst.write_text(text, encoding="utf-8")
PY

echo "Compile log: $LOG_FILE_UTF8"
sed -n '1,200p' "$LOG_FILE_UTF8"

if rg -n "0 errors, 0 warnings|0 error\\(s\\), 0 warning\\(s\\)" "$LOG_FILE_UTF8" >/dev/null 2>&1; then
  echo "Compilation succeeded."
  exit 0
fi

echo "Compilation may have failed or produced warnings. Review the log above." >&2
exit 1
