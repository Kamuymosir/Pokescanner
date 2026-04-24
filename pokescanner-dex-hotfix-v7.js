(function installDexPatchV7(){
  if(window.__psDexPatchV7Installed) return;
  window.__psDexPatchV7Installed = true;

  function detectLang(){
    try{
      if(typeof currentLang !== 'undefined' && currentLang) return currentLang;
    }catch{}
    const active = document.querySelector('.lang-btn.active');
    const txt = (active && active.textContent || '').trim();
    if(txt.includes('🇯🇵') || txt.toLowerCase()==='ja' || txt.includes('日')) return 'ja';
    if(txt.includes('🌍') || txt.toLowerCase()==='en' || txt.includes('英')) return 'en';
    const ph = document.getElementById('dex-search')?.getAttribute('placeholder') || '';
    if(/[ぁ-んァ-ヶ一-龠]/.test(ph)) return 'ja';
    return 'en';
  }

  function isJP(){ return detectLang() === 'ja'; }

  function escSafe(value){
    if(typeof esc === 'function') return esc(value);
    const div = document.createElement('div');
    div.textContent = value == null ? '' : String(value);
    return div.innerHTML;
  }

  function installStyles(){
    if(document.getElementById('ps-dex-patch-v7-style')) return;
    const style = document.createElement('style');
    style.id = 'ps-dex-patch-v7-style';
    style.textContent = `
      .ps-jp-noimage{display:flex;align-items:center;justify-content:center;min-height:160px;width:100%;height:100%;border-radius:0;background:rgba(0,0,0,.08);border:2px dashed rgba(26,32,0,.35);color:var(--muted,#6b7040);text-align:center;line-height:1.6;font-size:11px;padding:10px;}
      .ps-jp-noimage.large{min-height:420px;border-radius:0;background:#000;color:#94a3b8;border:none;}
      .ps-jp-noimage b{display:block;color:var(--text,#1a2000);font-size:12px;margin-bottom:6px;}
      .ps-jp-noimage.large b{color:#fff;}
      html.ps-jp-mode #dex-panel-series .pack-cards-grid .pack-card-item > img{display:none!important;visibility:hidden!important;}
      html.ps-jp-mode #dex-panel-series .pack-cards-grid .pack-card-item img{display:none!important;visibility:hidden!important;}
    `;
    document.head.appendChild(style);
  }

  function setHtmlLangClass(){
    document.documentElement.classList.toggle('ps-jp-mode', isJP());
  }

  function jpPlaceholderHTML(){
    return `<div class="ps-jp-noimage"><div><b>日本語版画像未対応</b>データのみ表示中<br>英語画像への誤フォールバック停止</div></div>`;
  }

  function jpModalPlaceholderHTML(){
    return `<div class="ps-jp-noimage large"><div><b>日本語版画像未対応</b>英語画像への誤フォールバックは停止しています</div></div>`;
  }

  function normalizeJPCardItem(item){
    if(!item || !isJP()) return;
    if(!item.closest('#dex-panel-series')) return;
    if(!item.closest('.pack-cards-grid')) return;

    item.querySelectorAll('img').forEach((img)=>img.remove());
    if(!item.querySelector('.ps-jp-noimage')){
      item.insertAdjacentHTML('afterbegin', jpPlaceholderHTML());
    }
    item.dataset.psJpImageDisabled = '1';
  }

  function normalizeJPImages(){
    setHtmlLangClass();
    if(!isJP()) return;
    document.querySelectorAll('#dex-panel-series .pack-cards-grid .pack-card-item').forEach(normalizeJPCardItem);
  }

  function removeJPPlaceholdersForEN(){
    setHtmlLangClass();
    if(isJP()) return;
    document.querySelectorAll('#dex-panel-series .pack-card-item[data-ps-jp-image-disabled="1"]').forEach((item)=>{
      delete item.dataset.psJpImageDisabled;
      item.querySelectorAll('.ps-jp-noimage').forEach((n)=>n.remove());
    });
  }

  function rerenderAllDexPanels(){
    const q = document.getElementById('dex-search')?.value || '';
    if(typeof window.renderDexSeries === 'function') window.renderDexSeries(q);
    if(typeof window.renderDexRarity === 'function') window.renderDexRarity();
    if(typeof window.renderDexHighValue === 'function') window.renderDexHighValue(q);
    scheduleNormalize();
  }

  let normalizeTimer = null;
  function scheduleNormalize(){
    clearTimeout(normalizeTimer);
    requestAnimationFrame(()=>{
      setHtmlLangClass();
      if(isJP()) normalizeJPImages();
      else removeJPPlaceholdersForEN();
    });
    normalizeTimer = setTimeout(()=>{
      setHtmlLangClass();
      if(isJP()) normalizeJPImages();
      else removeJPPlaceholdersForEN();
    },250);
  }

  function patchRenderDexSeries(){
    if(typeof window.renderDexSeries !== 'function' || window.__psDexSeriesPatchedV7) return;
    const original = window.renderDexSeries;
    window.renderDexSeries = function patchedRenderDexSeries(){
      const result = original.apply(this, arguments);
      scheduleNormalize();
      return result;
    };
    window.__psDexSeriesPatchedV7 = true;
  }

  function patchShowCardModalJP(){
    window.showCardModalJP = function patchedShowCardModalJP(card){
      const modal = document.getElementById('card-detail-modal');
      const content = document.getElementById('modal-content');
      if(!modal || !content) return;
      const setName = card?._pack?.name || card?.set?.name || '-';
      const localId = card?.localId || card?.number || '-';
      const rarity = card?.rarity || '-';
      const hp = card?.hp || '-';
      const name = card?.name || '';
      content.innerHTML = `
        ${jpModalPlaceholderHTML()}
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
      modal.style.display = 'flex';
    };
  }

  function patchLangFunctions(){
    if(typeof window.applyLangUI === 'function' && !window.__psApplyLangUIPatchedV7){
      const originalApply = window.applyLangUI;
      window.applyLangUI = function patchedApplyLangUI(){
        const result = originalApply.apply(this, arguments);
        rerenderAllDexPanels();
        return result;
      };
      window.__psApplyLangUIPatchedV7 = true;
    }

    if(typeof window.setLang === 'function' && !window.__psSetLangPatchedV7){
      const originalSet = window.setLang;
      window.setLang = function patchedSetLang(){
        const result = originalSet.apply(this, arguments);
        rerenderAllDexPanels();
        return result;
      };
      window.__psSetLangPatchedV7 = true;
    }
  }

  function installObserver(){
    if(window.__psDexPatchV7Observer) return;
    const obs = new MutationObserver((mutations)=>{
      let touched = false;
      for(const m of mutations){
        for(const n of m.addedNodes){
          if(n.nodeType !== 1) continue;
          if(n.matches?.('#dex-panel-series .pack-cards-grid .pack-card-item')){ normalizeJPCardItem(n); touched = true; }
          if(n.matches?.('#dex-panel-series .pack-cards-grid .pack-card-item img')){ normalizeJPCardItem(n.closest('.pack-card-item')); touched = true; }
          n.querySelectorAll?.('#dex-panel-series .pack-cards-grid .pack-card-item').forEach((item)=>{ normalizeJPCardItem(item); touched = true; });
          n.querySelectorAll?.('#dex-panel-series .pack-cards-grid .pack-card-item img').forEach((img)=>{ normalizeJPCardItem(img.closest('.pack-card-item')); touched = true; });
        }
      }
      if(touched) scheduleNormalize();
    });
    obs.observe(document.body,{childList:true,subtree:true});
    window.__psDexPatchV7Observer = obs;
  }

  function installClickCapture(){
    if(window.__psDexPatchV7ClickCapture) return;
    document.addEventListener('click',()=>setTimeout(scheduleNormalize,50),true);
    window.__psDexPatchV7ClickCapture = true;
  }

  function boot(){
    installStyles();
    setHtmlLangClass();
    patchRenderDexSeries();
    patchShowCardModalJP();
    patchLangFunctions();
    installObserver();
    installClickCapture();
    rerenderAllDexPanels();
    setTimeout(scheduleNormalize,500);
    setTimeout(scheduleNormalize,1200);
  }

  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded',boot,{once:true});
  else boot();
})();