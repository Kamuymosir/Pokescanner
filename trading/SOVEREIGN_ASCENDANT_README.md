# SOVEREIGN Ascendant v1

## Positioning

`SOVEREIGN_Ascendant_v1.mq5` is an integrated successor built from:

- `SOVEREIGN_OMEGA_Rebuild_v1`
- `SOVEREIGN_PHOENIX_v2`
- selected salvage ideas from `SOVEREIGN_v10.8_Lv80_FINAL`

It is not a blind merge.

The design principle is:

- keep the stable and testable structure from OMEGA
- keep the improved regime logic and hard guards from PHOENIX
- salvage only safe ideas from Lv80
- reject dangerous legacy elements such as DLL dependence and opaque scoring

## What was intentionally kept

### From OMEGA

- deterministic structure
- HTF + LTF split
- dual entry family (`Bandwagon`, `Stealth`)
- simple execution flow

### From PHOENIX

- score-based HTF regime
- ARMED multi-bar confirmation
- mode-specific SL / RR / BE / trailing
- daily DD guard
- consecutive loss guard

### From Lv80

- event-file based blackout hook
- daily profit soft-throttle idea
- focus on exit efficiency

## What was intentionally rejected

- DLL dependency (`AINISA.dll`)
- opaque black-box scoring
- direct equity-step lot inflation
- weak trigger timing based only on short tick jumps
- fragile legacy history access patterns

## New additions in Ascendant

### 1. Risk allocation by measured context

HTF score now affects risk allocation.

Risk can also be reduced by:

- current losing streak
- daily soft target already reached

This is bounded scaling, not martingale.

### 2. Partial profit + runner

Each mode can:

- take a partial close at a configurable R level
- move toward break-even
- continue with ATR-based trailing

### 3. Audit-ready trade state tracking

The EA stores:

- entry snapshot
- mode/submode
- HTF score
- spread and ATR at entry
- MAE/MFE
- partial close state
- break-even/trailing activation

### 4. CSV export for optimization

When enabled, completed trades are written to:

- `Common\\Files\\SOVEREIGN_Ascendant_Audit.csv`

This schema is aligned with:

- `trading/sov_audit/SOV_AUDIT_SCHEMA.md`

So the Python analyzer can be used directly.

## Strategy structure

### Bandwagon

Purpose:

- impulse continuation after structure break

Current conditions:

- HTF regime aligned
- swing breakout
- ATR minimum breakout distance
- minimum body ratio
- volume confirmation
- chase distance limit from EMA

### Stealth

Purpose:

- compression-release expansion

Current conditions:

- HTF regime aligned
- enough compressed bars inside lookback
- release through the compression box
- release range expansion
- EMA alignment
- volume confirmation

## Exit structure

Per mode:

- ATR-based initial stop
- RR-based initial target
- partial close at configurable R
- break-even activation at configurable ATR multiple
- trailing stop using ATR
- maximum hold bars

## Recommended first validation workflow

1. compile the EA
2. run one symbol at a time
3. export audit CSV
4. analyze with:

```bash
python3 trading/sov_audit/analyze_sov_audit.py path/to/export.csv
```

5. optimize in this order:
   - disable weak mode/session
   - improve exits
   - tune risk allocation
   - only then revisit entry filters

## Important note

Ascendant is meant to be the new experimental base, not the final production endpoint.

The correct loop is:

- measure
- isolate
- optimize
- re-test

not:

- add more filters blindly
