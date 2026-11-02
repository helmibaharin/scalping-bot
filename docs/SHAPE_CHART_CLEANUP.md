# Shape chart cleanup — 2026-11-03

The live log recorded ascending triangle `4074476353` as detected at broker time 17:30 and invalidated at the 17:30 candle with `BOUNDARIES_CROSSED` when that candle completed. Its earlier pivots were known at 14:45. Pattern drawings were created at detection and did not follow the candidate lifecycle. The shared `SBTrend` helper also gave the lines infinite right rays. As a result, inactive patterns could remain visible long after the strategy stopped considering them. All Shape subtypes used two boundary lines without a candidate-status label, which made them easy to mistake for active triangles.

The new Shape-only drawing helper:

- Draws active pattern boundaries only through the latest evaluated close, with both rays disabled.
- Labels each visible candidate with its actual subtype and phase, such as `ASCENDING_TRIANGLE | WAIT_BREAKOUT`. A candidate label does not mean an entry has been confirmed.
- Removes owned pattern boundaries, status labels and candidate-only sweep/CHoCH/BOS annotations when a candidate is invalidated, expired, blocked or executed, and when a registry slot is reused.
- Hides crossed or aged geometry at the displayed close without changing the candidate state or trading logic.
- Preserves executed trade entry, SL, TP and trade-label objects, other strategies' drawings and unrelated chart objects.
- Refreshes active geometry once after Shape replay/entry processing; it does not recreate historical drawings for each replayed candle. Terminal drawings cannot be recreated by the old post-transition annotation block.

The new engine's former unbounded `SBTrend` calls were replaced only for Shape candidate drawings. The legacy Triangle drawing helper and other strategies remain unchanged. No pattern detection thresholds, pivot confirmations, setup decisions, order submission, stop/target geometry, input defaults or profiles were changed. The original `SBShapeStep`, `SBShapeDecisionStep`, `SBShapePlanGeometry` and `SBShapeMakeSignal` function bodies are compared against the local pre-change snapshot by the preservation audit.

Validation uses native MT5 chart objects in `ShapeDrawingTests`, existing Shape and Shape timing fixtures, and the all-five historical signal-only run. The drawing test checks finite rays, endpoint updates, status labels, idempotent refresh, all four terminal phases, crossed/aged geometry, drawing switches, retained trade records and absence of orders. Compact final counts and source/binary fingerprints are recorded in `artifacts/shape-drawing-v1`; raw evidence stays local. These checks establish chart lifecycle behavior, not trading profitability.

Final results: the EA and three fixtures compiled with **0 errors and 0 warnings**. Four MT5 runs passed **176 native assertions** (25 drawing, 27 timing, 124 existing Shape), plus the all-five signal-only integration run. The existing **243 rule assertions**, **138 risk/execution assertions** and **18 Python tests** passed. Preservation checks confirmed identical decision-function bodies, 113 preserved existing project files and all 36 protected CapitalGuard files. The final matrix is `20261102T160324/matrix.json`.

Load the rebuilt `MQL5/Experts/ScalpingBot.ex5` to apply the cleanup. No input changes are required. The running installed EA and chart were not modified by the isolated tests. The existing deinitialization cleanup removes the old instance's owned objects when replacing/reloading that EA; the new instance then draws the current active candidates.

## Follow-up: overlapping 4H range and ORB references

The supplied screenshot shows the grey `ORB.H1_SWING_H` object at 3919.14, matching the recorded S1 4H range high. They are separate objects at the same price; the hovered grey object exposes the ORB reference name. The orange rectangle bounds S1's NY midnight–04:00 range, while the grey line is an hourly swing used by ORB. No swapped strategy constant or range-price assignment was found.

The shared horizontal-line renderer now adds explicit `S1 4H RANGE HIGH/LOW` and `S3 ORB RANGE HIGH/LOW` visible captions for those specific range objects. Coincident S1 and ORB range captions use opposite vertical anchors. H1/H4 swing references retain their object IDs and grey prices but have explicit `ORB REFERENCE - H1/H4 SWING HIGH/LOW` tooltips; they add no extra visible labels. S1 tooltips include the NY date and 00:00–04:00 window. Trade SL/TP and other horizontal lines are excluded from this caption mapping. Existing level prices, range calculations, colors, strategy constants and trading behavior remain unchanged.

`RangeLabelTests.mq5` reproduces the 3919.14 overlap using native chart objects and checks the separate names, prices, captions, anchors, reference tooltips, independent updates, high/low mapping, no duplicate objects and no orders. Its follow-up receipt is retained separately as `range-label-tests.json`; the earlier 176-assertion record describes the earlier Shape cleanup build. `final-build.json` identifies the latest binary and its source fingerprints.

Follow-up validation passed 13 native chart-object assertions. Nonvisual Strategy Tester does not retain `OBJPROP_TOOLTIP`, so the tooltip was separately verified through the actual renderer on a normal isolated chart by `RangeLabelTooltipProbe.mq5`: `ORB REFERENCE - H1 SWING HIGH 3919.14`. The EA and both fixtures compiled with zero errors/warnings. No trade was submitted and the user's chart was not changed. Raw final evidence is `range-labels-20261102T161803`; earlier failed tester-only tooltip attempts remain local and are not counted as passes.
