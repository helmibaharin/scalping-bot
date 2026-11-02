# SMT integration update

Strategy 4 uses one configurable engine in SMTTypes, SMTLocations, SMTEngine, SMTContext and SmartMoneyTrap. It reuses confirmed pivot/FVG helpers, keeps causal location snapshots, and resolves unfinished-HTF freshness with closed M1 bars. See [SMT design](SMT.md).

Only SMT uses opposing-zone dynamic TP and optional minimum RR. Its planner/fill branches bypass legacy fixed-R TP creation/repair. Account exposure, intent WAL, owner locks and accounting remain shared. Nine existing signal/time modules and four original profiles are hash-checked unchanged. The earlier architecture below describes Strategies 1-3.

# ORB integration update

Strategy 3 is integrated into the existing EA. `ORBTypes.mqh` defines separate continuation/reversal records and level availability; `ORBEngine.mqh` holds chronological pivot, BOS/CHoCH, FVG and reward-room rules; `ORBExternal.mqh` loads completed calendar/HTF context; `OpeningRangeBreakout.mqh` handles NY range construction, replay, state transitions and shared execution. See [ORB architecture and rules](ORB.md).

Shared integration extends magic lookup, owner locks, account-planner limits, fill reconciliation, deal-history recovery, order tags and the panel to a third strategy. Evaluation priority remains 4H, then Triangle, then ORB, with exposure reconciliation between each. Existing 4H and Triangle signal algorithms are unchanged. Account risk includes other EAs while ticket management remains ownership-scoped.

The original two-strategy architecture description follows; references to two strategies describe that earlier baseline.

# Architecture, risk and recovery

`ScalpingBot.mq5` orchestrates independent strategies over shared account risk and execution. `StrategyInterface.mqh` defines signals and plans. `FourHourBreakout.mqh` and `TriangleMethod.mqh` own separate state machines; the triangle geometry and 4H structural stops live in separate detectors. `Rules.mqh` contains pure decision rules, and `NewYorkTime.mqh` provides historical conversions. Diagnostics, persistence, risk, execution and position management are separate modules.

## Shared risk

The whole account's equity and positions count toward shared limits, including other EAs/manual positions. Estimated loss at each SL uses `OrderCalcProfit`, capped at zero for already protected profit; configured round-trip commission adds a conservative cost estimate per lot. Any account position without an SL, failed profit calculation or outstanding account order blocks new entries rather than assuming zero exposure. Foreign positions are never modified or closed.

Fixed-volume orders still pass monetary risk limits. Risk-based volume is floored to the broker step, never raised to meet its minimum. Volume outside min/max/directional limits is rejected. Initial risk includes adverse configured deviation; it cannot bound gaps or market-execution slippage. Enforce independent per-trade and combined account risk, maximum account positions, daily equity loss and observed-peak drawdown. Check free-margin reserve with `OrderCalcMargin` and `OrderCheck`. Configured RR cannot be below 2.0.

Daily loss uses New York midnight equity only when the boundary was continuously observed. Initial attachment or missed boundary locks entries until another observed midnight. Drawdown peak and emergency latches persist across restarts. Shared risk signatures must match across instances; mismatches fail closed. Risk state has an explicit commit-valid marker; a partial write is never treated as a new clean account.

An account-level exclusive common-files mutex covers risk checks, sizing, send and reconciliation so multiple symbol charts in one terminal cannot spend the same pre-trade budget. Separate lifetime locks per symbol and magic reject duplicate controllers. Different terminals/VPSs do **not** share terminal global variables; use a single terminal per account for this controller. Common-file locks are defence in depth, not a distributed risk ledger.

Hedging positions are owned by symbol and strategy magic. Netting/exchange same-symbol occupancy blocks a new order regardless of magic because a netting position cannot retain independent strategy ownership. In a netting account, another EA/manual actor can still modify an already existing position; do not share a symbol between independent controllers there. No allocation policy is implemented.

## Order lifecycle

1. Consume the fresh setup identity before evaluating execution so a rejected signal cannot be chased on later ticks.
2. Recheck current quote, permissions, sessions, per-strategy counts/cooldown, actual account positions, risk and margin.
3. Normalize SL/TP outward to tick size. Reject rather than artificially tightening a structural stop to satisfy a broker.
4. Select FOK when supported, otherwise IOC, otherwise RETURN only for non-market execution. `OrderCheck` must accept the request.
5. Persist and flush an account order-intent marker before `OrderSend`. Unknown outcomes keep the marker and emergency latch; never retry blindly.
6. Definitive broker rejection clears the intent but leaves the signal consumed. DONE/PARTIAL/PLACED remain pending until broker history/order state and owned position protection reconcile. Partial fills are never topped up. Live pending orders block further account entries.
7. Recheck actual-fill risk, stop distance and RR. Keep original structural SL; increase TP outward if needed for the configured RR and broker freeze/stops permit it. If protection is missing, risk excessive or RR cannot be repaired, latch emergency and attempt one ticket-specific safety close when execution is enabled and permitted. An unsuccessful/partial safety close needs operator review; it is not repeatedly hammered.

MT5 `OrderSend=true` is not assumed to mean execution. See [official OrderSend documentation](https://www.mql5.com/en/docs/trading/ordersend) and [trade request ownership fields](https://www.mql5.com/en/docs/constants/structures/mqltraderequest). Initial SL and TP are included in the entry request; no planned unprotected-entry period exists. Broker stops cannot guarantee loss size during gaps, disconnections or execution failures.

## Restart and data gaps

Rebuild today's 4H range and pending excursion from completed H1/M5 history. Missing post-range M5 candles invalidate that day's reconstruction. Replay the triangle detector and retest state using only the bars available at each historical index. Confirmations seen during replay are retired, never traded. Stored consumed pattern IDs and broker order-comment history suppress duplicate trades. Order counts deduplicate partial fills by entry order ticket. No entry is allowed from a candle already closed when recovery began.

Open owned positions remain managed regardless of strategy enable switches. Broker history and SL/TP are checked before entry intent is cleared. If a crash occurred before an order ticket was saved, automatic reconciliation is intentionally refused; inspect the broker history and use an explicit token reset after resolving any order uncertainty. Broker-modified comments may reduce reconstruction of setup IDs, but persisted setup markers and startup replay still prevent immediate historical entries.

Quotes/time failures block new decisions. Existing broker SL/TP remain active; active repair/closure requires a coherent fresh quote and permissions. The default signal-only mode never sends even a protective modification/close, so restoring signal-only while holding an unsafe position requires manual broker-side intervention.


