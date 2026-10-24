// Exercise the shipped card and tooltip controllers on the Code tab's markup.
async function runHoverCardRegression() {
  const failures = []
  let cases = 0
  for (const width of [1440, 960, 640, 390]) {
    const frame = document.createElement('iframe')
    frame.style.cssText = `width:${width}px;height:700px;border:0`
    document.body.append(frame)
    const doc = frame.contentDocument, win = frame.contentWindow
    doc.open()
    doc.write('<!doctype html><html lang="en"><head></head><body class="wm page" data-theme="dark"><main></main></body></html>')
    doc.close()
    const style = doc.createElement('style')
    style.textContent = fixtureData.styles
    doc.head.append(style)
    doc.querySelector('main').innerHTML = fixtureData.html + '<button id="outside">Outside</button>'
    const make = (name, element) => {
      const Klass = win.Function('Controller', fixtureData.controllers[name].replace(/^import .*$/m, '').replace('export default class', 'return class'))(class {})
      const instance = new Klass()
      instance.element = element
      for (const target of Klass.targets || []) Object.defineProperty(instance, `${target}Targets`, {
        get: () => [...element.querySelectorAll(`[data-${name}-target~="${target}"]`)]
      })
      instance.delayValue = 300
      return instance
    }
    const card = make('card', doc.querySelector('[data-controller~="card"]'))
    const tooltip = make('tooltip', doc.body)
    card.connect(); tooltip.connect()
    const check = (ok, reason) => { if (!ok) failures.push({ width, reason }) }
    const wait = ms => new Promise(resolve => win.setTimeout(resolve, ms))
    const links = [...doc.querySelectorAll('.cv .src a[href]')]
    const tip = () => doc.querySelector('.tip')
    check(links.length === 2 && links.every(l => l.dataset.tipHtml.includes('class="hcard"') && l.dataset.tipDelay === '100'), 'every reference link carries its card')
    check(links.every(l => !l.hasAttribute('title') && !l.hasAttribute('tabindex')), 'links keep native semantics')

    const [widget] = links
    widget.focus(); widget.dispatchEvent(new win.FocusEvent('focusin', { bubbles: true }))
    check(tip() && tip().querySelector('.hcard b')?.textContent === 'Domain::Widget', 'focus opens the card at once')
    check(tip() && widget.getAttribute('aria-describedby') === tip().id && tip().getAttribute('role') === 'tooltip', 'card describes the focused link')
    if (tip()) {
      const box = tip().getBoundingClientRect()
      check(box.left >= 0 && box.right <= width, `card fits the viewport (${Math.round(box.left)}..${Math.round(box.right)})`)
    }
    widget.dispatchEvent(new win.KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
    check(!tip() && !widget.hasAttribute('aria-describedby'), 'Escape closes the card')
    check(doc.activeElement === widget, 'Escape keeps focus on the link')

    const gadget = links[1]
    gadget.dispatchEvent(new win.MouseEvent('mouseover', { bubbles: true }))
    await wait(40)
    check(!tip(), 'hover waits for intent')
    await wait(110)
    check(tip() && tip().querySelector('.hcard b')?.textContent === 'Gadget', 'hover opens the card within the 100 ms delay')
    gadget.dispatchEvent(new win.MouseEvent('mouseout', { bubbles: true }))
    await wait(200)
    check(!tip(), 'leaving the link closes the card')

    tooltip.disconnect(); frame.remove(); cases++
  }
  document.getElementById('result').textContent = JSON.stringify({ cases, failures })
}
runHoverCardRegression().catch(error => { document.getElementById('result').textContent = JSON.stringify({ cases: 0, failures: [String(error.stack || error)] }) })
