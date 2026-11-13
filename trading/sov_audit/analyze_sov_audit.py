#!/usr/bin/env python3
"""Analyze SOVEREIGN audit CSV exports without third-party dependencies."""

from __future__ import annotations

import argparse
import csv
import math
import statistics
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable


REQUIRED_COLUMNS = {
    "strategy_version",
    "symbol",
    "session_bucket",
    "mode",
    "htf_direction",
    "htf_score",
    "spread_points_entry",
    "atr_points_entry",
    "stop_loss_points",
    "take_profit_points",
    "net_pnl",
    "r_multiple",
    "mae_points",
    "mfe_points",
    "holding_seconds",
}


@dataclass
class TradeRow:
    raw: dict[str, str]
    net_pnl: float
    r_multiple: float
    spread_points_entry: float
    atr_points_entry: float
    stop_loss_points: float
    take_profit_points: float
    mae_points: float
    mfe_points: float
    holding_seconds: int

    @property
    def is_win(self) -> bool:
        return self.net_pnl > 0

    @property
    def is_loss(self) -> bool:
        return self.net_pnl < 0


def parse_float(value: str, default: float = 0.0) -> float:
    if value is None:
        return default
    text = value.strip()
    if not text:
        return default
    try:
        return float(text)
    except ValueError:
        return default


def parse_int(value: str, default: int = 0) -> int:
    if value is None:
        return default
    text = value.strip()
    if not text:
        return default
    try:
        return int(float(text))
    except ValueError:
        return default


def percentile(sorted_values: list[float], q: float) -> float:
    if not sorted_values:
        return 0.0
    if len(sorted_values) == 1:
        return sorted_values[0]
    pos = (len(sorted_values) - 1) * q
    lower = math.floor(pos)
    upper = math.ceil(pos)
    if lower == upper:
        return sorted_values[lower]
    weight = pos - lower
    return sorted_values[lower] * (1.0 - weight) + sorted_values[upper] * weight


def build_bucketizer(values: list[float], labels: list[str]) -> Callable[[float], str]:
    clean_values = sorted(v for v in values if math.isfinite(v))
    if not clean_values:
        return lambda _value: labels[0]

    if len(labels) == 4:
        thresholds = [
            percentile(clean_values, 0.25),
            percentile(clean_values, 0.50),
            percentile(clean_values, 0.75),
        ]
    elif len(labels) == 3:
        thresholds = [
            percentile(clean_values, 1.0 / 3.0),
            percentile(clean_values, 2.0 / 3.0),
        ]
    else:
        raise ValueError("Unsupported bucket label count")

    def bucketize(value: float) -> str:
        if len(labels) == 4:
            if value <= thresholds[0]:
                return labels[0]
            if value <= thresholds[1]:
                return labels[1]
            if value <= thresholds[2]:
                return labels[2]
            return labels[3]
        if value <= thresholds[0]:
            return labels[0]
        if value <= thresholds[1]:
            return labels[1]
        return labels[2]

    return bucketize


def load_rows(path: Path) -> list[TradeRow]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise ValueError("CSV header is missing.")

        missing = REQUIRED_COLUMNS.difference(reader.fieldnames)
        if missing:
            raise ValueError(f"Missing required columns: {', '.join(sorted(missing))}")

        rows: list[TradeRow] = []
        for raw in reader:
            rows.append(
                TradeRow(
                    raw=raw,
                    net_pnl=parse_float(raw.get("net_pnl", "")),
                    r_multiple=parse_float(raw.get("r_multiple", "")),
                    spread_points_entry=parse_float(raw.get("spread_points_entry", "")),
                    atr_points_entry=parse_float(raw.get("atr_points_entry", "")),
                    stop_loss_points=parse_float(raw.get("stop_loss_points", "")),
                    take_profit_points=parse_float(raw.get("take_profit_points", "")),
                    mae_points=parse_float(raw.get("mae_points", "")),
                    mfe_points=parse_float(raw.get("mfe_points", "")),
                    holding_seconds=parse_int(raw.get("holding_seconds", "")),
                )
            )
        return rows


