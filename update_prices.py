#!/usr/bin/env python3
"""
PokeScanner Pro - 自動相場更新スクリプト
PokemonTCG API（無料・キー不要）から英語版市場価格を取得し prices.json を更新する。
GitHub Actions で毎日自動実行。

将来的に PokeTrace API キーを追加すれば eBay 落札データも取得可能。
"""

import json
import urllib.request
import urllib.parse
import os
import time
from datetime import datetime, timezone

TCGAPI = "https://api.pokemontcg.io/v2"
POKETRACE_API = "https://api.poketrace.com/v1"
POKETRACE_KEY = os.environ.get("POKETRACE_API_KEY", "")
USD_TO_JPY = 155

CARDS_TO_TRACK = [
    {"name": "リザードン", "nameEn": "Charizard", "set": "基本セット", "era": "旧裏面",
     "tcgQuery": 'name:"Charizard" set.id:base1 rarity:"Rare Holo"'},
    {"name": "ガルーラ", "nameEn": "Kangaskhan", "set": "ジャングル", "era": "旧裏面",
     "tcgQuery": 'name:"Kangaskhan" set.id:base2 rarity:"Rare Holo"'},
    {"name": "ブラッキー", "nameEn": "Umbreon", "set": "neo discovery", "era": "Neo",
     "tcgQuery": 'name:"Umbreon" set.id:neo2 rarity:"Rare Holo"'},
    {"name": "ルギア", "nameEn": "Lugia", "set": "neo genesis", "era": "Neo",
     "tcgQuery": 'name:"Lugia" set.id:neo1 rarity:"Rare Holo"'},
    {"name": "ミュウツー", "nameEn": "Mewtwo", "set": "基本セット", "era": "旧裏面",
     "tcgQuery": 'name:"Mewtwo" set.id:base1 rarity:"Rare Holo"'},
    {"name": "カイリュー", "nameEn": "Dragonite", "set": "化石の秘密", "era": "旧裏面",
     "tcgQuery": 'name:"Dragonite" set.id:base3 rarity:"Rare Holo"'},
    {"name": "ギャラドス", "nameEn": "Gyarados", "set": "基本セット", "era": "旧裏面",
     "tcgQuery": 'name:"Gyarados" set.id:base1 rarity:"Rare Holo"'},
    {"name": "ゲンガー", "nameEn": "Gengar", "set": "化石の秘密", "era": "旧裏面",
     "tcgQuery": 'name:"Gengar" set.id:base3 rarity:"Rare Holo"'},
    {"name": "エーフィ", "nameEn": "Espeon", "set": "neo discovery", "era": "Neo",
     "tcgQuery": 'name:"Espeon" set.id:neo2 rarity:"Rare Holo"'},
    {"name": "ミュウ", "nameEn": "Mew", "set": "化石の秘密", "era": "旧裏面",
     "tcgQuery": 'name:"Mew" set.id:base3'},
    {"name": "ブラッキーVMAX SA", "nameEn": "Umbreon VMAX", "set": "イーブイヒーローズ", "era": "SWSH",
     "tcgQuery": 'name:"Umbreon VMAX" set.id:swsh7 rarity:"Secret Rare"'},
    {"name": "リザードンex SAR", "nameEn": "Charizard ex", "set": "黒炎の支配者", "era": "SV",
     "tcgQuery": 'name:"Charizard ex" set.id:sv3 rarity:"Special Illustration Rare"'},
    {"name": "ナンジャモ SR", "nameEn": "Iono", "set": "クレイバースト", "era": "SV",
     "tcgQuery": 'name:"Iono" rarity:"Special Illustration Rare"'},
    {"name": "リーリエ SR", "nameEn": "Lillie", "set": "コレクションムーン", "era": "SM",
     "tcgQuery": 'name:"Lillie" set.id:sm1 rarity:"Ultra Rare"'},
    {"name": "マリィ SR", "nameEn": "Marnie", "set": "シールド", "era": "SWSH",
     "tcgQuery": 'name:"Marnie" rarity:"Ultra Rare" set.series:Sword'},
    {"name": "アセロラの予感 SR", "nameEn": "Acerola", "set": "VMAXクライマックス", "era": "SWSH",
     "tcgQuery": 'name:"Acerola" set.series:Sword'},
    {"name": "光るギャラドス", "nameEn": "Shining Gyarados", "set": "めざめる伝説", "era": "Neo",
     "tcgQuery": 'name:"Shining Gyarados" set.id:neo3'},
    {"name": "ピカチュウ（コロコロプロモ）", "nameEn": "Pikachu", "set": "コロコロコミック付録", "era": "旧裏面",
     "tcgQuery": 'name:"Pikachu" set.id:basep'},
]


