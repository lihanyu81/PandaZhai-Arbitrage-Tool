# 跨平台手动补单关联

支持 Arcus、Lighter、Robinhood Lighter、PopDEX。暂停新增后，在“持仓与恢复”需要处理的记录旁点击“关联手动补单”。程序识别失败平台并列出同账户、标的、方向、完整数量及失败后时间匹配的订单；选择后预览成交均价和手续费，再确认关联。不需要复制订单号。

当前范围是一腿完整成交、另一腿零成交的开仓失败。部分成交、两腿均失败、平仓失败不走该入口。其他平台的恢复不能用用户口头确认绕过未知原单；需先查询原订单终态。保留 Arcus 现有的拒单确认路径及其审计字段。

预览与确认均重新读取交易所记录。确认要求原订单不会再成交、成交明细总量完整、无冲突成交 ID、未被节点其他请求或一键平仓使用、所有启用平台实际仓位与关联后账本一致且没有挂单。账户或预览数据变化会拒绝确认。保留原请求、结果和备份，不自动恢复交易。

历史查询使用现有账户/子账户配置及认证，只发 GET，不写单、不撤单、不修改交易跟踪器。分页最多 20 页，超限或不完整时明确报错；候选最多展示 50 条。历史接口保存期限仍以平台为准。手续费来自实际成交，Lighter 的整数费率按官方 FEE_TICK（1,000,000）换算，PopDEX 核对费用币种并计入 builder fee；沿用原账本费用绝对值口径。

接口依据：
- https://apidocs.lighter.xyz/reference/accountinactiveorders
- https://apidocs.lighter.xyz/reference/trades
- https://github.com/elliottech/lighter-prover/blob/main/circuit/src/types/constants.rs
- https://popdex.xyz/docs/api/trade/orders/Get-Order-History
- https://popdex.xyz/docs/api/trade/orders/Get-Order-Fills

验证限于模拟 HTTP、模拟账户和全拦截浏览器页面；不以模拟通过代替实盘接口或真实补单验证。

## GRVT（0.5.29 新增）

GRVT 已接入相同的候选、预览和确认关联流程；要求原腿零成交且终态可证明、补单完全成交、子账户/市场/方向/数量/时间一致、全平台实际仓位匹配且无挂单。原请求未知仍不可用用户声明绕过。详见 [GRVT 接入说明](docs/GRVT-INTEGRATION.md)。
