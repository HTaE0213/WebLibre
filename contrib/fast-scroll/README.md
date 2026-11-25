# WebLibre Fast Scroll (experimental)

An **independent WebExtension** for Gecko-based browsers. It adds a draggable scrollbar to the right edge of long pages without changing WebLibre's Flutter or GeckoView code.

## Features

- Drag a touch-friendly scrollbar thumb to move through a long page.
- The extension toolbar button toggles the scrollbar for the current origin; the setting is stored locally.
- Only the root page scrolls. It never rewrites page content or runs downloaded code.
- Recalculates after resizes and changing page height; suppresses updates when the page is hidden.
- Does not appear on internal browser pages or non-HTTP(S) content.

## Build

Run from the repository root:

```sh
python3 contrib/fast-scroll/build_xpi.py
```

The result is `contrib/fast-scroll/dist/weblibre-fast-scroll-0.1.0.xpi`.
The **Fast Scroll XPI** GitHub Actions workflow also publishes the unsigned XPI as an artifact. Build output is not checked in.

## Install (manual preview)

Download the XPI from the GitHub Actions artifact and use WebLibre's local add-on installer. As a manually packaged extension it is **not signed by Mozilla**; the browser may refuse installation unless local unsigned extensions are explicitly allowed. Do not weaken signature verification globally just for an untrusted add-on. Test first in a disposable profile and restore the browser setting afterward.

Once installed, pin its browser action and tap it to toggle the scrollbar for the current site. By default it is enabled on long supported pages. The extension needs website access to render its thumb on each page.

## Limitations

- **Android GeckoView has not yet been tested on a physical device.** Chromium desktop smoke tests only validate page DOM behavior, not GeckoView integration, touch routing or gesture edges.
- Root-document scrolling only: nested scroll regions, PDF viewers, cross-origin frames, internal pages, and infinitely virtualized lists are unsupported.
- Some sites using custom touch handlers, full-screen overlays or unusual viewport rules may behave differently.
- No remote networking, analytics, history upload or arbitrary injection.
- An extension cannot automatically appear as a native browser setting without additional changes to WebLibre; this independent design avoids those upstream merge conflicts.

## Optional desktop smoke test

```sh
python3 -m pip install playwright
python3 contrib/fast-scroll/test_fast_scroll.py
```

Requires a local Chromium/Chrome browser. Source license: MPL-2.0.
