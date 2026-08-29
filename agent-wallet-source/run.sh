#!/usr/bin/env bash
set -Eeuo pipefail

REPO="https://github.com/lihanyu81/PandaZhai-Arbitrage-Tool"
BRANCH="${PANDAZHAI_BRANCH:-main}"
INSTALL_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/pandazhai/popdex-agent-wallet"
SOURCE_DIR="$INSTALL_ROOT/source"
VENV_DIR="$INSTALL_ROOT/venv"
TEMP_DIR=$(mktemp -d /tmp/pandazhai-agent-wallet.XXXXXX)
trap 'rm -rf -- "$TEMP_DIR"' EXIT

command -v python3 >/dev/null || { echo "错误：需要 Python 3.10 或更高版本" >&2; exit 1; }
command -v curl >/dev/null || { echo "错误：需要 curl" >&2; exit 1; }
python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)' \
  || { echo "错误：需要 Python 3.10 或更高版本" >&2; exit 1; }

echo "[PandaZhai] 正在下载开源 Agent 钱包工具……"
curl -fsSL --retry 3 "$REPO/archive/refs/heads/$BRANCH.tar.gz" -o "$TEMP_DIR/source.tar.gz"
tar -xzf "$TEMP_DIR/source.tar.gz" -C "$TEMP_DIR"
DOWNLOADED=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d -name 'PandaZhai-Arbitrage-Tool-*' -print -quit)
test -n "$DOWNLOADED" || { echo "错误：下载包结构无效" >&2; exit 1; }

mkdir -p "$INSTALL_ROOT"
rm -rf -- "$SOURCE_DIR"
mkdir -p "$SOURCE_DIR"
cp -a "$DOWNLOADED/agent-wallet-source/." "$SOURCE_DIR/"
python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --disable-pip-version-check --quiet --upgrade pip
"$VENV_DIR/bin/python" -m pip install --disable-pip-version-check --quiet --upgrade "$SOURCE_DIR"

echo "[PandaZhai] 安装完成，正在启动……"
if [[ -c /dev/tty ]] && { : </dev/tty; } 2>/dev/null; then
  exec "$VENV_DIR/bin/popdex-agent-wallet" "$@" </dev/tty
fi
exec "$VENV_DIR/bin/popdex-agent-wallet" "$@"
