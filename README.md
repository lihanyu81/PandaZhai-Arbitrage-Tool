# PandaZhai Arbitrage Control Release

这是 Linux x86_64 服务器发布包。管理程序、节点通信程序和三个对应的套利执行文件均为二进制文件，不包含 Python 源代码、测试、`.env`、私钥、2FA 文件或数据库。

## 四台服务器目录

每个目录都是独立部署单元，不需要另外复制 `panda-control-runtime`：

```text
manager-server/
└── panda-manager

popdex-server/
├── panda-node-popdex
└── panda-arb-popdex

rblighter-server/
├── panda-node-rblighter
└── panda-arb-rblighter

entropy-server/
├── panda-node-entropy
└── panda-arb-entropy
```

节点程序会自动启动同目录下对应的套利执行文件。每个服务器只需上传自己的目录。

## 管理中心

```bash
cd manager-server
chmod +x panda-manager
./panda-manager --data-dir ./manager-data --host 0.0.0.0 --port 9000
```

首次运行会在终端显示管理中心 2FA 二维码。浏览器访问 `http://管理中心IP:9000` 登录。

## 工具节点

节点服务器只运行对应节点入口，不运行管理页面。节点首次运行会显示节点 2FA 二维码；在管理中心添加节点时，只填写节点名称、节点 IP、节点端口和该节点验证码。管理中心会自动识别工具类型，并在验证后启动工具。

PopDEX-Lighter 节点：

```bash
cd popdex-server
chmod +x panda-node-popdex panda-arb-popdex
./panda-node-popdex \
  --data-dir ./popdex-node \
  --port 9100 \
  --child-port 18000 \
  --show-qr
```

RBLighter-Lighter 节点：

```bash
cd rblighter-server
chmod +x panda-node-rblighter panda-arb-rblighter
./panda-node-rblighter \
  --data-dir ./rblighter-node \
  --port 9100 \
  --child-port 18000 \
  --show-qr
```

Entropy-Lighter 节点：

```bash
cd entropy-server
chmod +x panda-node-entropy panda-arb-entropy
./panda-node-entropy \
  --data-dir ./entropy-node \
  --port 9100 \
  --child-port 18000 \
  --show-qr
```

PopDEX 和 RBLighter 节点分别进入对应目录后，运行各自的 `panda-node-*` 即可。首次启动会显示节点 2FA 二维码；在管理中心添加节点时，填写节点名称、IP、端口和该节点验证码。

如需使用自定义工具文件，可使用 `--tool-executable` 指定路径；`--command` 仍保留给开发测试和旧版部署。

管理中心会通过节点令牌转发工具界面，浏览器不直接访问工具端口。节点的工具进程绑定到本机回环地址；建议防火墙只允许管理中心访问节点通信端口。

## 校验

```bash
sha256sum -c SHA256SUMS
```

仅支持 Linux x86_64；不能直接在 macOS 或 Windows 上运行。套利执行文件的版本应与其目录对应，不要交叉替换。
