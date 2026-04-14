# SOVEREIGN research notes for optimization

## Purpose

This note translates research and robust-practice findings into concrete optimization rules for `SOVEREIGN_Ascendant_v1`.

The goal is not to make the EA academically "smart."
The goal is to stop random parameter thrashing and keep the search focused on variables that have a plausible economic reason to matter.

## Core references and what they imply

### 1. Time-series momentum / trend-following

Representative references:

- Moskowitz, Ooi, Pedersen (2012), *Time Series Momentum*
- Baltas, Kosowski (2013), *Momentum Strategies in Futures Markets and Trend-following Funds*

Practical interpretation for Ascendant:

- `Bandwagon` should remain a continuation engine, not drift into mean reversion.
- Stronger trend confirmation can justify slightly higher risk, but only in bounded form.
- Exit design matters because trend strategies often earn from fewer but larger moves.

What this means for search spaces:

- focus on moderate variation in:
  - `InpADXThreshold`
  - `InpBandwagonMinBreakATR`
  - `InpBandwagonTP_RR`
  - `InpBandwagonTrailATR`
- avoid wildly broad searches that let Bandwagon become a different strategy

### 2. FX intraday seasonality and spread/liquidity effects

Representative references:

- Ito and Hashimoto, *Intra-day Seasonality in Activities of the Foreign Exchange Markets*
- related electronic broking studies on EURUSD / USDJPY intraday activity

Practical interpretation for Ascendant:

- EURUSD and USDJPY should not share the same spread tolerance
- active hours matter because volatility, activity, and spread co-move
- overlap and active regional sessions usually give cleaner conditions than dead hours

What this means for search spaces:

- symbol-specific spread ceilings
- symbol-specific minimum trade floors
- session gating should eventually be aligned to broker-server time, not guessed blindly

### 3. Gold / precious metals intraday microstructure

Representative reference:

- research on intraday efficiency, volume, and volatility seasonality in Tokyo / New York gold futures

Practical interpretation for Ascendant:

- XAUUSD has higher upside but also noisier execution
- gold needs lower base risk and wider spread tolerance than major FX pairs
- breakout filters should be stricter to avoid paying for noisy spikes

What this means for search spaces:

- lower `InpBaseRiskPercent`
- wider `InpSpreadMaxPoints`
- slightly stricter `InpBandwagonMinBodyRatio`
- slightly stricter `InpStealthReleaseFactor`

### 4. Volatility compression and breakout release

Representative practical references:

- Bollinger/Keltner squeeze literature and volatility breakout implementations

This area is less academically standardized than time-series momentum, but the practical consensus is still useful:

- compression alone is not enough
- release quality matters
- breakout should be reactive, not predictive

Practical interpretation for Ascendant:

- `Stealth` should search around compression count, width factor, and release factor
- do not optimize compression and release over absurdly wide ranges
- volume and range expansion filters should remain present

### 5. Backtest overfitting and selection bias

Representative references:

- Bailey et al., *The Probability of Backtest Overfitting*
- Bailey and Lopez de Prado, *The Deflated Sharpe Ratio*

Practical interpretation for Ascendant:

- do not rank candidates on net profit alone
- narrow search spaces beat giant combinatorial grids
- minimum trade floors matter
- OOS and walk-forward checks are mandatory before promotion

What this means for our workflow:

- use research-backed grids with a limited number of choices
- rank on multiple metrics
- reject low-trade winners
- keep all tested candidates, not just the winners

## Translation into optimization rules

### Rule 1: Search narrowly around the current architecture

We are not exploring "all possible trading ideas."
We are refining:

- trend threshold
- breakout quality
- release quality
- risk intensity
- exit shape

That keeps the optimization aligned with the actual strategy family.

### Rule 2: Split by symbol first

Use separate search spaces for:

- EURUSD M15
- USDJPY M15
- XAUUSD M15

Do not start from one universal JSON.

### Rule 3: Keep minimum trade floors meaningful

Suggested starting floors:

- EURUSD M15: `min_trades >= 80`
- USDJPY M15: `min_trades >= 60`
- XAUUSD M15: `min_trades >= 40`

These are not permanent truths, but they reduce the chance of promoting a lucky low-sample candidate.

### Rule 4: Tune exits before adding new filters

Expected high-value levers:

- `InpBandwagonTP_RR`
- `InpBandwagonTrailATR`
- `InpStealthTP_RR`
- `InpStealthTrailATR`
- `InpStealthReleaseFactor`
- `InpBandwagonMinBreakATR`

### Rule 5: Use risk scaling conservatively

Research supports selective capital deployment, not martingale-like aggression.

So:

- keep `InpRiskMultVeryStrong` bounded
- keep `InpBaseRiskPercent` low on XAUUSD
- avoid large jumps in risk between score buckets

## What changed because of this research

The repository now includes research-backed search spaces:

- `research_search_space_eurusd_m15.json`
- `research_search_space_usdjpy_m15.json`
- `research_search_space_xauusd_m15.json`

These are intentionally narrower than "search everything" style grids.

## What this research does NOT justify

Do not use these papers as justification for:

- adding more and more indicators
- widening every parameter range
- accepting a candidate just because the equity curve looks smooth
- mixing all symbols and sessions into one production preset

## Recommended next loop

1. generate `.set` files from one symbol-specific research JSON
2. run direct Windows MT5 backtests
3. analyze audit CSV
4. disable or isolate weak mode/session groups
5. only then refine one parameter family further
