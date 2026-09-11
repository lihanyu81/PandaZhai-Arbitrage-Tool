#!/usr/bin/env bash
set -Eeuo pipefail

# In-place 0.5.0 update: preserve configuration, authentication, ledger and ports.
[[ $# == 0 ]] || { echo '用法：sudo bash update.sh' >&2; exit 1; }
[[ $(id -u) == 0 ]] || { echo '请使用 sudo bash update.sh' >&2; exit 1; }
[[ $(uname -s)/$(uname -m) == Linux/x86_64 ]] || { echo '仅支持 Linux x86_64' >&2; exit 1; }
for program in curl sha256sum systemctl install stat tar mktemp awk cp mv date flock python3; do
  command -v "$program" >/dev/null || { echo "缺少命令：$program" >&2; exit 1; }
done
exec 9>/var/lock/pandazhai-popdex-update.lock
flock -n 9 || { echo '已有 PopDEX 更新进程，请勿同时更新。' >&2; exit 1; }
prefix=/opt/pandazhai/popdex
data_dir=/var/lib/pandazhai/popdex
service=panda-popdex.service
if [[ -x "$prefix/panda-arb" ]]; then
  target="$prefix/panda-arb"
elif [[ -x "$prefix/panda-arb-popdex" ]]; then
  target="$prefix/panda-arb-popdex"
else
  echo '未找到已安装的 PopDEX-Lighter 程序；本脚本仅用于更新。' >&2
  exit 1
fi
[[ -d "$data_dir" ]] || { echo '未找到原节点数据目录，停止更新。' >&2; exit 1; }
systemctl cat "$service" >/dev/null
temporary=$(mktemp -d /tmp/pandazhai-popdex-update.XXXXXX)
stopped=0
replaced=0
success=0
was_active=0
cleanup() {
  local result=$?
  trap - EXIT INT TERM
  if (( stopped && !success )); then
    echo '更新未完成，保留当前账本，恢复原程序及服务状态。' >&2
    if (( replaced )); then
      if systemctl stop "$service" &&
          install -o "$owner" -g "$group" -m "$mode" "$backup/panda-arb.previous" "$target.rollback" &&
          mv -f "$target.rollback" "$target"; then
        replaced=0
      else
        echo "自动恢复程序失败；服务未主动启动。备份：$backup" >&2
      fi
    fi
    if (( was_active && !replaced )); then
      systemctl start "$service" || echo '原服务启动失败，请检查 systemctl status panda-popdex.service。' >&2
    fi
  fi
  rm -rf -- "$temporary"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

check_state() {
  python3 - "$data_dir/tool-data/arbitrage.db" <<'PYCODE'
import os
import sqlite3
import sys
from pathlib import Path
try:
    path = Path(sys.argv[1]).resolve()
    if not path.is_file():
        raise ValueError('未找到原账本，停止更新以免使用错误的数据目录')
    owner = path.stat()
    if os.geteuid() == 0:
        os.setgroups([])
        os.setgid(owner.st_gid)
        os.setuid(owner.st_uid)
    with sqlite3.connect(path.as_uri() + '?mode=ro', uri=True) as db:
        db.execute('BEGIN')
        if db.execute('PRAGMA quick_check').fetchone()[0] != 'ok':
            raise ValueError('数据库完整性检查失败')
        tasks = dict(db.execute('SELECT id,status FROM tasks'))
        safe = {'CREATED','PAUSED','STOPPED','COMPLETED','ERROR'}
        if any(status not in safe for status in tasks.values()):
            raise ValueError('请先在界面暂停任务，等待当前双腿执行结束后重试')
        pending = db.execute("SELECT task_id FROM executions WHERE state NOT IN ('SUCCEEDED','COMPENSATED','FAILED','RECONCILED')").fetchall()
        if any(tasks.get(task_id) != 'ERROR' for (task_id,) in pending):
            raise ValueError('存在尚未确认的执行，请先完成对账后重试')
        # 0.5.0 restores ERROR tasks under an opening lock, preserving all original
        # orders for monitoring. Do not rewrite their task or execution records.
        errors = sum(status == 'ERROR' for status in tasks.values())
        print(f'[检查通过] 保留原任务与账本；ERROR 任务 {errors} 个，新版核验后仍需人工继续。')
except Exception as exc:
    print(f'[停止更新] {exc}', file=sys.stderr)
    sys.exit(2)
PYCODE
}
release_ref="ad3ab05ea6348c27e0c203425db02a2de94c2e6b"
base="https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/$release_ref/packages/popdex-lighter"
curl -fL --retry 3 "$base/SHA256SUMS" -o "$temporary/SHA256SUMS"
curl -fL --retry 3 "$base/panda-arb" -o "$temporary/panda-arb"
awk '$2=="panda-arb" {print}' "$temporary/SHA256SUMS" > "$temporary/arb.sha256"
[[ -s "$temporary/arb.sha256" ]] || { echo '缺少策略程序校验值。' >&2; exit 1; }
(cd "$temporary" && sha256sum -c arb.sha256)
chmod 700 "$temporary/panda-arb"
[[ $("$temporary/panda-arb" --version) == 0.5.0 ]] || { echo '版本不符，原节点未变更。' >&2; exit 1; }
check_state

echo '检查通过，开始停止服务并备份。停止服务本身不会发出平仓指令。'
backup="/var/backups/pandazhai/popdex/$(date -u +%Y%m%dT%H%M%SZ)-$$"
install -d -m 700 "$backup"
cp -p "$target" "$backup/panda-arb.previous"
owner=$(stat -c %u "$target")
group=$(stat -c %g "$target")
mode=$(stat -c %a "$target")
kill_mode=$(systemctl show "$service" --property=KillMode --value)
[[ "$kill_mode" == control-group || "$kill_mode" == mixed ]] || { echo '服务 KillMode 无法保证停止全部子进程，原程序未替换。' >&2; exit 1; }
if systemctl is-active --quiet "$service"; then was_active=1; fi
stopped=1
systemctl stop "$service"
[[ $(systemctl show "$service" --property=ActiveState --value) == inactive ]] || { echo '服务未完全停止，终止更新。' >&2; exit 1; }
check_state
tar -C /var/lib/pandazhai -czf "$backup/popdex-data.tar.gz" popdex
chmod 600 "$backup/popdex-data.tar.gz"
tar -tzf "$backup/popdex-data.tar.gz" >/dev/null
install -o "$owner" -g "$group" -m "$mode" "$temporary/panda-arb" "$target.new"
# Arm rollback before the atomic replacement, including signal interruption.
replaced=1
mv -f "$target.new" "$target"
if (( was_active )); then
  systemctl start "$service"
  systemctl is-active --quiet "$service"
fi
success=1
echo "已更新至 PopDEX-Lighter 0.5.0，备份目录：$backup"
echo "配置、节点认证、历史数据和原端口均已保留。请刷新界面，核对版本后手动继续任务。"
