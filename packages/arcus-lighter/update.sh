#!/usr/bin/env bash
set -Eeuo pipefail

# Download and validate before stopping the node. Existing data, ports and 2FA
# are preserved. --recover-exit retains a verifiable, pending risk-exit intent.
recover_exit=0
case "${1:-}" in
  '') [[ $# == 0 ]] || exit 1 ;;
  --recover-exit) [[ $# == 1 ]] || exit 1; recover_exit=1 ;;
  *) echo '用法：sudo bash update.sh [--recover-exit]' >&2; exit 1 ;;
esac
[[ $(id -u) == 0 ]] || { echo '请使用 sudo bash update.sh' >&2; exit 1; }
[[ $(uname -s)/$(uname -m) == Linux/x86_64 ]] || { echo '仅支持 Linux x86_64' >&2; exit 1; }
for program in curl sha256sum systemctl install stat tar mktemp awk cp mv date flock; do
  command -v "$program" >/dev/null || { echo "缺少命令：$program" >&2; exit 1; }
done
if (( recover_exit )); then
  command -v python3 >/dev/null || { echo '恢复更新需要 python3 读取原账本。' >&2; exit 1; }
fi
exec 9>/var/lock/pandazhai-arcus-update.lock
flock -n 9 || { echo '已有 Arcus 更新进程，请勿同时更新。' >&2; exit 1; }
prefix=/opt/pandazhai/arcus
data_dir=/var/lib/pandazhai/arcus
service=panda-arcus.service
if [[ -x "$prefix/panda-arb" ]]; then
  target="$prefix/panda-arb"
elif [[ -x "$prefix/panda-arb-arcus" ]]; then
  target="$prefix/panda-arb-arcus"
else
  echo '未找到已安装的 Arcus-Lighter 程序；本脚本仅用于更新。' >&2
  exit 1
fi
[[ -d "$data_dir" ]] || { echo '未找到原节点数据目录，停止更新。' >&2; exit 1; }
systemctl cat "$service" >/dev/null
temporary=$(mktemp -d /tmp/pandazhai-arcus-update.XXXXXX)
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
      systemctl start "$service" || echo '原服务启动失败，请检查 systemctl status panda-arcus.service。' >&2
    fi
  fi
  rm -rf -- "$temporary"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

check_state() {
  if (( !recover_exit )); then
    local result=0
    "$temporary/panda-arb" update-check --data-dir "$data_dir/tool-data" || result=$?
    if (( result == 2 )); then
      echo '若旧版卡在“风险退出待确认”，可使用 --recover-exit；该模式保留原订单与账本，不清空记录。' >&2
    fi
    return "$result"
  fi
  python3 - "$data_dir/tool-data/arbitrage.db" <<'PY'
import json
import os
import sqlite3
import sys
from decimal import Decimal
from pathlib import Path

def require(condition, message):
    if not condition:
        raise ValueError(message)

try:
    path = Path(sys.argv[1]).resolve()
    require(path.is_file(), '缺少原任务数据库，请使用普通更新')
    # Even a read-only WAL reader may create -shm. Keep sidecars owned by the
    # original service account, so root's maintenance check cannot lock it out.
    owner = path.stat()
    if os.geteuid() == 0:
        os.setgroups([])
        os.setgid(owner.st_gid)
        os.setuid(owner.st_uid)
    with sqlite3.connect(path.as_uri() + '?mode=ro', uri=True) as db:
        db.row_factory = sqlite3.Row
        db.execute('BEGIN')  # Consistent read, including the old process's WAL.
        require(db.execute('PRAGMA quick_check').fetchone()[0] == 'ok', '数据库完整性检查失败')
        tasks = {r['id']: r for r in db.execute('SELECT id,status FROM tasks')}
        safe = {'CREATED', 'PAUSED', 'STOPPED', 'COMPLETED'}
        require(all(t['status'] in safe | {'RISK_EXIT'} for t in tasks.values()),
                '仍有普通运行、执行或恢复任务；请先暂停这些任务')
        sessions = {r['task_id']: json.loads(r['payload_json'])
                    for r in db.execute('SELECT task_id,payload_json FROM risk_exit_sessions')}
        require(set(sessions) == {k for k,t in tasks.items() if t['status'] == 'RISK_EXIT'},
                '任务状态与风险退出记录不一致')
        pending = {r['execution_id']: r for r in db.execute(
            "SELECT execution_id,task_id,direction FROM executions WHERE state NOT IN ('SUCCEEDED','COMPENSATED','FAILED','RECONCILED')")}
        allowed = set()
        for task_id, session in sessions.items():
            require(session.get('initialized') is True and not session.get('untracked_submission')
                    and not session.get('inflight_executions'), '退出尚未完成原订单接管，不能使用此恢复更新')
            execution_id = session['execution_id']
            execution = pending.get(execution_id)
            require(execution is not None and execution['task_id'] == task_id
                    and execution['direction'] == 'RISK_EXIT', '风险退出执行记录不完整')
            orders = session['orders']
            require(isinstance(orders, dict) and orders and set(orders) <= {'lighter','arcus'},
                    '缺少可追踪的原退出订单')
            for exchange, leg in orders.items():
                require(leg['exchange'] == exchange and bool(leg['client_order_id'])
                        and leg.get('execution_id', execution_id) == execution_id,
                        '原退出订单归属不一致')
                require(leg['status'] in {'SUBMITTING','UNKNOWN','ACCEPTED','FILLED','PARTIALLY_FILLED','CANCELED','FAILED'},
                        '未知的原订单状态')
                qty, filled = Decimal(leg['quantity']), Decimal(leg['filled_qty'])
                actual, baseline = Decimal(leg['actual']), Decimal(leg['baseline'])
                price, slippage = Decimal(leg['reference_price']), Decimal(leg['max_slippage_bps'])
                require(all(v.is_finite() for v in (qty, filled, actual, baseline, price, slippage))
                        and qty > 0 and 0 <= filled <= qty and price >= 0 and slippage >= 0,
                        '原退出订单数值无效')
                delta = actual - baseline
                require(leg['side'] == ('SELL' if delta > 0 else 'BUY') and actual * delta > 0
                        and qty <= abs(delta) <= abs(actual), '原订单不符合减仓退出方向')
            allowed.add(execution_id)
        require(set(pending) == allowed, '存在风险退出以外的未确认执行，不能使用此恢复更新')
        print(f'[恢复检查通过] 保留 {len(sessions)} 个退出会话及原订单；不会将未知订单直接标记为成功。')
except Exception as exc:
    print(f'[停止恢复更新] {exc}', file=sys.stderr)
    sys.exit(2)
PY
}
release_ref="${PANDAZHAI_REF:-main}"
base="https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/$release_ref/packages/arcus-lighter"
curl -fL --retry 3 "$base/SHA256SUMS" -o "$temporary/SHA256SUMS"
curl -fL --retry 3 "$base/panda-arb" -o "$temporary/panda-arb"
awk '$2=="panda-arb" {print}' "$temporary/SHA256SUMS" > "$temporary/arb.sha256"
[[ -s "$temporary/arb.sha256" ]] || { echo '缺少策略程序校验值。' >&2; exit 1; }
(cd "$temporary" && sha256sum -c arb.sha256)
chmod 700 "$temporary/panda-arb"
[[ $("$temporary/panda-arb" --version) == 0.1.1 ]] || { echo '版本不符，原节点未变更。' >&2; exit 1; }
check_state

echo '检查通过，开始停止服务并备份。停止服务本身不会发出平仓指令。'
backup="/var/backups/pandazhai/arcus/$(date -u +%Y%m%dT%H%M%SZ)-$$"
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
tar -C /var/lib/pandazhai -czf "$backup/arcus-data.tar.gz" arcus
chmod 600 "$backup/arcus-data.tar.gz"
tar -tzf "$backup/arcus-data.tar.gz" >/dev/null
install -o "$owner" -g "$group" -m "$mode" "$temporary/panda-arb" "$target.new"
# Arm rollback before the atomic replacement, including signal interruption.
replaced=1
mv -f "$target.new" "$target"
systemctl start "$service"
systemctl is-active --quiet "$service"
success=1
echo "已更新至 Arcus-Lighter 0.1.1，备份目录：$backup"
if (( recover_exit )); then
  echo '请打开节点启动新版：它将查询原平仓订单并核对仓位；确认后结束退出，若有残仓则沿用既有退出指令减仓。'
  echo '原订单无法确认时仍保持风险退出状态，不重复提交原单，不自动开启新套利任务。'
fi
echo '请在管理中心打开节点，核对版本、仓位和 STEP 后继续任务。历史成交会分批补账，也可点击“补查历史成交”。'
