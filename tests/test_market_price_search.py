import unittest

from market_price_search import (
    apply_item_filters,
    build_market_comparison,
    build_price_summary,
    parse_mercari_search_html,
    parse_yahoo_search_html,
)


MERCARI_SAMPLE = """
<ul>
  <li data-testid="item-cell" class="sample">
    <div>
      <a href="/item/m12345678901">
        <div class="merItemThumbnail" aria-label="PSA10 ピカチュウの画像 12,800円">
          <picture><img src="https://static.mercdn.net/thumb/item/webp/m12345678901_1.jpg" /></picture>
          <div class="overlayContent__a6f874a2">
            <div class="priceContainer__a6f874a2">
              <span class="merPrice priceContainerDefault__a6f874a2">
                <span class="currency__6b270ca7">¥</span>
                <span class="number__6b270ca7">12,800</span>
              </span>
            </div>
          </div>
          <span data-testid="thumbnail-item-name" class="itemName__a6f874a2">PSA10 ピカチュウ</span>
        </div>
      </a>
    </div>
  </li>
  <li data-testid="item-cell" class="sample">
    <div>
      <a href="/item/m12345678902">
        <div class="merItemThumbnail" aria-label="ジャンク ピカチュウの画像 800円">
          <picture><img src="https://static.mercdn.net/thumb/item/webp/m12345678902_1.jpg" /></picture>
          <div class="overlayContent__a6f874a2">
            <div class="priceContainer__a6f874a2">
              <span class="merPrice priceContainerDefault__a6f874a2">
                <span class="currency__6b270ca7">現在 ¥</span>
                <span class="number__6b270ca7">800</span>
              </span>
            </div>
          </div>
          <span data-testid="thumbnail-item-name" class="itemName__a6f874a2">ジャンク ピカチュウ</span>
        </div>
      </a>
    </div>
  </li>
</ul>
"""

YAHOO_SAMPLE = """
<div>
  <a href="https://auctions.yahoo.co.jp/jp/auction/abc123">
    <img src="https://img.yahoo.co.jp/abc123.jpg" alt="PSA10 ピカチュウ 旧裏" />
  </a>
  <p>
    <a href="https://auctions.yahoo.co.jp/jp/auction/abc123" title="PSA10 ピカチュウ 旧裏">PSA10 ピカチュウ 旧裏</a>
  </p>
  <div>
    <span>落札</span><span>15,500<span>円</span></span>
    <span>開始</span><span>10,000<span>円</span></span>
  </div>
  <div>4/9 00:43終了</div>
</div>
<div>
  <a href="https://paypayfleamarket.yahoo.co.jp/item/xyz456">
    <img src="https://img.yahoo.co.jp/xyz456.jpg" alt="ピカチュウ classic" />
  </a>
  <p>
    <a href="https://paypayfleamarket.yahoo.co.jp/item/xyz456" title="ピカチュウ classic">ピカチュウ classic</a>
  </p>
  <div>
    <span>落札</span><span>9,800<span>円</span></span>
  </div>
  <div>4/8 21:11終了</div>
</div>
"""


class MarketPriceSearchTests(unittest.TestCase):
    def test_parse_mercari_search_html(self):
        items = parse_mercari_search_html(MERCARI_SAMPLE, limit=10)

        self.assertEqual(len(items), 2)
        self.assertEqual(items[0]["id"], "m12345678901")
        self.assertEqual(items[0]["title"], "PSA10 ピカチュウ")
        self.assertEqual(items[0]["price"], 12800)
        self.assertEqual(items[0]["source_type"], "fixed_price")
        self.assertEqual(items[1]["source_type"], "auction")

    def test_parse_yahoo_search_html(self):
        items = parse_yahoo_search_html(YAHOO_SAMPLE, limit=10)

        self.assertEqual(len(items), 2)
        self.assertEqual(items[0]["id"], "abc123")
        self.assertEqual(items[0]["price"], 15500)
        self.assertEqual(items[0]["start_price"], 10000)
        self.assertEqual(items[0]["source_type"], "auction")
        self.assertEqual(items[1]["source_type"], "flea_market")
        self.assertEqual(items[1]["end_time"], "4/8 21:11")

    def test_apply_item_filters_and_summary(self):
        items = [
            {"title": "PSA10 ピカチュウ", "price": 10000, "source_type": "auction"},
            {"title": "ジャンク ピカチュウ", "price": 1000, "source_type": "auction"},
            {"title": "ピカチュウ classic", "price": 12000, "source_type": "flea_market"},
        ]

        filtered = apply_item_filters(
            items,
            marketplace="yahoo_auction",
            exclude_keywords=["ジャンク"],
            min_price=5000,
            max_price=11000,
        )

        self.assertEqual(len(filtered), 1)
        self.assertEqual(filtered[0]["title"], "PSA10 ピカチュウ")

        summary = build_price_summary(filtered)
        self.assertEqual(summary["median"], 10000)
        self.assertEqual(summary["recommended_low"], 10000)
        self.assertEqual(summary["recommended_high"], 10000)

    def test_build_market_comparison(self):
        mercari_items = [
            {"price": 9000},
            {"price": 11000},
        ]
        yahoo_items = [
            {"price": 14000},
            {"price": 16000},
        ]

        comparison = build_market_comparison(mercari_items, yahoo_items)
        self.assertEqual(comparison["cheaper_marketplace_by_median"], "mercari")
        self.assertEqual(comparison["median_gap"], 5000)


if __name__ == "__main__":
    unittest.main()
