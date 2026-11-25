/* WebLibre Fast Scroll: extension action toggles only the active page's thumb. */
(() => {
  'use strict';
  browser.browserAction.onClicked.addListener(async (tab) => {
    if (!tab || typeof tab.id !== 'number') return;
    try {
      await browser.tabs.sendMessage(tab.id, { type: 'WEBLIBRE_FAST_SCROLL_TOGGLE' });
    } catch (_) {
      // Unsupported schemes and tabs without a content script are ignored.
    }
  });
})();
