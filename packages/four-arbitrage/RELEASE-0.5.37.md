# v0.5.37

包含 Entropy、QFEX 手动补单和缓冲下限保存修复。修正 Entropy 历史接口同一订单返回 open/filled 多状态记录时的候选查询：比较身份并查询 orderStatus 确认终态，不按列表顺序选择。未自动关联补单或启动交易。
