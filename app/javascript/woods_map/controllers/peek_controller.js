import { Controller } from "@hotwired/stimulus"

// The peek drawer (B8-Code): p on a focused reference link, or Alt+click,
// fetches the target's first lines and opens them under the current row;
// ✕ or Escape closes and puts focus back on the reference that opened it.
// A plain click still navigates.
export default class extends Controller {
  connect() {
    this.onKey = (e) => this.key(e)
    this.onClick = (e) => this.click(e)
    this.element.addEventListener("keydown", this.onKey)
    this.element.addEventListener("click", this.onClick)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.onKey)
    this.element.removeEventListener("click", this.onClick)
  }

  key(event) {
    if (event.key === "Escape") { this.close(); return }
    if (event.key !== "p") return
    const link = event.target.closest(".cv .src a[href]")
    if (link) { event.preventDefault(); this.openFor(link) }
  }

  click(event) {
    const link = event.target.closest(".cv .src a[href]")
    if (link && event.altKey) { event.preventDefault(); this.openFor(link) }
  }

  async openFor(link) {
    this.remove()
    this.opener = link
    const row = link.closest(".row")
    if (!row) return
    try {
      const response = await fetch(this.constructor.peekUrl(link.getAttribute("href")), { headers: { Accept: "text/html" } })
      if (!response.ok) return
      const html = await response.text()
      const holder = document.createElement("div")
      holder.innerHTML = html
      this.peek = holder.firstElementChild
      row.insertAdjacentElement("afterend", this.peek)
      this.peek.querySelector("a, button")?.focus()
    } catch (_) {
      this.peek = null
    }
  }

  // The unit's peek route: a reference link may carry a line (#L48, a method
  // link), which the peek opens at, or a query (?since=), which it drops.
  static peekUrl(href) {
    const url = new URL(href, window.location.href)
    const line = /^#L(\d+)$/.exec(url.hash)
    // A trailing slash belongs to the identifier (GET /); the route keeps it.
    return `${url.pathname}/peek${line ? `?line=${line[1]}` : ""}`
  }

  close() {
    if (!this.peek) return
    this.remove()
    if (this.opener?.isConnected) this.opener.focus()
  }

  remove() {
    if (this.peek) { this.peek.remove(); this.peek = null }
  }
}
