// Exercise shipped controllers and actual request markup in native Chromium dialogs.
async function runHelpRegression() {
  const failures = []
  let cases = 0
  for (const page of fixtureData.pages) for (const width of [1440, 960, 640, 390]) {
    const frame = document.createElement('iframe')
    frame.style.cssText = `width:${width}px;height:700px;border:0`
    document.body.append(frame)
    const doc = frame.contentDocument, win = frame.contentWindow
    doc.open()
    doc.write('<!doctype html><html lang="en"><head></head><body class="wm page" data-theme="dark"></body></html>')
    doc.close()
    const style = doc.createElement('style')
    style.textContent = fixtureData.styles
    doc.head.append(style)
    doc.body.innerHTML = page.html + '<button id="outside">Outside</button><input id="edit"><div contenteditable="true"><span id="nested">Editable</span></div><nav aria-label="entry"><a href="#create">Create</a></nav><nav aria-label="Depth"><a href="#one">One</a></nav><button data-copy-text-value="test" data-key="y">Copy</button><div id="other" role="dialog" aria-modal="true" hidden><button>Other</button></div>'
    const instances = {}
    for (const [name, source] of Object.entries(fixtureData.controllers)) {
      const Klass = win.Function('Controller', source.replace(/^import .*$/m, '').replace('export default class', 'return class'))(class {})
      const instance = new Klass()
      instance.element = name === 'palette' ? doc.querySelector('[data-controller="palette"]') : doc.body
      for (const target of Klass.targets || []) Object.defineProperty(instance, `${target}Target`, {
        get: () => instance.element.querySelector(`[data-${name}-target~="${target}"]`)
      })
      instances[name] = instance
    }
    for (const node of doc.querySelectorAll('[data-action]')) for (const action of node.dataset.action.split(' ')) {
      const match = action.match(/^(?:(\w+)->)?(help|palette)#(\w+)$/)
      if (match) node.addEventListener(match[1] || 'click', event => instances[match[2]][match[3]](event))
    }
    for (const instance of Object.values(instances)) instance.connect()
    const { help, palette } = instances
    const dialog = help.dialogTarget, close = help.closeTarget, outside = doc.querySelector('#outside')
    const check = (ok, reason) => { if (!ok) failures.push({ mount: page.mount, width, reason }) }
    const tick = () => new Promise(resolve => win.setTimeout(resolve, 30))
    const key = (target, key, options = {}) => {
      const event = new win.KeyboardEvent('keydown', { key, bubbles: true, cancelable: true, ...options })
      target.dispatchEvent(event)
      return event
    }
    let background = 0
    for (const node of doc.querySelectorAll('[aria-label=entry] a, [aria-label=Depth] a, [data-copy-text-value]')) {
      node.addEventListener('click', event => { background++; event.preventDefault() })
    }
    outside.focus()
    check(key(outside, '?', { shiftKey: true }).defaultPrevented && dialog.open && doc.activeElement === close, '? opens and focuses Close')
    const box = dialog.getBoundingClientRect()
    check(box.left >= 0 && box.right <= width && dialog.scrollWidth <= dialog.clientWidth, 'dialog fits viewport without horizontal scrolling')
    for (const shiftKey of [false, true]) check(key(close, 'Tab', { shiftKey }).defaultPrevented && doc.activeElement === close, 'Tab remains inside modal')
    for (const value of ['c', '1', 'y', '/']) key(close, value)
    check(background === 0 && doc.activeElement === close && palette.wrapTarget.hidden, 'modal blocks background shortcuts')
    key(close, 'Escape')
    await tick()
    check(!dialog.open && doc.activeElement === outside, 'Escape restores keyboard opener')
    const button = doc.querySelector('[aria-controls="wm-keyboard-help"]')
    button.focus(); button.click()
    check(dialog.open && doc.activeElement === close, 'visible help button opens modal')
    close.click(); await tick()
    check(!dialog.open && doc.activeElement === button, 'Close restores button opener')
    outside.focus(); key(outside, '?')
    dialog.dispatchEvent(new win.MouseEvent('click', { clientX: box.left + 10, clientY: box.top + 10, bubbles: true }))
    check(dialog.open, 'click in dialog padding keeps help open')
    dialog.dispatchEvent(new win.MouseEvent('click', { clientX: -1, clientY: -1, bubbles: true }))
    await tick()
    check(!dialog.open && doc.activeElement === outside, 'backdrop restores opener')
    for (const target of [doc.querySelector('#edit'), doc.querySelector('#nested')]) {
      for (const value of ['?', '/', 'c', '1', 'y']) check(!key(target, value).defaultPrevented, 'editing keeps its keys')
    }
    for (const options of [{ ctrlKey: true }, { metaKey: true }, { altKey: true }, { repeat: true }, { isComposing: true }]) {
      check(!key(outside, '?', options).defaultPrevented && !dialog.open, 'modified/repeating/composing key does not open help')
    }
    const other = doc.querySelector('#other')
    other.hidden = false
    check(!key(other.firstChild, '?').defaultPrevented && !dialog.open, 'another modal owns its keys')
    other.hidden = true
    const prevented = new win.KeyboardEvent('keydown', { key: '?', bubbles: true, cancelable: true })
    prevented.preventDefault(); outside.dispatchEvent(prevented)
    check(!dialog.open && background === 0, 'consumed keys do not open help or activate page tools')
    key(outside, 'c'); key(outside, '1'); key(outside, 'y')
    check(background === 3, 'page shortcuts resume after dismissal')
    for (const instance of Object.values(instances)) instance.disconnect()
    key(outside, '?')
    check(!dialog.open, 'disconnect removes keyboard listener')
    frame.remove(); cases++
  }
  document.getElementById('result').textContent = JSON.stringify({ cases, failures })
}
runHelpRegression().catch(error => { document.getElementById('result').textContent = JSON.stringify({ cases: 0, failures: [String(error.stack || error)] }) })