def fetch_json(url, headers=None):
    h = {"User-Agent": "PokeScanner-PriceUpdater/1.0"}
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.load(r)
    except Exception as e:
        print(f"  Error: {e}")
        return None


def get_tcg_price(query):
    encoded = urllib.parse.quote(query)
    url = f"{TCGAPI}/cards?q={encoded}&pageSize=5&orderBy=-cardmarket.prices.averageSellPrice&select=id,name,tcgplayer,cardmarket,set,rarity"
    data = fetch_json(url)
    if not data or not data.get("data"):
        return {}

    prices = {}
    for card in data["data"]:
        tcg = card.get("tcgplayer", {}).get("prices", {})
        cm = card.get("cardmarket", {}).get("prices", {})

        for variant, p in tcg.items():
            if p.get("market"):
                usd = p["market"]
                prices["tcgplayer_usd"] = round(usd, 2)
                prices["tcgplayer_jpy"] = round(usd * USD_TO_JPY)
                break

        if cm.get("averageSellPrice"):
            eur = cm["averageSellPrice"]
            prices["cardmarket_eur"] = round(eur, 2)
            prices["cardmarket_jpy"] = round(eur * (USD_TO_JPY * 1.08))
        if cm.get("trendPrice"):
            prices["cardmarket_trend_eur"] = round(cm["trendPrice"], 2)
            prices["cardmarket_trend_jpy"] = round(cm["trendPrice"] * (USD_TO_JPY * 1.08))

        if prices:
            break

    return prices


def get_poketrace_price(query):
    if not POKETRACE_KEY:
        return {}
    url = f"{POKETRACE_API}/cards/search?q={urllib.parse.quote(query)}"
    data = fetch_json(url, headers={"X-API-Key": POKETRACE_KEY})
    if not data or not data.get("data"):
        return {}
    card = data["data"][0]
    prices = {}
    ebay = card.get("ebay", {})
    if ebay.get("average"):
        prices["ebay_avg"] = round(ebay["average"] * USD_TO_JPY)
    if ebay.get("lastSold"):
        prices["ebay_last_sold"] = round(ebay["lastSold"] * USD_TO_JPY)
    return prices


def main():
    print(f"PokeScanner Price Updater - {datetime.now(timezone.utc).isoformat()}")
    print(f"PokeTrace API key: {'SET' if POKETRACE_KEY else 'NOT SET (eBay data skipped)'}")
    print(f"USD/JPY rate: {USD_TO_JPY}")
    print(f"Cards to track: {len(CARDS_TO_TRACK)}")
    print()

    existing = {}
    if os.path.exists("prices.json"):
        try:
            with open("prices.json", "r", encoding="utf-8") as f:
                existing_data = json.load(f)
                for c in existing_data.get("cards", []):
                    existing[c["name"]] = c
        except Exception:
            pass

    results = []
    for i, card in enumerate(CARDS_TO_TRACK):
        print(f"[{i+1}/{len(CARDS_TO_TRACK)}] {card['name']} ({card['nameEn']})...")

        prices = {}

        prev = existing.get(card["name"], {}).get("prices", {})
        if prev.get("snkrdunk"):
            prices["snkrdunk"] = prev["snkrdunk"]
        if prev.get("mercari_avg"):
            prices["mercari_avg"] = prev["mercari_avg"]

        tcg_prices = get_tcg_price(card["tcgQuery"])
        prices.update(tcg_prices)

        if POKETRACE_KEY:
            pt_prices = get_poketrace_price(card["nameEn"])
            prices.update(pt_prices)

        prev_psa = existing.get(card["name"], {}).get("psa", {})

        entry = {
            "name": card["name"],
            "nameEn": card["nameEn"],
            "set": card["set"],
            "era": card.get("era", ""),
            "prices": {k: v for k, v in prices.items() if v is not None},
            "psa": prev_psa
        }
        results.append(entry)
        print(f"  Prices: {json.dumps(prices, ensure_ascii=False)}")

        time.sleep(0.5)

    output = {
        "updated": datetime.now(timezone.utc).isoformat(),
        "source": "PokemonTCG API + PokeTrace (if key set)",
        "usd_jpy_rate": USD_TO_JPY,
        "cards": results
    }

    with open("prices.json", "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\nDone! Updated {len(results)} cards in prices.json")


if __name__ == "__main__":
    main()
