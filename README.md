# 熊猫寨套利节点封包

本仓库提供熊猫寨多服务器管理系统使用的 Linux x86_64 节点封包。套利工具仍以编译程序发布；仓库另外开放了独立的 POPDEX Agent 钱包辅助程序源码。仓库不包含用户配置、数据库、私钥、API Key、助记词或 `.env`。

| 节点类型 | 套利组合 | systemd 服务 | 安装目录 | 数据目录 |
| --- | --- | --- | --- | --- |
| `entropy-lighter` | Entropy ↔ Lighter | `panda-entropy` | `/opt/pandazhai/entropy` | `/var/lib/pandazhai/entropy` |
| `popdex-lighter` | PopDEX ↔ Lighter | `panda-popdex` | `/opt/pandazhai/popdex` | `/var/lib/pandazhai/popdex` |
| `rblighter-lighter` | RBLighter ↔ Lighter | `panda-rblighter` | `/opt/pandazhai/rblighter` | `/var/lib/pandazhai/rblighter` |
| `vanta-lighter` | Vanta ↔ Lighter | `panda-vanta` | `/opt/pandazhai/vanta` | `/var/lib/pandazhai/vanta` |
| `arcus-lighter` | Arcus ↔ Lighter | `panda-arcus` | `/opt/pandazhai/arcus` | `/var/lib/pandazhai/arcus` |
| `decibel-lighter` | Decibel ↔ Lighter | `panda-decibel` | `/opt/pandazhai/decibel` | `/var/lib/pandazhai/decibel` |

每台服务器建议只安装一种节点。当前仅支持 Ubuntu/Debian Linux x86_64（amd64），使用 systemd 常驻运行。

## 架构与端口

```text
浏览器 → 管理中心 → 节点通信端口 → 本机工具端口
                       9100          18000
```

- 节点通信端口默认是 `9100`，监听 `0.0.0.0`，供管理中心访问。
- 工具端口默认是 `18000`，只监听 `127.0.0.1`，不应开放到公网。
- 多台服务器可以使用相同端口；同一台服务器运行多个节点时才需要错开端口。
- 云安全组和系统防火墙只需允许管理中心服务器 IP 访问节点通信端口。

Entropy 和 PopDEX 的钱包门禁统一经由管理中心查询：节点注册时记录管理中心公网 HTTPS 地址，工具使用节点令牌调用管理中心的只读门禁接口，管理中心再访问本机 `8010/8012` 白名单服务。白名单端口和管理令牌不需要暴露给节点或公网。

## 安装前准备

```bash
uname -m
timedatectl status
sudo timedatectl set-ntp true
```

`uname -m` 应输出 `x86_64`。管理服务器、节点服务器和手机时间必须准确，否则动态 2FA 验证码可能被拒绝。

## 一键安装

Entropy ↔ Lighter：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/install.sh \
  | sudo bash -s -- entropy-lighter
```

PopDEX ↔ Lighter：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/install.sh \
  | sudo bash -s -- popdex-lighter
```

RBLighter ↔ Lighter：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/install.sh \
  | sudo bash -s -- rblighter-lighter
```

Vanta ↔ Lighter：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/install.sh \
  | sudo bash -s -- vanta-lighter
```

Arcus ↔ Lighter：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/install.sh \
  | sudo bash -s -- arcus-lighter
```

Arcus 注册链接：[https://app.arcus.xyz/ref/CHOU](https://app.arcus.xyz/ref/CHOU)。

Arcus-Lighter **0.1.1** 修复成交回报超时及对账后净价差缺失。已有节点请在界面暂停任务，等待执行结束，再运行保留数据的更新命令：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/packages/arcus-lighter/update.sh | sudo bash
```

脚本先校验文件、检查任务状态，再备份并更新策略程序；保留账户配置、节点 2FA、历史账本、服务配置及端口。存在运行任务或未确认订单会拒绝更新。更新后打开节点，核对版本、仓位和 STEP 后继续任务；历史净价差自动分批补全，或点击“补查历史成交”。停止服务不会自动平仓，升级不要运行清除命令。详见 [0.1.1 更新说明](packages/arcus-lighter/RELEASE-0.1.1.md)。


Decibel ↔ Lighter：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/install.sh \
  | sudo bash -s -- decibel-lighter
