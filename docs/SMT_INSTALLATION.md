# Manual SMT installation and demo review

No EA is automatically installed into the running terminal. The workspace EX5 is compiled for review. Keep the earlier release packages and use the new SMT package/source together; do not mix old and new modules.

## Copy and compile manually

1. In the intended demo terminal use **File → Open Data Folder**. Remove Scalping Bot from its own chart before replacing its files. Leave CapitalGuard's charts and files alone.
2. Copy `scalping-bot/MQL5/Experts/ScalpingBot.mq5` into that terminal's `MQL5/Experts/ScalpingBot.mq5` and copy the entire `scalping-bot/MQL5/Include/ScalpingBot/` directory into `MQL5/Include/ScalpingBot/`. Preserve that directory layout; the EA uses relative includes. Copy only Scalping Bot files.
3. Open that EA source in MetaEditor and press **F7**. Require zero errors/warnings and use the newly generated matching EX5. Alternatively, manually copy the delivered workspace `ScalpingBot.ex5` to the terminal's Experts directory after verifying the release hash.
4. Attach **ScalpingBot**, not the tester-only `SMTTests` or `ORBTests` fixture, to a separate demo chart for the exact broker symbol/suffix.
5. Open EA **Inputs → Load** and choose one of the profile files below directly from the workspace. Loading a set file does not install another EA.

Workspace build without deploying:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scalping-bot\compile.ps1
```

## Exact profile paths

`C:\Users\C00567\Documents\trading-robot\scalping-bot\profiles\smt-mtf-d1-h1-m15-m5-demo.set`

`C:\Users\C00567\Documents\trading-robot\scalping-bot\profiles\smt-scalp-m15-m1-demo.set`

MTF uses D1 trend, H4 context, H4/H1 zones, M15 traps and M5 confirmation. SCALP uses M15 trend/context and M1 zones/traps/confirmation. Source logic is shared; magics and state are independent. Both files disable Strategies 1–3 and keep global and SMT-specific signal-only flags true, with real-account permission false.

## Check before observing

Verify historical broker UTC/DST mapping and its validity dates, then set the existing broker-time verification flag deliberately. Unknown/inconsistent clocks block the EA. Review symbol digits, tick size, point-based spread/zone tolerances, stop buffers, volumes and actual risk. These generic profiles are research starting points, not calibrated parameters for every instrument.

The shared daily-equity baseline initially remains locked until a continuously observed NY midnight. A reset-token increase does not bypass that existing daily lock. Signal detection can still be inspected in diagnostics while account execution is blocked. SMT itself has no ORB/opening-session dependency.

For simultaneous profiles, use separate charts and the supplied distinct magic numbers, including their unused Strategy 1–3 ownership magics. Shared account/time settings must agree. Netting accounts cannot hold independent same-symbol strategy positions: new same-symbol entries are blocked when any position exists. Other EAs' exposure and margin remain part of the shared safety checks.

## Suggested Strategy Tester scenarios

- Use **Every tick based on real ticks**, a demo symbol, realistic commission, variable spread and execution delay. Validate MTF and SCALP independently before combined charts. Keep their strict trend and original thresholds frozen during initial validation.
- Test XAUUSD and representative Forex pairs with their actual contract/tick/volume specifications. Include multi-month chronological samples and a later untouched interval. A two-day no-trade sample cannot estimate SMT performance.
- Review neutral/insufficient trend, aligned/opposing trend, all six location categories, all three trap variations, first-touch versus stale zones and invalidating distal closes.
- Examine M15 close versus subsequent M5 confirmation and M1 trap versus subsequent M1 confirmation. Pivot markers must appear only after right-side confirmation; CHoCH and BOS must be distinct.
- Exercise missing opposing targets, nearer overlapping/stale obstacles, positive dynamic targets below 2R, optional RR disabled, high spread, oversized fixed-volume risk and adverse fills. TP must not be pushed farther to meet RR.
- Restart while waiting for structure and after readiness. Verify historical replay sends no orders, consumed traps do not repeat and two profiles cannot submit the same confirmation/direction twice.
- Check both hedging and netting behavior, concurrent exposure from other EAs, daily/drawdown locks and market-history gaps. Inspect diagnostics and CSVs rather than assuming that no entry is a malfunction.

After a longer signal-only review, test limited demo execution deliberately by disabling both signal-only gates only in the intended simulation/demo setup. Keep real-account permission false. Compilation and fixture coverage are not production-readiness or profitability evidence.
