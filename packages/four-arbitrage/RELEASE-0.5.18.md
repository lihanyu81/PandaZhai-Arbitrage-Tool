# 0.5.18 — 平台邀请信息与持仓列表精简

接入平台页按运营方提供内容更新 Entropy、Lighter、Robinhood Lighter、PopDEX、QFEX、Vanta、Arcus 的邀请码、邀请链接及政策。Arcus 使用 PANAZHAI；QFEX 链接到联系人的 Telegram。暂时隐藏 Decibel 接入卡片，保存其他平台时保留既有 Decibel 配置与选择状态。

组合持仓周期列表移除组合账本仓位和操作两列，保留组合与标的、状态与模式、净收益。需要处理的 Arcus 记录在状态旁保留关联手动补单入口。

验证：3 项接口测试通过；封包管理中心浏览器检查通过，覆盖七张接入卡片、Decibel 隐藏、三列持仓列表及补单选单流程。未提交真实交易订单。
