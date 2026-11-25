/*
 * WebLibre Fast Scroll 0.1.0
 * Isolated, opt-out, root-document-only scrollbar for GeckoView/Firefox Android.
 * No external communication, remote code, or page scripting is required.
 */
(() => {
  'use strict';

  if (window !== window.top || !document.documentElement) return;
  if (document.getElementById('weblibre-fast-scroll-anchor')) return;

  const key = `weblibreFastScrollDisabled:${location.origin}`;
  const host = document.createElement('div');
  host.id = 'weblibre-fast-scroll-anchor';
  const shadow = host.attachShadow({ mode: 'closed' });
  shadow.innerHTML = `
    <style>
      :host {
        all: initial !important;
        position: fixed !important;
        z-index: 2147483647 !important;
        top: max(12px, env(safe-area-inset-top, 0px)) !important;
        bottom: max(12px, env(safe-area-inset-bottom, 0px)) !important;
        right: 4px !important;
        width: 22px !important;
        display: none;
        pointer-events: none !important;
        contain: layout style;
      }
      #track { position: absolute; inset: 0; pointer-events: none; }
      #thumb {
        position: absolute; top: 0; right: 0; width: 22px; height: 52px;
        box-sizing: border-box; border-radius: 11px;
        touch-action: none; user-select: none; -webkit-user-select: none;
        -webkit-tap-highlight-color: transparent;
        pointer-events: auto; cursor: grab; outline: none;
      }
      #thumb::after {
        content: ''; position: absolute; right: 4px; top: 0;
        width: 7px; height: 100%; border-radius: 8px;
        background: rgba(66, 80, 100, .58);
        box-shadow: 0 0 0 1px rgba(255, 255, 255, .4);
        transition: background-color 120ms linear;
      }
      :host(.engaged) #thumb::after,
      #thumb:focus-visible::after,
      #thumb:active::after {
        background: rgba(36, 113, 227, .88);
      }
      #thumb:active { cursor: grabbing; }
      @media (prefers-color-scheme: dark) {
        #thumb::after { background: rgba(230, 234, 241, .58); }
        :host(.engaged) #thumb::after { background: rgba(119, 174, 255, .95); }
      }
      @media (prefers-reduced-motion: reduce) {
        #thumb::after { transition: none; }
      }
    </style>
    <div id="track">
      <div id="thumb" role="scrollbar" aria-label="Fast page scroll"
           aria-orientation="vertical" aria-valuemin="0" aria-valuemax="100"
           aria-valuenow="0" tabindex="0"></div>
    </div>`;

  const track = shadow.getElementById('track');
  const thumb = shadow.getElementById('thumb');
  const MIN_THUMB = 52;
  let enabled = false;
  let dragging = false;
  let pointerId = null;
  let grabOffset = 0;
  let raf = 0;
  let attentionTimer = 0;
  let pollTimer = 0;
  let resizeObserver = null;
  let lastMetrics = null;

  function pageMetrics() {
    const root = document.scrollingElement || document.documentElement;
    const viewport = Math.max(1, root.clientHeight || window.innerHeight);
    const body = document.body;
    const documentHeight = Math.max(
      root.scrollHeight || 0,
      document.documentElement.scrollHeight || 0,
      body ? body.scrollHeight : 0,
      viewport,
    );
    return {
      root,
      viewport,
      scrollTop: Math.max(0, root.scrollTop || window.scrollY || 0),
      maxScroll: Math.max(0, documentHeight - viewport),
      documentHeight,
    };
  }

  function update() {
    raf = 0;
    if (!enabled || document.hidden || !host.isConnected) return;
    const metrics = pageMetrics();
    // A hidden host has a zero-height track; measure it before deciding
    // whether this document can scroll and whether the thumb should show.
    host.style.display = 'block';
    const trackHeight = track.getBoundingClientRect().height;
    // Ignore pages too short to benefit or impossible-to-measure layouts.
    if (metrics.maxScroll < Math.max(48, metrics.viewport * 0.25) || trackHeight < 100) {
      host.style.display = 'none';
      lastMetrics = null;
      return;
    }
    host.style.display = 'block';
    const thumbHeight = Math.min(
      trackHeight,
      Math.max(MIN_THUMB, Math.min(trackHeight * 0.7,
        trackHeight * metrics.viewport / metrics.documentHeight)),
    );
    const travel = Math.max(0, trackHeight - thumbHeight);
    const progress = Math.min(1, Math.max(0, metrics.scrollTop / metrics.maxScroll));
    thumb.style.height = `${thumbHeight}px`;
    thumb.style.transform = `translate3d(0, ${Math.round(travel * progress)}px, 0)`;
    thumb.setAttribute('aria-valuenow', String(Math.round(100 * progress)));
    lastMetrics = metrics;
  }

  function schedule() {
    if (!enabled || raf) return;
    raf = requestAnimationFrame(update);
  }

  function engage() {
    host.classList.add('engaged');
    clearTimeout(attentionTimer);
    if (!dragging) {
      attentionTimer = window.setTimeout(() => host.classList.remove('engaged'), 1250);
    }
  }

  function onScroll() {
    schedule();
    engage();
  }

  function seek(clientY) {
    const metrics = pageMetrics();
    const bounds = track.getBoundingClientRect();
    const thumbHeight = thumb.getBoundingClientRect().height;
    const travel = Math.max(1, bounds.height - thumbHeight);
    const fraction = Math.max(0, Math.min(1,
      (clientY - bounds.top - grabOffset) / travel,
    ));
    // Use the root scroller; arbitrary nested scrollers are intentionally not
    // intercepted because guessing the target breaks application UIs.
    metrics.root.scrollTop = fraction * metrics.maxScroll;
    schedule();
  }

  function onPointerDown(event) {
    if (!enabled || event.button !== 0 || !lastMetrics) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    dragging = true;
    pointerId = event.pointerId;
    grabOffset = event.clientY - thumb.getBoundingClientRect().top;
    thumb.setPointerCapture(pointerId);
    engage();
  }

  function onPointerMove(event) {
    if (!dragging || event.pointerId !== pointerId) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    seek(event.clientY);
  }

  function onPointerEnd(event) {
    if (!dragging || event.pointerId !== pointerId) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    dragging = false;
    pointerId = null;
    clearTimeout(attentionTimer);
    attentionTimer = window.setTimeout(() => host.classList.remove('engaged'), 1250);
    schedule();
  }

  function onKeyDown(event) {
    if (!enabled) return;
    const metrics = pageMetrics();
    const step = Math.max(60, metrics.viewport * 0.12);
    const target = {
      ArrowUp: metrics.scrollTop - step,
      ArrowDown: metrics.scrollTop + step,
      PageUp: metrics.scrollTop - metrics.viewport * 0.9,
      PageDown: metrics.scrollTop + metrics.viewport * 0.9,
      Home: 0,
      End: metrics.maxScroll,
    }[event.key];
    if (target === undefined) return;
    event.preventDefault();
    event.stopPropagation();
    metrics.root.scrollTop = Math.min(metrics.maxScroll, Math.max(0, target));
    schedule();
  }

  // Pointer listeners are attached only to the 22px wide handle so web links,
  // text selection, and the browser's regular gestures work everywhere else.
  thumb.addEventListener('pointerdown', onPointerDown);
  thumb.addEventListener('pointermove', onPointerMove);
  thumb.addEventListener('pointerup', onPointerEnd);
  thumb.addEventListener('pointercancel', onPointerEnd);
  thumb.addEventListener('keydown', onKeyDown);

  function setEnabled(next) {
    if (enabled === next) return;
    enabled = next;
    if (enabled) {
      document.documentElement.appendChild(host);
      window.addEventListener('scroll', onScroll, { passive: true });
      window.addEventListener('resize', schedule, { passive: true });
      window.addEventListener('pageshow', schedule, { passive: true });
      document.addEventListener('visibilitychange', schedule);
      if (window.visualViewport) {
        window.visualViewport.addEventListener('resize', schedule, { passive: true });
      }
      if (typeof ResizeObserver !== 'undefined') {
        resizeObserver = new ResizeObserver(schedule);
        resizeObserver.observe(document.documentElement);
        if (document.body) resizeObserver.observe(document.body);
      }
      // Dynamic/infinite scrolling can change scrollHeight without a resize.
      // The once-per-1.5s check is cheap and does not traverse the DOM.
      pollTimer = window.setInterval(schedule, 1500);
      schedule();
    } else {
      if (raf) cancelAnimationFrame(raf);
      raf = 0;
      clearTimeout(attentionTimer);
      clearInterval(pollTimer);
      pollTimer = 0;
      resizeObserver?.disconnect();
      resizeObserver = null;
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', schedule);
      window.removeEventListener('pageshow', schedule);
      document.removeEventListener('visibilitychange', schedule);
      window.visualViewport?.removeEventListener('resize', schedule);
      host.classList.remove('engaged');
      host.remove();
      lastMetrics = null;
    }
  }

  browser.runtime.onMessage.addListener((message) => {
    if (message?.type !== 'WEBLIBRE_FAST_SCROLL_TOGGLE') return;
    const next = !enabled;
    setEnabled(next);
    // Per-origin opt-out; no URLs or browsing history leave the device.
    return browser.storage.local.set({ [key]: !next });
  });

  browser.storage.local.get(key).then(
    (result) => setEnabled(result[key] !== true),
    () => setEnabled(true),
  );
})();
