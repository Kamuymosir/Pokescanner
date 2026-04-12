#!/usr/bin/env python3
"""Run repeated MT5 backtests for SOVEREIGN Ascendant and score results."""

from __future__ import annotations

import argparse
import csv
import itertools
import json
import math
import re
import shutil
import subprocess
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
TRADING_DIR = WORKSPACE_ROOT / "trading"
MT5_ENV_DIR = TRADING_DIR / "mt5_env"
SOV_OPT_DIR = TRADING_DIR / "sov_opt"
MT5_EXPERT_SOURCE = TRADING_DIR / "mt5" / "SOVEREIGN_Ascendant_v1.mq5"
MT5_SYNC_SCRIPT = MT5_ENV_DIR / "scripts" / "sync_ea.sh"
MT5_COMPILE_SCRIPT = MT5_ENV_DIR / "scripts" / "compile_ea.sh"
MT5_BACKTEST_SCRIPT = MT5_ENV_DIR / "scripts" / "run_backtest.sh"
INI_TEMPLATE_PATH = SOV_OPT_DIR / "ascendant_tester.ini.tpl"


@dataclass
class TradeResult:
    exit_time: datetime
    net_pnl: float
    r_multiple: float


@dataclass
class RunMetrics:
    trades: int
    wins: int
    losses: int
    net_pnl: float
    gross_profit: float
    gross_loss: float
    profit_factor: float
    avg_r: float
    max_drawdown: float
    dd_ratio: float
    score: float
    status: str
    reason: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Batch backtest runner for SOVEREIGN Ascendant.")
    parser.add_argument("config", help="Path to JSON search-space config.")
    parser.add_argument("--dry-run", action="store_true", help="Generate files only, do not execute MT5.")
    parser.add_argument("--limit", type=int, default=0, help="Limit number of generated candidates.")
    parser.add_argument("--skip-compile", action="store_true", help="Do not sync/compile the EA before running.")
    parser.add_argument("--output-dir", default="", help="Override output directory.")
    return parser.parse_args()


