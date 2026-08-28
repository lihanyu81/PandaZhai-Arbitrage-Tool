# 熊猫寨套利节点封包

本仓库只提供三种 Linux x86_64 套利节点封包，不包含 Python 源码、用户配置、数据库、私钥或 `.env`：

- `entropy-lighter`
- `popdex-lighter`
- `rblighter-lighter`

每台服务器安装一种节点。支持 Ubuntu/Debian x86_64，使用 systemd 常驻运行。

## 一键部署

Entropy ↔ Lighter：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/install.sh | sudo bash -s -- entropy-lighter
```

PopDEX ↔ Lighter：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/install.sh | sudo bash -s -- popdex-lighter
```

RBLighter ↔ Lighter：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/install.sh | sudo bash -s -- rblighter-lighter
```

安装器会自动完成以下操作：

1. 检查 root 权限、Linux x86_64 架构和所需命令。
2. 下载对应节点程序与套利程序并核验 SHA-256。
3. 创建权限受限的 `panda` 系统用户和数据目录。
4. 首次初始化节点认证信息。
5. 创建并启动 systemd 服务。
6. 检查节点健康状态并显示服务信息。

默认节点通信端口为 `9100`，工具子进程仅监听本机 `127.0.0.1:18000`。自定义端口：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/install.sh \
  | sudo bash -s -- entropy-lighter --port 9200 --child-port 19000
```

## 安装后管理

以 Entropy 节点为例：

```bash
sudo systemctl status panda-entropy
sudo journalctl -u panda-entropy -f
sudo systemctl restart panda-entropy
```

另外两个服务名分别为 `panda-popdex` 和 `panda-rblighter`。程序和数据位置：

```text
/opt/pandazhai/<节点简称>/
/var/lib/pandazhai/<节点简称>/
```

交易所凭据和 Telegram 配置保存在节点数据目录的 `tool-data/config.json`，敏感字段不会回显。首次部署请保持 DRY RUN，确认账户、市场映射、网络和风控参数后再开启实盘。

## 手动校验

```bash
cd packages/entropy-lighter
sha256sum -c SHA256SUMS
```

## 安全建议

- 防火墙只允许管理端 IP 访问节点通信端口。
- 不要将工具子进程端口暴露到公网。
- 生产环境使用专用账户或子账户，并限制资金和权限。
- 使用 NTP/chrony 保持服务器时间同步。
- 本封包仅支持 Linux x86_64，不支持 ARM、Windows 或 macOS。
