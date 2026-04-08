from __future__ import annotations

import copy
import html
import re
import statistics
import time
import urllib.parse
import urllib.request
from typing import Any


DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
)
GOOGLEBOT_USER_AGENT = (
    "Mozilla/5.0 (compatible; Googlebot/2.1; "
    "+http://www.google.com/bot.html)"
)
CACHE_TTL_SECONDS = 300
MAX_RESULTS_PER_SOURCE = 50

MERCARI_BASE_URL = "https://jp.mercari.com"
YAHOO_CLOSED_SEARCH_URL = "https://auctions.yahoo.co.jp/closedsearch/closedsearch"

_SEARCH_CACHE: dict[tuple[Any, ...], tuple[float, dict[str, Any]]] = {}

_MERCARI_ITEM_PATTERN = re.compile(r'<li data-testid="item-cell".*?</li>', re.S)
_MERCARI_URL_PATTERN = re.compile(r'href="(/item/m\d{8,})"')
_MERCARI_TITLE_PATTERN = re.compile(
    r'<span data-testid="thumbnail-item-name"[^>]*>(.*?)</span>',
    re.S,
)
_MERCARI_PRICE_PATTERN = re.compile(
    r'<span class="number[^"]*">([\d,]+)</span>'
)
_MERCARI_IMAGE_PATTERN = re.compile(r'<img src="([^"]+)"')
_MERCARI_AUCTION_PATTERN = re.compile(r'現在 ¥')

_YAHOO_URL_PATTERN = re.compile(
    r'href="(https://(?:auctions\.yahoo\.co\.jp/jp/auction/'
    r'[A-Za-z0-9]+|paypayfleamarket\.yahoo\.co\.jp/item/[A-Za-z0-9]+))"'
)
_YAHOO_TITLE_PATTERN = re.compile(r'title="([^"]+)"')
_YAHOO_IMAGE_ALT_PATTERN = re.compile(r'<img [^>]*alt="([^"]+)"')
_YAHOO_PRICE_PATTERN = re.compile(
    r'>落札</span><span[^>]*>([\d,]+)<span[^>]*>円',
    re.S,
)
_YAHOO_START_PRICE_PATTERN = re.compile(
    r'>開始</span><span[^>]*>([\d,]+)<span[^>]*>円',
    re.S,
)
_YAHOO_IMAGE_PATTERN = re.compile(r'<img src="([^"]+)"')
_YAHOO_END_PATTERN = re.compile(r'(\d{1,2}/\d{1,2}\s+\d{2}:\d{2})終了')


class MarketSearchError(RuntimeError):
    """Raised when a remote marketplace search fails."""


def search_market_prices(
    query: str,
    limit_per_source: int = 20,
    marketplace: str = "all",
    exclude_keywords: list[str] | None = None,
    min_price: int | None = None,
    max_price: int | None = None,
) -> dict[str, Any]:
    normalized_query = _normalize_space(query)
    if not normalized_query:
        raise ValueError("query is required")

    normalized_marketplace = normalize_marketplace(marketplace)
    safe_limit = max(1, min(int(limit_per_source), MAX_RESULTS_PER_SOURCE))
    safe_exclude_keywords = [w for w in (exclude_keywords or []) if w]

    cache_key = (
        normalized_query,
        safe_limit,
        normalized_marketplace,
        tuple(safe_exclude_keywords),
        min_price,
        max_price,
    )
    cached = _SEARCH_CACHE.get(cache_key)
    now = time.time()
    if cached and cached[0] > now:
        return copy.deepcopy(cached[1])

    errors: list[dict[str, str]] = []
    mercari_items: list[dict[str, Any]] = []
    yahoo_items: list[dict[str, Any]] = []

    if normalized_marketplace in {"all", "mercari"}:
        try:
            mercari_html = fetch_mercari_search_html(normalized_query)
            mercari_items = parse_mercari_search_html(mercari_html, limit=safe_limit)
        except Exception as exc:  # pragma: no cover - exercised via endpoint behavior
            errors.append({"marketplace": "mercari", "message": str(exc)})

    if normalized_marketplace in {"all", "yahoo", "yahoo_auction", "yahoo_flea"}:
        try:
            yahoo_html = fetch_yahoo_search_html(normalized_query)
            yahoo_items = parse_yahoo_search_html(yahoo_html, limit=safe_limit)
        except Exception as exc:  # pragma: no cover - exercised via endpoint behavior
            errors.append({"marketplace": "yahoo", "message": str(exc)})

    filtered_mercari_items = apply_item_filters(
        mercari_items,
        marketplace=normalized_marketplace,
        exclude_keywords=safe_exclude_keywords,
        min_price=min_price,
        max_price=max_price,
    )
    filtered_yahoo_items = apply_item_filters(
        yahoo_items,
        marketplace=normalized_marketplace,
        exclude_keywords=safe_exclude_keywords,
        min_price=min_price,
        max_price=max_price,
    )

    all_items = filtered_mercari_items + filtered_yahoo_items
    all_items.sort(key=lambda item: (item["price"], item["title"]))

    response = {
        "ok": bool(all_items) or not errors,
        "query": normalized_query,
        "marketplace": normalized_marketplace,
        "limit_per_source": safe_limit,
        "fetched_at": int(now),
        "filters": {
            "exclude_keywords": safe_exclude_keywords,
            "min_price": min_price,
            "max_price": max_price,
        },
        "items": all_items,
        "sources": {
            "mercari": {
                "label": "メルカリ",
                "count": len(filtered_mercari_items),
                "items": filtered_mercari_items,
                "summary": build_price_summary(filtered_mercari_items),
            },
            "yahoo": {
                "label": "ヤフオク系",
                "count": len(filtered_yahoo_items),
                "items": filtered_yahoo_items,
                "summary": build_price_summary(filtered_yahoo_items),
            },
            "yahoo_auction": {
                "label": "Yahoo!オークション",
                "count": len([i for i in filtered_yahoo_items if i["source_type"] == "auction"]),
                "summary": build_price_summary(
                    [i for i in filtered_yahoo_items if i["source_type"] == "auction"]
                ),
            },
            "yahoo_flea": {
                "label": "Yahoo!フリマ",
                "count": len([i for i in filtered_yahoo_items if i["source_type"] == "flea_market"]),
                "summary": build_price_summary(
                    [i for i in filtered_yahoo_items if i["source_type"] == "flea_market"]
                ),
            },
            "all": {
                "label": "全体",
                "count": len(all_items),
                "summary": build_price_summary(all_items),
            },
        },
        "comparison": build_market_comparison(
            filtered_mercari_items,
            filtered_yahoo_items,
        ),
        "warnings": [
            "公開検索ページをもとにしたMVPのため、サイト構造変更で取得できなくなる可能性があります。",
            "統計は取得できたサンプル件数の範囲で算出しています。",
        ],
        "errors": errors,
    }

    _SEARCH_CACHE[cache_key] = (now + CACHE_TTL_SECONDS, response)
    return copy.deepcopy(response)


