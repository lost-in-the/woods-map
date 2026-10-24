import { Controller } from "@hotwired/stimulus"

// The guide panel (B8-Guide, M7). Opens and closes beside the page (the bar's
// Guide button or g), sends a question or an action with the page's context,
// and reads the answer from the server as events with EventSource: tool cards
// as calls start and end, text as it streams, then the finished answer the
// server rendered (links only to known identifiers). No Turbo and no cable;
// the policy's connect-src 'self' covers the stream. Text from the stream is
// set as text; only the server's rendered answers are set as HTML.
const FINISHED = ["done", "limited", "cancelled", "failed"]

export default class extends Controller {
  static targets = ["panel", "toggle", "thread", "empty", "form", "input", "submit", "stop", "reset",
    "calls", "tokens", "lines", "linesField", "needsLines", "answer", "exhausted"]

  connect() {
    if (!this.hasPanelTarget) return
    this.onSelection = () => this.selectionChanged()
    document.addEventListener("selectionchange", this.onSelection)
    this.linesFromHash()
    if (this.remembered()) this.open(false)
    const pending = this.answerTargets.find((answer) => answer.dataset.stream)
    if (pending) this.stream(pending, pending.dataset.stream, pending.dataset.cancel)
  }

  disconnect() {
    document.removeEventListener("selectionchange", this.onSelection)
    this.source?.close()
  }

  toggle() {
    if (!this.hasPanelTarget) return
    this.panelTarget.hidden ? this.open(true) : this.close()
  }