```

Decibel 注册链接：暂留空（目前暂无）。

Decibel 封包在 Ubuntu 24.04（glibc 2.39）构建，需使用 glibc 2.39 或更新的 Linux x86_64 系统。配置需要交易子账户地址、Geomi API Key 和已授权的 API Wallet Ed25519 私钥；API Wallet 需持有 APT 支付 Gas。默认模拟模式，尚未进行真实成交验证。

安装器会检查系统、下载并校验 `panda-node` 和 `panda-arb`、创建权限受限的 `panda` 用户、生成节点认证信息、安装 systemd 服务并检查 `/health`。

首次安装时，请立即使用身份验证器扫描终端显示的节点 2FA 二维码，并安全保存手动密钥。以后在管理中心注册节点时，需要填写该节点的当前六位动态验证码。

Vanta 用户请使用熊猫寨注册链接注册账号：

```text
https://app.vanta.exchange?ref=PANDAZHAI
```

## POPDEX Agent 钱包一键工具

在用户自己的 Linux 或 macOS 终端执行：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/agent-wallet-source/run.sh | bash
```

程序会隐藏读取 POPDEX 主钱包私钥，在本机生成并显示 Agent 钱包私钥，然后预演授权。只有用户再次输入大写 `AUTHORIZE` 才会广播授权交易。主钱包私钥不会保存或上传；Agent 私钥会以仅当前用户可读的权限保存。完整源码、安全说明和从源码安装方法见 [`agent-wallet-source`](agent-wallet-source/README.md)。

## 自定义端口

`--port` 修改节点通信端口，`--child-port` 修改本机工具端口：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/install.sh \
  | sudo bash -s -- rblighter-lighter --port 9200 --child-port 19000
```

此时管理中心应填写：

```text
http://节点公网IP:9200
```

不要填写 `19000`，该端口仅供节点程序在本机转发工具界面。

如果在已运行的节点上重新安装或修改端口，请显式重启服务，使新的 systemd 参数生效：

```bash
sudo systemctl daemon-reload
sudo systemctl restart panda-rblighter
curl -fsS http://127.0.0.1:9200/health
```

检查实际启动参数和监听端口：

```bash
sudo systemctl status panda-rblighter -l --no-pager
sudo ss -lntp | grep panda-node
```

## 在管理中心注册节点

1. 在节点服务器检查本机健康状态：

   ```bash
   curl -fsS http://127.0.0.1:9100/health
   ```

2. 在管理服务器检查远程连通性：

   ```bash
   curl -fsS http://节点公网IP:9100/health
   ```

3. 在管理中心添加节点，填写节点名称和 `http://节点公网IP:节点通信端口`。
4. 输入节点身份验证器中的当前六位验证码完成注册。

升级自旧版本后，需要删除旧节点记录并重新注册一次，让节点保存管理中心门禁回调地址。建议在管理中心服务环境中显式设置 `PANDA_MANAGER_PUBLIC_URL=https://你的管理域名`；未设置时系统会根据浏览器请求的协议和 Host 自动判断。

管理中心账号 2FA 与节点 2FA 是两套独立认证：

- 登录管理中心、修改工具配置时使用管理中心账号 2FA。
- 首次注册节点时使用节点安装初始化时生成的节点 2FA。

二者不能混用。

## 安装后管理

以下以 RBLighter 为例：

```bash
sudo systemctl status panda-rblighter -l --no-pager
sudo systemctl restart panda-rblighter
sudo systemctl stop panda-rblighter
sudo systemctl start panda-rblighter
sudo journalctl -u panda-rblighter -f
```

检查节点和工具端口：

```bash
sudo ss -lntp | grep -E ':9100|:18000'
curl -fsS http://127.0.0.1:9100/health
```

工具配置位于对应数据目录的 `tool-data/config.json`。交易所凭据和 Telegram 配置不会由管理中心明文回显。备份或迁移数据目录时应保持严格的文件权限。

保存配置时，节点会先保留上一份可用配置，再使用新配置重启工具。如果新配置导致启动失败，节点会自动恢复上一份配置并重新启动界面，同时将具体启动错误返回给管理中心。配置失败后无需登录服务器手工修改 JSON。

## 清除节点

清除命令会停止服务，并删除该节点程序、配置、数据库、注册信息和节点 2FA。需要保留的数据请先备份。以下以 Vanta 为例：

```bash
sudo systemctl disable --now panda-vanta.service

sudo rm -f -- /etc/systemd/system/panda-vanta.service
sudo rm -rf -- /opt/pandazhai/vanta
sudo rm -rf -- /var/lib/pandazhai/vanta

sudo systemctl daemon-reload
sudo systemctl reset-failed
```

Arcus ↔ Lighter 清除命令：

