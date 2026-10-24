// Exercise the shipped settings controller on the Code tab's markup.
async function runSettingsRegression() {
  const failures = []
  let cases = 0
  for (const width of [1440, 960, 640, 390]) {
    const frame = document.createElement('iframe')
    frame.style.cssText = `width:${width}px;height:700px;border:0`
    document.body.append(frame)
    const doc = frame.contentDocument, win = frame.contentWindow
    doc.open()
    doc.write('<!doctype html><html lang="en"><head></head><body class="wm page" data-theme="dark"><main class="page-main"></main></body></html>')
    doc.close()
    const style = doc.createElement('style')
    style.textContent = fixtureData.styles
    doc.head.append(style)
    doc.querySelector('main').innerHTML = fixtureData.html
    // A line longer than any viewport, so the unwrapped region must scroll and the wrapped one must not.
    doc.querySelector('.cv .src').textContent = 'x = "' + 'long '.repeat(80) + '"'
    const check = (ok, reason) => { if (!ok) failures.push({ width, reason }) }
    const wait = ms => new Promise(resolve => win.setTimeout(resolve, ms))
    const store = {}
    const storage = { getItem: k => (k in store ? store[k] : null), setItem: (k, v) => { store[k] = String(v) } }
    const make = (storageImpl) => {
      const Klass = win.Function('Controller', fixtureData.controller.replace(/^import .*$/m, '').replace('export default class', 'return class'))(class {})
      const instance = new Klass()
      instance.element = doc.body
      for (const target of Klass.targets || []) {
        const cap = target[0].toUpperCase() + target.slice(1)
        const find = () => doc.querySelector(`[data-settings-target~="${target}"]`)
        Object.defineProperty(instance, `${target}Target`, { get: find })
        Object.defineProperty(instance, `has${cap}Target`, { get: () => !!find() })
      }
      instance.storage = () => storageImpl
      return instance
    }
    for (const node of doc.querySelectorAll('[data-action]')) for (const action of node.dataset.action.split(' ')) {
      const match = action.match(/^(?:(\w+)->)?settings#(\w+)$/)
      if (match) node.addEventListener(match[1] || 'click', event => settings[match[2]](event))
    }
    const broken = make({ getItem: () => { throw new Error('denied') }, setItem: () => { throw new Error('denied') } })
    broken.connect(); broken.disconnect()
    check(!doc.body.dataset.codeWrap, 'refused storage leaves the defaults')

    const settings = make(storage)
    settings.connect()
    const editor = doc.querySelector('[data-settings-target="editor"]')
    const code = doc.querySelector('[data-settings-target="code"]')
    const region = doc.querySelector('.cvwrap')
    const src = doc.querySelector('.cv .src')
    check(editor.hidden && !code.hidden, 'no editor: Code at L stays the primary action')
    check(!doc.body.dataset.codeWrap && win.getComputedStyle(src).whiteSpace === 'pre', 'unwrapped by default')
    check(region.scrollWidth > region.clientWidth, 'default: one region scrolls the long line')

    const opener = doc.querySelector('[aria-controls="wm-settings"]')
    opener.focus(); opener.click()
    const dialog = doc.getElementById('wm-settings')
    check(dialog.open && doc.activeElement?.name === 'lens' && doc.activeElement.checked, 'opens modally with the current lens focused')
    const box = dialog.getBoundingClientRect()
    check(box.left >= 0 && box.right <= width && dialog.scrollWidth <= dialog.clientWidth, 'dialog fits the viewport')

    const form = dialog.querySelector('form')
    const fire = (el) => el.dispatchEvent(new win.Event('change', { bubbles: true }))
    form.elements.wrap.checked = true; fire(form.elements.wrap)
    check(doc.body.dataset.codeWrap === 'on' && win.getComputedStyle(src).whiteSpace === 'pre-wrap', 'wrap is an opt-in')
    check(region.scrollWidth <= region.clientWidth + 1, 'wrapped: the same region no longer scrolls')
    check(JSON.parse(store['woods_map.settings']).wrap === true, 'wrap is kept per browser')
    form.querySelector('input[name=size][value=large]').checked = true; fire(form.querySelector('input[name=size][value=large]'))
    check(win.getComputedStyle(doc.querySelector('.cv')).fontSize === '15px', 'large font size')

    form.elements.editor.value = 'vscode'; fire(form.elements.editor)
    check(editor.hidden && !code.hidden, 'a preset without a checkout path makes no link')
    form.elements.root.value = '/home/me/my app/'; fire(form.elements.root)
    check(!editor.hidden && code.hidden && editor.getAttribute('href') === `vscode://file/home/me/my%20app/${editor.dataset.file}:${editor.dataset.line}`, 'VS Code link from the checkout path')
    check(editor.textContent === `In editor at L${editor.dataset.line}`, 'editor button names the line')
    win.location.hash = '#L5'; await wait(30)
    check(editor.textContent === 'In editor at L5' && editor.getAttribute('href').endsWith(':5'), 'the targeted line follows the hash')
    form.elements.editor.value = 'custom'; fire(form.elements.editor)
    const custom = dialog.querySelector('[data-settings-target="custom"]')
    check(!custom.hidden && editor.hidden, 'custom shows its template field')
    form.elements.template.value = 'javascript:alert(1)//{file}'; fire(form.elements.template)
    check(editor.hidden && /not allowed/.test(dialog.querySelector('[data-settings-target="preview"]').textContent), 'unsafe schemes are refused')
    form.elements.template.value = 'myed://open?f={file}&l={line}'; fire(form.elements.template)
    check(!editor.hidden && editor.getAttribute('href') === `myed://open?f=${editor.dataset.file}&l=5`, 'custom template')

    settings.close(); await wait(30)
    check(!dialog.open && doc.activeElement === opener, 'closing restores the opener')

    const again = make(storage)
    settings.disconnect(); delete doc.body.dataset.codeWrap; delete doc.body.dataset.codeSize
    again.connect()
    check(doc.body.dataset.codeWrap === 'on' && doc.body.dataset.codeSize === 'large' && !editor.hidden, 'a new page applies the saved settings')
    again.disconnect()
    win.location.hash = ''
    frame.remove(); cases++
  }
  document.getElementById('result').textContent = JSON.stringify({ cases, failures })
}
runSettingsRegression().catch(error => { document.getElementById('result').textContent = JSON.stringify({ cases: 0, failures: [String(error.stack || error)] }) })
