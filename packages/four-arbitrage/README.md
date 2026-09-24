# 四平台套利管理节点（Linux x86_64）

版本 **0.1.3**。Entropy、Lighter、Robinhood Lighter、QFEX 四平台工具现已接入 pandazhai.com 管理中心。

## 一键安装或从独立版迁移

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/install.sh | sudo bash -s -- four-arbitrage --port 9100
```

安装时显示**节点注册 2FA 二维码和手动密钥**，请绑定到身份验证器。然后打开 https://pandazhai.com ，创建节点，填写服务器 IP、9100 端口和节点验证码。管理中心会自动识别“四平台套利”并打开工具界面，不需要 SSH 隧道或再输入工具登录验证码。保存交易配置仍需管理中心账户的 2FA。

节点网关监听 `0.0.0.0:9100`；策略子进程仅监听 `127.0.0.1:18000`。安全组允许管理中心访问节点端口，不需要开放子端口。如果同机其他工具占用端口，可同时调整：

```bash
curl -fsSL https://raw.githubusercontent.com/lihanyu81/PandaZhai-Arbitrage-Tool/main/install.sh | sudo bash -s -- four-arbitrage --port 9101 --child-port 18001
```

安装器只会停止/替换 `panda-four.service`，遇到其他服务占用端口会退出。从旧独立版迁移时，会先备份，再把配置、交易账本和旧工具 2FA 移到 `/var/lib/pandazhai/four/tool-data`；不需要清空重装。若发现两套冲突数据，会拒绝覆盖。备份位于 `/var/backups/pandazhai-four/`，应按敏感账户数据保管。

迁移期间服务会暂时停止；先暂停任务并核对仓位。升级或注册不会自动恢复套利，新装默认演示模式并暂停。注册后的节点保持原账户配置，但仍需核对持仓后自行恢复。

重新查看**节点注册**二维码：

```bash
sudo -u panda-four /opt/pandazhai/four/panda-node node --tool four-arbitrage --tool-executable /opt/pandazhai/four/panda-four --data-dir /var/lib/pandazhai/four --init-only --show-qr
```

这是节点身份验证器，与旧独立版工具 2FA、管理中心账户 2FA 分开。

## 停止服务

```bash
sudo systemctl stop panda-four.service
```

停止服务不会平掉交易所仓位。

## 清除节点

先处理交易所仓位和挂单。以下命令永久删除本节点程序、配置、2FA 和交易记录，不会自动平仓，也不删除迁移备份。

```bash
sudo systemctl disable --now panda-four.service
sudo rm -f -- /etc/systemd/system/panda-four.service
sudo rm -rf -- /etc/systemd/system/panda-four.service.d
sudo rm -rf -- /opt/pandazhai/four /var/lib/pandazhai/four
sudo systemctl daemon-reload
```

如需连备份一起清除，确认不再需要恢复后执行：

```bash
sudo rm -rf -- /var/backups/pandazhai-four
```

## 交易与封包说明

单标的生成六组组合、十二个买卖方向；每次执行一组买卖两腿，不保证跨交易所原子成交。未确认订单持续查单、不自动重发，完整回报到齐后计算收益。未知订单期间显示待核对。已平仓收益按组合开平仓成交与手续费汇总，不包含资金费及人工交易。

封包不含松散 Python 应用源码、账户配置或数据库；不能保证防止专业反编译。保留独立版 `install-local.sh`，需要独立部署时可使用。见 [0.1.3 版本说明](RELEASE-0.1.3.md)。
