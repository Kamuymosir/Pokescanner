#!/usr/bin/env bash
set -euo pipefail

MT5_PREFIX="${MT5_PREFIX:-$HOME/.mt5-traderx}"
MT5_INSTALL_DIR_WIN='C:\MT5Portable'
MT5_INSTALL_DIR_LINUX="$MT5_PREFIX/drive_c/MT5Portable"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/workspace/trading/mt5_env/downloads}"
MT5_SETUP_EXE="$DOWNLOAD_DIR/mt5setup.exe"

mkdir -p "$DOWNLOAD_DIR"

sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y wine64 wine32:i386 winbind cabextract p7zip-full xvfb

export WINEPREFIX="$MT5_PREFIX"
export WINEARCH=win64

if [ ! -d "$MT5_PREFIX" ]; then
  xvfb-run -a wineboot -i
fi

if [ ! -f "$MT5_SETUP_EXE" ]; then
  curl -L --fail --output "$MT5_SETUP_EXE" \
    https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
fi

if [ ! -f "$MT5_INSTALL_DIR_LINUX/terminal64.exe" ]; then
  xvfb-run -a wine "$MT5_SETUP_EXE" /auto /path:"$MT5_INSTALL_DIR_WIN" || true
fi

# First launch populates the portable data tree, including MQL5.
timeout 45s xvfb-run -a wine "$MT5_INSTALL_DIR_LINUX/terminal64.exe" /portable || true

printf 'MT5 prefix: %s\n' "$MT5_PREFIX"
printf 'MT5 install: %s\n' "$MT5_INSTALL_DIR_LINUX"