def normalize_marketplace(value: str | None) -> str:
    normalized = (value or "all").strip().lower().replace("-", "_")
    allowed = {"all", "mercari", "yahoo", "yahoo_auction", "yahoo_flea"}
    return normalized if normalized in allowed else "all"


def fetch_mercari_search_html(query: str) -> str:
    params = urllib.parse.urlencode(
        {
            "keyword": query,
            "status": "sold_out",
        }
    )
    url = f"{MERCARI_BASE_URL}/search?{params}"
    return fetch_html(url, user_agent=GOOGLEBOT_USER_AGENT)


def fetch_yahoo_search_html(query: str) -> str:
    params = urllib.parse.urlencode(
        {
            "p": query,
            "n": MAX_RESULTS_PER_SOURCE,
            "b": 1,
        }
    )
    url = f"{YAHOO_CLOSED_SEARCH_URL}?{params}"
    return fetch_html(url, user_agent=DEFAULT_USER_AGENT)


def fetch_html(url: str, user_agent: str) -> str:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": user_agent,
            "Accept-Language": "ja,en-US;q=0.9,en;q=0.8",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return response.read().decode("utf-8", "ignore")
    except Exception as exc:
        raise MarketSearchError(f"fetch failed: {url}") from exc


def parse_mercari_search_html(html_text: str, limit: int = 20) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    seen_ids: set[str] = set()

    for block in _MERCARI_ITEM_PATTERN.findall(html_text):
        url_match = _MERCARI_URL_PATTERN.search(block)
        title_match = _MERCARI_TITLE_PATTERN.search(block)
        price_match = _MERCARI_PRICE_PATTERN.search(block)
        if not (url_match and title_match and price_match):
            continue

        item_path = url_match.group(1)
        item_id = item_path.rstrip("/").split("/")[-1]
        if item_id in seen_ids:
            continue
        seen_ids.add(item_id)

        title = clean_html_text(title_match.group(1))
        price = parse_price_number(price_match.group(1))
        image_match = _MERCARI_IMAGE_PATTERN.search(block)

        items.append(
            {
                "id": item_id,
                "marketplace": "mercari",
                "marketplace_label": "メルカリ",
                "source_type": "auction" if _MERCARI_AUCTION_PATTERN.search(block) else "fixed_price",
                "source_type_label": (
                    "メルカリ オークション"
                    if _MERCARI_AUCTION_PATTERN.search(block)
                    else "メルカリ"
                ),
                "title": title,
                "price": price,
                "price_display": f"¥{price:,}",
                "url": urllib.parse.urljoin(MERCARI_BASE_URL, item_path),
                "image_url": html.unescape(image_match.group(1)) if image_match else None,
            }
        )

        if len(items) >= limit:
            break

    return items


