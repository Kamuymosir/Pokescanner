(function installDexPatchV8(){
  if(window.__psDexPatchV8Installed) return;
  window.__psDexPatchV8Installed = true;

  function textOf(sel){ return (document.querySelector(sel)?.textContent || '').trim(); }
  function placeholderOf(sel){ return document.querySelector(sel)?.getAttribute('placeholder') || ''; }
  function hasJP(s){ return /[ぁ-んァ-ヶ一-龠]/.test(String(s || '')); }

  function detectLang(){
    const active = document.querySelector('.lang-btn.active');
    const activeText = (active?.textContent || '').trim();
    const ph = placeholderOf('#dex-search');
    const visibleDexText = textOf('#dex-page') || textOf('#tab-dex') || textOf('#dex-panel-series');

    if(activeText.includes('🇯🇵') || activeText.toLowerCase()==='ja' || activeText.includes('日')) return 'ja';
    if(activeText.includes('🌍') || activeText.toLowerCase()==='en' || activeText.includes('英')) return 'en';
    if(hasJP(ph)) return 'ja';
    if(/Search series or card name/i.test(ph)) return 'en';
    if(hasJP(visibleDexText) && !/Series List|Rarity Table|High-Value/i.test(visibleDexText)) return 'ja';
    try{ if(typeof currentLang !== 'undefined' && currentLang) return currentLang; }catch{}
    return 'ja';
  }

  function isJP(){ return detectLang() === 'ja'; }

  function escSafe(value){
    if(typeof esc === 'function') return esc(value);
    const div = document.createElement('div');
    div.textContent = value == null ? '' : String(value);
    return div.innerHTML;
  }

  function installStyles(){
    if(document.getElementById('ps-dex-patch-v8-style')) return;
    const style = document.createElement('style');
    style.id = 'ps-dex-patch-v8-style';
    style.textContent = `
      .ps-jp-noimage{display:flex!important;align-items:center;justify-content:center;min-height:160px;width:100%;height:100%;border-radius:0;background:rgba(0,0,0,.08);border:2px dashed rgba(26,32,0,.35);color:var(--muted,#6b7040);text-align:center;line-height:1.6;font-size:11px;padding:10px;}
      .ps-jp-noimage.large{min-height:420px;border-radius:0;background:#000;color:#94a3b8;border:none;}
      .ps-jp-noimage b{display:block;color:var(--text,#1a2000);font-size:12px;margin-bottom:6px;}
      .ps-jp-noimage.large b{color:#fff;}
      html.ps-jp-mode #dex-panel-series .pack-cards-grid .pack-card-item > img,
      html.ps-jp-mode #dex-panel-series .pack-cards-grid .pack-card-item img{display:none!important;visibility:hidden!important;opacity:0!important;width:0!important;height:0!important;}
    `;
    document.head.appendChild(style);
  }

  function setHtmlLangClass(){ document.documentElement.classList.toggle('ps-jp-mode', isJP()); }

  function jpPlaceholderHTML(){
    return `<div class="ps-jp-noimage"><div><b>日本語版画像未対応</b>データのみ表示中<br>英語画像への誤フォールバック停止</div></div>`;
  }
  function jpModalPlaceholderHTML(){
    return `<div class="ps-jp-noimage large"><div><b>日本語版画像未対応</b>英語画像への誤フォールバックは停止しています</div></div>`;
  }

  function isLikelyJPCardItem(item){
    if(!item) return false;
    if(!item.closest('#dex-panel-series')) return false;
    if(!item.closest('.pack-cards-grid')) return false;
    return true;
  }

  function normalizeJPCardItem(item){
    if(!isJP()) return;
    if(!isLikelyJPCardItem(item)) return;
    item.querySelectorAll('img').forEach((img)=>img.remove());
    if(!item.querySelector('.ps-jp-noimage')) item.insertAdjacentHTML('afterbegin', jpPlaceholderHTML());
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

  let normalizeTimer = null;
  function scheduleNormalize(){
    clearTimeout(normalizeTimer);
    const run = ()=>{ setHtmlLangClass(); if(isJP()) normalizeJPImages(); else removeJPPlaceholdersForEN(); };
    requestAnimationFrame(run);
    normalizeTimer = setTimeout(run,80);
    setTimeout(run,300);
    setTimeout(run,900);
  }

  function rerenderAllDexPanels(){
    const q = document.getElementById('dex-search')?.value || '';
    if(typeof window.renderDexSeries === 'function') window.renderDexSeries(q);
    if(typeof window.renderDexRarity === 'function') window.renderDexRarity();
    if(typeof window.renderDexHighValue === 'function') window.renderDexHighValue(q);
    scheduleNormalize();
  }

  function patchRenderDexSeries(){
    if(typeof window.renderDexSeries !== 'function' || window.__psDexSeriesPatchedV8) return;
    const original = window.renderDexSeries;
    window.renderDexSeries = function patchedRenderDexSeries(){ const result = original.apply(this, arguments); scheduleNormalize(); return result; };
    window.__psDexSeriesPatchedV8 = true;
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
      content.innerHTML = `${jpModalPlaceholderHTML()}<div class="modal-body"><div class="modal-title">${escSafe(name)}</div><div class="modal-sub">${escSafe(setName)} · #${escSafe(localId)} · ${escSafe(rarity)}</div><div class="modal-info"><div class="modal-info-item"><div class="modal-info-label">SET</div><div class="modal-info-value">${escSafe(setName)}</div></div><div class="modal-info-item"><div class="modal-info-label">RARITY</div><div class="modal-info-value">${escSafe(rarity)}</div></div><div class="modal-info-item"><div class="modal-info-label">NUMBER</div><div class="modal-info-value">#${escSafe(localId)}</div></div><div class="modal-info-item"><div class="modal-info-label">HP</div><div class="modal-info-value">${escSafe(hp)}</div></div></div></div>`;
      modal.style.display = 'flex';
    };
  }

  function patchLangFunctions(){
    if(typeof window.applyLangUI === 'function' && !window.__psApplyLangUIPatchedV8){
      const originalApply = window.applyLangUI;
      window.applyLangUI = function patchedApplyLangUI(){ const result = originalApply.apply(this, arguments); rerenderAllDexPanels(); return result; };
      window.__psApplyLangUIPatchedV8 = true;
    }
    if(typeof window.setLang === 'function' && !window.__psSetLangPatchedV8){
      const originalSet = window.setLang;
      window.setLang = function patchedSetLang(){ const result = originalSet.apply(this, arguments); rerenderAllDexPanels(); return result; };
      window.__psSetLangPatchedV8 = true;
    }
  }

  function installObserver(){
    if(window.__psDexPatchV8Observer) return;
    const obs = new MutationObserver((mutations)=>{
      let hit = false;
      for(const m of mutations){
        for(const n of m.addedNodes){
          if(n.nodeType !== 1) continue;
          if(n.matches?.('#dex-panel-series .pack-cards-grid .pack-card-item')){ normalizeJPCardItem(n); hit = true; }
          if(n.matches?.('#dex-panel-series .pack-cards-grid .pack-card-item img')){ normalizeJPCardItem(n.closest('.pack-card-item')); hit = true; }
          n.querySelectorAll?.('#dex-panel-series .pack-cards-grid .pack-card-item').forEach((item)=>{ normalizeJPCardItem(item); hit = true; });
          n.querySelectorAll?.('#dex-panel-series .pack-cards-grid .pack-card-item img').forEach((img)=>{ normalizeJPCardItem(img.closest('.pack-card-item')); hit = true; });
        }
      }
      if(hit) scheduleNormalize();
    });
    obs.observe(document.documentElement,{childList:true,subtree:true});
    window.__psDexPatchV8Observer = obs;
  }

  function installClickCapture(){
    if(window.__psDexPatchV8ClickCapture) return;
    document.addEventListener('click',()=>setTimeout(scheduleNormalize,30),true);
    window.__psDexPatchV8ClickCapture = true;
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
    scheduleNormalize();
  }

  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded',boot,{once:true}); else boot();
})();