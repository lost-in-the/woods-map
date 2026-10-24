// Press y on real pages with the shipped keys controller and record which copy tool it activates.
async function runCopyKeyRegression() {
  const failures = []
  let cases = 0
  for (const page of fixtureData.pages) for (const width of [1440, 390]) {
    const frame = document.createElement('iframe')
    frame.style.cssText = `width:${width}px;height:700px;border:0`
    document.body.append(frame)
    const doc = frame.contentDocument, win = frame.contentWindow
    doc.open()
    doc.write('<!doctype html><html lang="en"><head></head><body class="wm page" data-theme="dark"><main class="page-main"></main><button id="outside">Outside</button><input id="edit"></body></html>')
    doc.close()
    doc.querySelector('main').innerHTML = page.html
    const Klass = win.Function('Controller', fixtureData.keys.replace(/^import .*$/m, '').replace('export default class', 'return class'))(class {})
    const keys = new Klass()
    keys.element = doc.body
    keys.connect()
    const clicked = []
    for (const tool of doc.querySelectorAll('[data-copy-text-value]')) {
      tool.addEventListener('click', event => { event.preventDefault(); clicked.push(tool.textContent.trim()) })
    }
    const check = (ok, reason) => { if (!ok) failures.push({ path: page.path, width, reason }) }
    const press = (target, options = {}) => {
      const event = new win.KeyboardEvent('keydown', { key: 'y', bubbles: true, cancelable: true, ...options })
      target.dispatchEvent(event)
      return event
    }
    const event = press(doc.getElementById('outside'))
    check(event.defaultPrevented && clicked.length === 1, `y activates one tool (${clicked.join(', ')})`)
    check(clicked[0] === page.expected, `y activates "${page.expected}", not "${clicked[0]}"`)
    clicked.length = 0
    press(doc.getElementById('edit'))
    check(clicked.length === 0, 'typing y in a field copies nothing')
    keys.disconnect(); frame.remove(); cases++
  }
  document.getElementById('result').textContent = JSON.stringify({ cases, failures })
}
runCopyKeyRegression().catch(error => { document.getElementById('result').textContent = JSON.stringify({ cases: 0, failures: [String(error.stack || error)] }) })
