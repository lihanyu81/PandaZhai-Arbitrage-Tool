# PandaZhai Arbitrage Control Release

这是 Linux x86_64 服务器发布包。发布内容是 PyInstaller 封装的二进制运行时和固定工具类型启动入口，不包含 Python 源代码、测试、`.env`、私钥、2FA 文件或数据库。

## 发布文件

- `release/panda-manager`：管理中心入口
- `release/panda-node-rblighter`：RBLighter-Lighter 节点入口
- `release/panda-node-popdex`：PopDEX-Lighter 节点入口
- `release/panda-node-entropy`：Entropy-Lighter 节点入口
- `release/panda-control-runtime`：封装后的共享运行时二进制，请与上述入口放在同一目录

## 管理中心

```bash
cd release
chmod +x panda-*
./panda-manager --data-dir ./manager-data --host 0.0.0.0 --port 9000
```

首次运行会在终端显示管理中心 2FA 二维码。浏览器访问 `http://管理中心IP:9000` 登录。

## 工具节点

节点服务器只运行对应节点入口，不运行管理页面。节点首次运行会显示节点 2FA 二维码；在管理中心添加节点时，只填写节点名称、节点 IP、节点端口和该节点验证码。管理中心会自动识别工具类型，并在验证后启动工具。

示例：

```bash
cd release
./panda-node-entropy \
  --data-dir ./entropy-node \
  --port 9100 \
  --child-port 18000 \
  --show-qr \
  --command /opt/entropy/panda-arb serve --data-dir /opt/entropy/tool-data
```

`--command` 必须放在最后；它后面的参数会完整传给已安装的套利工具。工具可执行文件需由对应工具的正式发布包提供，本仓库不包含其源代码。

管理中心会通过节点令牌转发工具界面，浏览器不直接访问工具端口。节点的工具进程绑定到本机回环地址；建议防火墙只允许管理中心访问节点通信端口。

## 校验

```bash
sha256sum -c SHA256SUMS
```

仅支持 Linux x86_64；不能直接在 macOS 或 Windows 上运行。
