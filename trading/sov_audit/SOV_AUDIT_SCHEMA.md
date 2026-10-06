# SOVEREIGN CSV audit schema

## Purpose

This schema is designed for `SOVEREIGN_OMEGA_Rebuild_v1`, `SOVEREIGN_PHOENIX_v2`, and future descendants.

The objective is not just post-trade bookkeeping. The real purpose is to make profit optimization measurable:

- which mode makes money
- where it makes money
- when it loses
- how exits affect MFE capture
- how spread and volatility degrade expectancy

## Logging principles

1. Write **one row per completed trade**.
2. Capture **entry snapshot fields at entry time** and persist them until exit.
3. Capture **final result fields only after the trade is closed**.
4. Do not rely on comments alone; write structured columns.
5. Keep field names stable across versions.

## Required columns

These fields should exist in every row.

| Column | Type | Description |
|---|---|---|
| `trade_id` | string | Unique trade identifier. Prefer position ticket or synthetic ID. |
| `strategy_family` | string | Always `SOVEREIGN`. |
| `strategy_version` | string | Example: `OMEGA_Rebuild_v1`, `PHOENIX_v2`. |
| `symbol` | string | Example: `EURUSD`, `USDJPY`, `XAUUSD`. |
| `timeframe` | string | Execution timeframe, example `M15`. |
| `session_bucket` | string | Example: `Asia`, `London`, `NewYork`, `Overlap`, `OffHours`. |
| `mode` | string | `Bandwagon` or `Stealth`. |
| `submode` | string | Optional specialization, but column should still exist. Example: `DirectBreak`, `BreakRetest`, `ReleaseRetest`. |
| `htf_direction` | string | `BULL`, `BEAR`, `NEUTRAL`. |
| `htf_score` | float | Final HTF score used at entry. |
| `htf_score_margin` | float | Difference between bullish and bearish score. |
| `entry_time` | ISO datetime | Trade open time. |
| `entry_price` | float | Actual entry price. |
| `spread_points_entry` | float | Spread in points at entry. |
| `atr_points_entry` | float | ATR in points used at entry. |
| `volatility_bucket` | string | Example: `Low`, `Normal`, `High`. |
| `stop_loss_points` | float | Initial SL distance in points. |
| `take_profit_points` | float | Initial TP distance in points, even if later managed dynamically. |
| `risk_percent` | float | Percent risk allocated to the trade. |
| `size_lots` | float | Executed position size. |
| `exit_time` | ISO datetime | Trade close time. |
| `exit_price` | float | Final close price. |
| `exit_reason` | string | See exit reason enum below. |
| `gross_pnl` | float | Gross profit or loss in account currency before fees. |
| `net_pnl` | float | Net profit or loss after fees. |
| `commission` | float | Commission paid. |
| `swap` | float | Swap paid or received. |
| `r_multiple` | float | Net result divided by initial risk in money terms. |
| `mae_points` | float | Maximum adverse excursion in points. |
| `mfe_points` | float | Maximum favorable excursion in points. |
| `holding_seconds` | int | Total holding time in seconds. |
| `consecutive_losses_before_entry` | int | Losing streak state before the trade was opened. |
| `daily_dd_pct_before_entry` | float | Daily drawdown percent at entry time. |

## Strongly recommended columns

These are not strictly mandatory, but they greatly improve optimization quality.

| Column | Type | Description |
|---|---|---|
| `entry_bar_time` | ISO datetime | Open time of the signal bar. |
| `entry_reason_code` | string | Human-readable signal code, example `BW_SWING_BREAK`, `ST_RELEASE_BOX`. |
| `breakout_distance_atr` | float | Breakout distance relative to ATR for Bandwagon entries. |
| `body_ratio_entry` | float | Entry bar body ratio. |
| `tick_volume_entry` | float | Tick volume at signal bar. |
| `ema_distance_points_entry` | float | Distance from entry to the key EMA. |
| `compression_score` | float | Compression quality score for Stealth entries. |
| `release_strength_score` | float | Release-bar quality score for Stealth entries. |
| `slippage_points_entry` | float | Real entry slippage. |
| `slippage_points_exit` | float | Real exit slippage. |
| `partial_close_count` | int | Number of partial exits taken. |
| `first_partial_r` | float | R-multiple at first scale-out. |
| `trail_activated` | int | `1` if trailing activated, else `0`. |
| `be_activated` | int | `1` if break-even activated, else `0`. |
| `kill_switch_state` | int | `1` if strategy-level kill switch was armed after this trade, else `0`. |

## Enumerations

### `mode`

- `Bandwagon`
- `Stealth`

### `submode`

Suggested starting set:

- `DirectBreak`
- `BreakRetest`
- `CompressionRelease`
- `ReleaseRetest`
- `Unknown`

### `exit_reason`

Suggested starting set:

- `StopLoss`
- `TakeProfit`
- `BreakEven`
- `TrailingStop`
- `TimeStop`
- `ManualClose`
- `RiskGuardClose`
- `SessionClose`
- `PartialThenTrail`
- `Unknown`

## Bucketing guidance

If you do not want to write bucket strings directly from the EA, the Python analyzer can derive them later.
But if buckets are stable in your process, logging them directly is better.

### `session_bucket`

Suggested default:

- `Asia`
- `London`
- `NewYork`
- `Overlap`
- `OffHours`

### `volatility_bucket`

Suggested default using ATR percentile per symbol:

- `Low`
- `Normal`
- `High`

### HTF score bands

Suggested interpretation:

- `Weak`: valid but near threshold
- `Medium`
- `Strong`
- `VeryStrong`

## Minimal header example

```csv
trade_id,strategy_family,strategy_version,symbol,timeframe,session_bucket,mode,submode,htf_direction,htf_score,htf_score_margin,entry_time,entry_price,spread_points_entry,atr_points_entry,volatility_bucket,stop_loss_points,take_profit_points,risk_percent,size_lots,exit_time,exit_price,exit_reason,gross_pnl,net_pnl,commission,swap,r_multiple,mae_points,mfe_points,holding_seconds,consecutive_losses_before_entry,daily_dd_pct_before_entry
```

## Implementation note for MQL5

The EA should capture entry snapshot values into a position-scoped structure when the order is accepted.
On close, it should merge:

- stored entry snapshot
- realized exit data
- computed MAE/MFE

and write a single CSV row.

Do not try to reconstruct entry context only from close-time state.