def profit_factor(rows: Iterable[TradeRow]) -> float:
    gross_profit = sum(r.net_pnl for r in rows if r.net_pnl > 0)
    gross_loss = abs(sum(r.net_pnl for r in rows if r.net_pnl < 0))
    if gross_loss == 0.0:
        return float("inf") if gross_profit > 0 else 0.0
    return gross_profit / gross_loss


def safe_mean(values: list[float]) -> float:
    return statistics.fmean(values) if values else 0.0


def group_rows(rows: list[TradeRow], key_func: Callable[[TradeRow], str]) -> dict[str, list[TradeRow]]:
    grouped: dict[str, list[TradeRow]] = defaultdict(list)
    for row in rows:
        grouped[key_func(row)].append(row)
    return dict(grouped)


def summarize_group(rows: list[TradeRow]) -> dict[str, float]:
    wins = sum(1 for row in rows if row.is_win)
    losses = sum(1 for row in rows if row.is_loss)
    total = len(rows)
    mfe_values = [row.mfe_points for row in rows]
    mae_values = [row.mae_points for row in rows]
    return {
        "trades": total,
        "wins": wins,
        "losses": losses,
        "win_rate": (wins / total * 100.0) if total else 0.0,
        "net_pnl": sum(row.net_pnl for row in rows),
        "avg_pnl": safe_mean([row.net_pnl for row in rows]),
        "pf": profit_factor(rows),
        "avg_r": safe_mean([row.r_multiple for row in rows]),
        "avg_hold_min": safe_mean([row.holding_seconds for row in rows]) / 60.0,
        "avg_mae": safe_mean(mae_values),
        "avg_mfe": safe_mean(mfe_values),
        "mfe_mae_ratio": (safe_mean(mfe_values) / safe_mean(mae_values)) if safe_mean(mae_values) > 0 else 0.0,
    }


def format_number(value: float) -> str:
    if math.isinf(value):
        return "inf"
    return f"{value:.2f}"


