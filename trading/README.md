# Trader X style reference EA

This directory contains a reference MT5 Expert Advisor inspired by public descriptions of Trader X's tournament style. It is not a reverse-engineered clone, because the real parameters and source code are not public.

## Files

- `mt5/TraderXRangeBurstEA.mq5`
- `mt5_env/scripts/setup_mt5.sh`
- `mt5_env/scripts/sync_ea.sh`
- `mt5_env/scripts/compile_ea.sh`
- `mt5_env/scripts/run_mt5.sh`
- `mt5_env/scripts/run_backtest.sh`
- `mt5_env/config/tester.ini`

## What this EA tries to reproduce

- Ultra short-term execution on every tick
- Strong preference for low-volatility range conditions
- "Fast in, fast out" exits
- Burst execution with multiple market orders in one cycle
- Strict risk controls for spread, session, drawdown, and stop-loss sizing

## Core logic

1. Detect a narrow range on `InpRangeTimeframe` using:
   - lookback high/low width
   - ATR ceiling
2. Wait for price to reach the lower or upper edge of that range.
3. Open a burst of buy or sell orders:
   - buy near range low
   - sell near range high
4. Exit with one of these mechanisms:
   - fixed take profit
   - fixed stop loss
   - midline mean-reversion exit
   - time-based forced exit
5. Stop opening new cycles when:
   - spread is too wide
   - session is closed
   - cooldown is active
   - daily drawdown limit is hit

## Suggested starting parameters for XAUUSD demo tests

These are only starting points and must be optimized with broker-specific tick data.

- `InpRangeTimeframe = PERIOD_M1`
- `InpRangeLookbackBars = 20`
- `InpMinRangeWidthPoints = 100`
- `InpMaxRangeWidthPoints = 600`
- `InpATRPeriod = 14`
- `InpMaxATRPoints = 120`
- `InpEdgeZonePercent = 0.18`
- `InpBurstOrders = 3`
- `InpStopLossPoints = 280`
- `InpTakeProfitPoints = 160`
- `InpTimeExitSeconds = 20`
- `InpMaxSpreadPoints = 80`
- `InpRiskPercentPerCycle = 0.50`
- `InpMaxDailyLossPercent = 3.0`

## Notes on the optional bias filter

The EA includes an optional EMA-based bias filter to emulate the idea of a higher-level directional filter. Public interviews mention smart-money style market reading, but there is not enough public detail to encode exact SMC rules faithfully. If you want, that filter can be replaced later with:

- higher timeframe swing structure
- order block reaction
- fair value gap fill logic
- session liquidity sweep detection

## How to use in MetaTrader 5

1. Copy `mt5/TraderXRangeBurstEA.mq5` into your terminal's `MQL5/Experts` directory.
2. Open MetaEditor and compile the file.
3. Run Strategy Tester in "Every tick based on real ticks" mode.
4. Test on XAUUSD first, then re-tune for your broker.
5. Start on demo only.

## Linux + Wine practical validation environment

This repository now includes a reproducible MT5 validation toolchain for Linux.

### One-time setup

```bash
bash trading/mt5_env/scripts/setup_mt5.sh
```

What it does:

- installs Wine and required compatibility packages
- creates a dedicated Wine prefix at `~/.mt5-traderx`
- downloads and installs MT5 into `C:\MT5Portable`
- performs an initial portable-mode launch so `MQL5/Experts` exists

### Sync the EA into MT5

```bash
bash trading/mt5_env/scripts/sync_ea.sh
```

This copies `mt5/TraderXRangeBurstEA.mq5` into the MT5 portable data directory.

### Compile from the command line

```bash
bash trading/mt5_env/scripts/compile_ea.sh
```

The script:

- syncs the EA
- runs `MetaEditor64.exe` under Wine
- writes compiler output to `trading/mt5_env/logs/compile-*.log`
- expects the compiled file at `~/.mt5-traderx/drive_c/MT5Portable/MQL5/Experts/TraderXRangeBurstEA.ex5`

### Launch the terminal

```bash
bash trading/mt5_env/scripts/run_mt5.sh
```

This starts the terminal in portable mode under `xvfb-run`.

### Launch a backtest from config

```bash
bash trading/mt5_env/scripts/run_backtest.sh
```

Before running a backtest, update `trading/mt5_env/config/tester.ini`:

- `Login`, `Password`, `Server` if broker login is required
- `TestSymbol`, `TestPeriod`, and date range
- `TestExpertParameters` if you create a `.set` file
- `TestReport` is generated dynamically by the shell script, so keep the `__REPORT_PATH__` placeholder

Generated files are placed under:

- `trading/mt5_env/logs/`
- `trading/mt5_env/reports/`
- `trading/mt5_env/downloads/`

### Notes for practical use

- this is suitable for development, compilation, and backtest validation
- for real ultra-short-term live trading, a native Windows VPS is still the safer choice
- Wine logs can contain noisy GUI warnings even when MT5 is otherwise usable
- first broker login and market data download may still require manual terminal interaction

## Important limitations

- Tournament environments can have better execution conditions than retail live accounts.
- This style is highly sensitive to spread, slippage, and latency.
- Burst trading can amplify losses quickly when the market breaks out of a range.
- On MT5 netting accounts, multiple burst orders may collapse into one aggregated position instead of separate tickets.
- Real performance depends heavily on broker execution, symbol contract specs, and VPS latency.

## Good next steps

- Add a real SMC-style structure filter
- Add news blackout windows
- Add equity curve protection after consecutive losses
- Build a broker-specific `.set` preset after backtests
