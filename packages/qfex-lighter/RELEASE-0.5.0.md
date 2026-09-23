# QFEX-Lighter 0.5.0

QFEX ↔ Lighter arbitrage node packaged as single-file Linux x86_64 executables.

The package contains `panda-node` and `panda-arb`; Python source is embedded in the executable and is not distributed as loose files. The node supports the same task lifecycle, DRY RUN/LIVE gates, reconciliation, risk monitoring, emergency exit, and manager registration flow as the other Lighter nodes.

QFEX configuration uses `QFEX_PUBLIC_KEY`, `QFEX_SECRET_KEY`, `QFEX_ACCOUNT_ID`, `QFEX_TRADE_WS_URL`, and `QFEX_MDS_WS_URL`. Keep `DRY_RUN=true` until contract precision and a small live proof-of-concept are verified.