```bash
sudo systemctl disable --now panda-arcus.service

sudo rm -f -- /etc/systemd/system/panda-arcus.service
sudo rm -rf -- /opt/pandazhai/arcus
sudo rm -rf -- /var/lib/pandazhai/arcus

sudo systemctl daemon-reload
sudo systemctl reset-failed
```

Decibel ↔ Lighter 清除命令：

```bash
sudo systemctl disable --now panda-decibel.service

sudo rm -f -- /etc/systemd/system/panda-decibel.service
sudo rm -rf -- /opt/pandazhai/decibel
sudo rm -rf -- /var/lib/pandazhai/decibel

sudo systemctl daemon-reload
sudo systemctl reset-failed
```

## 更新节点程序

重新执行对应的一键安装命令即可下载最新封包。安装完成后主动重启并检查健康状态：

```bash
sudo systemctl daemon-reload
sudo systemctl restart panda-rblighter
curl -fsS http://127.0.0.1:9100/health
```

更新不会主动删除数据目录中的节点认证和工具配置。更新前建议备份：

```bash
sudo cp -a /var/lib/pandazhai/rblighter /var/lib/pandazhai/rblighter.backup
```

## 常见问题

### 安装提示“服务未在预期时间内通过健康检查”

```bash
sudo systemctl status panda-rblighter -l --no-pager
sudo journalctl -u panda-rblighter -n 100 --no-pager
sudo ss -lntp | grep panda-node
```

如果刚修改过端口，旧进程可能仍使用旧参数。执行：

```bash
sudo systemctl daemon-reload
sudo systemctl restart panda-rblighter
```

然后使用新端口重新检查 `/health`。

### 注册节点返回 `401 Unauthorized`

节点 `/register` 返回 401 通常表示节点 2FA 验证码错误。确认使用的是节点初始化时绑定的 2FA，而不是管理中心账号 2FA，并确认手机和服务器时间同步。

如果节点 2FA 密钥已丢失，可停止服务、备份认证文件并重新初始化。以下以 RBLighter 为例：

```bash
sudo systemctl stop panda-rblighter
sudo mv /var/lib/pandazhai/rblighter/auth.json \
  /var/lib/pandazhai/rblighter/auth.json.backup
sudo -u panda /opt/pandazhai/rblighter/panda-node \
  node \
  --tool rblighter-lighter \
  --tool-executable /opt/pandazhai/rblighter/panda-arb \
  --data-dir /var/lib/pandazhai/rblighter \
  --init-only
sudo systemctl start panda-rblighter
```

重新初始化会使原节点认证失效，需要用新二维码重新绑定并在管理中心重新注册。备份文件可用于人工恢复旧认证。

### “工具界面转发失败：All connection attempts failed”

这表示节点通信服务可访问，但节点暂时连接不到本机工具进程：

```bash
sudo systemctl status panda-rblighter -l --no-pager
sudo journalctl -u panda-rblighter -n 200 --no-pager
sudo ss -lntp | grep 18000
curl -v http://127.0.0.1:18000/
```

当前节点程序在配置保存触发重启后，会等待工具界面开始接受 HTTP 请求再返回。如果仍然失败，通常是新配置导致工具进程启动失败，具体原因应在 systemd 日志中。

### 管理中心无法访问节点

依次检查：

1. 节点本机 `/health` 是否正常。
2. 节点端口是否监听在 `0.0.0.0`。
3. 云安全组是否允许管理服务器 IP 访问节点 TCP 端口。
4. UFW、iptables 等主机防火墙是否放行。
5. 管理中心填写的是节点通信端口，而不是工具端口。

UFW 只允许管理服务器 IP 的示例：

```bash
sudo ufw allow from 管理服务器IP to any port 9100 proto tcp
```

## 手动校验封包

```bash
cd packages/rblighter-lighter
sha256sum -c SHA256SUMS
```

正常输出：

```text
panda-node: OK
panda-arb: OK
```

## 安全建议

- 首次部署保持 DRY RUN，确认账户、市场映射、行情、下单和风控行为后再开启实盘。
- 使用专用交易账户或子账户，并限制资金规模和 API 权限。
- 不要把工具端口暴露到公网。
- 节点通信端口只允许管理中心服务器 IP 访问。
- 不要把私钥、API Key、TOTP 密钥、配置或数据目录提交到 GitHub。
- 使用 NTP/chrony 保持服务器时间同步。
- 定期备份节点数据目录并妥善保护备份文件。
- 本封包不支持 ARM、Windows 或 macOS。
