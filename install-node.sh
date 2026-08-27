#!/usr/bin/env bash
set -Eeuo pipefail
[[ $(id -u) == 0 ]] || { echo '请使用 root 执行：sudo bash install-node.sh --tool entropy-lighter' >&2; exit 1; }
TOOL=''; PORT=9100; CHILD=18000
while [[ $# -gt 0 ]]; do case "$1" in --tool) TOOL="$2"; shift 2;; --port) PORT="$2"; shift 2;; --child-port) CHILD="$2"; shift 2;; *) echo "未知参数：$1" >&2; exit 1;; esac; done
case "$TOOL" in entropy-lighter) SHORT=entropy;; rblighter-lighter) SHORT=rblighter;; popdex-lighter) SHORT=popdex;; *) echo '--tool 参数无效' >&2; exit 1;; esac
case "$(uname -m)" in x86_64) ARCH=amd64;; aarch64|arm64) ARCH=arm64;; *) echo '不支持的 CPU 架构' >&2; exit 1;; esac
BASE_URL="${PANDAZHAI_RELEASE_BASE_URL:-https://github.com/lihanyu81/PandaZhai-Arbitrage-Tool/releases/download/${PANDAZHAI_VERSION:-latest}}"; PREFIX="/opt/pandazhai/$SHORT"; DATA="/var/lib/pandazhai/$SHORT"; TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
command -v curl >/dev/null || { echo '缺少 curl' >&2; exit 1; }; command -v sha256sum >/dev/null || { echo '缺少 sha256sum' >&2; exit 1; }; getent passwd panda >/dev/null || useradd --system --home-dir "$DATA" --shell /usr/sbin/nologin panda; install -d -o panda -g panda -m 0750 "$PREFIX" "$DATA" "$DATA/tool-data"
for artifact in "panda-node-$SHORT" "panda-arb-$SHORT"; do curl -fL "$BASE_URL/$artifact-$ARCH" -o "$TMP/$artifact"; curl -fL "$BASE_URL/$artifact-$ARCH.sha256" -o "$TMP/$artifact.sha256"; (cd "$TMP" && sha256sum -c "$artifact.sha256"); install -o panda -g panda -m 0750 "$TMP/$artifact" "$PREFIX/$artifact"; done
run_as_panda() { if command -v runuser >/dev/null; then runuser -u panda -- "$@"; else su -s /bin/sh panda -c "$(printf '%q ' "$@")"; fi; }
[[ -f "$DATA/auth.json" ]] || run_as_panda "$PREFIX/panda-node-$SHORT" --data-dir "$DATA" --init-only
cat >/etc/systemd/system/panda-$SHORT.service <<EOF
[Unit]
Description=PandaZhai $TOOL node
After=network-online.target
Wants=network-online.target
[Service]
User=panda
Group=panda
WorkingDirectory=$PREFIX
ExecStart=$PREFIX/panda-node-$SHORT --data-dir $DATA --host 0.0.0.0 --port $PORT --child-port $CHILD
Restart=always
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=$DATA
UMask=0077
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable --now "panda-$SHORT"; sleep 2; curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null; echo "节点已启动：$TOOL，通信端口 $PORT，child-port $CHILD 仅监听本机。"
