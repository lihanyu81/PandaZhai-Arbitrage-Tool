# v0.5.38

修复 Entropy 下单签名字段顺序：使用官方 SDK order_request_to_order_wire 构造签名报文，订单类型 t 位于客户订单号 c 之前。保留价格、数量、滑点、IOC 和 reduce-only 语义。新增模拟 HTTP 捕获和独立规范顺序验签测试，覆盖买卖及只减仓。未提交真实测试订单，不自动启动交易。
