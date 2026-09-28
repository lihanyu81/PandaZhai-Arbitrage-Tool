# 跨平台手动补单关联

支持 Arcus、Lighter、Robinhood Lighter、PopDEX、GRVT、Entropy、QFEX。暂停新增后，在“持仓与恢复”需要处理的记录旁点击“关联手动补单”。程序识别失败平台并列出同账户、标的、方向、完整数量及失败后时间匹配的订单；选择后预览成交均价和手续费，再确认关联。不需要复制订单号。

当前范围是一腿完整成交、另一腿零成交的开仓失败。部分成交、两腿均失败不走开仓补单入口。其他平台的恢复不能用用户口头确认绕过未知原单；需先查询原订单终态。保留 Arcus 现有的拒单确认路径及其审计字段。

预览与确认均重新读取交易所记录。确认要求原订单不会再成交、成交明细总量完整、无冲突成交 ID、未被节点其他请求或一键平仓使用、所有启用平台实际仓位与关联后账本一致且没有挂单。账户或预览数据变化会拒绝确认。保留原请求、结果和备份，不自动恢复交易。

历史查询使用现有账户/子账户配置及认证，仅调用只读接口（Entropy 的 /info 使用 POST），不写单、不撤单、不修改交易跟踪器。分页最多 20 页，超限或不完整时明确报错；候选最多展示 50 条。历史接口保存期限仍以平台为准。手续费来自实际成交，Lighter 的整数费率按官方 FEE_TICK（1,000,000）换算，PopDEX 核对费用币种并计入 builder fee；沿用原账本费用绝对值口径。

接口依据：
- https://apidocs.lighter.xyz/reference/accountinactiveorders
- https://apidocs.lighter.xyz/reference/trades
- https://github.com/elliottech/lighter-prover/blob/main/circuit/src/types/constants.rs
- https://popdex.xyz/docs/api/trade/orders/Get-Order-History
- https://popdex.xyz/docs/api/trade/orders/Get-Order-Fills

验证限于模拟 HTTP、模拟账户和全拦截浏览器页面；不以模拟通过代替实盘接口或真实补单验证。

## GRVT（0.5.29 新增）

GRVT 已接入相同的候选、预览和确认关联流程；要求原腿零成交且终态可证明、补单完全成交、子账户/市场/方向/数量/时间一致、全平台实际仓位匹配且无挂单。原请求未知仍不可用用户声明绕过。详见 [GRVT 接入说明](docs/GRVT-INTEGRATION.md)。

## Entropy 与 QFEX

入口仍是“持仓与恢复 → 持仓记录 → 需要处理 → 关联手动补单”。不需要用户填写订单号；实际仓位平衡不等于补单已关联。

- Entropy：以配置的真实账户地址（非代理签名钱包）查询 historicalOrders，并用 orderStatus 复核候选终态；userFillsByTime 查询非聚合逐笔成交。核对 HIP-3 完整市场名、方向、原始数量、剩余量、时间和 USDC 手续费（不重复添加已包含的 builder fee）。历史订单或成交达到 2000 条上限时明确拒绝，不假定分页完整。
- QFEX：沿用已认证的 _get 和子账户头，通过 /user/historic-orders 与 /user/trade 读取历史；固定时间范围、每页 1000 条、最多 20 页，总数变化、重复或短页不完整均拒绝。订单创建时间取成交记录的 order_timestamp，不能用较晚的最后成交时间冒充新补单；缺少创建时间或完整成交明细不接受。
- 两家均不允许通过口头声明覆盖未知原订单。每次确认重新查询并核验，保留原始失败记录。Vanta、Decibel 仍未支持。

接口参考：
- https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/info-endpoint
- https://docs.qfex.com/api-reference/rest/user/historic-orders
- https://docs.qfex.com/api-reference/rest/user/user-trades

已通过模拟接口的候选、预览、确认与拒绝路径测试。Entropy 已只读验证真实补单历史；未代用户执行真实关联。QFEX 尚未验证真实补单。

Entropy 历史接口可能同时返回同一订单的 open、filled 等状态事件；身份字段一致时使用 orderStatus 复核当前终态，不能依赖列表排序或相同时间戳挑选状态。

## 手动平仓（v0.5.39）

“需要处理”周期在只剩一腿账本仓位、平仓原腿零成交失败时显示“关联手动平仓”。候选数量必须完全抵消该周期剩余仓位，核验所有启用平台实际仓位与关联后账本一致且无挂单；确认后沿用对账、关闭周期和净收益计算。连续零成交重试保留审计记录，回溯最早兼容失败；所有相关原请求均须不会再成交。未知、部分成交、两边仍有账本持仓不支持此恢复入口。不会代用户补仓、平仓或恢复交易。
