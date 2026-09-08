#!/usr/bin/env bash
set -Eeuo pipefail

die() { echo "错误：$*" >&2; exit 1; }
info() { echo "[PandaZhai] $*"; }

[[ $(id -u) -eq 0 ]] || die "请使用 root 权限运行（例如 sudo bash）。"
[[ $(uname -s) == Linux ]] || die "仅支持 Linux。"
[[ $(uname -m) == x86_64 ]] || die "仅支持 x86_64/amd64，当前架构：$(uname -m)。"

TOOL="${1:-}"
[[ -n "$TOOL" ]] || die "缺少节点类型：entropy-lighter、popdex-lighter、rblighter-lighter、vanta-lighter 或 arcus-lighter。"
shift

PORT=9100
CHILD_PORT=18000
BRANCH="${PANDAZHAI_BRANCH:-main}"
REPO_RAW="${PANDAZHAI_BASE_URL:-https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/$BRANCH}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) [[ $# -ge 2 ]] || die "--port 缺少值。"; PORT="$2"; shift 2 ;;
    --child-port) [[ $# -ge 2 ]] || die "--child-port 缺少值。"; CHILD_PORT="$2"; shift 2 ;;
    *) die "未知参数：$1" ;;
  esac
done

case "$TOOL" in
  entropy-lighter) SHORT=entropy ;;
  popdex-lighter) SHORT=popdex ;;
  rblighter-lighter) SHORT=rblighter ;;
  vanta-lighter) SHORT=vanta ;;
  arcus-lighter) SHORT=arcus ;;
  *) die "不支持的节点类型：$TOOL" ;;
esac

[[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )) || die "无效端口：$PORT"
[[ "$CHILD_PORT" =~ ^[0-9]+$ ]] && (( CHILD_PORT >= 1 && CHILD_PORT <= 65535 )) || die "无效子端口：$CHILD_PORT"
[[ "$PORT" != "$CHILD_PORT" ]] || die "节点端口与子端口不能相同。"

for command_name in curl sha256sum install systemctl getent; do
  command -v "$command_name" >/dev/null || die "缺少命令：$command_name"
done

PREFIX="/opt/pandazhai/$SHORT"
DATA_DIR="/var/lib/pandazhai/$SHORT"
SERVICE="panda-$SHORT"
PACKAGE_URL="$REPO_RAW/packages/$TOOL"
TEMP_DIR=$(mktemp -d /tmp/pandazhai-install.XXXXXX)
trap 'rm -rf -- "$TEMP_DIR"' EXIT

info "下载 $TOOL 节点封包……"
curl --fail --location --retry 3 "$PACKAGE_URL/SHA256SUMS" --output "$TEMP_DIR/SHA256SUMS"
for artifact in panda-node panda-arb; do
  curl --fail --location --retry 3 "$PACKAGE_URL/$artifact" --output "$TEMP_DIR/$artifact"
done
(cd "$TEMP_DIR" && sha256sum --check SHA256SUMS)

if ! getent passwd panda >/dev/null; then
  useradd --system --home-dir /var/lib/pandazhai --shell /usr/sbin/nologin panda
fi
install -d -o panda -g panda -m 0750 "$PREFIX" "$DATA_DIR" "$DATA_DIR/tool-data"
install -o panda -g panda -m 0750 "$TEMP_DIR/panda-node" "$PREFIX/panda-node"
install -o panda -g panda -m 0750 "$TEMP_DIR/panda-arb" "$PREFIX/panda-arb"

run_as_panda() {
  if command -v runuser >/dev/null; then
    runuser -u panda -- "$@"
  else
    su -s /bin/sh panda -c "$(printf '%q ' "$@")"
  fi
}

if [[ ! -f "$DATA_DIR/auth.json" ]]; then
  info "初始化节点认证信息……"
  run_as_panda "$PREFIX/panda-node" node --tool "$TOOL" --tool-executable "$PREFIX/panda-arb" --data-dir "$DATA_DIR" --init-only
fi

SERVICE_FILE="/etc/systemd/system/$SERVICE.service"
{
  printf '%s\n' \
    '[Unit]' \
    "Description=PandaZhai $TOOL arbitrage node" \
    'After=network-online.target' \
    'Wants=network-online.target' \
    '' \
    '[Service]' \
    'User=panda' \
    'Group=panda' \
    "WorkingDirectory=$PREFIX" \
    "ExecStart=$PREFIX/panda-node node --tool $TOOL --tool-executable $PREFIX/panda-arb --data-dir $DATA_DIR --host 0.0.0.0 --port $PORT --child-port $CHILD_PORT" \
    'Restart=always' \
    'RestartSec=5' \
    'NoNewPrivileges=true' \
    'PrivateTmp=true' \
    'ProtectHome=true' \
    'ProtectSystem=strict' \
    "ReadWritePaths=$DATA_DIR" \
    'UMask=0077' \
    '' \
    '[Install]' \
    'WantedBy=multi-user.target'
} > "$SERVICE_FILE"

systemctl daemon-reload
systemctl enable --now "$SERVICE"

info "等待节点启动……"
for _ in {1..20}; do
  if curl --fail --silent "http://127.0.0.1:$PORT/health" >/dev/null; then
    info "部署成功：$TOOL"
    info "服务：$SERVICE；节点端口：$PORT；本机子端口：$CHILD_PORT"
    info "查看日志：sudo journalctl -u $SERVICE -f"
    exit 0
  fi
  sleep 1
done

systemctl status "$SERVICE" --no-pager || true
die "服务未在预期时间内通过健康检查，请查看：journalctl -u $SERVICE -n 100"
