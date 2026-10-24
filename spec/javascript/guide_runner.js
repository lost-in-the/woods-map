// Exercise the shipped guide controller on a Graph tab's panel (M7): units a
// graph hands over become context fields and a chip; a finished answer gets
// copy and draft-an-issue; the history list takes the thread's place, closes
// with Escape and opens an earlier conversation. fetch is stubbed; nothing
// leaves the page.
async function runGuideRegression() {
  const failures = []
  let cases = 0
  for (const width of [1440, 960, 640, 390]) {
    const frame = document.createElement('iframe')
    frame.style.cssText = `width:${width}px;height:800px;border:0`
    document.body.append(frame)
    const doc = frame.contentDocument, win = frame.contentWindow
    doc.open()
    doc.write('<!doctype html><html lang="en" class="js"><head><meta name="csrf-token" content="t"></head><body class="wm page" data-theme="dark"><div class="page-row"><main class="page-main"><p>page</p></main></div></body></html>')
    doc.close()
    const style = doc.createElement('style')
    style.textContent = fixtureData.styles
    doc.head.append(style)
    doc.querySelector('.page-row').insertAdjacentHTML('beforeend', fixtureData.panel)
    const check = (ok, reason) => { if (!ok) failures.push({ width, reason }) }
    const wait = ms => new Promise(resolve => win.setTimeout(resolve, ms))
    const requests = []
    win.fetch = async (url, options = {}) => {
      requests.push({ url: String(url), method: options.method || 'GET' })
      const html = /conversations$/.test(url) ? fixtureData.history : fixtureData.thread
      return { ok: true, status: 200, json: async () => ({ html }) }
    }

    const Klass = win.Function('Controller', fixtureData.controller.replace(/^import .*$/m, '').replace('export default class', 'return class'))(class {})
    const guide = new Klass()
    guide.element = doc.body
    const cap = (name) => name.charAt(0).toUpperCase() + name.slice(1)
    for (const target of Klass.targets) {
      const selector = `[data-guide-target~="${target}"]`
      Object.defineProperty(guide, `${target}Target`, { get: () => doc.querySelector(selector) })
      Object.defineProperty(guide, `${target}Targets`, { get: () => [...doc.querySelectorAll(selector)] })
      Object.defineProperty(guide, `has${cap(target)}Target`, { get: () => doc.querySelector(selector) !== null })
    }
    // Stimulus would route data-action; the runner calls the actions the clicks name.
    doc.addEventListener('click', (event) => {
      const button = event.target.closest('[data-action*="guide#"]')
      if (!button) return
      const name = button.dataset.action.match(/guide#(\w+)/)[1]
      const params = {}
      for (const [key, value] of Object.entries(button.dataset)) {
        const match = key.match(/^guideParam(\w+)$/) || key.match(/^guide(\w+)Param$/)
        if (match) params[match[1].charAt(0).toLowerCase() + match[1].slice(1)] = value
      }
      guide[name]({ params, currentTarget: button, preventDefault() {} })
    })
    doc.querySelector('#wm-guide').addEventListener('keydown', (event) => guide.keydown(event))
    guide.connect()
    guide.open(false)
    const panel = doc.querySelector('#wm-guide')
    check(!panel.hidden, 'the panel opens')

    // Graph units become context.
    const selection = panel.querySelector('[data-guide-key-param="explain_selection"]')
    check(selection && selection.disabled, 'explain the selected units waits for a selection')
    doc.dispatchEvent(new win.CustomEvent('woods-map:graph-pick', { detail: { units: [
      { identifier: 'Micropost', type: 'model' }, { identifier: 'User', type: 'model' }] } }))
    const chip = panel.querySelector('[data-guide-target="nodes"]')
    check(!chip.hidden && /Micropost, User/.test(chip.textContent) && /selected/.test(chip.textContent), `the chip names the selection (${chip.textContent})`)
    const fields = [...new win.FormData(panel.querySelector('form.ask')).getAll('context[nodes][]')]
    check(JSON.stringify(fields) === JSON.stringify(['model:Micropost', 'model:User']), `the form sends typed units (${fields})`)
    check(!selection.disabled, 'the selection action is offered once units are picked')
    let cleared = 0
    doc.addEventListener('woods-map:graph-pick-clear', () => { cleared++ })
    chip.querySelector('button').click()
    check(cleared === 1, 'clear asks the graph to drop its selection')
    doc.dispatchEvent(new win.CustomEvent('woods-map:graph-pick', { detail: { units: [] } }))
    check(chip.hidden && selection.disabled && new win.FormData(panel.querySelector('form.ask')).getAll('context[nodes][]').length === 0, 'an empty selection removes the chip and the fields')

    // A finished answer offers copy and draft-an-issue; a draft offers its text only.
    const answer = guide.answerShell()
    guide.threadTarget.appendChild(answer)
    guide.current = { answer, calls: 0 }
    guide.finish(answer, 'done', { id: '0123456789abcdef', answer: 'User has many Posts.', html: '<p>User has many Posts.</p>', tool_calls: [], elapsed: 1.2,
      trail: { pin: '/woods/trail?entry=UsersController%23show&pin%5B%5D=model%3AUser', investigation: '/woods/trail?pin%5B%5D=model%3AUser&gen=1' } })
    const tools = [...answer.querySelectorAll('.answer-tools .tool')].map((b) => b.textContent)
    check(JSON.stringify(tools) === JSON.stringify(['pin', 'open as investigation', '⎘ copy', 'draft an issue']), `answer tools (${tools})`)
    check(answer.querySelector('.answer-tools a.tool').getAttribute('href').startsWith('/woods/trail?entry='), 'pin links the board')
    check(answer.querySelector('[data-controller="copy"]').dataset.copyTextValue === 'User has many Posts.', 'copy carries the Markdown')
    check(answer.querySelector('[data-action="guide#draftIssue"]').dataset.guideSourceParam === '0123456789abcdef', 'the draft names its source answer')
    const draft = guide.answerShell()
    guide.threadTarget.appendChild(draft)
    guide.finish(draft, 'done', { id: 'fedcba9876543210', kind: 'issue', answer: '# Title', html: '<p><b>Title</b></p>', tool_calls: [] })
    check(draft.classList.contains('issue') && [...draft.querySelectorAll('.answer-tools button')].map((b) => b.textContent).join() === '⎘ copy issue', 'a draft offers copy issue only')
    check(/posts nothing/.test(draft.querySelector('.answer-tools').textContent), 'a draft says the map posts nothing')
    const box = draft.querySelector('.answer-tools').getBoundingClientRect()
    const right = panel.getBoundingClientRect().right
    check(box.right <= right + 0.5, `the answer tools fit the panel (${Math.round(box.right)} > ${Math.round(right)})`)

    // The history list replaces the thread; Escape returns; opening one loads its thread.
    const toggle = panel.querySelector('[data-guide-target="historyToggle"]')
    await guide.history()
    const history = panel.querySelector('#wm-guide-history')
    check(!history.hidden && guide.threadTarget.hidden && toggle.getAttribute('aria-expanded') === 'true', 'history replaces the thread')
    check(doc.activeElement && doc.activeElement.classList.contains('hrow'), 'focus moves to the first conversation')
    check(history.scrollWidth <= history.clientWidth + 1, `the list does not scroll sideways (${history.scrollWidth} > ${history.clientWidth})`)
    doc.activeElement.dispatchEvent(new win.KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true }))
    check(history.hidden && !guide.threadTarget.hidden && !panel.hidden && doc.activeElement === toggle, 'Escape closes the list, not the panel, and returns focus')
    await guide.history()
    history.querySelector('button.hrow').click()
    await wait(20)
    check(history.hidden && /Earlier question/.test(guide.threadTarget.textContent), 'opening a conversation shows its thread')
    check(requests.some((r) => r.method === 'POST' && /\/woods\/guide\/conversations\/[0-9a-f]{16}$/.test(r.url)), 'opening posts to the conversation')

    // A spent budget disables draft-an-issue too.
    guide.threadTarget.appendChild(answer)
    guide.exhaust()
    check(guide.threadTarget.querySelector('[data-action="guide#draftIssue"]').disabled, 'a spent budget disables draft an issue')

    guide.disconnect()
    frame.remove(); cases++
  }
  document.getElementById('result').textContent = JSON.stringify({ cases, failures })
}
runGuideRegression().catch(error => { document.getElementById('result').textContent = JSON.stringify({ cases: 0, failures: [String(error.stack || error)] }) })
