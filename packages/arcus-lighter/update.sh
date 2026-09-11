#!/usr/bin/env bash
set -Eeuo pipefail

# Download and validate before stopping the node. Existing data, ports and 2FA
# are preserved. Pause tasks and wait for executions to finish before running.
[[ $(id -u) == 0 ]] || { echo '请使用 sudo bash update.sh' >&2; exit 1; }
[[ $(uname -s)/$(uname -m) == Linux/x86_64 ]] || { echo '仅支持 Linux x86_64' >&2; exit 1; }
for program in curl sha256sum systemctl install stat tar mktemp awk cp mv date; do
  command -v "$program" >/dev/null || { echo "缺少命令：$program" >&2; exit 1; }
done
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
trap 'rm -rf -- "$temporary"' EXIT
release_ref="${PANDAZHAI_REF:-main}"
base="https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/$release_ref/packages/arcus-lighter"
curl -fL --retry 3 "$base/SHA256SUMS" -o "$temporary/SHA256SUMS"
curl -fL --retry 3 "$base/panda-arb" -o "$temporary/panda-arb"
awk '$2=="panda-arb" {print}' "$temporary/SHA256SUMS" > "$temporary/arb.sha256"
[[ -s "$temporary/arb.sha256" ]] || { echo '缺少策略程序校验值。' >&2; exit 1; }
(cd "$temporary" && sha256sum -c arb.sha256)
chmod 700 "$temporary/panda-arb"
[[ $("$temporary/panda-arb" --version) == 0.1.1 ]] || { echo '版本不符，原节点未变更。' >&2; exit 1; }
"$temporary/panda-arb" update-check --data-dir "$data_dir/tool-data"

echo '只读检查通过，开始更新。停止服务不会平仓；更新后需核对并手动继续任务。'
backup="/var/backups/pandazhai/arcus/$(date -u +%Y%m%dT%H%M%SZ)-$$"
install -d -m 700 "$backup"
cp -p "$target" "$backup/panda-arb.previous"
owner=$(stat -c %u "$target")
group=$(stat -c %g "$target")
mode=$(stat -c %a "$target")
systemctl stop "$service"
rollback() {
  trap - ERR
  echo '更新未完成，正在恢复原程序；配置和账本保留。' >&2
  install -o "$owner" -g "$group" -m "$mode" "$backup/panda-arb.previous" "$target"
  systemctl start "$service" || true
  exit 1
}
trap rollback ERR
"$temporary/panda-arb" update-check --data-dir "$data_dir/tool-data"
tar -C /var/lib/pandazhai -czf "$backup/arcus-data.tar.gz" arcus
chmod 600 "$backup/arcus-data.tar.gz"
install -o "$owner" -g "$group" -m "$mode" "$temporary/panda-arb" "$target.new"
mv -f "$target.new" "$target"
systemctl start "$service"
systemctl is-active --quiet "$service"
trap - ERR
echo "已更新至 Arcus-Lighter 0.1.1，备份目录：$backup"
echo '请在管理中心打开节点，核对版本、仓位和 STEP 后继续任务。历史成交会分批补账，也可点击“补查历史成交”。'
