# Strategy 4 extension

See [Smart Money Trap](SMT.md) for both profiles, six locations, three traps, sequential confirmation, sweep SL and opposing-zone dynamic TP. Strategies 1-3 retain their rules below. Source defaults disable SMT in the four original profiles.

# Strategy 3 extension

The current EA also includes [ORB continuation and false-breakout reversal](ORB.md), with [complete ORB settings](ORB_INPUTS.md). All three strategies are independently switchable. The original Strategy 1 and Strategy 2 rules below remain unchanged.

# Strategy definitions

All decisions use completed OHLC candles. There are no indicator handles, ML models, external services or databases. Quote, contract and account APIs are used only for broker execution/risk checks. Every threshold below is a configurable research assumption, not an optimized value.

## 4H Breakout

At each New York calendar day change, discard the previous range/pending setup; existing positions keep their SL/TP. Wait for the four exact completed H1 intervals covering local 00:00 through 04:00. Their high/low define a fixed daily range. Missing H1 data prevents a range; it is retried as history becomes available. A discontinuous broker mapping or a US DST transition day whose local 00â€“04 interval does not contain exactly four H1 hours is skipped explicitly. The EA never manufactures or substitutes a fifth/third candle.

After the range, an upper M5 body cross is `min(open,close) <= high` with `close > high`; a lower cross is `max(open,close) >= low` with `close < low`. Comparisons tolerate one tenth of a broker tick to avoid floating-point equality errors. A wick-only break or an entirely outside body does not start a new setup.

The first upper breakout arms SELL; the first lower breakout arms BUY. Track the excursion high/low, including the breakout candle and every completed candle through the return candle. **There is no candle-count, elapsed-hours or extension timeout.** Retain the first direction until an M5 close is strictly inside both original boundaries or the New York day ends. An excursion can therefore last most of the day. Returning inside freezes the extreme and creates one entry evaluation. Intrabar returns never qualify.

Repeated same-side excursions only update the extreme. Closing beyond the opposite range boundary retires the entire range for that day, logs the conflict and opens no reverse trade. A missing post-range M5 candle also retires the day because the true excursion cannot be established. The daily limit counts executed entry orders, not rejected signals or partial-fill deals. Following a rejected/consumed confirmation, a later distinct body breakout may form another setup, subject to the same independent daily limit.

### Direction-specific stop fallback

The default stop is the frozen excursion extreme plus an outward configurable point buffer. If its entry-to-stop distance exceeds `Inp4HMaxStopPoints`, use only the corresponding structural fallback:

- **SELL:** confirmed M5 pivot-high resistance. A pivot is strictly higher than its configured completed left/right neighbours. Require `InpResistanceMinTouches` pivot highs within `InpResistanceTolerancePoints`, separated by at least pivot-strength+1 bars. Reject any zone subsequently closed above its highest touch plus tolerance. Rank qualifying anchors newest first. The stop is above the highest touch plus the buffer, must remain above executable SELL entry and within maximum distance.
- **BUY:** the most recent completed bearish candle preceding bullish displacement within `InpOrderBlockDisplacementBars`. The confirming bullish close must exceed that candle's high and exceed its open by at least `InpOrderBlockDisplacementFactor * max(candle range,tick size)`. Zone boundaries use the full wick range or bearish body according to `InpOrderBlockUseWicks`. Reject any later wick below the zone low, including during displacement. The entire zone must lie below executable BUY entry. Stop goes below the zone low plus buffer and must satisfy maximum distance.

These are mechanical research definitions. Neither detector looks beyond the return candle. If the correct fallback is absent, broken, wrongly located, oversized or broker-invalid, skip the trade. Never choose an arbitrary nearby price or the opposite strategy's fallback.

TP is calculated from the **selected final stop** and executable Ask/Bid entry at configured RR, at least 2.0. Prices are rounded outward to actual tick size. After fill, the actual entry-to-stop risk and TP RR are rechecked. The original rejected extreme is not reused for fallback TP.

## Triangle Method

Default timeframe M5, independently configurable. Confirm pivots only after `InpTrianglePivotRight` later candles have closed; ties are not pivots. All detector calls receive an explicit available end index. Pivot scanning cannot see future indices even when the copied history array contains later bars during replay.

Within the maximum formation duration, use the most recent two separated pivot highs and two separated pivot lows as fixed resistance/support line endpoints. Additional required touches must lie within tolerance of those lines. The earliest required touch through latest endpoint must meet minimum/maximum duration. Formation closes before the possible signal candle must remain inside the lines within horizontal tolerance, and timestamps must be contiguous. Extrapolate each line at each candle's **opening timestamp**, the common MQL candle timestamp convention; never replace a sloped line with a horizontal level.

- **Ascending:** approximately horizontal resistance and rising support.
- **Descending:** falling resistance and approximately horizontal support.
- **Symmetrical:** falling resistance and rising support.

â€œHorizontalâ€ means absolute slope no greater than horizontal tolerance divided by formation time span. Classification precedence is ascending, descending, symmetrical; only one qualifies for fixed geometry. Require a positive initial height, configured contraction, non-crossed current boundaries and a future apex between the configured minimum/maximum bar distances. Reject missing/flat/degenerate/diverging geometry, insufficient pivots, discontinuous history, excess age and past/too-close apex.

Pattern identity hashes symbol (including suffix), timeframe, all four pivot timestamps and type. While a pattern is active its endpoints and identity are frozen. Consumed/traded formations are not repeatedly entered under the same identity. Distinct later confirmed pivots may define a new formation; this is intentionally a new setup, not discretionary chart pattern matching.

### Breakout â†’ retest â†’ continuation

Both directions are allowed for every type. A completed close must newly cross the appropriate extrapolated line, with the configured point clearance. The prior close must not already be outside that same boundary. A wick or chasing an already outside close is rejected.

The breakout candle cannot double as a retest. A later completed candle must intersect/approach the broken line within tolerance, and close on/near the breakout side. Record that candle's high/low. A **separate later completed candle** must close back beyond the broken line and, by default, have a directional body. It must also leave the relevant retest extreme intact: higher low for BUY, lower high for SELL. If the extreme extends, move the structural retest extreme and wait for a new right-hand confirmation. Thus a wick touch never triggers an entry alone.

Reject a decisive close back inside beyond invalidation tolerance, an opposite boundary break, crossed/apex geometry, excessive pattern age, or more than `InpTriangleMaxRetestBars` timeframe intervals since breakout. This timeout is specific to Triangle Method; it never applies to the 4H strategy.

The stop is beyond the completed retest swing low/high plus its own buffer. Reject wrong-side, excessive or broker-invalid stops. TP is at least 2R from actual selected stop; triangle-height targets do not control exits. Broker SL/TP are the V1 exits. No discretionary trailing stop, grid, averaging, martingale or lot escalation exists.

## Execution order and limits

4H is evaluated first, then actual broker exposure/protection is reconciled before Triangle is checked. A rejected strategy signal does not globally stop the other strategy. Only shared risk/clock/persistence or unresolved order conditions block both. Each strategy has its own executed-order daily limit and open-position limit. Triangle also has its own executed-entry cooldown. An NY-day reset never closes an existing trade.

See [architecture and risk](ARCHITECTURE.md) for exact broker and restart behaviour.


