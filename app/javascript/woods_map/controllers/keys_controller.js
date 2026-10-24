import { Controller } from "@hotwired/stimulus"

// Page keys that are not owned by a component: c / u / d pick the lifecycle
// event, s / f / l / k its view (sequence, flowchart, lanes, C4 dynamic), 1 / 2 / 3 the depth,
// y activates the copy tool the page marks with data-key="y" (the one its
// status bar names), g opens or closes the guide when the host enabled it.
// Each is a link or a copy tool on the page, so the key only follows it.
// j / k from outside every table step into the page's first row table (the
// rows controller moves within it), first row or last.
export default class extends Controller {
  connect() {
    this.onKey = (e) => this.key(e)
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
  }

  key(event) {
    if (event.defaultPrevented || event.isComposing || event.metaKey || event.ctrlKey || event.altKey) return
    if (event.target.closest('input, textarea, select, [contenteditable]:not([contenteditable="false"]), [aria-modal="true"], dialog[open]')) return
    const map = { c: "[aria-label=entry] a:nth-child(1)", u: "[aria-label=entry] a:nth-child(2)", d: "[aria-label=entry] a:nth-child(3)", s: "[aria-label=view] a:nth-child(1)", f: "[aria-label=view] a:nth-child(2)", l: "[aria-label=view] a:nth-child(3)", k: "[aria-label=view] a:nth-child(4)", "[": "[data-key=prev-chunk]", "]": "[data-key=next-chunk]", 1: "[aria-label=Depth] a:nth-child(1)", 2: "[aria-label=Depth] a:nth-child(2)", 3: "[aria-label=Depth] a:nth-child(3)" }
    if (event.key === "g") {
      const toggle = this.element.querySelector("[data-guide-target=toggle]:not([disabled])")
      if (toggle) { toggle.click(); event.preventDefault() }
      return
    }
    if (event.key === "y") {
      const tool = this.element.querySelector('[data-key~="y"][data-copy-text-value]')
      if (tool) { tool.click(); event.preventDefault() }
      return
    }
    const selector = map[event.key]
    const link = selector && this.element.querySelector(selector)
    if (link) { link.click(); event.preventDefault(); return }
    if ((event.key === "j" || event.key === "k") && this.enterRows(event.key === "j")) event.preventDefault()
  }

  enterRows(first) {
    if (document.activeElement?.closest?.('[data-controller~="rows"]')) return false
    const section = [...this.element.querySelectorAll('[data-controller~="rows"]')].find((el) => el.querySelector("tbody > tr:not(.sub)") && el.getClientRects().length)
    if (!section) return false
    const rows = [...section.querySelectorAll("tbody > tr:not(.sub)")]
    const row = first ? rows[0] : rows[rows.length - 1]
    const target = row.querySelector(".tgl, input, a, button") || row
    if (target === row && !row.hasAttribute("tabindex")) row.tabIndex = -1
    target.focus()
    return true
  }
}
