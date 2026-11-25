"""Desktop Chromium DOM smoke test. Android GeckoView still needs device E2E."""
from pathlib import Path
from shutil import which
from playwright.sync_api import sync_playwright

source = Path(__file__).with_name('content.js').read_text().replace("mode: 'closed'", "mode: 'open'")
stub = """
window._receiver = null;
window._stored = {};
window.browser = {
  runtime: {onMessage: {addListener: (callback) => {window._receiver = callback;}}},
  storage: {local: {
    get: async (key) => ({[key]: window._stored[key]}),
    set: async (value) => {Object.assign(window._stored, value);}
  }}
};
"""

with sync_playwright() as p:
  executable = which('chromium') or which('google-chrome') or which('chrome')
  browser = p.chromium.launch(
      **({'executable_path': executable} if executable else {}),
      args=['--no-sandbox'],
  )
  page = browser.new_page(viewport={'width': 420, 'height': 820})
  page.set_content('<html><body style="margin:0">' + ('<p style="height:180px">Line</p>' * 120) + '</body></html>')
  page.evaluate(stub)
  page.evaluate(source)
  page.wait_for_timeout(100)
  thumb = page.locator('#weblibre-fast-scroll-anchor').evaluate(
      "host => host.shadowRoot.getElementById('thumb').getBoundingClientRect().toJSON()"
  )
  hostdisplay = page.locator('#weblibre-fast-scroll-anchor').evaluate(
      "host => getComputedStyle(host).display"
  )
  assert hostdisplay == 'block', hostdisplay
  assert thumb['height'] >= 52, thumb
  page.evaluate('window.scrollTo(0, document.documentElement.scrollHeight/2)')
  page.wait_for_timeout(80)
  middle = page.locator('#weblibre-fast-scroll-anchor').evaluate(
      "host => host.shadowRoot.getElementById('thumb').getBoundingClientRect().toJSON()"
  )
  assert middle['y'] > thumb['y'], (thumb, middle)
  page.mouse.move(middle['x'] + middle['width']/2, middle['y'] + middle['height']/2)
  page.mouse.down()
  page.mouse.move(middle['x'] + middle['width']/2, 775, steps=10)
  page.mouse.up()
  page.wait_for_timeout(100)
  top, maximum = page.evaluate('''() => [window.scrollY,document.documentElement.scrollHeight-innerHeight]''')
  assert top / maximum > 0.9, (top, maximum)
  page.evaluate("window._receiver({type: 'WEBLIBRE_FAST_SCROLL_TOGGLE'})")
  page.wait_for_timeout(80)
  assert page.locator('#weblibre-fast-scroll-anchor').count() == 0
  page.evaluate("window._receiver({type: 'WEBLIBRE_FAST_SCROLL_TOGGLE'})")
  page.wait_for_timeout(80)
  assert page.locator('#weblibre-fast-scroll-anchor').count() == 1
  print('PASS: initial thumb, scroll-position update, drag-to-bottom, per-site toggle')
  browser.close()
