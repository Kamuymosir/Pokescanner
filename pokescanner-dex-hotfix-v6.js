(function installDexPatchV6(){
  if(window.__psDexPatchV6Installed) return;
  window.__psDexPatchV6Installed = true;

  function getLang(){
    try { return typeof currentLang !== 'undefined' ? currentLang : 'ja'; }
    catch { return 'ja'; }
  }

  function escSafe(value){
    if(typeof esc === 'function') return esc(value);
    const div = document.createElement('div');
    div.textContent = value == null ? '' : String(value);
    return div.innerHTML;
  }

  function installStyles(){
    if(document.getElementById('ps-dex-patch-v6-style')) return;
    const style = document.createElement('style');
    style.id = 'ps-dex-patch-v6-style';
    style.textContent = `
      .ps-jp-noimage{display:flex;align-items:center;justify-content:center;min-height:160px;width:100%;height:100%;border-radius:12px;background:var(--surface2,rgba(255,255,255,.03));border:1px dashed rgba(255,255,255,.10);color:var(--muted,#8ea0c0);text-align:center;line-height:1.6;font-size:11px;padding:10px;}
      .ps-jp-noimage.large{min-height:420px;border-radius:0;background:#000;}
      .ps-jp-noimage b{display:block;color:var(--text,#fff);font-size:12px;margin-bottom:6px;}
    `;
    document.head.appendChild(style);
  }

  function jpNoImageHTML(isLarge){
    return `<div class="ps-jp-noimage${isLarge ? ' large' : ''}"><div><b>日本語版画像未対応</b>英語画像への誤フォールバックは停止中</div></div>`;
  }

  function isInSeriesJPGrid(img){
    if(getLang() !== 'ja') return false;
    const item = img.closest('.pack-card-item');
    if(!item) return false;
    const grid = item.closest('.pack-cards-grid');
    if(!grid) return false;
    return true;
  }

  function disableOneJPImage(img){
    if(!(img instanceof HTMLImageElement)) return;
    if(!isInSeriesJPGrid(img)) return;
    const item = img.closest('.pack-card-item');
    if(!item || item.dataset.psJpImageDisabled === '1') return;
    img.remove();
    if(!item.querySelector('.ps-jp-noimage')){
      item.insertAdjacentHTML('afterbegin', jpNoImageHTML(false));
    }
    item.dataset.psJpImageDisabled = '1';
  }

  function replaceJPGridImages(){
    if(getLang() !== 'ja') return;
    document.querySelectorAll('#dex-panel-series .pack-cards-grid .pack-card-item img').forEach(disableOneJPImage);
  }

  function resetJPImagePlaceholdersWhenEnglish(){
    if(getLang() === 'ja') return;
    document.querySelectorAll('#dex-panel-series .pack-card-item[data-ps-jp-image-disabled="1"]').forEach((item)=>{
      item.dataset.psJpImageDisabled = '';
      item.querySelectorAll('.ps-jp-noimage').forEach((n)=>n.remove());
    });
  }

  function forceRerenderDexPanels(){
    const q = document.getElementById('dex-search')?.value || '';
    if(typeof window.renderDexSeries === 'function') window.renderDexSeries(q);
    if(typeof window.renderDexRarity === 'function') window.renderDexRarity();
    if(typeof window.renderDexHighValue === 'function') window.renderDexHighValue(q);
    requestAnimationFrame(()=>{
      if(getLang()==='ja') replaceJPGridImages();
      else resetJPImagePlaceholdersWhenEnglish();
    });
  }

  function patchRenderDexSeries(){
    if(typeof window.renderDexSeries !== 'function' || window.__psDexSeriesPatchedV6) return;
    const original = window.renderDexSeries;
    window.renderDexSeries = function patchedRenderDexSeries(){
      const result = original.apply(this, arguments);
      requestAnimationFrame(()=>{
        if(getLang()==='ja') replaceJPGridImages();
      });
      return result;
    };
    window.__psDexSeriesPatchedV6 = true;
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
        ${jpNoImageHTML(true)}
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

  function patchApplyLangUI(){
    if(typeof window.applyLangUI !== 'function' || window.__psApplyLangUIPatchedV6) return;
    const original = window.applyLangUI;
    window.applyLangUI = function patchedApplyLangUI(){
      const result = original.apply(this, arguments);
      forceRerenderDexPanels();
      return result;
    };
    window.__psApplyLangUIPatchedV6 = true;
  }

  function patchSetLang(){
    if(typeof window.setLang !== 'function' || window.__psSetLangPatchedV6) return;
    const original = window.setLang;
    window.setLang = function patchedSetLang(){
      const result = original.apply(this, arguments);
      forceRerenderDexPanels();
      return result;
    };
    window.__psSetLangPatchedV6 = true;
  }

  function installObserver(){
    if(window.__psDexPatchV6Observer) return;
    const obs = new MutationObserver((mutations)=>{
      if(getLang() !== 'ja') return;
      for(const m of mutations){
        for(const n of m.addedNodes){
          if(n.nodeType !== 1) continue;
          if(n.matches && n.matches('#dex-panel-series .pack-cards-grid .pack-card-item img')) disableOneJPImage(n);
          if(n.querySelectorAll) n.querySelectorAll('#dex-panel-series .pack-cards-grid .pack-card-item img').forEach(disableOneJPImage);
        }
      }
    });
    obs.observe(document.body,{childList:true,subtree:true});
    window.__psDexPatchV6Observer = obs;
  }

  function boot(){
    installStyles();
    patchRenderDexSeries();
    patchShowCardModalJP();
    patchApplyLangUI();
    patchSetLang();
    installObserver();
    forceRerenderDexPanels();
  }

  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded',boot,{once:true});
  else boot();
})();