// Drag and Shift+arrows on the History strip and the timeline with the shipped brush controller.
async function runBrushRegression() {
  const failures = []
  let cases = 0
  for (const page of fixtureData.pages) for (const width of [1440, 390]) {
    const frame = document.createElement('iframe')
    frame.style.cssText = `width:${width}px;height:700px;border:0`
    document.body.append(frame)
    const doc = frame.contentDocument, win = frame.contentWindow
    doc.open()
    doc.write('<!doctype html><html lang="en"><head></head><body><main></main></body></html>')
    doc.close()
    doc.querySelector('main').innerHTML = page.html
    const Klass = win.Function('Controller', fixtureData.brush.replace(/^import .*$/m, '').replace('export default class', 'return class'))(class {})
    const check = (ok, reason) => { if (!ok) failures.push({ page: page.name, width, reason }) }
    const make = () => {
      const brush = new Klass()
      brush.element = doc.querySelector(page.selector)
      brush.visited = []
      brush.navigate = url => brush.visited.push(url)
      brush.connect()
      return brush
    }
    const band = () => doc.querySelector(`${page.selector} [data-brush-band]`)
    const status = () => doc.querySelector(`${page.selector} [data-brush-status]`).textContent
    const key = (target, k, shift = true) => {
      const event = new win.KeyboardEvent('keydown', { key: k, shiftKey: shift, bubbles: true, cancelable: true })
      target.dispatchEvent(event)
      return event
    }

    // Keyboard: from a focused bar, Shift+← twice selects three buckets; Enter lists them.
    let brush = make()
    const bar = doc.querySelector(`${page.selector} a[data-index]`)
    bar.focus()
    check(key(bar, 'ArrowLeft').defaultPrevented, 'Shift+← is taken by the brush')
    key(bar, 'ArrowLeft')
    check(band().getAttribute('visibility') === 'visible', 'the band shows while selecting')
    check(/^3 \w+s selected, \d{4}-\d\d-\d\d to \d{4}-\d\d-\d\d\. Press Enter/.test(status()), `status reads the span (${status()})`)
    check(key(bar, 'Enter', false).defaultPrevented, 'Enter applies the span instead of following the bar')
    const span = new URL(brush.visited[0] || '/', 'http://map.test').searchParams.get('span') || ''
    check(/^\d{4}-\d\d-\d\d\.\.\d{4}-\d\d-\d\d$/.test(span), `Enter navigates to ?span= (${brush.visited[0]})`)
    brush.disconnect()

    // Escape cancels a keyboard selection.
    brush = make()
    key(bar, 'ArrowRight'); key(bar, 'Escape', false)
    check(band().getAttribute('visibility') === 'hidden' && brush.visited.length === 0, 'Escape cancels')
    brush.disconnect()

    // Pointer: a drag across the plot selects and navigates; the click that ends it is swallowed.
    brush = make()
    const svg = brush.svg
    const box = svg.getBoundingClientRect()
    const at = share => box.left + box.width * share
    const pointer = (type, share) => svg.dispatchEvent(new win.PointerEvent(type, { clientX: at(share), clientY: box.top + 5, button: 0, pointerId: 1, bubbles: true, cancelable: true }))
    pointer('pointerdown', 0.1); pointer('pointermove', 0.5); pointer('pointermove', 0.9); pointer('pointerup', 0.9)
    check(brush.visited.length === 1 && brush.visited[0].includes('span='), `a drag navigates once (${brush.visited.join(' ')})`)
    const click = new win.MouseEvent('click', { bubbles: true, cancelable: true })
    bar.dispatchEvent(click)
    check(click.defaultPrevented, 'the click ending a drag does not follow the bar')
    brush.disconnect()

    // A click without a drag keeps the bar's own link.
    brush = make()
    pointer('pointerdown', 0.5); pointer('pointerup', 0.5)
    const plain = new win.MouseEvent('click', { bubbles: true, cancelable: true })
    bar.dispatchEvent(plain)
    check(brush.visited.length === 0 && !plain.defaultPrevented, 'a plain click is left to the link')
    brush.disconnect()
    frame.remove(); cases++
  }
  document.getElementById('result').textContent = JSON.stringify({ cases, failures })
}
runBrushRegression().catch(error => { document.getElementById('result').textContent = JSON.stringify({ cases: 0, failures: [String(error.stack || error)] }) })
