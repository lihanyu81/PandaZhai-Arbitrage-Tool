# 四平台套利节点（Linux x86_64）

接入 Entropy、Lighter、Robinhood Lighter、QFEX。选择一个共同标的，生成六组组合，计算十二个买卖方向并统一核对仓位。

## 下载安装

在服务器上执行以下命令，下载可执行文件与安装脚本并校验：

```bash
mkdir -p ~/panda-four-install
cd ~/panda-four-install
curl -fL -o panda-four https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/packages/four-arbitrage/panda-four
curl -fL -o install-local.sh https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/packages/four-arbitrage/install-local.sh
curl -fL -o SHA256SUMS https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/packages/four-arbitrage/SHA256SUMS
sha256sum -c SHA256SUMS
chmod +x panda-four install-local.sh
sudo ./install-local.sh
```

确认校验全部显示 `OK` 后再安装。脚本创建独立 `panda-four` 服务，程序位于 `/opt/pandazhai/four`，数据位于 `/var/lib/pandazhai/four`。默认只监听 `127.0.0.1:8007`。

在自己的电脑建立 SSH 隧道，将服务器地址替换为实际地址：

```bash
ssh -L 8007:127.0.0.1:8007 ubuntu@服务器地址
```

然后打开浏览器 `http://127.0.0.1:8007`。在服务器本机查看并绑定工具 2FA：

```bash
sudo -u panda-four /opt/pandazhai/four/panda-four auth --data-dir /var/lib/pandazhai/four
```

不安装服务也可运行：`./panda-four serve --host 127.0.0.1 --port 8007`，默认数据目录为当前用户的 `~/.local/share/panda-four-arb`。

## 使用与运行边界

默认演示模式且暂停。先选标的生成六组策略，确认模拟流程；再配置四家账户、实际费率和限额，切换真实行情模拟。共同标的来自四家市场目录交集，不支持的平台不会用假行情代替。

实盘需要明确开启实盘模式和确认开关。首次使用的标的应无旧持仓或挂单，也不要让其他节点或人工同时交易相同账户标的。本版本不支持导入已有仓位作为基线。

两家交易所不能原子成交，一腿失败或部分成交会暂停新增、等待核验与处理。暂停新增后已有持仓的止盈和风险退出仍会运行。重启后需先对账再恢复。

仓位按相同基础资产单位汇总。仅适用于相同标的、相同合约计量单位；净数量为零也需要逐平台核对账本。净 bps 估算包含预留手续费和滑点，不包含资金费，也不保证收益。

当前为独立节点版，尚未包含管理中心注册组件，尚未完成四平台真实资金开平仓验收。详见 [版本说明](RELEASE-0.1.2.md)。

## 停止服务

```bash
sudo systemctl stop panda-four
```

停止服务不会平掉交易所仓位。账户密钥和 2FA 数据保存在独立数据目录，不随发布包分发。

## 封包说明

分发的是单文件可执行程序，不包含散装 Python 应用源码。普通解压无法直接得到 `.py` 源文件；封包不是不可逆加密，不能承诺防止专业反编译。前端资源会由浏览器加载。

当前版本 **0.1.2**：QFEX 回报兼容修复、逐腿独立保存与超时控制；未确认订单每 30 秒自动补查，补齐收益后仍需核对持仓再恢复，不自动重发订单。

0.1.2 补充退出收益保护：未知订单期间显示“待核对”，完整成交确认后再计算；已验证全部 12 个方向的手动/风险退出、部分成交多轮退出、延迟回报和重启后收益。
