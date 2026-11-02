# Strategy 3 demo checklist

Use the matching current source/EX5 and the ORB release package documented in [ORB validation](ORB_VALIDATION.md); the original ZIP is the preserved two-strategy release. Copy files only to Scalping Bot's own installation paths. CapitalGuard source, datasets and settings are independent.

1. Start on a separate demo chart and load the full symbol profile. Verify all three magic numbers differ from each other and from other installed EAs. Keep signal-only enabled and real-account permission disabled.
2. Verify the broker's historical UTC/DST policy and symbol digits/tick size. Check that 09:30 and 09:45 NY map correctly in both US DST seasons and in US/EU mismatch weeks. Set the existing mapping verification input only when confirmed. The initial daily-equity lock still requires an observed NY midnight.
3. Isolate ORB first with the 4H/Triangle switches off. Observe continuation-only and reversal-only separately, then both. Keep baseline BOS/conditional CHoCH/FVG and Strict external policies enabled. Watch range finalization once per NY day and compare completed-candle pivot availability with logs.
4. Check retest failures, sequential CHoCH/BOS, FVG outer-boundary closes, external obstruction and countertrend logs. Restart during a pending setup and after a confirmation; no historical entry or duplicate order should appear. Validate all symbol-specific point distances rather than copying gold distances blindly to Forex.
5. Run longer chronological real-tick tests with spread/commission/delay assumptions before demo execution. Short zero-trade samples provide no ORB performance estimate. Keep rejected setups rejected; threshold changes define new research configurations and need separate evidence.
6. Only after reviewing signal-only behavior, run limited simulated execution in Strategy Tester, then a separate demo forward trial. Recheck combined risk, simultaneous charts, netting conflicts and loss locks with the other strategies enabled. No real-money readiness is implied by compilation or unit tests.

The original installation instructions follow.

# Installation and broker setup

Use a demo account and a separate chart first. Copy only Scalping Bot's EX5 into the terminal's Experts folder. Source installation additionally requires both `MQL5/Experts/ScalpingBot.mq5` and the entire matching `MQL5/Include/ScalpingBot` folder. Never copy these files into CapitalGuard's source tree.

The EA trades the chart symbol. EURUSD.a, XAUUSDm and other suffixes need no string substitution. It queries the broker's actual point/tick size, digits, contract/tick value, min/max/step/directional volume limit, stops/freeze levels, sessions, trade modes and permitted fills. The profiles are starting points for common 5-digit EURUSD/GBPUSD, 3-digit USDJPY and 2-digit XAUUSD. A different broker quote precision requires reviewing every point-distance setting; XAU values are not Forex pip distances.

## Time mapping is required

`InpBrokerTimeVerified=false` deliberately blocks signal evaluation until you verify the broker's historical UTC mapping. MT5 server times do not encode a timezone, and tester `TimeGMT()` cannot establish a historical broker offset.

Set the broker winter/summer offsets in **minutes east of UTC**, validity from/until dates, and one explicit rule:

| Rule | Meaning |
|---|---|
| Fixed | Winter offset for all dates; summer value ignored |
| EU | Last Sunday March 01:00 UTC through last Sunday October 01:00 UTC uses summer offset |
| US | US Eastern DST transition instants select summer offset |

The US broker rule is only appropriate if your broker changes at those exact UTC instants. Many brokers use another schedule. If no supported rule exactly represents your broker over the test interval, do not enable verified mapping; use separate fixed-offset test intervals or add a verified mapping implementation. The default validity interval is 2007â€“2038. Supported New York history is 1987â€“2099: 1987â€“2006 first Sunday April/last Sunday October; 2007 onward second Sunday March/first Sunday November. Earlier historical exceptions are intentionally unsupported.

Live operation also requires mapped UTC within 120 seconds of the computer's UTC clock, current server time coherent with estimated server time, and a fresh synchronized chart quote. Set Windows time correctly. Repeated/nonexistent broker wall-clock hours fail closed. NY 00â€“04 transition-day ranges with three/five elapsed hours are explicitly skipped. Market holidays do not create synthetic candles; missing data and broker session/market-closed checks prevent entries.

Sources: [US Naval Observatory DST history](https://aa.usno.navy.mil/faq/daylight_time), [NIST DST rules](https://www.nist.gov/pml/time-and-frequency-division/popular-links/daylight-saving-time-dst). Rules after the supported dates must be reviewed if legislation changes.

## Profiles and switches

Load one of the four `.set` files from `profiles/`. All inputs are explicit. Both strategies and all triangle types are enabled; signal-only is true, fixed volume is 0.01, real-account permission is false. Magic pairs are distinct by distributed symbol profile. Keep magics stable for trade-history recovery, and choose fresh numbers if another EA uses them.

Disable only `InpEnable4HBreakout` or `InpEnableTriangleMethod` to stop that strategy's new signals. Existing owned positions still receive safety monitoring. Disable individual triangle types with the three type switches. Do not attach a second controller for the same symbol and magic, even on another timeframe.

After confirming mapping, watch the Experts journal, CSV logs and panel. The first account baseline is locked until an observed NY midnight, including in the tester. Keep the EA running across that boundary. A downtime/gap at the boundary preserves the daily lock instead of inventing start-of-day equity. `InpResetToken` is an explicit acknowledgement after manual order/history reconciliation; it clears the emergency/intent latch and resets observed drawdown peak but does **not** bypass a daily lock. All chart instances must agree on shared risk and time settings. Changing those settings requires a deliberate state/configuration migration, not deleting globals.

Runtime logs are in the terminal sandbox `MQL5/Files/ScalpingBot/`. Ownership mutexes use `Terminal/Common/Files/ScalpingBot/`; account risk and consumed setup keys use the `SB.*` terminal-global namespace. Tester keys use `SB.TEST.*` and cannot erase production keys. No CapitalGuard files/globals are used.

