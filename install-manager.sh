#!/usr/bin/env bash
set -Eeuo pipefail
[[ $(id -u) == 0 ]] || { echo '请使用 root 执行：sudo bash install-manager.sh' >&2; exit 1; }
case "$(uname -m)" in x86_64) ARCH=amd64;; aarch64|arm64) ARCH=arm64;; *) echo '不支持的 CPU 架构' >&2; exit 1;; esac
BASE_URL="${PANDAZHAI_RELEASE_BASE_URL:-https://github.com/lihanyu81/PandaZhai-Arbitrage-Tool/releases/download/${PANDAZHAI_VERSION:-latest}}"
PREFIX=/opt/pandazhai/manager; DATA=/var/lib/pandazhai/manager; TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
command -v curl >/dev/null || { echo '缺少 curl' >&2; exit 1; }; command -v sha256sum >/dev/null || { echo '缺少 sha256sum' >&2; exit 1; }
getent passwd panda >/dev/null || useradd --system --home-dir "$DATA" --shell /usr/sbin/nologin panda
install -d -o panda -g panda -m 0750 "$PREFIX" "$DATA"
curl -fL "$BASE_URL/panda-manager-$ARCH" -o "$TMP/panda-manager"; curl -fL "$BASE_URL/panda-manager-$ARCH.sha256" -o "$TMP/panda-manager.sha256"; (cd "$TMP" && sha256sum -c panda-manager.sha256)
install -o panda -g panda -m 0750 "$TMP/panda-manager" "$PREFIX/panda-manager"
run_as_panda() { if command -v runuser >/dev/null; then runuser -u panda -- "$@"; else su -s /bin/sh panda -c "$(printf '%q ' "$@")"; fi; }
[[ -f "$DATA/manager.db" ]] || run_as_panda "$PREFIX/panda-manager" --data-dir "$DATA" --admin-email "${PANDAZHAI_ADMIN_EMAIL:-}" --init-only
cat >/etc/systemd/system/panda-manager.service <<EOF
[Unit]
Description=PandaZhai Arbitrage Manager
After=network-online.target
Wants=network-online.target
[Service]
User=panda
Group=panda
WorkingDirectory=$PREFIX
ExecStart=$PREFIX/panda-manager --data-dir $DATA --host 127.0.0.1 --port 9000
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
systemctl daemon-reload; systemctl enable --now panda-manager; sleep 2; curl -fsS http://127.0.0.1:9000/health >/dev/null
echo '管理中心已启动于 127.0.0.1:9000，请使用 Caddy/Nginx 反代到 HTTPS 443。'
