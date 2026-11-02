# Shape Pattern inputs

All existing Triangle-prefixed ownership, pivot, risk, buffering and geometry inputs remain supported. See SHAPE_PATTERN.md for migration and policies.

| Input | Type | Default |
|---|---|---|
| `InpShapeLegacyTriangle` | `bool` | `false` |
| `InpShapeFormationTF` | `ENUM_TIMEFRAMES` | `PERIOD_M15` |
| `InpShapeEntryTF` | `ENUM_TIMEFRAMES` | `PERIOD_M5` |
| `InpShapeContextTF` | `ENUM_TIMEFRAMES` | `PERIOD_H1` |
| `InpShapeUseContext` | `bool` | `false` |
| `InpShapeContinuation` | `bool` | `true` |
| `InpShapeReversal` | `bool` | `true` |
| `InpShapeTriangle` | `bool` | `true` |
| `InpShapeFlag` | `bool` | `true` |
| `InpShapeHeadShoulders` | `bool` | `true` |
| `InpShapeInverseHeadShoulders` | `bool` | `true` |
| `InpShapeDoubleTop` | `bool` | `true` |
| `InpShapeDoubleBottom` | `bool` | `true` |
| `InpShapeFallingWedge` | `bool` | `true` |
| `InpShapeRisingWedge` | `bool` | `true` |
| `InpShapeLookback` | `int` | `240` |
| `InpShapeMaxCandidates` | `int` | `16` |
| `InpShapeConfirmationBars` | `int` | `36` |
| `InpShapeFailureBars` | `int` | `6` |
| `InpShapeToleranceATR` | `double` | `0.15` |
| `InpShapeShoulderTolerance` | `double` | `0.20` |
| `InpShapeSymmetryRatio` | `double` | `3.0` |
| `InpShapePoleATR` | `double` | `3.0` |
| `InpShapeFlagMaxPoleFraction` | `double` | `0.50` |
| `InpShapeBreakBodyATR` | `double` | `0.25` |
| `InpShapeSweepPoints` | `double` | `2` |
| `InpShapeTPBufferPoints` | `double` | `5` |
| `InpShapeContinuationMinRR` | `double` | `2.0` |
| `InpShapeReversalMinRREnabled` | `bool` | `true` |
| `InpShapeReversalMinRR` | `double` | `1.0` |
| `InpShapeDraw` | `bool` | `true` |