def render_table(title: str, grouped: dict[str, list[TradeRow]], min_trades: int) -> str:
    lines = [f"## {title}", "", "| Group | Trades | Win% | NetPnL | PF | AvgR | AvgHoldMin | AvgMAE | AvgMFE | MFE/MAE |", "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    sortable = []
    for group_name, rows in grouped.items():
        if len(rows) < min_trades:
            continue
        stats = summarize_group(rows)
        sortable.append((stats["net_pnl"], group_name, stats))

    for _net, group_name, stats in sorted(sortable, reverse=True):
        lines.append(
            "| {group} | {trades} | {win_rate} | {net_pnl} | {pf} | {avg_r} | {avg_hold_min} | {avg_mae} | {avg_mfe} | {mfe_mae_ratio} |".format(
                group=group_name,
                trades=int(stats["trades"]),
                win_rate=format_number(stats["win_rate"]),
                net_pnl=format_number(stats["net_pnl"]),
                pf=format_number(stats["pf"]),
                avg_r=format_number(stats["avg_r"]),
                avg_hold_min=format_number(stats["avg_hold_min"]),
                avg_mae=format_number(stats["avg_mae"]),
                avg_mfe=format_number(stats["avg_mfe"]),
                mfe_mae_ratio=format_number(stats["mfe_mae_ratio"]),
            )
        )
    if len(lines) == 3:
        lines.append("| _no groups above threshold_ | - | - | - | - | - | - | - | - | - |")
    lines.append("")
    return "\n".join(lines)


def derive_bucket_label(row: TradeRow, field_name: str, bucketizer: Callable[[float], str]) -> str:
    existing = row.raw.get(field_name, "").strip()
    if existing:
        return existing
    if field_name == "htf_score_bucket":
        return bucketizer(parse_float(row.raw.get("htf_score", "")))
    if field_name == "spread_bucket":
        return bucketizer(row.spread_points_entry)
    if field_name == "volatility_bucket":
        return bucketizer(row.atr_points_entry)
    return "Unknown"


def build_actionable_findings(rows: list[TradeRow], min_trades: int) -> list[str]:
    findings: list[str] = []

    mode_groups = group_rows(rows, lambda r: r.raw.get("mode", "Unknown") or "Unknown")
    mode_stats = {mode: summarize_group(group) for mode, group in mode_groups.items() if len(group) >= min_trades}
    if len(mode_stats) >= 2:
        best_mode = max(mode_stats.items(), key=lambda item: item[1]["avg_r"])
        worst_mode = min(mode_stats.items(), key=lambda item: item[1]["avg_r"])
        if best_mode[1]["avg_r"] - worst_mode[1]["avg_r"] >= 0.20:
            findings.append(
                f"`{best_mode[0]}` と `{worst_mode[0]}` の期待値差が大きいです。両者を同一設定で最適化せず、独立したパラメータ系に分けるべきです。"
            )

    exit_groups = group_rows(rows, lambda r: r.raw.get("exit_reason", "Unknown") or "Unknown")
    time_stop_rows = exit_groups.get("TimeStop", [])
    if len(time_stop_rows) >= min_trades:
        time_stop_stats = summarize_group(time_stop_rows)
        if time_stop_stats["avg_r"] < 0:
            findings.append("`TimeStop` 終了群の平均Rがマイナスです。保有時間上限か、時間切れ前の管理ロジックを見直す価値があります。")

    spread_bucketizer = build_bucketizer([r.spread_points_entry for r in rows], ["Tight", "Normal", "Wide", "Extreme"])
    spread_groups = group_rows(rows, lambda r: derive_bucket_label(r, "spread_bucket", spread_bucketizer))
    if "Extreme" in spread_groups and len(spread_groups["Extreme"]) >= min_trades:
        extreme_stats = summarize_group(spread_groups["Extreme"])
        if extreme_stats["avg_r"] < 0:
            findings.append("スプレッドが極端に広い局面の平均Rがマイナスです。`InpMaxSpreadPoints` かモード別スプレッド上限を厳しくする候補です。")

    score_bucketizer = build_bucketizer([parse_float(r.raw.get("htf_score", "")) for r in rows], ["Weak", "Medium", "Strong", "VeryStrong"])
    score_groups = group_rows(rows, lambda r: derive_bucket_label(r, "htf_score_bucket", score_bucketizer))
    if "VeryStrong" in score_groups and "Weak" in score_groups:
        strong_rows = score_groups["VeryStrong"]
        weak_rows = score_groups["Weak"]
        if len(strong_rows) >= min_trades and len(weak_rows) >= min_trades:
            strong_stats = summarize_group(strong_rows)
            weak_stats = summarize_group(weak_rows)
            if strong_stats["avg_r"] > weak_stats["avg_r"] + 0.15:
                findings.append("HTFスコア上位群の期待値が明確に高いです。スコアを gate だけでなく risk allocation に使う余地があります。")

    profitable_rows = [r for r in rows if r.net_pnl > 0]
    if len(profitable_rows) >= min_trades:
        avg_mfe = safe_mean([r.mfe_points for r in profitable_rows])
        avg_sl = safe_mean([r.stop_loss_points for r in profitable_rows])
        if avg_sl > 0 and avg_mfe / avg_sl > 1.8:
            findings.append("勝ちトレードの平均MFEが初期SLのかなり上まで伸びています。部分利確 + runner の導入余地が大きい可能性があります。")

    if not findings:
        findings.append("現時点のサンプルでは強い偏りが十分見えていません。取引件数を増やし、モード別・時間帯別のサンプル数を確保してください。")

    return findings


def overview(rows: list[TradeRow]) -> str:
    stats = summarize_group(rows)
    first_trade = min((r.raw.get("entry_time", "") for r in rows if r.raw.get("entry_time", "")), default="")
    last_trade = max((r.raw.get("exit_time", "") for r in rows if r.raw.get("exit_time", "")), default="")
    return "\n".join(
        [
            "# SOVEREIGN audit report",
            "",
            "## Overview",
            "",
            f"- Trades: {int(stats['trades'])}",
            f"- NetPnL: {format_number(stats['net_pnl'])}",
            f"- Win rate: {format_number(stats['win_rate'])}%",
            f"- Profit factor: {format_number(stats['pf'])}",
            f"- Average R: {format_number(stats['avg_r'])}",
            f"- Average hold time (min): {format_number(stats['avg_hold_min'])}",
            f"- Average MAE: {format_number(stats['avg_mae'])}",
            f"- Average MFE: {format_number(stats['avg_mfe'])}",
            f"- MFE/MAE ratio: {format_number(stats['mfe_mae_ratio'])}",
            f"- First trade: {first_trade or 'n/a'}",
            f"- Last trade: {last_trade or 'n/a'}",
            "",
        ]
    )


def build_report(rows: list[TradeRow], min_trades: int) -> str:
    score_bucketizer = build_bucketizer([parse_float(r.raw.get("htf_score", "")) for r in rows], ["Weak", "Medium", "Strong", "VeryStrong"])
    spread_bucketizer = build_bucketizer([r.spread_points_entry for r in rows], ["Tight", "Normal", "Wide", "Extreme"])
    volatility_bucketizer = build_bucketizer([r.atr_points_entry for r in rows], ["Low", "Normal", "High", "Extreme"])

    sections = [overview(rows)]
    sections.append(render_table("By mode", group_rows(rows, lambda r: r.raw.get("mode", "Unknown") or "Unknown"), min_trades))
    sections.append(render_table("By symbol", group_rows(rows, lambda r: r.raw.get("symbol", "Unknown") or "Unknown"), min_trades))
    sections.append(render_table("By session", group_rows(rows, lambda r: r.raw.get("session_bucket", "Unknown") or "Unknown"), min_trades))
    sections.append(render_table("By HTF score bucket", group_rows(rows, lambda r: derive_bucket_label(r, "htf_score_bucket", score_bucketizer)), min_trades))
    sections.append(render_table("By spread bucket", group_rows(rows, lambda r: derive_bucket_label(r, "spread_bucket", spread_bucketizer)), min_trades))
    sections.append(render_table("By volatility bucket", group_rows(rows, lambda r: derive_bucket_label(r, "volatility_bucket", volatility_bucketizer)), min_trades))
    sections.append(render_table("By exit reason", group_rows(rows, lambda r: r.raw.get("exit_reason", "Unknown") or "Unknown"), min_trades))

    sections.append("## Actionable findings\n")
    for finding in build_actionable_findings(rows, min_trades):
        sections.append(f"- {finding}")
    sections.append("")

    sections.append(
        "\n".join(
            [
                "## Next optimization loop",
                "",
                "1. disable or isolate structurally weak groups rather than averaging them into the whole strategy",
                "2. test exit changes before adding more filters",
                "3. promote score/session/symbol groups with stronger average R into larger but bounded risk allocations",
                "4. split presets by symbol and session instead of forcing a universal production setup",
                "",
            ]
        )
    )

    return "\n".join(sections).strip() + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Analyze SOVEREIGN trade audit CSV files.")
    parser.add_argument("csv_path", help="Path to the audit CSV file.")
    parser.add_argument("--output", help="Optional path to write the Markdown report.")
    parser.add_argument("--min-trades", type=int, default=5, help="Minimum group size to include in grouped tables.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    csv_path = Path(args.csv_path)
    if not csv_path.is_file():
        raise SystemExit(f"CSV file not found: {csv_path}")

    rows = load_rows(csv_path)
    if not rows:
        raise SystemExit("CSV file contains no data rows.")

    report = build_report(rows, max(1, args.min_trades))
    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(report, encoding="utf-8")
        print(f"Report written to: {output_path}")
    else:
        print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
