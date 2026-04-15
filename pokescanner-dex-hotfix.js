(function () {
  const TCGDEX_ENDPOINT = 'https://api.tcgdex.net/v2';

  function lang() {
    try { return typeof currentLang !== 'undefined' ? currentLang : 'ja'; } catch { return 'ja'; }
  }

  function tr(ja, en) {
    return lang() === 'ja' ? ja : en;
  }

  function escSafe(value) {
    if (typeof esc === 'function') return esc(value);
    const div = document.createElement('div');
    div.textContent = value == null ? '' : String(value);
    return div.innerHTML;
  }

  function eraLabel(era) {
    if (lang() === 'ja') return era.era;
    const map = {
      old: 'Vintage Back (1996-2001)',
      neo: 'Neo Series (2000-2001)',
      e: 'e Series (2001-2003)',
      adv: 'ADV/PCG (2003-2006)',
      dpt: 'DPt Series (2006-2010)',
      bw: 'BW Series (2010-2013)',
      xy: 'XY Series (2013-2016)',
      sm: 'SM Series (2016-2019)',
      swsh: 'Sword & Shield (2019-2023)',
      sv: 'Scarlet & Violet (2023-)'
    };
    return map[era.id] || era.era;
  }

  function packDisplayName(pack) {
    if (lang() === 'ja') return pack.name || pack.code || pack.apiId || '';
    const code = String(pack.code || '').trim();
    const apiId = String(pack.apiId || '').trim();
    if (/[A-Za-z]{3,}/.test(code) || code.includes(' ')) return code;
    return code || apiId.toUpperCase() || pack.name || '';
  }

  function packMetaText(pack) {
    const code = String(pack.code || pack.apiId || '').trim();
    if (lang() === 'ja') {
      return `${code} · ${pack.cards || '?'}枚${pack.note ? ' · ' + pack.note : ''}`;
    }
    return `${code} · ${pack.cards || '?'} cards`;
  }

  function packCountText(n) {
    return lang() === 'ja' ? `${n}パック` : `${n} packs`;
  }

  function cardsCountText(n, isJaSource) {
    if (lang() === 'ja') return `全${n}枚（日本語版 · TCGDex API · 無料）`;
    return isJaSource ? `${n} cards (JP list · image fallback active)` : `${n} cards (English · PokemonTCG API · Free)`;
  }

  function chaseTitle() {
    return tr('💰 高額レアカード', '💰 Featured chase cards');
  }

  function deriveFallbackImage(card, pack) {
    const apiId = String(pack?.apiId || '').trim();
    const localIdRaw = String(card?.localId ?? card?.number ?? '').trim();
    if (!apiId || !localIdRaw) return '';
    const localId = /^\d+$/.test(localIdRaw) ? String(parseInt(localIdRaw, 10)) : localIdRaw.replace(/^0+/, '') || localIdRaw;
    return `https://images.pokemontcg.io/${encodeURIComponent(apiId)}/${encodeURIComponent(localId)}.png`;
  }

  async function showCardModalJPPatched(card, pack) {
    let fullCard = card || {};
    try {
      if (pack?.jpSetId && card?.localId) {
        const res = await fetch(`${TCGDEX_ENDPOINT}/ja/sets/${encodeURIComponent(pack.jpSetId)}/${encodeURIComponent(card.localId)}`);
        if (res.ok) {
          const data = await res.json();
          if (data && typeof data === 'object') fullCard = data;
        }
      }
    } catch {}

    const modal = document.getElementById('card-detail-modal');
    const content = document.getElementById('modal-content');
    if (!modal || !content) return;

    const baseImg = fullCard.image || card.image || '';
    const fallbackImg = deriveFallbackImage(fullCard, pack) || deriveFallbackImage(card, pack);
    const imgUrl = baseImg ? `${baseImg}/high.webp` : fallbackImg;
    const imgSmall = baseImg ? `${baseImg}/low.webp` : fallbackImg;
    const setName = fullCard.set?.name || pack?.name || '';
    const rarity = fullCard.rarity || card.rarity || '-';
    const hp = fullCard.hp || card.hp || '-';
    const localId = fullCard.localId || card.localId || card.number || '-';

    content.innerHTML = `
      ${imgUrl ? `<img class="modal-img" src="${imgUrl}" alt="${escSafe(fullCard.name || card.name || '')}" style="cursor:zoom-in" onclick="openLightbox('${imgUrl}','${escSafe(fullCard.name || card.name || '')}')" onerror="if(this.dataset.fallback && this.src!==this.dataset.fallback){this.src=this.dataset.fallback}else if('${imgSmall}'){this.src='${imgSmall}'}else{this.style.display='none'}" data-fallback="${fallbackImg}">` : ''}
      <div class="modal-body">
        <div class="modal-title">${escSafe(fullCard.name || card.name || '')}</div>
        <div class="modal-sub">${escSafe(setName)} · #${escSafe(localId)} · ${escSafe(rarity)}</div>
        <div class="modal-info">
          <div class="modal-info-item"><div class="modal-info-label">SET</div><div class="modal-info-value">${escSafe(setName || '-')}</div></div>
          <div class="modal-info-item"><div class="modal-info-label">RARITY</div><div class="modal-info-value">${escSafe(rarity || '-')}</div></div>
          <div class="modal-info-item"><div class="modal-info-label">NUMBER</div><div class="modal-info-value">#${escSafe(localId)}</div></div>
          <div class="modal-info-item"><div class="modal-info-label">HP</div><div class="modal-info-value">${escSafe(hp)}</div></div>
        </div>
        ${fullCard.category ? `<div style="margin-top:8px;font-size:12px;color:var(--text2)">${tr('カテゴリ', 'Category')}: ${escSafe(fullCard.category)}</div>` : ''}
      </div>
    `;

    modal.style.display = 'flex';
  }

  function patchRenderDexSeries() {
    if (typeof window.renderDexSeries !== 'function' || window.__psDexSeriesPatched) return;

    window.renderDexSeries = function patchedRenderDexSeries(filter) {
      const container = document.getElementById('dex-panel-series');
      if (!container || typeof SERIES_DATA === 'undefined') return;
      container.innerHTML = '';
      const q = String(filter || '').toLowerCase();

      SERIES_DATA.forEach((era) => {
        const filtered = era.packs.filter((p) => {
          const hay = [p.name, p.code, p.note, p.apiId, packDisplayName(p), eraLabel(era)].filter(Boolean).join(' ').toLowerCase();
          return !q || hay.includes(q);
        });
        if (filtered.length === 0) return;

        const group = document.createElement('div');
        group.className = 'era-group';
        group.innerHTML = `<div class="era-title">${escSafe(era.icon)} ${escSafe(eraLabel(era))} <span class="era-badge">${escSafe(packCountText(filtered.length))}</span><span class="arrow">▼</span></div>`;
        const packsDiv = document.createElement('div');
        packsDiv.className = 'era-packs';

        filtered.forEach((p) => {
          const d = document.createElement('div');
          d.className = 'pack-item';
          d.dataset.setcode = String(p.apiId || p.code || '').toLowerCase();
          d.dataset.setname = packDisplayName(p);
          d.style.flexWrap = 'wrap';

          const cacheKey = String(p.apiId || p.code || '').toLowerCase();
          const cached = (typeof setImageCache !== 'undefined' && setImageCache) ? (setImageCache[cacheKey] || setImageCache[String(p.code || '').toLowerCase()]) : null;
          const imgHtml = cached?.logo
            ? `<img class="pack-img" src="${cached.logo}" alt="" loading="lazy" data-full="${cached.logo}" data-caption="${escSafe(packDisplayName(p))}">`
            : `<div class="pack-icon">${escSafe(p.icon || '📦')}</div>`;

          d.innerHTML = `
            ${imgHtml}
            <div class="pack-info">
              <div class="pack-name">${escSafe(packDisplayName(p))}</div>
              <div class="pack-meta">${escSafe(packMetaText(p))}</div>
            </div>
            <div class="pack-date">${escSafe(p.date || '')}</div>
          `;

          const relatedCards = (typeof HIGH_VALUE_CARDS !== 'undefined' ? HIGH_VALUE_CARDS : []).filter((c) => {
            const eraMatch = c.era === era.era.split(' ')[0] || era.id === String(c.era || '').toLowerCase();
            const setMatch = c.set && (p.name.includes(c.set.replace(/（.*）/, '')) || c.set.includes(p.name.replace(/（.*）/, '')));
            return setMatch || (eraMatch && p.name.includes(c.set?.split('（')[0] || '___NOMATCH'));
          });

          if (relatedCards.length > 0) {
            const cardsSection = document.createElement('div');
            cardsSection.className = 'series-cards-section';
            cardsSection.style.width = '100%';
            cardsSection.innerHTML = `<div class="series-cards-title">${escSafe(chaseTitle())}</div>` +
              relatedCards.map((c) => {
                const price = c.psa10 ? 'PSA10 ¥' + Number(c.psa10).toLocaleString() : c.raw;
                return `<span class="series-card-chip" data-cardname="${escSafe(c.name)}">${escSafe(c.name)} <span class="chip-price">${escSafe(price)}</span></span>`;
              }).join('');
            d.appendChild(cardsSection);
            cardsSection.querySelectorAll('.series-card-chip').forEach((chip) => {
              chip.addEventListener('click', (e) => {
                e.stopPropagation();
                document.querySelectorAll('.dex-subtab').forEach((t) => t.classList.remove('active'));
                document.querySelectorAll('.dex-panel').forEach((panel) => panel.classList.remove('active'));
                document.querySelector('.dex-subtab[data-panel="highvalue"]')?.classList.add('active');
                document.getElementById('dex-panel-highvalue')?.classList.add('active');
                const search = document.getElementById('dex-search');
                if (search) search.value = chip.dataset.cardname;
                if (typeof renderDexHighValue === 'function') renderDexHighValue(chip.dataset.cardname);
              });
            });
          }

          const imgEl = d.querySelector('.pack-img');
          if (imgEl) imgEl.addEventListener('click', (e) => { e.stopPropagation(); openLightbox(imgEl.dataset.full, imgEl.dataset.caption); });

          d.addEventListener('click', async (e) => {
            if (e.target.closest('.pack-img') || e.target.closest('.series-card-chip')) return;
            const existing = d.querySelector('.pack-cards-grid');
            if (existing) { existing.remove(); return; }

            const loadingEl = document.createElement('div');
            loadingEl.className = 'pack-cards-loading';
            loadingEl.style.width = '100%';
            loadingEl.textContent = tr('カード読み込み中...', 'Loading cards...');
            d.appendChild(loadingEl);

            try {
              let allCards = [];
              let isJaSource = false;

              if (lang() === 'ja' && p.jpSetId) {
                isJaSource = true;
                const cRes = await fetch(`${TCGDEX_ENDPOINT}/ja/sets/${encodeURIComponent(p.jpSetId)}`);
                if (!cRes.ok) { loadingEl.textContent = tr('このセットはAPIに未登録です', 'Set not found in API'); return; }
                const setData = await cRes.json();
                allCards = (setData.cards || []).map((c) => ({ ...c, _fromTcgDex: true, _pack: p }));
              } else {
                let setId = p.apiId || null;
                if (!setId) {
                  const code = p.code || '';
                  let sRes = await fetch(`${TCGAPI}/sets?q=id:${encodeURIComponent(code.toLowerCase())}&select=id,name`);
                  if (sRes.ok) { const sData = await sRes.json(); if (sData.data?.length > 0) setId = sData.data[0].id; }
                  if (!setId) {
                    sRes = await fetch(`${TCGAPI}/sets?q=name:\"${encodeURIComponent(code)}\"&select=id,name`);
                    if (sRes.ok) { const sData = await sRes.json(); if (sData.data?.length > 0) setId = sData.data[0].id; }
                  }
                }
                if (!setId) { loadingEl.textContent = tr('このセットはAPIに未登録です', 'Set not found in API'); return; }
                let pg = 1;
                while (true) {
                  loadingEl.textContent = allCards.length > 0 ? `${tr('カード読み込み中...', 'Loading cards...')} ${allCards.length}` : tr('カード読み込み中...', 'Loading cards...');
                  const cRes = await fetch(`${TCGAPI}/cards?q=set.id:${setId}&page=${pg}&pageSize=250&orderBy=number&select=id,name,images,set,rarity,number,artist,tcgplayer,cardmarket`);
                  if (!cRes.ok) { loadingEl.textContent = 'Failed to load'; return; }
                  const cData = await cRes.json();
                  const batch = cData.data || [];
                  allCards = allCards.concat(batch);
                  if (batch.length < 250 || allCards.length >= (cData.totalCount || 999)) break;
                  pg += 1;
                }
              }

              loadingEl.remove();
              const cards = allCards || [];
              if (cards.length === 0) return;

              const grid = document.createElement('div');
              grid.className = 'pack-cards-grid';
              const countLabel = document.createElement('div');
              countLabel.style.cssText = 'grid-column:1/-1;font-size:10px;color:var(--muted);padding:0 0 4px;text-align:center';
              countLabel.textContent = cardsCountText(cards.length, isJaSource);
              grid.appendChild(countLabel);

              cards.forEach((card) => {
                const item = document.createElement('div');
                item.className = 'pack-card-item';

                let imgSrc = '';
                let fallbackSrc = '';
                let cardName = '';
                let cardMeta = '';

                if (card._fromTcgDex) {
                  imgSrc = card.image ? `${card.image}/low.webp` : '';
                  fallbackSrc = deriveFallbackImage(card, p);
                  cardName = card.name || '';
                  cardMeta = `#${card.localId || ''} ${card.rarity || ''}`.trim();
                } else {
                  imgSrc = card.images?.small || '';
                  cardName = card.name || '';
                  cardMeta = `#${card.number || ''} ${card.rarity || ''}`.trim();
                }

                item.innerHTML = `<img src="${imgSrc || fallbackSrc}" data-fallback="${fallbackSrc}" alt="${escSafe(cardName)}" loading="lazy" onerror="if(this.dataset.fallback && this.src !== this.dataset.fallback){this.src=this.dataset.fallback}else{this.parentElement.style.background='var(--surface)';this.style.display='none'}"><div class="pack-card-label">${escSafe(cardName)}<small>${escSafe(cardMeta)}</small></div>`;
                item.addEventListener('click', (ev) => {
                  ev.stopPropagation();
                  if (card._fromTcgDex) showCardModalJPPatched(card, p);
                  else if (typeof showCardModal === 'function') showCardModal(card);
                });
                grid.appendChild(item);
              });

              d.appendChild(grid);
            } catch (err) {
              loadingEl.textContent = 'Error: ' + err.message;
            }
          });

          packsDiv.appendChild(d);
        });

        group.appendChild(packsDiv);
        container.appendChild(group);

        group.querySelector('.era-title')?.addEventListener('click', function () {
          this.classList.toggle('collapsed');
          packsDiv.classList.toggle('hidden');
        });
      });

      if (container.children.length === 0) {
        container.innerHTML = `<div class="dex-empty">${escSafe(tr('該当するシリーズが見つかりません', 'No matching series found'))}</div>`;
      }
    };

    window.__psDexSeriesPatched = true;
  }

  function boot() {
    patchRenderDexSeries();

    const activeSeries = document.getElementById('dex-panel-series');
    const search = document.getElementById('dex-search');
    if (activeSeries && typeof renderDexSeries === 'function') {
      renderDexSeries(search?.value || '');
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot, { once: true });
  } else {
    boot();
  }
})();
