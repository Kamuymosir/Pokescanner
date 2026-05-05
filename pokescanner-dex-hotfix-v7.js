(function(){
  if(window.__psOfficialLinkPatch) return;
  window.__psOfficialLinkPatch = true;

  function addStyle(){
    if(document.getElementById('ps-official-link-style')) return;
    var s = document.createElement('style');
    s.id = 'ps-official-link-style';
    s.textContent = '.ps-official-box{display:flex;align-items:center;justify-content:center;width:100%;height:100%;min-height:96px;background:rgba(0,0,0,.06);border:2px dashed rgba(0,0,0,.25);font-size:11px;line-height:1.5;text-align:center;padding:6px}.ps-official-box a{display:inline-block;margin-top:6px;padding:4px 8px;border:2px solid currentColor;color:inherit;text-decoration:none;font-weight:700}.ps-jp-box{display:flex;align-items:center;justify-content:center;width:100%;height:100%;min-height:150px;background:rgba(0,0,0,.06);border:2px dashed rgba(0,0,0,.25);font-size:11px;line-height:1.5;text-align:center;padding:8px}';
    document.head.appendChild(s);
  }

  function cleanName(name){
    return String(name || '').replace(/（.*?）/g,'').replace(/\(.*?\)/g,'').trim();
  }

  function officialUrl(name){
    return 'https://www.pokemon-card.com/card-search/index.php?keyword=' + encodeURIComponent(cleanName(name));
  }

  function currentIsJapanese(){
    try{ if(typeof currentLang !== 'undefined') return currentLang !== 'en'; }catch(e){}
    var p = (document.getElementById('dex-search') || {}).placeholder || '';
    return !/Search series/i.test(p);
  }

  function patchHighValue(){
    document.querySelectorAll('.dex-card-with-img').forEach(function(card){
      var nameEl = card.querySelector('.dex-card-name');
      var name = nameEl ? nameEl.textContent.trim() : '';
      var thumb = card.querySelector('.dex-card-thumb');
      if(!thumb || thumb.dataset.psOfficial === '1') return;
      thumb.innerHTML = '<div class="ps-official-box"><div>画像は公式で確認<br><a target="_blank" rel="noopener" href="' + officialUrl(name) + '">公式で確認</a></div></div>';
      thumb.dataset.psOfficial = '1';
    });
  }

  function patchSeriesJP(){
    if(!currentIsJapanese()) return;
    document.querySelectorAll('#dex-panel-series .pack-cards-grid .pack-card-item').forEach(function(item){
      if(item.dataset.psJpBox === '1') return;
      item.querySelectorAll('img').forEach(function(img){ img.remove(); });
      item.insertAdjacentHTML('afterbegin','<div class="ps-jp-box"><div>日本語版画像未対応<br>公式検索で確認</div></div>');
      item.dataset.psJpBox = '1';
    });
  }

  function run(){
    addStyle();
    patchHighValue();
    patchSeriesJP();
  }

  function wrap(name, after){
    if(typeof window[name] !== 'function' || window['__psWrapped_'+name]) return;
    var old = window[name];
    window[name] = function(){ var r = old.apply(this, arguments); setTimeout(after, 50); setTimeout(after, 300); return r; };
    window['__psWrapped_'+name] = true;
  }

  function boot(){
    wrap('renderDexHighValue', run);
    wrap('renderDexSeries', run);
    wrap('setLang', run);
    wrap('applyLangUI', run);
    run();
    document.addEventListener('click', function(){ setTimeout(run, 80); }, true);
    setInterval(run, 1200);
  }

  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot, {once:true}); else boot();
})();