def parse_yahoo_search_html(html_text: str, limit: int = 20) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    seen_urls: set[str] = set()

    for url_match in _YAHOO_URL_PATTERN.finditer(html_text):
        url = html.unescape(url_match.group(1))
        if url in seen_urls:
            continue

        window = html_text[url_match.start(): url_match.start() + 5000]
        title = _extract_yahoo_title(window)
        price_match = _YAHOO_PRICE_PATTERN.search(window)
        if not title or not price_match:
            continue

        price = parse_price_number(price_match.group(1))
        seen_urls.add(url)
        image_match = _YAHOO_IMAGE_PATTERN.search(window)
        start_price_match = _YAHOO_START_PRICE_PATTERN.search(window)
        end_match = _YAHOO_END_PATTERN.search(window)

        if "paypayfleamarket.yahoo.co.jp" in url:
            source_type = "flea_market"
            source_type_label = "Yahoo!フリマ"
        else:
            source_type = "auction"
            source_type_label = "Yahoo!オークション"

        items.append(
            {
                "id": url.rstrip("/").split("/")[-1],
                "marketplace": "yahoo",
                "marketplace_label": "ヤフオク系",
                "source_type": source_type,
                "source_type_label": source_type_label,
                "title": title,
                "price": price,
                "price_display": f"¥{price:,}",
                "start_price": (
                    parse_price_number(start_price_match.group(1))
                    if start_price_match
                    else None
                ),
                "end_time": end_match.group(1) if end_match else None,
                "url": url,
                "image_url": html.unescape(image_match.group(1)) if image_match else None,
            }
        )

        if len(items) >= limit:
            break

    return items


def apply_item_filters(
    items: list[dict[str, Any]],
    marketplace: str,
    exclude_keywords: list[str] | None = None,
    min_price: int | None = None,
    max_price: int | None = None,
) -> list[dict[str, Any]]:
    normalized_excludes = [w.lower() for w in (exclude_keywords or [])]
    filtered: list[dict[str, Any]] = []

    for item in items:
        if marketplace == "yahoo_auction" and item["source_type"] != "auction":
            continue
        if marketplace == "yahoo_flea" and item["source_type"] != "flea_market":
            continue

        title_lower = item["title"].lower()
        if normalized_excludes and any(word in title_lower for word in normalized_excludes):
            continue
        if min_price is not None and item["price"] < min_price:
            continue
        if max_price is not None and item["price"] > max_price:
            continue
        filtered.append(item)

    return filtered


def build_price_summary(items: list[dict[str, Any]]) -> dict[str, Any]:
    prices = sorted(item["price"] for item in items if isinstance(item.get("price"), int))
    if not prices:
        return {
            "count": 0,
            "min": None,
            "max": None,
            "average": None,
            "median": None,
            "p25": None,
            "p75": None,
            "trimmed_mean": None,
            "recommended_low": None,
            "recommended_high": None,
        }

    def percentile(values: list[int], p: float) -> int:
        if len(values) == 1:
            return values[0]
        idx = (len(values) - 1) * p
        lower = int(idx)
        upper = min(lower + 1, len(values) - 1)
        if lower == upper:
            return values[lower]
        weight = idx - lower
        return round(values[lower] * (1 - weight) + values[upper] * weight)

    trim_size = max(0, int(len(prices) * 0.1))
    trimmed = prices[trim_size: len(prices) - trim_size] if trim_size else prices[:]
    p25 = percentile(prices, 0.25)
    p75 = percentile(prices, 0.75)

    return {
        "count": len(prices),
        "min": prices[0],
        "max": prices[-1],
        "average": round(sum(prices) / len(prices)),
        "median": round(statistics.median(prices)),
        "p25": p25,
        "p75": p75,
        "trimmed_mean": round(sum(trimmed) / len(trimmed)),
        "recommended_low": p25,
        "recommended_high": p75,
    }


def build_market_comparison(
    mercari_items: list[dict[str, Any]],
    yahoo_items: list[dict[str, Any]],
) -> dict[str, Any]:
    mercari_summary = build_price_summary(mercari_items)
    yahoo_summary = build_price_summary(yahoo_items)

    mercari_median = mercari_summary["median"]
    yahoo_median = yahoo_summary["median"]

    comparison: dict[str, Any] = {
        "mercari_summary": mercari_summary,
        "yahoo_summary": yahoo_summary,
        "median_gap": None,
        "average_gap": None,
        "cheaper_marketplace_by_median": None,
    }

    if mercari_median is not None and yahoo_median is not None:
        comparison["median_gap"] = yahoo_median - mercari_median
        comparison["average_gap"] = yahoo_summary["average"] - mercari_summary["average"]
        comparison["cheaper_marketplace_by_median"] = (
            "mercari" if mercari_median < yahoo_median else "yahoo"
        )

    return comparison


def parse_price_number(raw: str) -> int:
    digits = re.sub(r"[^\d]", "", raw or "")
    return int(digits) if digits else 0


def clean_html_text(value: str) -> str:
    text = re.sub(r"<[^>]+>", "", value or "")
    return _normalize_space(html.unescape(text))


def _extract_yahoo_title(window: str) -> str:
    title_match = _YAHOO_TITLE_PATTERN.search(window)
    if title_match:
        return clean_html_text(title_match.group(1))
    image_alt_match = _YAHOO_IMAGE_ALT_PATTERN.search(window)
    if image_alt_match:
        return clean_html_text(image_alt_match.group(1))
    return ""


def _normalize_space(value: str) -> str:
    return re.sub(r"\s+", " ", value or "").strip()
