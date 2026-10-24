// Exercise the shipped share and keys controllers on a unit tab with a diagram.
async function runShareRegression() {
  const failures = []
  let cases = 0
  for (const width of [1440, 960, 640, 390]) {
    const frame = document.createElement('iframe')
    frame.style.cssText = `width:${width}px;height:700px;border:0`
    document.body.append(frame)
    const doc = frame.contentDocument, win = frame.contentWindow
    doc.open()
    doc.write('<!doctype html><html lang="en"><head></head><body class="wm page" data-theme="dark"><main class="page-main"></main><button id="outside">Outside</button></body></html>')
    doc.close()
    const style = doc.createElement('style')
    style.textContent = fixtureData.styles
    doc.head.append(style)
    doc.querySelector('main').innerHTML = fixtureData.html
    const make = (name, element) => {
      const Klass = win.Function('Controller', fixtureData.controllers[name].replace(/^import .*$/m, '').replace('export default class', 'return class'))(class {})
      const instance = new Klass()
      instance.element = element
      for (const target of Klass.targets || []) Object.defineProperty(instance, `${target}Target`, {
        get: () => element.querySelector(`[data-${name}-target~="${target}"]`)
      })
      return instance
    }
    const details = doc.querySelector('details.share')
    const share = make('share', details)
    const keys = make('keys', doc.body)
    details.addEventListener('toggle', () => share.toggle())
    details.addEventListener('keydown', event => share.key(event))
    share.connect(); keys.connect()
    const check = (ok, reason) => { if (!ok) failures.push({ width, reason }) }
    const wait = ms => new Promise(resolve => win.setTimeout(resolve, ms))
    const summary = details.querySelector('summary')
    const source = doc.querySelector('.dia [data-diagram-target="source"]').textContent

    win.location.hash = '#L3'
    summary.focus(); summary.click(); await wait(40)
    check(details.open, 'the summary opens the menu')
    const url = details.querySelector('.sh-url').textContent
    check(url.endsWith('/schema#L3') && details.querySelector('[data-share-target="copyUrl"]').dataset.copyTextValue === url, 'the focus URL carries the targeted line')
    const copies = [...details.querySelectorAll('[data-share-target="diagrams"] button')]
    check(copies.length === 1 && copies[0].dataset.copyTextValue === source && copies[0].dataset.controller === 'copy', 'one Mermaid copy per diagram, with the panel\'s own text')
    check(/User schema/.test(copies[0]?.getAttribute('aria-label') || ''), 'the Mermaid copy names its diagram')
    const mmd = details.querySelector('[data-share-target="diagrams"] a')
    check(mmd && /\/woods\/units\/model\/User\/schema\.mmd$/.test(mmd.getAttribute('href')) && /^https?:/.test(mmd.getAttribute('href')), 'each diagram links its absolute .mmd URL')
    const box = details.querySelector('.share-panel').getBoundingClientRect()
    check(box.left >= 0 && box.right <= width, `the panel fits the viewport (${Math.round(box.left)}..${Math.round(box.right)})`)
    summary.click(); summary.click(); await wait(40)
    check(details.querySelectorAll('[data-share-target="diagrams"] button').length === 1 && details.querySelectorAll('[data-share-target="diagrams"] a').length === 1, 'reopening does not duplicate the Mermaid copies')

    copies[0].focus()
    details.querySelector('.share-panel').dispatchEvent(new win.KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true }))
    check(!details.open && doc.activeElement === summary, 'Escape closes and returns focus to Share')

    summary.click(); await wait(40)
    doc.getElementById('outside').click()
    check(!details.open, 'a click outside closes the menu')

    // Without the crumbs' path tool, the Share menu's copy is the first in the page; y must skip it.
    doc.querySelector('.crumbs [data-copy-text-value]')?.remove()
    let pageCopy = 0, shareCopy = 0
    for (const tool of doc.querySelectorAll('[data-copy-text-value]')) {
      tool.addEventListener('click', event => { event.preventDefault(); if (tool.closest('.share')) shareCopy++; else pageCopy++ })
    }
    doc.getElementById('outside').focus()
    doc.getElementById('outside').dispatchEvent(new win.KeyboardEvent('keydown', { key: 'y', bubbles: true, cancelable: true }))
    check(pageCopy === 1 && shareCopy === 0, 'y still copies the page\'s Mermaid, not the Share menu\'s URL')

    share.disconnect(); keys.disconnect()
    win.location.hash = ''
    frame.remove(); cases++
  }
  document.getElementById('result').textContent = JSON.stringify({ cases, failures })
}
runShareRegression().catch(error => { document.getElementById('result').textContent = JSON.stringify({ cases: 0, failures: [String(error.stack || error)] }) })
