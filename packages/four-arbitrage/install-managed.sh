#!/usr/bin/env bash
set -Eeuo pipefail
[[ $(id -u) == 0 ]] || { echo '请使用 sudo'; exit 1; }
port=9100
child_port=18000
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) port=${2:?}; shift 2;;
    --child-port) child_port=${2:?}; shift 2;;
    *) echo "未知参数 $1"; exit 1;;
  esac
done
for value in "$port" "$child_port"; do
  [[ $value =~ ^[0-9]{1,5}$ ]] && ((10#$value > 0 && 10#$value < 65536)) || { echo '端口无效'; exit 1; }
done
port=$((10#$port)); child_port=$((10#$child_port))
[[ $port != "$child_port" ]] || { echo '两个端口不能相同'; exit 1; }
source_dir=$(cd -- "$(dirname -- "$0")" && pwd)
for artifact in panda-node panda-four; do [[ -f $source_dir/$artifact ]] || { echo "缺少 $artifact"; exit 1; }; done
# Permit upgrading this service, but never stop a different node occupying a port.
python3 - "$port" "$child_port" <<'PY'
import pathlib,re,subprocess,sys
for port in sys.argv[1:]:
    output=subprocess.check_output(['ss','-H','-ltnp',f'sport = :{port}'],text=True)
    for line in output.splitlines():
        pids=re.findall(r'pid=(\d+)',line)
        if not pids or any('panda-four.service' not in pathlib.Path('/proc',p,'cgroup').read_text() for p in pids):
            raise SystemExit(f'端口 {port} 被其他服务占用，请使用其他端口；没有停止任何服务。')
PY
prefix=/opt/pandazhai/four
data=/var/lib/pandazhai/four
backup=/var/backups/pandazhai-four/$(date -u +%Y%m%dT%H%M%SZ)-$$
install -d -m 700 "$backup"
[[ ! -d $prefix ]] || cp -a "$prefix" "$backup/program"
[[ ! -f /etc/systemd/system/panda-four.service ]] || cp -a /etc/systemd/system/panda-four.service "$backup/service"
[[ ! -d /etc/systemd/system/panda-four.service.d ]] || cp -a /etc/systemd/system/panda-four.service.d "$backup/dropins"
was_active=0
systemctl is-active --quiet panda-four.service && was_active=1
systemctl stop panda-four.service 2>/dev/null || true
rollback() {
  trap - ERR
  systemctl stop panda-four.service 2>/dev/null || true
  if [[ -d $backup/program ]]; then rm -rf -- "$prefix"; cp -a "$backup/program" "$prefix"; fi
  if [[ -d $backup/data ]]; then rm -rf -- "$data"; cp -a "$backup/data" "$data"; fi
  if [[ -f $backup/service ]]; then cp -a "$backup/service" /etc/systemd/system/panda-four.service; else rm -f /etc/systemd/system/panda-four.service; fi
  rm -rf -- /etc/systemd/system/panda-four.service.d
  [[ ! -d $backup/dropins ]] || cp -a "$backup/dropins" /etc/systemd/system/panda-four.service.d
  systemctl daemon-reload
  ((was_active == 0)) || systemctl start panda-four.service
  echo "安装失败，已恢复备份：$backup" >&2
}
trap rollback ERR
if [[ -d $data ]]; then cp -a "$data" "$backup/data.tmp"; mv "$backup/data.tmp" "$backup/data"; fi
id panda-four >/dev/null 2>&1 || useradd --system --home-dir "$data" --create-home --shell /usr/sbin/nologin panda-four
install -d -m 755 "$prefix"
install -d -m 700 -o panda-four -g panda-four "$data" "$data/tool-data"
python3 - "$data" <<'PY'
import json,pathlib,sys,shutil
root=pathlib.Path(sys.argv[1]); child=root/'tool-data'
auth=root/'auth.json'
standalone=(root/'four.db').exists() or (root/'config.json').exists()
if auth.exists(): standalone |= json.loads(auth.read_text()).get('issuer')=='PandaZhai Four Venue Arbitrage'
if standalone:
    files=[p for p in root.iterdir() if p.is_file() and (p.name in {'config.json','auth.json'} or p.name.endswith(('.db','.db-wal','.db-shm')))]
    conflicts=[p.name for p in files if (child/p.name).exists()]
    if conflicts: raise SystemExit('发现两套数据，请先核对，拒绝覆盖：'+','.join(conflicts))
    for p in files: shutil.move(str(p),str(child/p.name))
PY
chown -R panda-four:panda-four "$data"
install -m 755 "$source_dir/panda-node" "$prefix/panda-node"
install -m 755 "$source_dir/panda-four" "$prefix/panda-four"
# Register a separate node identity; retain the old tool identity under tool-data.
runuser -u panda-four -- "$prefix/panda-node" node --tool four-arbitrage --tool-executable "$prefix/panda-four" --data-dir "$data" --init-only --show-qr
cat > /etc/systemd/system/panda-four.service <<UNIT
[Unit]
Description=PandaZhai four-arbitrage managed node
After=network-online.target
Wants=network-online.target
[Service]
User=panda-four
Group=panda-four
WorkingDirectory=$prefix
ExecStart=$prefix/panda-node node --tool four-arbitrage --tool-executable $prefix/panda-four --data-dir $data --host 0.0.0.0 --port $port --child-port $child_port
Restart=on-failure
RestartSec=5
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
[Install]
WantedBy=multi-user.target
UNIT
# Remove the previous standalone port override, which would bypass the node wrapper.
rm -f /etc/systemd/system/panda-four.service.d/port.conf
systemctl daemon-reload
systemctl enable --now panda-four.service
ready=0
for _ in {1..30}; do
  if curl -fsS "http://127.0.0.1:$port/health" | python3 -c 'import json,sys;d=json.load(sys.stdin);sys.exit(0 if d.get("tool")=="four-arbitrage" and d.get("interface")=="/ui/" else 1)' 2>/dev/null; then ready=1; break; fi
  sleep 1
done
[[ $ready == 1 ]]
trap - ERR
echo "安装完成：在 pandazhai.com 创建节点，填写服务器 IP、端口 $port 和上方节点 2FA 验证码。"
echo "备份：$backup；配置、2FA 和交易记录已保留。工具子进程在注册后启动，不自动恢复套利。"
echo "重新显示注册二维码：sudo -u panda-four $prefix/panda-node node --tool four-arbitrage --tool-executable $prefix/panda-four --data-dir $data --init-only --show-qr"
