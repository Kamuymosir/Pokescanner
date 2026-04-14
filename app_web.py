# SingKANA Webアプリ本体（Flask）
# Canonical Version – 2026-01-03

from __future__ import annotations

import os
import json
import datetime
import traceback
import re
from pathlib import Path

from flask import (
    Flask,
    request,
    jsonify,
    send_from_directory,
    Response,
)

# ===== 基本設定 =========================================================

BASE_DIR = Path(__file__).resolve().parent
APP_NAME = "SingKANA"

# .env 読み込み（あれば）
try:
    from dotenv import load_dotenv  # type: ignore
except Exception:
    load_dotenv = None

if load_dotenv:
    load_dotenv(BASE_DIR / ".env")

# エンジン
import singkana_engine as engine
import market_price_search as market_search

app = Flask(__name__)

# ======================================================================
# API: 歌詞変換（唯一・Canonical）
# ======================================================================

@app.post("/api/convert")
def api_convert():
    data = request.get_json(silent=True) or {}

    lyrics = data.get("text") or data.get("lyrics") or ""
    if not lyrics:
        return jsonify({"ok": False, "error": "empty_lyrics"}), 400

    meta = data.get("meta") if isinstance(data.get("meta"), dict) else {}
    display_mode = str(meta.get("display_mode") or "basic").lower()

    # ---- 課金ゲート（Basicのみ無料） ----
    if display_mode != "basic":
        return jsonify({
            "ok": False,
            "error": "payment_required",
            "message": "This mode is available on Pro plan.",
            "requested_mode": display_mode,
            "allowed_free_modes": ["basic"],
            "required_plan": "pro",
        }), 402

    # ---- 変換処理 ----
    try:
        if hasattr(engine, "convertLyrics"):
            result = engine.convertLyrics(lyrics)
        elif hasattr(engine, "convert_lyrics"):
            result = engine.convert_lyrics(lyrics)
        else:
            result = [{"en": lyrics, "kana": lyrics}]
    except Exception as e:
        traceback.print_exc()
        return jsonify({
            "ok": False,
            "error": "engine_error",
            "detail": str(e),
        }), 500

    return jsonify({
        "ok": True,
        "result": result,
    })


# ======================================================================
# 静的ファイル / 画面
# ======================================================================

@app.get("/")
def index() -> Response:
    return send_from_directory(str(BASE_DIR), "index.html")


@app.get("/price-compare")
def price_compare() -> Response:
    return send_from_directory(str(BASE_DIR), "price_compare.html")


@app.get("/singkana_core.js")
def singkana_core_js() -> Response:
    resp = send_from_directory(
        str(BASE_DIR),
        "singkana_core.js",
        mimetype="application/javascript; charset=utf-8",
    )
    resp.headers["Content-Type"] = "application/javascript; charset=utf-8"
    return resp


@app.get("/assets/<path:filename>")
def assets_files(filename):
    return send_from_directory(str(BASE_DIR / "assets"), filename)

@app.get("/paywall_gate.js")
def serve_paywall_gate_js():
    return send_from_directory(str(BASE_DIR), "paywall_gate.js")


# ======================================================================
# API: 相場検索・比較
# ======================================================================

@app.get("/api/market-price-search")
def api_market_price_search():
    query = (request.args.get("query") or request.args.get("q") or "").strip()
    if not query:
        return jsonify({"ok": False, "error": "missing_query"}), 400

    marketplace = request.args.get("marketplace", "all")
    limit_raw = request.args.get("limit", "20")
    exclude_raw = request.args.get("exclude", "")
    min_price_raw = request.args.get("min_price", "").strip()
    max_price_raw = request.args.get("max_price", "").strip()

    try:
        limit = int(limit_raw)
    except ValueError:
        return jsonify({"ok": False, "error": "invalid_limit"}), 400

    def parse_optional_int(value: str, field_name: str):
        if not value:
            return None
        try:
            return int(value)
        except ValueError:
            raise ValueError(field_name) from None

    exclude_keywords = [
        keyword.strip()
        for keyword in exclude_raw.split(",")
        if keyword.strip()
    ]

    try:
        min_price = parse_optional_int(min_price_raw, "min_price")
        max_price = parse_optional_int(max_price_raw, "max_price")
    except ValueError as exc:
        return jsonify({"ok": False, "error": f"invalid_{exc.args[0]}"}), 400

    try:
        payload = market_search.search_market_prices(
            query=query,
            limit_per_source=limit,
            marketplace=marketplace,
            exclude_keywords=exclude_keywords,
            min_price=min_price,
            max_price=max_price,
        )
    except ValueError as exc:
        return jsonify({"ok": False, "error": str(exc)}), 400
    except Exception as exc:
        traceback.print_exc()
        return jsonify({
            "ok": False,
            "error": "market_search_failed",
            "detail": str(exc),
        }), 500

    return jsonify(payload)


# ======================================================================
# Health Check
# ======================================================================

@app.get("/healthz")
def healthz():
    return jsonify({
        "ok": True,
        "service": APP_NAME,
        "time": datetime.datetime.utcnow().isoformat() + "Z",
    })
