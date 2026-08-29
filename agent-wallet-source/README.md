# POPDEX Agent 钱包一键工具

这是从 PandaZhai POPDEX Agent 钱包模块整理、审计并优化的开源命令行工具，采用 MIT 许可证。它会在用户自己的电脑或服务器上生成 Agent 钱包，并可由 POPDEX 主钱包进行链上授权。

## 一键运行

Linux 或 macOS 终端执行：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/agent-wallet-source/run.sh | bash
```

程序会：

1. 在终端隐藏读取 POPDEX 主钱包私钥。
2. 在本机随机生成 Agent 钱包；已存在时安全复用，不覆盖旧私钥。
3. 直接显示 Agent 地址和 Agent 私钥，供用户离线备份。
4. 将 Agent 私钥保存到 `~/.config/pandazhai/popdex-agent/agent.env`，Linux/macOS 权限为 `0600`。
5. 预演 POPDEX 授权交易；只有输入大写 `AUTHORIZE` 才会广播。

只生成 Agent、不授权：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/agent-wallet-source/run.sh | bash -s -- --create-only
```

## 安全说明

- 主钱包私钥不会写入文件、数据库或日志，也不会通过 HTTP 请求发送。
- Agent 私钥会按用户要求显示在终端，并保存到本机私有文件；不要截图、粘贴到聊天或提交到 Git。
- 一键脚本从本仓库 `main` 分支下载源码。高安全要求用户应先审计并固定到具体提交。
- 授权交易需要 POPDEX 网络 Gas，并要求再次输入 `AUTHORIZE`。
- 不要使用 `sudo` 运行，否则 Agent 文件会保存在 root 用户目录。

## 从源码安装

```bash
cd agent-wallet-source
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e .
popdex-agent-wallet
```
