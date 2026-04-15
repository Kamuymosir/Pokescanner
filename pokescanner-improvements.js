(function () {
  const STORAGE_KEY_API_LOCAL = 'pokescanner_apikey';
  const STORAGE_KEY_API_SESSION = 'pokescanner_apikey_session';
  const STORAGE_KEY_API_REMEMBER = 'pokescanner_apikey_remember';

  function safeGet(storage, key) {
    try { return storage.getItem(key) || ''; } catch { return ''; }
  }
  function safeSet(storage, key, value) {
    try { storage.setItem(key, value); } catch {}
  }
  function safeRemove(storage, key) {
    try { storage.removeItem(key); } catch {}
  }
  function wantsRemember() {
    return safeGet(localStorage, STORAGE_KEY_API_REMEMBER) === '1';
  }
  function setRememberFlag(enabled) {
    if (enabled) safeSet(localStorage, STORAGE_KEY_API_REMEMBER, '1');
    else safeRemove(localStorage, STORAGE_KEY_API_REMEMBER);
  }
  function currentLangSafe() {
    try { return typeof currentLang !== 'undefined' ? currentLang : 'ja'; } catch { return 'ja'; }
  }
  function tr(ja, en) {
    return currentLangSafe() === 'ja' ? ja : en;
  }
  function escSafe(value) {
    if (typeof esc === 'function') return esc(value);
    const div = document.createElement('div');
    div.textContent = value == null ? '' : String(value);
    return div.innerHTML;
  }

  function loadApiKeyPatched() {
    const remembered = wantsRemember();
    const legacyLocal = safeGet(localStorage, STORAGE_KEY_API_LOCAL);
    if (remembered) return legacyLocal;
    return safeGet(sessionStorage, STORAGE_KEY_API_SESSION) || legacyLocal;
  }

  function saveApiKeyPatched(value) {
    const key = (value || '').trim();
    if (!key) {
      safeRemove(localStorage, STORAGE_KEY_API_LOCAL);
      safeRemove(sessionStorage, STORAGE_KEY_API_SESSION);
      return;
    }
    if (wantsRemember()) {
      safeSet(localStorage, STORAGE_KEY_API_LOCAL, key);
      safeRemove(sessionStorage, STORAGE_KEY_API_SESSION);
    } else {
      safeSet(sessionStorage, STORAGE_KEY_API_SESSION, key);
      safeRemove(localStorage, STORAGE_KEY_API_LOCAL);
    }
  }

  window.loadApiKey = loadApiKeyPatched;
  window.saveApiKey = saveApiKeyPatched;
  try {
    loadApiKey = loadApiKeyPatched;
    saveApiKey = saveApiKeyPatched;
  } catch {}

  function injectApiKeyControls() {
    const wrap = document.getElementById('apikey-wrap');
    const input = document.getElementById('apikey');
    const saved = document.getElementById('apikey-saved');
    if (!wrap || !input || document.getElementById('apikey-persistence-wrap')) return;

    const hadLegacyKey = !!safeGet(localStorage, STORAGE_KEY_API_LOCAL);
    if (hadLegacyKey && !safeGet(localStorage, STORAGE_KEY_API_REMEMBER)) {
      setRememberFlag(true);
    }

    const box = document.createElement('div');
    box.id = 'apikey-persistence-wrap';
    box.innerHTML = `
      <label class="ps-enhanced-api-persist">
        <input type="checkbox" id="apikey-remember-toggle">
        <span id="apikey-remember-label"></span>
      </label>
      <div class="ps-enhanced-api-note" id="apikey-safety-note"></div>
      <div class="ps-enhanced-api-actions">
        <button type="button" class="ps-mini-btn" id="apikey-clear-btn"></button>
      </div>
    `;
    wrap.insertAdjacentElement('afterend', box);

    const rememberToggle = document.getElementById('apikey-remember-toggle');
    rememberToggle.checked = wantsRemember();

    function syncApiKeyUI() {
      const key = loadApiKeyPatched();
      input.value = key;
      const hasKey = !!key;
      if (saved) saved.classList.toggle('show', hasKey);
      document.getElementById('apikey-remember-label').textContent = tr('この端末に保存する', 'Remember on this device');
      document.getElementById('apikey-safety-note').innerHTML = tr(
        '既定では <b>このタブの間だけ保持</b> します。共有端末では保存しない方が安全です。',
        'By default the key is kept <b>for this tab session only</b>. On shared devices, leave persistence off.'
      );
      document.getElementById('apikey-clear-btn').textContent = tr('キーを削除', 'Clear key');
    }

    rememberToggle.addEventListener('change', () => {
      setRememberFlag(rememberToggle.checked);
      saveApiKeyPatched(input.value);
      syncApiKeyUI();
      if (typeof showToast === 'function') {
        showToast(rememberToggle.checked ? tr('APIキーをローカル保存に切り替えました', 'API key will now persist locally') : tr('APIキーをセッション保持に切り替えました', 'API key will now stay only for this session'));
      }
    });

    document.getElementById('apikey-clear-btn').addEventListener('click', () => {
      input.value = '';
      saveApiKeyPatched('');
      syncApiKeyUI();
      if (typeof showToast === 'function') showToast(tr('APIキーを削除しました', 'API key cleared'));
    });

    syncApiKeyUI();
  }

  function confidenceMeta(card) {
    let points = 0;
    const p = card?.pricing || {};
    const c = card?.condition || {};
    if (p.rawMin != null && p.rawMax != null && (p.rawMin > 0 || p.rawMax > 0)) points += 1;
    if (p.psa10 || p.psa9 || p.psa8 || p.psa7) points += 1;
    if (card?.circulation || card?._ultraRareMatch) points += 1;
    if (c.psaEquivalent) points += 1;
    if (points >= 4) return { key: 'high', ja: '高', en: 'High' };
    if (points >= 2) return { key: 'medium', ja: '中', en: 'Medium' };
    return { key: 'low', ja: '低', en: 'Low' };
  }

  function injectResultClarity(data) {
    const totalBox = document.getElementById('total-box');
    if (!totalBox) return;

    totalBox.querySelectorAll('.ps-result-note').forEach((n) => n.remove());

    const note = document.createElement('div');
    note.className = 'ps-result-note';
    note.innerHTML = `
      <div class="ps-result-note-title">${tr('価格の読み方', 'How to read these prices')}</div>
      <div class="ps-result-note-body">${tr(
        '表示価格は <b>成約保証価格ではなく推定レンジ</b> です。カード状態・版・実際の販路で大きくブレます。AIコメントは参考情報、外部価格ソースは別扱いで見てください。',
        'Displayed values are <b>estimation ranges, not guaranteed sale prices</b>. Actual outcomes vary by condition, print, and selling venue. Treat AI commentary separately from external pricing sources.'
      )}</div>
    `;
    totalBox.appendChild(note);

    const cards = document.querySelectorAll('#cards-list .card');
    cards.forEach((el, index) => {
      el.querySelectorAll('.ps-card-footnote').forEach((n) => n.remove());
      const card = (data.cards || [])[index] || {};
      const meta = confidenceMeta(card);
      const foot = document.createElement('div');
      foot.className = 'ps-card-footnote';
      foot.innerHTML = `
        <span class="ps-source-pill ${meta.key}">${tr('推定信頼度', 'Estimate confidence')}: ${currentLangSafe() === 'ja' ? meta.ja : meta.en}</span>
        <span class="ps-source-pill neutral">${tr('価格種別', 'Price type')}: ${tr('推定レンジ', 'Estimated range')}</span>
        ${card.pricing?.rawNote ? `<div class="ps-card-footnote-text">${escSafe(card.pricing.rawNote)}</div>` : ''}
        ${card.pricing?.psaNote ? `<div class="ps-card-footnote-text">${escSafe(card.pricing.psaNote)}</div>` : ''}
      `;
      el.appendChild(foot);
    });

    const marketSection = document.getElementById('market-section');
    if (marketSection) {
      const title = marketSection.querySelector('.market-title');
      if (title) title.textContent = tr('📊 参考価格ソース', '📊 Reference price sources');
    }
  }

  function patchRenderResults() {
    if (typeof window.renderResults !== 'function' || window.__psRenderResultsPatched) return;
    const original = window.renderResults;
    window.renderResults = function patchedRenderResults(data) {
      original(data);
      injectResultClarity(data || {});
    };
    window.__psRenderResultsPatched = true;
  }

  function injectPinModal() {
    if (document.getElementById('pin-form-modal')) return;
    const modal = document.createElement('div');
    modal.id = 'pin-form-modal';
    modal.className = 'add-modal';
    modal.style.display = 'none';
    modal.innerHTML = `
      <div class="add-modal-inner">
        <div class="add-modal-title">
          <span id="pin-modal-title"></span>
          <button class="card-modal-close" id="pin-modal-close" aria-label="Close">✕</button>
        </div>
        <div class="add-field">
          <label id="pin-name-label"></label>
          <input id="pin-name-input" type="text" maxlength="80">
        </div>
        <div class="add-field">
          <label id="pin-note-label"></label>
          <input id="pin-note-input" type="text" maxlength="140">
        </div>
        <div class="add-field">
          <label id="pin-type-label"></label>
          <select id="pin-type-input">
            <option value="shop"></option>
            <option value="found"></option>
            <option value="other"></option>
          </select>
        </div>
        <button class="add-submit" id="pin-submit-btn"></button>
      </div>
    `;
    document.body.appendChild(modal);

    function applyPinI18n() {
      document.getElementById('pin-modal-title').textContent = tr('スポットを登録', 'Add spot');
      document.getElementById('pin-name-label').textContent = tr('店舗名・場所名', 'Store / place name');
      document.getElementById('pin-note-label').textContent = tr('メモ（在庫・価格・一言）', 'Notes (stock / price / memo)');
      document.getElementById('pin-type-label').textContent = tr('種類', 'Type');
      document.querySelector('#pin-type-input option[value="shop"]').textContent = tr('カードショップ', 'Card shop');
      document.querySelector('#pin-type-input option[value="found"]').textContent = tr('在庫あり', 'Found stock');
      document.querySelector('#pin-type-input option[value="other"]').textContent = tr('その他', 'Other');
      document.getElementById('pin-submit-btn').textContent = tr('登録する', 'Save spot');
    }
    applyPinI18n();

    document.getElementById('pin-modal-close').addEventListener('click', closePinModal);
    modal.addEventListener('click', (e) => { if (e.target === modal) closePinModal(); });
    document.getElementById('pin-submit-btn').addEventListener('click', submitPinModal);

    window.__applyPinI18n = applyPinI18n;
  }

  let pendingPinPosition = null;
  function openPinModal(lat, lng) {
    injectPinModal();
    if (typeof window.__applyPinI18n === 'function') window.__applyPinI18n();
    pendingPinPosition = { lat, lng };
    document.getElementById('pin-name-input').value = '';
    document.getElementById('pin-note-input').value = '';
    document.getElementById('pin-type-input').value = 'shop';
    document.getElementById('pin-form-modal').style.display = 'flex';
    document.getElementById('pin-name-input').focus();
  }
  function closePinModal() {
    const modal = document.getElementById('pin-form-modal');
    if (modal) modal.style.display = 'none';
  }
  function resetPendingPinState() {
    try {
      if (typeof mapAddMode !== 'undefined') mapAddMode = false;
      const btn = document.getElementById('map-btn-add');
      const instructions = document.getElementById('map-pin-instructions');
      if (btn) {
        btn.classList.remove('active');
        btn.textContent = tr('➕ ピンを追加', '➕ Add Pin');
      }
      if (instructions) instructions.classList.remove('show');
      if (typeof pendingPinMarker !== 'undefined' && pendingPinMarker && mapInstance) {
        mapInstance.removeLayer(pendingPinMarker);
        pendingPinMarker = null;
      }
    } catch {}
  }
  function submitPinModal() {
    const name = document.getElementById('pin-name-input').value.trim();
    const note = document.getElementById('pin-note-input').value.trim();
    const type = document.getElementById('pin-type-input').value;
    if (!name || !pendingPinPosition) return;
    resetPendingPinState();
    if (typeof createPin === 'function') {
      createPin(name, note, type, pendingPinPosition.lat, pendingPinPosition.lng);
    }
    pendingPinPosition = null;
    closePinModal();
  }

  window.confirmPinPlacement = function patchedConfirmPinPlacement() {
    if (typeof pendingPinMarker === 'undefined' || !pendingPinMarker) return;
    const pos = pendingPinMarker.getLatLng();
    openPinModal(pos.lat, pos.lng);
  };

  function injectWalletEditModal() {
    if (document.getElementById('wallet-edit-modal')) return;
    const modal = document.createElement('div');
    modal.id = 'wallet-edit-modal';
    modal.className = 'add-modal';
    modal.style.display = 'none';
    modal.innerHTML = `
      <div class="add-modal-inner">
        <div class="add-modal-title">
          <span id="wallet-edit-title"></span>
          <button class="card-modal-close" id="wallet-edit-close" aria-label="Close">✕</button>
        </div>
        <div class="add-field">
          <label id="wallet-edit-name"></label>
          <div id="wallet-edit-card-name" class="ps-static-value"></div>
        </div>
        <div class="add-field">
          <label id="wallet-edit-qty-label"></label>
          <input id="wallet-edit-qty" type="number" min="1" max="999">
        </div>
        <div class="add-field">
          <label id="wallet-edit-cost-label"></label>
          <input id="wallet-edit-cost" type="number" min="0">
        </div>
        <button class="add-submit" id="wallet-edit-save"></button>
      </div>
    `;
    document.body.appendChild(modal);

    function applyWalletEditI18n() {
      document.getElementById('wallet-edit-title').textContent = tr('所持カードを編集', 'Edit holding');
      document.getElementById('wallet-edit-name').textContent = tr('カード名', 'Card');
      document.getElementById('wallet-edit-qty-label').textContent = tr('数量', 'Quantity');
      document.getElementById('wallet-edit-cost-label').textContent = tr('購入価格（円）', 'Purchase price (JPY)');
      document.getElementById('wallet-edit-save').textContent = tr('保存する', 'Save changes');
    }
    applyWalletEditI18n();

    document.getElementById('wallet-edit-close').addEventListener('click', closeWalletEditModal);
    modal.addEventListener('click', (e) => { if (e.target === modal) closeWalletEditModal(); });
    document.getElementById('wallet-edit-save').addEventListener('click', submitWalletEdit);

    window.__applyWalletEditI18n = applyWalletEditI18n;
  }

  let walletEditIndex = null;
  function openWalletEditModal(index) {
    injectWalletEditModal();
    if (typeof window.__applyWalletEditI18n === 'function') window.__applyWalletEditI18n();
    const wallet = typeof getWallet === 'function' ? getWallet() : [];
    const card = wallet[index];
    if (!card) return;
    walletEditIndex = index;
    document.getElementById('wallet-edit-card-name').textContent = card.name || '';
    document.getElementById('wallet-edit-qty').value = card.qty || 1;
    document.getElementById('wallet-edit-cost').value = card.cost || 0;
    document.getElementById('wallet-edit-modal').style.display = 'flex';
    document.getElementById('wallet-edit-qty').focus();
  }
  function closeWalletEditModal() {
    const modal = document.getElementById('wallet-edit-modal');
    if (modal) modal.style.display = 'none';
    walletEditIndex = null;
  }
  function submitWalletEdit() {
    if (walletEditIndex == null || typeof getWallet !== 'function' || typeof saveWallet !== 'function') return;
    const wallet = getWallet();
    const card = wallet[walletEditIndex];
    if (!card) return;
    card.qty = Math.max(1, parseInt(document.getElementById('wallet-edit-qty').value || '1', 10));
    card.cost = Math.max(0, parseInt(document.getElementById('wallet-edit-cost').value || '0', 10));
    saveWallet(wallet);
    closeWalletEditModal();
    if (typeof renderWallet === 'function') renderWallet();
    if (typeof showToast === 'function') showToast(tr('カード情報を更新しました', 'Card holding updated'));
  }

  function patchRenderWallet() {
    if (typeof window.renderWallet !== 'function' || window.__psRenderWalletPatched) return;
    const original = window.renderWallet;
    window.renderWallet = function patchedRenderWallet() {
      original();
      const list = document.getElementById('wallet-list');
      if (!list) return;

      const empty = list.querySelector('.wallet-empty');
      if (empty) empty.innerHTML = tr(
        'カードが登録されていません<br>「➕ カードを追加」から所持カードを登録しましょう<br><br>価格は外部API参照の概算です。売買前に実際の出品・成約も確認してください。',
        'No cards registered yet.<br>Add cards from “➕ Add Card” to start tracking.<br><br>Values are approximate external API references. Verify live listings before buying or selling.'
      );

      list.querySelectorAll('.wallet-card-btn[data-action="edit"]').forEach((btn) => {
        const clone = btn.cloneNode(true);
        btn.replaceWith(clone);
        clone.addEventListener('click', () => openWalletEditModal(parseInt(clone.dataset.idx, 10)));
      });
    };
    window.__psRenderWalletPatched = true;
  }

  function patchSetLang() {
    if (typeof window.setLang !== 'function' || window.__psSetLangPatched) return;
    const original = window.setLang;
    window.setLang = function patchedSetLang(lang) {
      original(lang);
      if (typeof window.__applyPinI18n === 'function') window.__applyPinI18n();
      if (typeof window.__applyWalletEditI18n === 'function') window.__applyWalletEditI18n();
      injectApiKeyControls();
      if (typeof renderWallet === 'function') renderWallet();
    };
    window.__psSetLangPatched = true;
  }

  function injectStyles() {
    if (document.getElementById('ps-enhancement-styles')) return;
    const style = document.createElement('style');
    style.id = 'ps-enhancement-styles';
    style.textContent = `
      .ps-enhanced-api-persist{display:flex;align-items:center;gap:8px;margin-top:-4px;font-size:11px;color:var(--text2)}
      .ps-enhanced-api-persist input{accent-color:var(--accent)}
      .ps-enhanced-api-note{font-size:10px;color:var(--muted);line-height:1.7;margin-top:6px}
      .ps-enhanced-api-actions{display:flex;justify-content:flex-end;margin-top:8px}
      .ps-mini-btn{padding:6px 10px;border-radius:8px;border:1px solid var(--border);background:var(--surface);color:var(--muted);font-size:11px;cursor:pointer}
      .ps-mini-btn:hover{background:var(--surface2);color:var(--text2)}
      .ps-result-note{margin-top:14px;padding-top:14px;border-top:1px solid var(--border)}
      .ps-result-note-title{font-size:10px;color:var(--muted);letter-spacing:.5px;font-weight:600;margin-bottom:6px}
      .ps-result-note-body{font-size:12px;color:var(--text2);line-height:1.7}
      .ps-card-footnote{margin-top:10px;padding-top:10px;border-top:1px dashed var(--border);display:flex;gap:6px;flex-wrap:wrap}
      .ps-card-footnote-text{width:100%;font-size:11px;color:var(--muted);line-height:1.6}
      .ps-source-pill{display:inline-flex;align-items:center;padding:4px 10px;border-radius:999px;font-size:10px;font-weight:600;background:var(--bg);color:var(--text2)}
      .ps-source-pill.high{color:#10b981;background:rgba(16,185,129,.08)}
      .ps-source-pill.medium{color:#f0b429;background:rgba(240,180,41,.08)}
      .ps-source-pill.low{color:#ef4444;background:rgba(239,68,68,.08)}
      .ps-source-pill.neutral{color:var(--text2)}
      .ps-static-value{padding:12px 14px;background:var(--bg);border:1px solid var(--border);border-radius:var(--radius-sm);color:var(--text2);font-size:14px}
    `;
    document.head.appendChild(style);
  }

  function boot() {
    injectStyles();
    injectApiKeyControls();
    injectPinModal();
    injectWalletEditModal();
    patchRenderResults();
    patchRenderWallet();
    patchSetLang();

    const keyInput = document.getElementById('apikey');
    if (keyInput) keyInput.value = loadApiKeyPatched();

    if (typeof window.renderWallet === 'function') window.renderWallet();
    if (window.lastResult && typeof window.renderResults === 'function') window.renderResults(window.lastResult);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot, { once: true });
  } else {
    boot();
  }
})();
