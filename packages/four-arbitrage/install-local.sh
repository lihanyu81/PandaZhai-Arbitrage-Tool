#!/usr/bin/env bash
set -euo pipefail
if [ "$(id -u)" != 0 ]; then echo '请使用 sudo 运行安装脚本'; exit 1; fi
artifact_dir=$(cd -- "$(dirname -- "$0")" && pwd)
if [ ! -x "$artifact_dir/panda-four" ]; then echo '缺少同目录 panda-four 二进制'; exit 1; fi
id panda-four >/dev/null 2>&1 || useradd --system --home-dir /var/lib/pandazhai/four --create-home --shell /usr/sbin/nologin panda-four
install -d -m 755 /opt/pandazhai/four
install -d -m 700 -o panda-four -g panda-four /var/lib/pandazhai/four
install -m 755 "$artifact_dir/panda-four" /opt/pandazhai/four/panda-four
cat > /etc/systemd/system/panda-four.service <<'UNIT'
[Unit]
Description=PandaZhai Four Venue Arbitrage
After=network-online.target
Wants=network-online.target
[Service]
User=panda-four
Group=panda-four
WorkingDirectory=/var/lib/pandazhai/four
ExecStart=/opt/pandazhai/four/panda-four serve --host 127.0.0.1 --port 8007 --data-dir /var/lib/pandazhai/four
Restart=on-failure
RestartSec=5
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now panda-four
printf '%s\n' '已启动，监听 127.0.0.1:8007。远程访问请使用 SSH 隧道或认证反向代理。' '查看工具 2FA：sudo -u panda-four /opt/pandazhai/four/panda-four auth --data-dir /var/lib/pandazhai/four'
