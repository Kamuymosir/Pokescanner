(function(){
  function lang(){try{return typeof currentLang!=='undefined'?currentLang:'ja'}catch{return'ja'}}
  function jpFallback(img, packCode, localId){
    if(!img || !packCode || !localId) return '';
    const id = /^\d+$/.test(String(localId)) ? String(parseInt(String(localId),10)) : String(localId).replace(/^0+/,'') || String(localId);
    return `https://images.pokemontcg.io/${encodeURIComponent(String(packCode))}/${encodeURIComponent(id)}.png`;
  }
  function rerenderSeries(){
    try{
      const search=document.getElementById('dex-search');
      if(typeof window.renderDexSeries==='function') window.renderDexSeries(search?.value||'');
    }catch{}
  }
  function patchSetLang(){
    if(typeof window.setLang!=='function' || window.__psDexLangLitePatched) return;
    const original=window.setLang;
    window.setLang=function(nextLang){
      original(nextLang);
      rerenderSeries();
    };
    window.__psDexLangLitePatched=true;
  }
  function patchBrokenImages(){
    const root=document.getElementById('dex-panel-series');
    if(!root || root.__psImageObserver) return;
    const repair=(img)=>{
      if(!(img instanceof HTMLImageElement)) return;
      if(img.dataset.psRepaired==='1') return;
      const item=img.closest('.pack-card-item');
      const pack=item?.closest('.pack-item');
      const label=item?.querySelector('small')?.textContent||'';
      const localId=(label.match(/#([A-Za-z0-9-]+)/)||[])[1]||'';
      const packCode=pack?.dataset?.setcode||'';
      const fallback=jpFallback(img, packCode, localId);
      if(!fallback) return;
      img.dataset.psRepaired='1';
      img.addEventListener('error',()=>{ if(img.src!==fallback) img.src=fallback; },{once:true});
      if(img.complete && img.naturalWidth===0) img.src=fallback;
    };
    root.querySelectorAll('img').forEach(repair);
    const obs=new MutationObserver((ms)=>{
      ms.forEach(m=>m.addedNodes.forEach(n=>{
        if(n.nodeType!==1) return;
        if(n.matches?.('img')) repair(n);
        n.querySelectorAll?.('img').forEach(repair);
      }));
    });
    obs.observe(root,{childList:true,subtree:true});
    root.__psImageObserver=obs;
  }
  function boot(){ patchSetLang(); patchBrokenImages(); rerenderSeries(); }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',boot,{once:true}); else boot();
})();