  open(focus) {
    this.panelTarget.hidden = false
    document.body.classList.add("guide-open")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "true")
    this.remember(true)
    if (focus && this.hasInputTarget && !this.inputTarget.disabled) this.inputTarget.focus()
  }

  close() {
    this.panelTarget.hidden = true
    document.body.classList.remove("guide-open")
    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-expanded", "false")
      this.toggleTarget.focus()
    }
    this.remember(false)
  }

  // Escape inside the panel closes it.
  keydown(event) {
    if (event.key === "Escape" && !this.panelTarget.hidden && this.panelTarget.contains(event.target)) this.close()
  }

  submitOnEnter(event) {
    if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      event.preventDefault()
      this.formTarget.requestSubmit()
    }
  }

  ask(event) {
    event.preventDefault()
    if (this.busy) return
    const question = this.inputTarget.value.trim()
    if (question === "") { this.inputTarget.focus(); return }
    this.send(null)
  }

  run(event) {
    if (this.busy) return
    this.send(event.params.key)
  }

  async send(actionKey) {
    const body = new FormData(this.formTarget)
    if (actionKey) body.set("action_key", actionKey)
    this.setBusy(true)
    try {
      const response = await fetch(this.panelTarget.dataset.askUrl, {
        method: "POST", body, credentials: "same-origin",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken() }
      })
      const data = await response.json().catch(() => ({}))
      if (!response.ok) {
        this.note(data.message || `The guide refused the question (HTTP ${response.status}).`, data.error === "budget")
        this.setBusy(false)
        if (data.error === "budget") this.exhaust()
        return
      }
      this.inputTarget.value = ""
      if (this.hasEmptyTarget) this.emptyTarget.remove()
      this.threadTarget.insertAdjacentHTML("beforeend", data.html)
      const answer = this.answerShell()
      this.threadTarget.appendChild(answer)
      this.stream(answer, data.stream, data.cancel)
    } catch (_) {
      this.note("The guide could not be reached.")
      this.setBusy(false)
    }
  }

  // An answer element the stream fills: who, cards, live text with a cursor.
  answerShell() {
    const answer = document.createElement("div")
    answer.className = "msg answer"
    answer.dataset.guideTarget = "answer"
    answer.innerHTML = '<span class="who">guide</span><div class="calls"></div><div class="text"><p class="live cursor"></p></div>'
    return answer
  }

  stream(answer, url, cancelUrl) {
    this.setBusy(true)
    this.current = { answer, cancelUrl, calls: 0 }
    answer.setAttribute("aria-busy", "true")
    delete answer.dataset.stream
    if (!answer.querySelector(".live")) {
      const text = answer.querySelector(".text")
      const live = document.createElement("p")
      live.className = "live cursor"
      text.replaceChildren(live)
    }
    const source = new EventSource(url)
    this.source = source
    source.addEventListener("tool", (event) => this.tool(answer, JSON.parse(event.data)))
    source.addEventListener("delta", (event) => {
      answer.querySelector(".live")?.append(JSON.parse(event.data).text)
      this.scroll()
    })
    for (const state of FINISHED) {
      source.addEventListener(state, (event) => this.finish(answer, state, JSON.parse(event.data)))
    }
    source.onerror = () => {
      if (this.source !== source) return
      source.close()
      this.finish(answer, "failed", { message: "The answer stream was interrupted." })
    }
  }

  tool(answer, call) {
    const calls = answer.querySelector(".calls")
    let card = calls.querySelector(`[data-call="${CSS.escape(call.id)}"]`)
    if (!card) {
      card = document.createElement("div")
      card.className = "call"
      card.dataset.call = call.id
      card.innerHTML = '<span class="g" role="img"></span><span><span class="name"></span><span class="mut"></span></span><span class="t"></span>'
      calls.appendChild(card)
      this.current.calls += 1
      this.calls(this.current.calls)
    }
    const glyph = card.querySelector(".g")
    glyph.className = `g${call.state === "running" ? " run" : ""}${call.state === "failed" ? " fail" : ""}`
    glyph.textContent = call.state === "running" ? "◌" : call.state === "failed" ? "✕" : "✓"
    glyph.setAttribute("aria-label", call.state)
    card.querySelector(".name").textContent = call.name
    card.querySelector(".mut").textContent = `(${call.args || ""})`
    card.querySelector(".t").textContent = call.ms === undefined ? "" : `${(call.ms / 1000).toFixed(1)}s`
    this.scroll()
  }

  finish(answer, state, turn) {
    this.source?.close()
    this.source = null
    answer.dataset.state = state
    answer.removeAttribute("aria-busy")
    const calls = (turn.tool_calls || []).length
    const who = ["guide", calls ? `${calls} tool ${calls === 1 ? "call" : "calls"}` : null, turn.elapsed !== undefined ? `${turn.elapsed} s` : null]
    answer.querySelector(".who").textContent = who.filter(Boolean).join(", ")
    const text = answer.querySelector(".text")
    if (turn.html !== undefined) {
      text.innerHTML = turn.html
    } else {
      text.querySelector(".live")?.classList.remove("cursor")
    }
    if (state === "limited" && turn.limit) this.finding(answer, "note limit", "Limit reached.", turn.limit.message)
    if (state === "cancelled") this.finding(answer, "note", "Stopped.", "")
    if (state === "failed") this.finding(answer, "risk", "The guide could not answer.", turn.error || turn.message || "")
    if (turn.budget) {
      this.calls(turn.budget.tool_calls)
      this.tokens(turn.budget.session_tokens)
    }
    this.setBusy(false)
    if (turn.limit?.kind === "tokens") this.exhaust()
    this.scroll()
  }

  async stop() {
    const current = this.current
    if (!current || !this.busy) return
    this.source?.close()
    this.source = null
    try {
      await fetch(current.cancelUrl, { method: "POST", credentials: "same-origin", headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken() } })
    } catch (_) { /* the closed stream stops the answer too */ }
    this.finish(current.answer, "cancelled", {})
  }

  async reset() {
    if (this.busy) await this.stop()
    try {
      await fetch(this.panelTarget.dataset.resetUrl, { method: "DELETE", credentials: "same-origin", headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken() } })
    } catch (_) { return }
    this.threadTarget.replaceChildren()
    this.calls(0)
    this.inputTarget.focus()
  }

  // Selected code lines become context: the rows carry id="L<n>".
  selectionChanged() {
    const selection = document.getSelection()
    if (!selection || selection.isCollapsed || !selection.anchorNode) return
    const rowOf = (node) => (node.nodeType === 1 ? node : node.parentElement)?.closest('.cv [id^="L"]')
    const first = rowOf(selection.anchorNode)
    const last = rowOf(selection.focusNode)
    if (!first || !last) return
    const numbers = [first, last].map((row) => parseInt(row.id.slice(1), 10)).sort((a, b) => a - b)
    this.setLines(numbers[0], numbers[1])
  }

  linesFromHash() {
    const match = /^#L(\d+)(?:-L?(\d+))?$/.exec(window.location.hash)
    if (match) this.setLines(parseInt(match[1], 10), parseInt(match[2] || match[1], 10))
  }

  setLines(first, last) {
    if (!this.hasLinesFieldTarget) return
    this.linesFieldTarget.value = first === last ? `${first}` : `${first}-${last}`
    if (this.hasLinesTarget) {
      const label = first === last ? `L${first}` : `L${first}–L${last}`
      const bold = document.createElement("b")
      bold.textContent = label
      this.linesTarget.replaceChildren(bold, " selected")
      this.linesTarget.hidden = false
    }
    for (const button of this.needsLinesTargets) {
      if (!this.exhausted) button.disabled = false
      button.removeAttribute("title")
    }
  }

  setBusy(busy) {
    this.busy = busy
    if (this.exhausted) return
    this.submitTarget.disabled = busy
    this.stopTarget.hidden = !busy
    this.panelTarget.querySelectorAll(".acts .btn").forEach((button) => {
      button.disabled = busy || (this.needsLinesTargets.includes(button) && this.linesFieldTarget.value === "")
    })
  }

  exhaust() {
    this.exhausted = true
    this.inputTarget.disabled = true
    this.submitTarget.disabled = true
    this.stopTarget.hidden = true
    this.panelTarget.querySelectorAll(".acts .btn").forEach((button) => { button.disabled = true })
  }

  calls(count) {
    if (this.hasCallsTarget) this.callsTarget.textContent = `${count} of ${this.panelTarget.dataset.toolLimit}`
  }

  tokens(count) {
    if (this.hasTokensTarget) this.tokensTarget.textContent = count >= 1000 ? `${(Math.floor(count / 100) / 10).toFixed(1)}k` : `${count}`
  }

  finding(answer, kind, lead, text) {
    const note = document.createElement("div")
    note.className = `finding ${kind}`
    const bold = document.createElement("b")
    bold.textContent = lead
    note.append(bold, text ? ` ${text}` : "")
    answer.appendChild(note)
  }

  note(message, persistent = false) {
    const note = document.createElement("div")
    note.className = "finding note"
    note.textContent = message
    this.threadTarget.appendChild(note)
    if (!persistent) setTimeout(() => note.remove(), 8000)
    this.scroll()
  }

  scroll() {
    this.threadTarget.scrollTop = this.threadTarget.scrollHeight
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  remembered() {
    try { return window.localStorage.getItem("woods-map-guide") === "open" } catch (_) { return false }
  }

  remember(open) {
    try { window.localStorage.setItem("woods-map-guide", open ? "open" : "closed") } catch (_) { /* private mode */ }
  }
}
