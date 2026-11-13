# SOVEREIGN audit toolkit

This directory contains the first practical layer for improving SOVEREIGN with data instead of intuition.

## Files

- `SOV_AUDIT_SCHEMA.md` - exact CSV logging schema for future `.mq5` integration
- `sample_audit.csv` - sample export structure
- `analyze_sov_audit.py` - no-dependency Python analyzer that converts audit CSV into a Markdown report

## Why this exists

The uploaded SOVEREIGN notes already show good strategy design instincts:

- HTF/LTF separation
- mode split (`Bandwagon`, `Stealth`)
- ATR-based exits
- risk guards

The missing piece for profit maximization is measurement.

Without a consistent trade audit, you cannot answer:

- which mode actually earns money
- which session should be disabled
- whether filters reduce good trades too aggressively
- whether exits are leaving too much MFE on the table
- whether HTF score should affect position size

## Intended workflow

### Step 1: Add CSV logging to the actual EA

When the real `SOVEREIGN_*.mq5` source is available, add one-row-per-trade CSV export using the schema in:

`SOV_AUDIT_SCHEMA.md`

### Step 2: Export a Strategy Tester run

Run a backtest on one:

- symbol
- session
- preset
- strategy version

at a time.

Do not mix all runs into one file until you have at least stable version tags and session buckets.

### Step 3: Analyze the export

Example:

```bash
python3 trading/sov_audit/analyze_sov_audit.py \
  trading/sov_audit/sample_audit.csv
```

Write a report file:

```bash
python3 trading/sov_audit/analyze_sov_audit.py \
  trading/sov_audit/sample_audit.csv \
  --output trading/sov_audit/output/sample_report.md \
  --min-trades 2
```

### Step 4: Turn findings into parameter changes

Use the report to make only one category of change at a time:

1. disable a weak mode or session
2. change exits
3. change risk allocation
4. relax or tighten one filter

Do not change everything at once.

## Highest-value metrics to watch

These are the first metrics that should drive optimization:

- net PnL by mode
- average R by mode
- net PnL by symbol
- net PnL by session
- average R by HTF score bucket
- average R by spread bucket
- average R by exit reason
- MFE/MAE ratio by mode

## Practical interpretation rules

### If `Bandwagon` has higher average R but lower win rate

That is not automatically bad.
Trend-continuation logic often wins less often but pays more when it wins.
Focus on:

- PF
- average R
- exit quality

before discarding it.

### If `Stealth` wins often but average R is weak

That usually means one of these:

- compression filter is too late
- release quality is too loose
- exits cash out too early
- false expansions are being overtraded

### If wide-spread buckets are negative

Do not optimize the entry harder first.
Tighten spread governance.

### If high HTF score buckets are clearly stronger

Use HTF score for bounded risk scaling, not just signal gating.

### If `TimeStop` has negative average R

Your trade is probably stale before the current time stop.
Test:

- earlier time decay exits
- earlier partial scale-out
- better invalidation logic

## What should be implemented first in code

When the actual SOVEREIGN source code is available, the best coding order is:

1. CSV audit logger
2. mode-specific namespaces for parameters
3. partial profit and runner logic
4. exit-reason logging
5. HTF score risk scaling
6. per-symbol and per-session preset files

## Important limitation

This toolkit does not improve returns by itself.
It makes the strategy measurable enough that return improvement becomes an engineering task.
