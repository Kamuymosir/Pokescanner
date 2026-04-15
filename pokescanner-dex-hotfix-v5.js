(function(){
  function lang(){ try { return typeof currentLang!=='undefined' ? currentLang : 'ja'; } catch { return 'ja'; } }
  function tr(ja,en){ return lang()==='ja' ? ja : en; }
  function escSafe(value){ if(typeof esc==='function') return esc(value); const d=document.createElement('div'); d.textContent=value==null?'':String(value); return d.innerHTML; }

  function installStyles(){
    if(document.getElementById('ps-dex-v5-styles')) return;
    const style=document.createElement('style');
    style.id='ps-dex-v5-styles';
    style.textContent=`
      .ps-jp-noimage{display:flex;align-items:center;justify-content:center;min-height:160px;border:1px dashed rgba(255,255,255,.08);border-radius:14px;background:rgba(255,255,255,.02);color:var(--muted);font-size:11px;line-height:1.6;padding:12px;text-align:center}
      .ps-jp-noimage.large{min-height:420px;border-radius:0}
      .ps-jp-noimage b{display:block;color:var(--text);font-size:12px;margin-bottom:6px}
    `;
    document.head.appendChild(style);
  }

  function patchSetLang(){
    if(typeof window.setLang!=='function' || window.__psDexLangV5Patched) return;
    const original=window.setLang;
    window.setLang=function(nextLang){
      original(nextLang);
      try {
        const search=document.getElementById('dex-search');
        if(typeof window.renderDexSeries==='function') window.renderDexSeries(search?.value||'');
      } catch {}
    };
    window.__psDexLangV5Patched=true;
  }

  function patchRenderDexSeries(){
    if(typeof window.renderDexSeries!=='function' || window.__psDexSeriesV5Wrapped) return;
    const original=window.renderDexSeries;
    window.renderDexSeries=function(filter){
      original(filter);
      if(lang()!=='ja') return;
      const container=document.getElementById('dex-panel-series');
      if(!container) return;

      container.querySelectorAll('.pack-cards-grid').forEach((grid)=>{
        grid.querySelectorAll('.pack-card-item').forEach((item)=>{
          const img=item.querySelector('img');
          if(!img) return;
          const existing=item.querySelector('.ps-jp-noimage');
          if(existing) return;
          img.remove();
          const ph=document.createElement('div');
          ph.className='ps-jp-noimage';
          ph.innerHTML=`<div><b>${escSafe(tr('日本語版画像未対応','JP image unavailable'))}</b>${escSafe(tr('このカードは日本語データのみ表示中です','Data is shown in Japanese, but no JP image source is attached'))}</div>`;
          item.insertBefore(ph,item.firstChild);
        });
      });
    };
    window.__psDexSeriesV5Wrapped=true;
  }

  function patchShowCardModalJP(){
    if(window.__psShowCardModalJPV5Patched) return;
    window.showCardModalJP=function(card){
      const modal=document.getElementById('card-detail-modal');
      const content=document.getElementById('modal-content');
      if(!modal || !content) return;
      const localId=card?.localId || card?.number || '-';
      const name=card?.name || '';
      const rarity=card?.rarity || '-';
      const setName=card?._pack?.name || card?.set?.name || '-';
      const hp=card?.hp || '-';
      content.innerHTML=`
        <div class="ps-jp-noimage large"><div><b>${escSafe(tr('日本語版画像未対応','JP image unavailable'))}</b>${escSafe(tr('英語画像への誤フォールバックを停止しました','Misleading fallback to English artwork has been disabled'))}</div></div>
        <div class="modal-body">
          <div class="modal-title">${escSafe(name)}</div>
          <div class="modal-sub">${escSafe(setName)} · #${escSafe(localId)} · ${escSafe(rarity)}</div>
          <div class="modal-info">
            <div class="modal-info-item"><div class="modal-info-label">SET</div><div class="modal-info-value">${escSafe(setName)}</div></div>
            <div class="modal-info-item"><div class="modal-info-label">RARITY</div><div class="modal-info-value">${escSafe(rarity)}</div></div>
            <div class="modal-info-item"><div class="modal-info-label">NUMBER</div><div class="modal-info-value">#${escSafe(localId)}</div></div>
            <div class="modal-info-item"><div class="modal-info-label">HP</div><div class="modal-info-value">${escSafe(hp)}</div></div>
          </div>
        </div>`;
      modal.style.display='flex';
    };
    window.__psShowCardModalJPV5Patched=true;
  }

  function boot(){
    installStyles();
    patchSetLang();
    patchRenderDexSeries();
    patchShowCardModalJP();
    try {
      const search=document.getElementById('dex-search');
      if(typeof window.renderDexSeries==='function') window.renderDexSeries(search?.value||'');
    } catch {}
  }

  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',boot,{once:true}); else boot();
})();