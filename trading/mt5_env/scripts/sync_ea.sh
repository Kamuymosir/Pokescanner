#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

MT5_WINEPREFIX="${MT5_WINEPREFIX:-/home/ubuntu/.mt5-traderx}"
MT5_INSTALL_DIR="${MT5_INSTALL_DIR:-${MT5_WINEPREFIX}/drive_c/MT5Portable}"
MT5_EXPERTS_DIR="${MT5_EXPERTS_DIR:-${MT5_INSTALL_DIR}/MQL5/Experts}"

SOURCE_EA="${1:-${ROOT_DIR}/trading/mt5/TraderXRangeBurstEA.mq5}"
TARGET_NAME="${2:-TraderXRangeBurstEA.mq5}"

if [[ ! -f "${SOURCE_EA}" ]]; then
  echo "EA source not found: ${SOURCE_EA}" >&2
  exit 1
fi

mkdir -p "${MT5_EXPERTS_DIR}"
install -m 0644 "${SOURCE_EA}" "${MT5_EXPERTS_DIR}/${TARGET_NAME}"

echo "Synced EA to: ${MT5_EXPERTS_DIR}/${TARGET_NAME}"