def load_config(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def now_stamp() -> str:
    return datetime.now(UTC).strftime("%Y%m%d-%H%M%S")


def run_command(command: list[str], timeout_seconds: int | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=str(WORKSPACE_ROOT),
        text=True,
        capture_output=True,
        timeout=timeout_seconds,
        check=False,
    )


def extract_input_defaults(mq5_path: Path) -> tuple[list[str], dict[str, str]]:
    order: list[str] = []
    defaults: dict[str, str] = {}
    pattern = re.compile(r"^\s*input\s+(?!group\b).+?\s+([A-Za-z_]\w*)\s*=\s*(.+?);\s*$")

    for line in mq5_path.read_text(encoding="utf-8").splitlines():
        match = pattern.match(line)
        if not match:
            continue

        name = match.group(1)
        value = match.group(2).strip()
        if value.startswith('"') and value.endswith('"'):
            value = value[1:-1]
        elif value.startswith("PERIOD_") or value.startswith("MODE_"):
            # Enum defaults are omitted unless explicitly overridden in JSON.
            continue

        order.append(name)
        defaults[name] = value

    return order, defaults


def normalize_param_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if value.is_integer():
            return str(int(value))
        return f"{value:.10g}"
    return str(value)


def build_candidates(config: dict[str, Any], default_values: dict[str, str]) -> list[dict[str, str]]:
    base_parameters = dict(default_values)
    for key, value in config.get("base_parameters", {}).items():
        base_parameters[key] = normalize_param_value(value)

    search_space = config.get("search_space", {})
    if not search_space:
        return [base_parameters]

    keys = list(search_space.keys())
    value_lists = []
    for key in keys:
        values = search_space[key]
        if not isinstance(values, list) or not values:
            raise ValueError(f"search_space[{key}] must be a non-empty list")
        value_lists.append([normalize_param_value(v) for v in values])

    candidates: list[dict[str, str]] = []
    for combo in itertools.product(*value_lists):
        params = dict(base_parameters)
        for key, value in zip(keys, combo, strict=True):
            params[key] = value
        candidates.append(params)
    return candidates


def ensure_compiled(expert_name: str, skip_compile: bool) -> None:
    if skip_compile:
        return

    sync_result = run_command(
        ["bash", str(MT5_SYNC_SCRIPT), str(MT5_EXPERT_SOURCE), f"{expert_name}.mq5"]
    )
    if sync_result.returncode != 0:
        raise RuntimeError(f"sync failed:\n{sync_result.stdout}\n{sync_result.stderr}")

    compile_result = run_command(["bash", str(MT5_COMPILE_SCRIPT), expert_name], timeout_seconds=240)
    if compile_result.returncode != 0:
        raise RuntimeError(f"compile failed:\n{compile_result.stdout}\n{compile_result.stderr}")


def make_output_dir(args: argparse.Namespace, config: dict[str, Any]) -> Path:
    if args.output_dir:
        out_dir = Path(args.output_dir)
    else:
        prefix = config.get("report_prefix", "ascendant-batch")
        out_dir = SOV_OPT_DIR / "output" / f"{prefix}-{now_stamp()}"
    out_dir.mkdir(parents=True, exist_ok=True)
    return out_dir


def mt5_prefix() -> Path:
    return Path.home() / ".mt5-traderx"


def mt5_presets_dir() -> Path:
    return mt5_prefix() / "drive_c" / "MT5Portable" / "MQL5" / "Presets"

def mt5_tester_profiles_dir() -> Path:
    return mt5_prefix() / "drive_c" / "MT5Portable" / "MQL5" / "Profiles" / "Tester"

def mt5_terminal_common_files_dir() -> Path:
    return mt5_prefix() / "drive_c" / "users" / "ubuntu" / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"


def write_set_file(path: Path, params: dict[str, str], order: list[str]) -> None:
    lines = [
        "; generated by trading/sov_opt/run_sov_opt.py",
        ";name=value||start||step||stop||selected",
    ]

    written = set()
    for name in order:
        if name not in params:
            continue
        lines.append(f"{name}={params[name]}")
        written.add(name)

    for name in sorted(params):
        if name in written:
            continue
        lines.append(f"{name}={params[name]}")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_ini_file(
    path: Path,
    expert_name: str,
    set_file_name: str,
    symbol: str,
    period: str,
    from_date: str,
    to_date: str,
) -> None:
    template = INI_TEMPLATE_PATH.read_text(encoding="utf-8")
    content = (
        template.replace("__EXPERT_NAME__", expert_name)
        .replace("__SET_FILE__", set_file_name)
        .replace("__SYMBOL__", symbol)
        .replace("__PERIOD__", period)
        .replace("__FROM_DATE__", from_date)
        .replace("__TO_DATE__", to_date)
    )
    path.write_text(content, encoding="utf-8")


def remove_previous_audit_files(audit_file_name: str) -> None:
    for root in (mt5_prefix(), mt5_terminal_common_files_dir()):
        if not root.exists():
            continue
        for path in root.rglob(audit_file_name):
            try:
                path.unlink()
            except OSError:
                pass


def locate_audit_file(audit_file_name: str) -> Path | None:
    matches = []
    for root in (mt5_terminal_common_files_dir(), mt5_prefix()):
        if root.exists():
            matches.extend(root.rglob(audit_file_name))
    if not matches:
        return None
    matches.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return matches[0]


def locate_report_files(run_dir: Path, report_base_name: str) -> list[Path]:
    report_dir = mt5_prefix() / "drive_c" / "MT5Portable" / "reports"
    if not report_dir.exists():
        return []
    return sorted(report_dir.glob(f"{report_base_name}*"))


def parse_trade_results(audit_csv: Path) -> list[TradeResult]:
    rows: list[TradeResult] = []
    with audit_csv.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            exit_time_raw = (row.get("exit_time") or "").strip()
            if not exit_time_raw:
                continue
            exit_time = datetime.strptime(exit_time_raw, "%Y.%m.%d %H:%M:%S")
            rows.append(
                TradeResult(
                    exit_time=exit_time,
                    net_pnl=float((row.get("net_pnl") or "0").strip() or "0"),
                    r_multiple=float((row.get("r_multiple") or "0").strip() or "0"),
                )
            )
    rows.sort(key=lambda r: r.exit_time)
    return rows


def score_metrics(results: list[TradeResult], min_trades: int) -> RunMetrics:
    if not results:
        return RunMetrics(0, 0, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -9999.0, "failed", "audit CSV missing or empty")

    wins = sum(1 for r in results if r.net_pnl > 0)
    losses = sum(1 for r in results if r.net_pnl < 0)
    net_pnl = sum(r.net_pnl for r in results)
    gross_profit = sum(r.net_pnl for r in results if r.net_pnl > 0)
    gross_loss = abs(sum(r.net_pnl for r in results if r.net_pnl < 0))
    profit_factor = float("inf") if gross_loss == 0 and gross_profit > 0 else (gross_profit / gross_loss if gross_loss > 0 else 0.0)
    avg_r = sum(r.r_multiple for r in results) / len(results)

    equity = 0.0
    peak = 0.0
    max_drawdown = 0.0
    for row in results:
        equity += row.net_pnl
        if equity > peak:
            peak = equity
        drawdown = peak - equity
        if drawdown > max_drawdown:
            max_drawdown = drawdown

    dd_ratio = max_drawdown / gross_profit if gross_profit > 0 else 1.0
    candidate_score = 0.0
    status = "ok"
    reason = ""

    if len(results) < min_trades:
        status = "rejected"
        reason = f"trade count below threshold ({len(results)} < {min_trades})"
        candidate_score -= 100.0

    pf_capped = min(profit_factor, 3.0) if math.isfinite(profit_factor) else 3.0
    trade_factor = min(len(results) / max(min_trades, 1), 2.0)
    drawdown_efficiency = max(0.0, 1.25 - min(dd_ratio, 1.25))

    candidate_score += pf_capped * 18.0
    candidate_score += avg_r * 40.0
    candidate_score += math.log1p(max(net_pnl, 0.0)) * 8.0
    candidate_score += trade_factor * 8.0
    candidate_score += drawdown_efficiency * 20.0
    candidate_score -= max_drawdown * 0.05

    if net_pnl <= 0.0:
        candidate_score -= 50.0
        if not reason:
            status = "rejected"
            reason = "non-positive net pnl"

    return RunMetrics(
        trades=len(results),
        wins=wins,
        losses=losses,
        net_pnl=net_pnl,
        gross_profit=gross_profit,
        gross_loss=gross_loss,
        profit_factor=profit_factor,
        avg_r=avg_r,
        max_drawdown=max_drawdown,
        dd_ratio=dd_ratio,
        score=candidate_score,
        status=status,
        reason=reason,
    )


def format_float(value: float) -> str:
    if math.isinf(value):
        return "inf"
    return f"{value:.4f}"


def write_summary_csv(path: Path, rows: list[dict[str, str]]) -> None:
    if not rows:
        return
    fieldnames = list(rows[0].keys())
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_summary_markdown(path: Path, rows: list[dict[str, str]]) -> None:
    lines = [
        "# SOVEREIGN Ascendant optimization summary",
        "",
        "| Run | Status | Score | Trades | NetPnL | PF | AvgR | MaxDD | Reason |",
        "|---|---|---:|---:|---:|---:|---:|---:|---|",
    ]
    for row in rows:
        lines.append(
            "| {run_id} | {status} | {score} | {trades} | {net_pnl} | {profit_factor} | {avg_r} | {max_drawdown} | {reason} |".format(
                **row
            )
        )
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    args = parse_args()
    config_path = Path(args.config).resolve()
    config = load_config(config_path)

    expert_name = config.get("expert_name", "SOVEREIGN_Ascendant_v1")
    symbol = config.get("symbol", "XAUUSD")
    period = config.get("period", "M15")
    from_date = config.get("from_date", "2025.01.01")
    to_date = config.get("to_date", "2025.03.31")
    min_trades = int(config.get("min_trades", 20))
    timeout_seconds = int(config.get("timeout_seconds", 240))

    output_dir = make_output_dir(args, config)
    sets_dir = output_dir / "sets"
    configs_dir = output_dir / "configs"
    runs_dir = output_dir / "runs"
    for directory in (sets_dir, configs_dir, runs_dir):
        directory.mkdir(parents=True, exist_ok=True)

    order, defaults = extract_input_defaults(MT5_EXPERT_SOURCE)
    candidates = build_candidates(config, defaults)
    if args.limit > 0:
        candidates = candidates[: args.limit]

    print(f"Loaded {len(candidates)} candidate(s) from {config_path}")

    mt5_presets_dir().mkdir(parents=True, exist_ok=True)
    ensure_compiled(expert_name, args.skip_compile)

    summary_rows: list[dict[str, str]] = []

    for index, params in enumerate(candidates, start=1):
        run_id = f"{index:03d}"
        run_name = f"{symbol.lower()}-{period.lower()}-{run_id}"
        report_base = f"{config.get('report_prefix', 'ascendant')}-{run_id}"
        run_dir = runs_dir / run_name
        run_dir.mkdir(parents=True, exist_ok=True)

        audit_file_name = f"{expert_name}_{run_id}_audit.csv"
        params = dict(params)
        params["InpEnableAuditCSV"] = "true"
        params["InpAuditFileName"] = audit_file_name

        set_file_name = f"{expert_name}_{run_id}.set"
        local_set_path = sets_dir / set_file_name
        mt5_set_path = mt5_tester_profiles_dir() / set_file_name
        ini_path = configs_dir / f"{expert_name}_{run_id}.ini"
        report_path = run_dir / "reports" / report_base
        report_path.parent.mkdir(parents=True, exist_ok=True)

        write_set_file(local_set_path, params, order)
        shutil.copy2(local_set_path, mt5_set_path)
        write_ini_file(ini_path, expert_name, set_file_name, symbol, period, from_date, to_date)

        print(f"[{run_id}] prepared candidate -> {run_name}")

        status = "dry-run"
        reason = ""
        metrics = RunMetrics(0, 0, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, status, reason)
        audit_copy_path = run_dir / audit_file_name

        if not args.dry_run:
            remove_previous_audit_files(audit_file_name)
            try:
                result = run_command(
                    ["bash", str(MT5_BACKTEST_SCRIPT), str(ini_path), str(report_path)],
                    timeout_seconds=timeout_seconds,
                )
                (run_dir / "stdout.log").write_text(result.stdout, encoding="utf-8")
                (run_dir / "stderr.log").write_text(result.stderr, encoding="utf-8")

                if result.returncode != 0:
                    metrics = RunMetrics(0, 0, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -9999.0, "failed", f"mt5 exit code {result.returncode}")
                else:
                    audit_path = locate_audit_file(audit_file_name)
                    if audit_path is None:
                        metrics = RunMetrics(0, 0, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -9999.0, "failed", "audit CSV not found")
                    else:
                        shutil.copy2(audit_path, audit_copy_path)
                        results = parse_trade_results(audit_copy_path)
                        metrics = score_metrics(results, min_trades)
            except subprocess.TimeoutExpired:
                (run_dir / "stderr.log").write_text(
                    f"Backtest timed out after {timeout_seconds} seconds.\n",
                    encoding="utf-8",
                )
                metrics = RunMetrics(
                    0,
                    0,
                    0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    -9999.0,
                    "timeout",
                    f"mt5 timed out after {timeout_seconds}s",
                )

            for report_file in locate_report_files(run_dir, report_base):
                target = run_dir / report_file.name
                if report_file != target:
                    shutil.copy2(report_file, target)

        summary_rows.append(
            {
                "run_id": run_name,
                "status": metrics.status,
                "score": format_float(metrics.score),
                "trades": str(metrics.trades),
                "wins": str(metrics.wins),
                "losses": str(metrics.losses),
                "net_pnl": format_float(metrics.net_pnl),
                "profit_factor": format_float(metrics.profit_factor),
                "avg_r": format_float(metrics.avg_r),
                "max_drawdown": format_float(metrics.max_drawdown),
                "dd_ratio": format_float(metrics.dd_ratio),
                "audit_file": audit_copy_path.name if audit_copy_path.exists() else "",
                "set_file": set_file_name,
                "reason": metrics.reason,
            }
        )

    summary_rows.sort(key=lambda row: float(row["score"]) if row["score"] != "inf" else 999999.0, reverse=True)
    write_summary_csv(output_dir / "summary.csv", summary_rows)
    write_summary_markdown(output_dir / "summary.md", summary_rows)

    print(f"Summary written to: {output_dir / 'summary.csv'}")
    print(f"Markdown report:   {output_dir / 'summary.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
