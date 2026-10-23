// Actual request markup and shipped controller in isolated real-browser viewports.
// Bind only the template's declared Stimulus actions; exercise native focus events
// and DOM click activation without starting a server or following test links.
async function runPaletteRegression() {
  const failures = []
  let cases = 0
  for (const page of fixtureData.pages) for (const width of [1440, 960, 640, 390]) {
    const frame = document.createElement("iframe")
    frame.style.cssText = `width:${width}px;height:700px;border:0`
    document.body.append(frame)
    const doc = frame.contentDocument
    doc.open()
    doc.write('<!doctype html><html lang="en"><head></head><body class="wm page" data-theme="dark"></body></html>')
    doc.close()
    const style = doc.createElement("style")
    style.textContent = fixtureData.styles
    doc.head.append(style)
    doc.body.innerHTML = page.html + `<a id="outside" href="${page.mount}/units/model/User">source destination</a>`
    const win = frame.contentWindow
    const Palette = win.Function("Controller", fixtureData.controller.replace(/^import .*$/m, "").replace("export default class", "return class"))(class {})
    const palette = new Palette()
    const form = doc.querySelector('[data-controller="palette"]')
    palette.element = form
    for (const name of Palette.targets) Object.defineProperty(palette, `${name}Target`, {
      get: () => form.querySelector(`[data-palette-target~="${name}"]`)
    })
    palette.urlValue = form.dataset.paletteUrlValue
    const source = [...doc.querySelectorAll('.cv .src')].map(node => node.innerHTML)
    const details = { mount: page.mount, lens: page.lens, width }
    const check = (ok, reason) => { if (!ok) failures.push({ ...details, reason }) }
    for (const node of form.querySelectorAll('[data-action]')) bind(node)
    bind(form)
    function bind(node) {
      for (const action of (node.dataset.action || '').split(' ')) {
        const match = action.match(/^(\w+)->palette#(\w+)$/)
        if (match) node.addEventListener(match[1], event => palette[match[2]](event))
      }
    }
    const input = palette.inputTarget
    const outside = doc.getElementById('outside')
    const key = (node, value) => {
      const event = new win.KeyboardEvent('keydown', { key: value, bubbles: true, cancelable: true })
      node.dispatchEvent(event)
      return event
    }
    const emptyListboxes = () => [...doc.querySelectorAll('[role=listbox]')].filter(node => node.getClientRects().length && !node.querySelector('[role=option]')).length
    palette.connect()
    if (!input.getClientRects().length) {
      outside.focus()
      const shortcut = key(outside, '/')
      check(!shortcut.defaultPrevented && palette.wrapTarget.hidden && doc.activeElement === outside, 'hidden mobile search does not capture shortcut or focus')
      palette.disconnect()
      frame.remove()
      cases++
      continue
    }
    outside.focus()
    input.focus()
    if (input.getClientRects().length) {
      check(!palette.wrapTarget.hidden, 'focus opens search help')
      check(emptyListboxes() === 0, 'empty search exposes a listbox without options')
      outside.focus()
      check(palette.wrapTarget.hidden && input.getAttribute('aria-expanded') === 'false', 'focus leaving search closes popup')
      input.focus()
      key(input, 'Escape')
      check(palette.wrapTarget.hidden && doc.activeElement === input, 'Escape from input closes without moving focus')
    }
    input.value = 'user'
    // Resolve the real query timer without any network requests.
    win.fetch = async () => ({ json: async () => ({ query: 'user', complete: true, groups: [{ name: 'models', total: 2,
      items: [{ label: 'User', detail: 'model', href: `${page.mount}/units/model/User` },
              { label: 'UserProfile', detail: 'model', href: `${page.mount}/units/model/UserProfile` }] }] }) })
    palette.open()
    await new Promise(resolve => win.setTimeout(resolve, 150))
    const options = [...doc.querySelectorAll('[role=option]')]
    check(options.length === 2, 'query renders two typed choices')
    check(options.every(node => node.closest('[role=listbox]')), 'every option belongs to listbox')
    check(!doc.querySelector('[role=listbox] .foot'), 'keyboard hints are outside listbox')
    key(input, 'ArrowDown')
    const selected = doc.getElementById(input.getAttribute('aria-activedescendant'))
    check(selected?.getAttribute('aria-selected') === 'true' && selected.textContent.includes('UserProfile'), 'combobox identifies keyboard-selected option')
    for (const action of ['typing', 'ArrowDown', 'click']) {
      key(input, 'Escape')
      check(palette.wrapTarget.hidden && doc.activeElement === input, `${action} starts dismissed with input focus`)
      if (action === 'typing') {
        input.value = 'profile'
        input.dispatchEvent(new win.Event('input', { bubbles: true }))
      } else if (action === 'ArrowDown') {
        check(key(input, 'ArrowDown').defaultPrevented, 'ArrowDown reopening prevents page scrolling')
      } else {
        input.click()
      }
      check(!palette.wrapTarget.hidden && palette.hits.length === 0, `${action} reopens without stale choices`)
      await new Promise(resolve => win.setTimeout(resolve, 150))
      check(!palette.wrapTarget.hidden && input.getAttribute('aria-expanded') === 'true' &&
        doc.getElementById(input.getAttribute('aria-activedescendant'))?.getAttribute('aria-selected') === 'true', `${action} exposes fetched suggestions and selection`)
      palette.open()
    }
    let finishDismissed
    const fetchResults = win.fetch
    win.fetch = () => new Promise(resolve => { finishDismissed = resolve })
    input.value = 'dismissed'
    input.dispatchEvent(new win.Event('input', { bubbles: true }))
    await new Promise(resolve => win.setTimeout(resolve, 150))
    key(input, 'Escape')
    finishDismissed(await fetchResults())
    await new Promise(resolve => win.setTimeout(resolve, 0))
    check(palette.wrapTarget.hidden && palette.hits.length === 0 && !input.hasAttribute('aria-activedescendant'), 'late response after Escape cannot reopen or restore choices')
    input.value = 'older'
    palette.open()
    await new Promise(resolve => win.setTimeout(resolve, 150))
    key(input, 'Escape')
    win.fetch = fetchResults
    input.value = 'newer'
    input.dispatchEvent(new win.Event('input', { bubbles: true }))
    await new Promise(resolve => win.setTimeout(resolve, 150))
    const currentChoices = palette.panelTarget.innerHTML
    finishDismissed({ json: async () => ({ query: 'older', complete: true, groups: [] }) })
    await new Promise(resolve => win.setTimeout(resolve, 0))
    check(!palette.wrapTarget.hidden && palette.panelTarget.innerHTML === currentChoices, 'late dismissed response cannot replace reopened query choices')
    palette.open()
    await new Promise(resolve => win.setTimeout(resolve, 150))
    const first = doc.querySelector('[role=option]')
    if (first.getClientRects().length) {
      first.focus()
      check(!palette.wrapTarget.hidden, 'focus moving into result preserves popup')
      key(first, 'Escape')
      check(palette.wrapTarget.hidden && doc.activeElement === input, 'Escape from result closes and returns to search')
      check(!input.hasAttribute('aria-activedescendant'), 'closed popup clears active descendant')
    }
    palette.open()
    await new Promise(resolve => win.setTimeout(resolve, 150))
    const pointer = doc.querySelector('[role=option]')
    let click
    doc.addEventListener('click', event => {
      if (event.target.closest('[role=option]') !== pointer) return
      click = { prevented: event.defaultPrevented, href: pointer.getAttribute('href') }
      event.preventDefault()
    })
    pointer.click()
    check(click && !click.prevented && click.href === `${page.mount}/units/model/User`, 'pointer activation preserves result destination')
    pointer.dispatchEvent(new win.MouseEvent('click', { bubbles: true, cancelable: true, metaKey: true }))
    check(click && !click.prevented, 'modifier pointer activation is not intercepted')
    palette.wrapTarget.click()
    check(palette.wrapTarget.hidden, 'pointer backdrop closes popup')
    input.value = 'changed'
    palette.open()
    check(palette.hits.length === 0 && !doc.querySelector('[role=listbox]:not([hidden])') && input.getAttribute('aria-expanded') === 'false', 'pending query cannot display or submit stale choices')
    palette.close()
    input.value = ''
    palette.open()
    check(palette.hits.length === 0 && emptyListboxes() === 0, 'empty query clears stale choices without invalid listbox')
    input.value = 'missing'
    win.fetch = async () => ({ json: async () => ({ query: 'missing', complete: true, groups: [] }) })
    palette.open()
    await new Promise(resolve => win.setTimeout(resolve, 150))
    check(emptyListboxes() === 0 && palette.hits.length === 0 && palette.panelTarget.textContent.includes('no match'), 'no-results status is not an empty listbox')
    let finish
    win.fetch = () => new Promise(resolve => { finish = resolve })
    input.value = 'late'
    input.focus()
    palette.open()
    await new Promise(resolve => win.setTimeout(resolve, 150))
    outside.focus()
    finish({ json: async () => ({ query: 'late', complete: true, groups: [{ name: 'models', total: 1,
      items: [{ label: 'Late', detail: 'model', href: `${page.mount}/units/model/Late` }] }] }) })
    await new Promise(resolve => win.setTimeout(resolve, 0))
    check(palette.wrapTarget.hidden && palette.hits.length === 0 && !input.hasAttribute('aria-activedescendant'), 'late response after focus exit cannot restore choices')
    check(JSON.stringify([...doc.querySelectorAll('.cv .src')].map(node => node.innerHTML)) === JSON.stringify(source), 'source bytes and anchors unchanged')
    palette.disconnect()
    frame.remove()
    cases++
  }
  document.getElementById('result').textContent = JSON.stringify({ cases, failures })
}
runPaletteRegression().catch(error => { document.getElementById('result').textContent = JSON.stringify({ cases: 0, failures: [String(error.stack || error)] }) })
