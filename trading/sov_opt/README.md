# SOVEREIGN Ascendant optimization runner

This directory contains the first automation layer for repeated backtests of `SOVEREIGN_Ascendant_v1`.

## What it does

- generates `.set` files from a JSON search space
- writes per-run MT5 tester `.ini` configs
- runs backtests sequentially through the existing Linux + Wine MT5 stack
- looks for the generated audit CSV
- scores each run with practical metrics instead of only final profit
- writes ranked summaries for later review

## Files

- `ascendant_tester.ini.tpl` - INI template used for each MT5 run
- `sample_search_space.json` - example parameter search definition
- `research_search_space_eurusd_m15.json` - research-backed EURUSD M15 search grid
- `research_search_space_usdjpy_m15.json` - research-backed USDJPY M15 search grid
- `research_search_space_xauusd_m15.json` - research-backed XAUUSD M15 search grid
- `SOVEREIGN_RESEARCH_NOTES.md` - paper-to-parameter translation notes
- `run_sov_opt.py` - orchestration script

## Search-space format

The JSON file supports:

- `expert_name`
- `symbol`
- `period`
- `from_date`
- `to_date`
- `report_prefix`
- `min_trades`
- `timeout_seconds`
- `base_parameters`
- `search_space`

`base_parameters` are applied to every run.  
`search_space` is expanded as a Cartesian product.

## Example

Dry run:

```bash
python3 trading/sov_opt/run_sov_opt.py \
  trading/sov_opt/sample_search_space.json \
  --dry-run \
  --limit 4
```

Real execution:

```bash
python3 trading/sov_opt/run_sov_opt.py \
  trading/sov_opt/sample_search_space.json \
  --limit 8
```

Research-backed example:

```bash
python3 trading/sov_opt/run_sov_opt.py \
  trading/sov_opt/research_search_space_eurusd_m15.json \
  --limit 12
```

## Output

Generated files go under:

- `trading/sov_opt/output/<timestamp>/sets/`
- `trading/sov_opt/output/<timestamp>/configs/`
- `trading/sov_opt/output/<timestamp>/runs/<run_id>/`

Main summary files:

- `summary.csv`
- `summary.md`

## Scoring philosophy

The runner does **not** optimize for raw profit alone.

It scores runs using a mix of:

- trade count floor
- net PnL
- average R
- profit factor
- max drawdown from the closed-trade sequence
- drawdown efficiency

This is still not a full walk-forward engine, but it is a much safer base than profit-only ranking.

## Practical note

If MT5 has not yet downloaded broker history or completed the first login, some runs may fail or produce no audit CSV.  
The runner records those failures instead of pretending they succeeded.

## Why the research-backed JSON files matter

The research-backed search spaces are intentionally narrower than brute-force optimization grids.

They reflect:

- trend-following evidence for continuation setups
- intraday FX seasonality and spread/liquidity differences by symbol
- noisier execution and risk constraints for gold
- backtest-overfitting research that argues for smaller, more meaningful search spaces

Use them as the preferred starting point instead of expanding all parameters at once.
