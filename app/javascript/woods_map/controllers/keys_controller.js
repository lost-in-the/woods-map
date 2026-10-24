import { Controller } from "@hotwired/stimulus"

// Page keys that are not owned by a component: c / u / d pick the lifecycle
// event, 1 / 2 / 3 the depth, y activates the copy tool the page marks with
// data-key="y" (the one its status bar names). Each is a link or a copy tool
// on the page, so the key only follows it.
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
    const map = { c: "[aria-label=entry] a:nth-child(1)", u: "[aria-label=entry] a:nth-child(2)", d: "[aria-label=entry] a:nth-child(3)", 1: "[aria-label=Depth] a:nth-child(1)", 2: "[aria-label=Depth] a:nth-child(2)", 3: "[aria-label=Depth] a:nth-child(3)" }
    if (event.key === "y") {
      const tool = this.element.querySelector('[data-key~="y"][data-copy-text-value]')
      if (tool) { tool.click(); event.preventDefault() }
      return
    }
    const selector = map[event.key]
    if (!selector) return
    const link = this.element.querySelector(selector)
    if (link) { link.click(); event.preventDefault() }
  }
}
