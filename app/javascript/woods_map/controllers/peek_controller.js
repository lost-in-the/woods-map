import { Controller } from "@hotwired/stimulus"

// The peek drawer (B8-Code): p on a focused reference link, or Alt+click,
// fetches the target's first lines and opens them under the current row;
// ✕ or Escape closes. A plain click still navigates.
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
    this.close()
    const row = link.closest(".row")
    if (!row) return
    try {
      const response = await fetch(`${link.getAttribute("href")}/peek`, { headers: { Accept: "text/html" } })
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

  close() {
    if (this.peek) { this.peek.remove(); this.peek = null }
  }
}
