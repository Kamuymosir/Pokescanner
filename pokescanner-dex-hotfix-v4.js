(function(){
  const TCGDEX_ENDPOINT='https://api.tcgdex.net/v2';

  function lang(){ try { return typeof currentLang!=='undefined' ? currentLang : 'ja'; } catch { return 'ja'; } }
  function tr(ja,en){ return lang()==='ja' ? ja : en; }
  function escSafe(value){ if(typeof esc==='function') return esc(value); const d=document.createElement('div'); d.textContent=value==null?'':String(value); return d.innerHTML; }

  const ERA_MAP = {
    old:'Vintage Back (1996-2001)', neo:'Neo Series (2000-2001)', e:'e Series (2001-2003)', adv:'ADV/PCG (2003-2006)',
    dpt:'DPt Series (2006-2010)', bw:'BW Series (2010-2013)', xy:'XY Series (2013-2016)', sm:'SM Series (2016-2019)',
    swsh:'Sword & Shield (2019-2023)', sv:'Scarlet & Violet (2023-)'
  };

  function eraLabel(era){ return lang()==='ja' ? era.era : (ERA_MAP[era.id] || era.era); }
  function packDisplayName(pack){ return lang()==='ja' ? (pack.name || pack.code || pack.apiId || '') : (pack.code || (pack.apiId ? String(pack.apiId).toUpperCase() : '') || pack.name || ''); }
  function packMetaText(pack){ const code=String(pack.code||pack.apiId||'').trim(); return lang()==='ja' ? `${code} · ${pack.cards||'?'}枚${pack.note ? ' · '+pack.note : ''}` : `${code} · ${pack.cards||'?'} cards`; }
  function packCountText(n){ return lang()==='ja' ? `${n}パック` : `${n} packs`; }
  function cardsCountText(n,isJaSource){ return lang()==='ja' ? `全${n}枚（日本語版 · TCGDex API · 無料）` : (isJaSource ? `${n} cards (JP list · image fallback active)` : `${n} cards (English · PokemonTCG API · Free)`); }

  function inferAssetBaseFromSetData(setData){
    const candidates = [setData?.logo, setData?.symbol, setData?.serie?.logo, setData?.serie?.symbol].filter(Boolean);
    for(const url of candidates){
      const m = String(url).match(/^(https:\/\/assets\.tcgdex\.net\/[a-z-]+\/.+?)\/(?:logo|symbol)(?:\.[a-z]+)?$/i);
      if(m) return m[1];
    }
    return '';
  }

  function jpAssetImage(card, pack){
    const localIdRaw = String(card?.localId ?? card?.number ?? '').trim();
    if(!localIdRaw) return '';
    const localId = /^\d+$/.test(localIdRaw) ? String(parseInt(localIdRaw,10)) : (localIdRaw.replace(/^0+/,'') || localIdRaw);
    const assetBase = String(pack?._assetBase || '').trim();
    return assetBase ? `${assetBase}/${encodeURIComponent(localId)}` : '';
  }

  function enFallbackImage(card, pack){
    const apiId = String(pack?.apiId || '').trim();
    const localIdRaw = String(card?.localId ?? card?.number ?? '').trim();
    if(!apiId || !localIdRaw) return '';
    const localId = /^\d+$/.test(localIdRaw) ? String(parseInt(localIdRaw,10)) : (localIdRaw.replace(/^0+/,'') || localIdRaw);
    return `https://images.pokemontcg.io/${encodeURIComponent(apiId)}/${encodeURIComponent(localId)}.png`;
  }

  function lowImg(primaryBase, fallbackUrl){
    if(primaryBase) return `${primaryBase}/low.webp`;
    return fallbackUrl || '';
  }
  function highImg(primaryBase, fallbackUrl){
    if(primaryBase) return `${primaryBase}/high.webp`;
    return fallbackUrl || '';
  }

  function imgTagWithFallbacks(src, jpBase, enFallback, alt){
    const low = lowImg(jpBase, enFallback);
    const high = highImg(jpBase, enFallback);
    return `<img src="${src || low}" data-jp-low="${low}" data-jp-high="${high}" data-en-fallback="${enFallback || ''}" alt="${escSafe(alt || '')}" loading="lazy" onerror="(function(img){const jp=img.dataset.jpLow||''; const en=img.dataset.enFallback||''; if(jp && img.src!==jp){img.src=jp; return;} if(en && img.src!==en){img.src=en; return;} img.parentElement.style.background='var(--surface)'; img.style.display='none';})(this)">`;
  }

  async function showCardModalJPPatched(card, pack){
    let fullCard = card || {};
    const effectivePack = pack || card?._pack || null;
    try {
      if(effectivePack?.jpSetId && card?.localId){
        const res = await fetch(`${TCGDEX_ENDPOINT}/ja/sets/${encodeURIComponent(effectivePack.jpSetId)}/${encodeURIComponent(card.localId)}`);
        if(res.ok){
          const data = await res.json();
          if(data && typeof data === 'object') fullCard = { ...data, _pack: effectivePack };
        }
      }
    } catch {}

    const modal = document.getElementById('card-detail-modal');
    const content = document.getElementById('modal-content');
    if(!modal || !content) return;

    const jpBase = fullCard.image || card.image || jpAssetImage(fullCard, effectivePack) || jpAssetImage(card, effectivePack);
    const enFallback = enFallbackImage(fullCard, effectivePack) || enFallbackImage(card, effectivePack);
    const imgUrl = highImg(jpBase, enFallback);
    const imgLow = lowImg(jpBase, enFallback);
    const setName = fullCard.set?.name || effectivePack?.name || '';
    const rarity = fullCard.rarity || card.rarity || '-';
    const hp = fullCard.hp || card.hp || '-';
    const localId = fullCard.localId || card.localId || card.number || '-';

    content.innerHTML = `
      ${imgUrl ? `<img class="modal-img" src="${imgUrl}" alt="${escSafe(fullCard.name || card.name || '')}" style="cursor:zoom-in" onclick="openLightbox('${imgUrl}','${escSafe(fullCard.name || card.name || '')}')" onerror="if(this.dataset.low && this.src!==this.dataset.low){this.src=this.dataset.low}else if(this.dataset.en && this.src!==this.dataset.en){this.src=this.dataset.en}else{this.style.display='none'}" data-low="${imgLow}" data-en="${enFallback || ''}">` : ''}
      <div class="modal-body">
        <div class="modal-title">${escSafe(fullCard.name || card.name || '')}</div>
        <div class="modal-sub">${escSafe(setName)} · #${escSafe(localId)} · ${escSafe(rarity)}</div>
        <div class="modal-info">
          <div class="modal-info-item"><div class="modal-info-label">SET</div><div class="modal-info-value">${escSafe(setName || '-')}</div></div>
          <div class="modal-info-item"><div class="modal-info-label">RARITY</div><div class="modal-info-value">${escSafe(rarity || '-')}</div></div>
          <div class="modal-info-item"><div class="modal-info-label">NUMBER</div><div class="modal-info-value">#${escSafe(localId)}</div></div>
          <div class="modal-info-item"><div class="modal-info-label">HP</div><div class="modal-info-value">${escSafe(hp)}</div></div>
        </div>
      </div>`;
    modal.style.display='flex';
  }

  function patchRenderDexSeries(){
    if(typeof window.renderDexSeries !== 'function' || window.__psDexSeriesV4Patched) return;
    window.renderDexSeries = function patchedRenderDexSeries(filter){
      const container = document.getElementById('dex-panel-series');
      if(!container || typeof SERIES_DATA === 'undefined') return;
      container.innerHTML='';
      const q=String(filter||'').toLowerCase();

      SERIES_DATA.forEach((era)=>{
        const filtered=era.packs.filter((p)=>{
          const hay=[p.name,p.code,p.note,p.apiId,packDisplayName(p),eraLabel(era)].filter(Boolean).join(' ').toLowerCase();
          return !q || hay.includes(q);
        });
        if(!filtered.length) return;

        const group=document.createElement('div');
        group.className='era-group';
        group.innerHTML=`<div class="era-title">${escSafe(era.icon)} ${escSafe(eraLabel(era))} <span class="era-badge">${escSafe(packCountText(filtered.length))}</span><span class="arrow">▼</span></div>`;
        const packsDiv=document.createElement('div');
        packsDiv.className='era-packs';

        filtered.forEach((p)=>{
          const d=document.createElement('div');
          d.className='pack-item';
          d.dataset.setcode=String(p.apiId||p.code||'').toLowerCase();
          d.dataset.setname=packDisplayName(p);
          d.style.flexWrap='wrap';
          const cacheKey=String(p.apiId||p.code||'').toLowerCase();
          const cached=(typeof setImageCache!=='undefined'&&setImageCache)?(setImageCache[cacheKey]||setImageCache[String(p.code||'').toLowerCase()]||setImageCache[String(p.name||'').toLowerCase()]):null;
          const imgHtml=cached?.logo ? `<img class="pack-img" src="${cached.logo}" alt="" loading="lazy" data-full="${cached.logo}" data-caption="${escSafe(packDisplayName(p))}">` : `<div class="pack-icon">${escSafe(p.icon||'📦')}</div>`;
          d.innerHTML=`${imgHtml}<div class="pack-info"><div class="pack-name">${escSafe(packDisplayName(p))}</div><div class="pack-meta">${escSafe(packMetaText(p))}</div></div><div class="pack-date">${escSafe(p.date||'')}</div>`;

          const imgEl=d.querySelector('.pack-img');
          if(imgEl) imgEl.addEventListener('click',(e)=>{ e.stopPropagation(); openLightbox(imgEl.dataset.full,imgEl.dataset.caption); });

          d.addEventListener('click', async (e)=>{
            if(e.target.closest('.pack-img')||e.target.closest('.series-card-chip')) return;
            const existing=d.querySelector('.pack-cards-grid');
            if(existing){ existing.remove(); return; }
            const loadingEl=document.createElement('div');
            loadingEl.className='pack-cards-loading';
            loadingEl.style.width='100%';
            loadingEl.textContent=tr('カード読み込み中...','Loading cards...');
            d.appendChild(loadingEl);
            try {
              let allCards=[];
              let isJaSource=false;
              let packCtx={...p};

              if(lang()==='ja' && p.jpSetId){
                isJaSource=true;
                const cRes=await fetch(`${TCGDEX_ENDPOINT}/ja/sets/${encodeURIComponent(p.jpSetId)}`);
                if(!cRes.ok){ loadingEl.textContent=tr('このセットはAPIに未登録です','Set not found in API'); return; }
                const setData=await cRes.json();
                packCtx={...p,_assetBase:inferAssetBaseFromSetData(setData)};
                allCards=(setData.cards||[]).map((c)=>({ ...c, _fromTcgDex:true, _pack:packCtx, image:c.image || jpAssetImage(c, packCtx) }));
              } else {
                let setId=p.apiId||null;
                if(!setId){
                  const code=p.code||'';
                  let sRes=await fetch(`${TCGAPI}/sets?q=id:${encodeURIComponent(code.toLowerCase())}&select=id,name`);
                  if(sRes.ok){ const sData=await sRes.json(); if(sData.data?.length>0) setId=sData.data[0].id; }
                  if(!setId){
                    sRes=await fetch(`${TCGAPI}/sets?q=name:\"${encodeURIComponent(code)}\"&select=id,name`);
                    if(sRes.ok){ const sData=await sRes.json(); if(sData.data?.length>0) setId=sData.data[0].id; }
                  }
                }
                if(!setId){ loadingEl.textContent=tr('このセットはAPIに未登録です','Set not found in API'); return; }
                let pg=1;
                while(true){
                  loadingEl.textContent=allCards.length>0?`${tr('カード読み込み中...','Loading cards...')} ${allCards.length}`:tr('カード読み込み中...','Loading cards...');
                  const cRes=await fetch(`${TCGAPI}/cards?q=set.id:${setId}&page=${pg}&pageSize=250&orderBy=number&select=id,name,images,set,rarity,number,artist,tcgplayer,cardmarket`);
                  if(!cRes.ok){ loadingEl.textContent='Failed to load'; return; }
                  const cData=await cRes.json();
                  const batch=cData.data||[];
                  allCards=allCards.concat(batch);
                  if(batch.length<250||allCards.length>=(cData.totalCount||999)) break;
                  pg+=1;
                }
              }

              loadingEl.remove();
              if(!allCards.length) return;
              const grid=document.createElement('div');
              grid.className='pack-cards-grid';
              const countLabel=document.createElement('div');
              countLabel.style.cssText='grid-column:1/-1;font-size:10px;color:var(--muted);padding:0 0 4px;text-align:center';
              countLabel.textContent=cardsCountText(allCards.length,isJaSource);
              grid.appendChild(countLabel);

              allCards.forEach((card)=>{
                const item=document.createElement('div');
                item.className='pack-card-item';
                const jpBase = card._fromTcgDex ? (card.image || jpAssetImage(card, packCtx)) : '';
                const enFallback = card._fromTcgDex ? enFallbackImage(card, packCtx) : '';
                const imgSrc = card._fromTcgDex ? lowImg(jpBase, enFallback) : (card.images?.small || '');
                const cardName = card.name || '';
                const cardMeta = card._fromTcgDex ? `#${card.localId || ''} ${card.rarity || ''}`.trim() : `#${card.number || ''} ${card.rarity || ''}`.trim();
                const imgHtml = card._fromTcgDex ? imgTagWithFallbacks(imgSrc, jpBase, enFallback, cardName) : `<img src="${imgSrc}" alt="${escSafe(cardName)}" loading="lazy" onerror="this.parentElement.style.background='var(--surface)';this.style.display='none'">`;
                item.innerHTML = `${imgHtml}<div class="pack-card-label">${escSafe(cardName)}<small>${escSafe(cardMeta)}</small></div>`;
                item.addEventListener('click',(ev)=>{ ev.stopPropagation(); if(card._fromTcgDex) showCardModalJPPatched(card, packCtx); else if(typeof showCardModal==='function') showCardModal(card); });
                grid.appendChild(item);
              });
              d.appendChild(grid);
            } catch(err){
              loadingEl.textContent='Error: '+err.message;
            }
          });
          packsDiv.appendChild(d);
        });

        group.appendChild(packsDiv);
        container.appendChild(group);
        group.querySelector('.era-title')?.addEventListener('click',function(){ this.classList.toggle('collapsed'); packsDiv.classList.toggle('hidden'); });
      });

      if(!container.children.length){ container.innerHTML=`<div class="dex-empty">${escSafe(tr('該当するシリーズが見つかりません','No matching series found'))}</div>`; }
    };
    window.__psDexSeriesV4Patched=true;
  }

  function patchSetLang(){
    if(typeof window.setLang!=='function' || window.__psDexLangV4Patched) return;
    const original=window.setLang;
    window.setLang=function(nextLang){ original(nextLang); try{ const search=document.getElementById('dex-search'); if(typeof window.renderDexSeries==='function') window.renderDexSeries(search?.value||''); }catch{} };
    window.__psDexLangV4Patched=true;
  }

  function patchShowCardModalJP(){ window.showCardModalJP=function(card){ return showCardModalJPPatched(card, card?._pack || null); }; }

  function boot(){ patchRenderDexSeries(); patchSetLang(); patchShowCardModalJP(); const activeSeries=document.getElementById('dex-panel-series'); const search=document.getElementById('dex-search'); if(activeSeries && typeof renderDexSeries==='function') renderDexSeries(search?.value||''); }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',boot,{once:true}); else boot();
})();