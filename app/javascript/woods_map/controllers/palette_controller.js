import { Controller } from "@hotwired/stimulus"

// The search palette (B8-Search): opens on / from any page or on focus in
// the bar's search, fetches grouped hits from the pinned generation as the
// query changes, ↑ ↓ move, Enter opens, Esc closes. Without JavaScript the
// form submits to the results page.
//
// Lives on the bar's search form.
export default class extends Controller {
  static targets = ["input", "wrap", "panel"]
  static values = { url: String }

  connect() {
    this.onKeydown = (e) => this.globalKey(e)
    document.addEventListener("keydown", this.onKeydown)
    this.selected = 0
    this.hits = []
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  globalKey(event) {
    if (event.key !== "/" || event.target.matches("input, textarea, select, [contenteditable]")) return
    event.preventDefault()
    this.inputTarget.focus()
    this.inputTarget.select()
    this.open()
  }

  open() {
    this.wrapTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
    this.query()
  }

  close() {
    this.wrapTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
  }

  outside(event) {
    if (event.target === this.wrapTarget) this.close()
  }

  submit(event) {
    const hit = this.hits[this.selected]
    if (!this.wrapTarget.hidden && hit && hit.href) {
      event.preventDefault()
      window.location.assign(hit.href)
    }
  }

  key(event) {
    if (this.wrapTarget.hidden) return
    if (event.key === "ArrowDown") { this.move(1); event.preventDefault() }
    else if (event.key === "ArrowUp") { this.move(-1); event.preventDefault() }
    else if (event.key === "Escape") { this.close(); event.preventDefault() }
  }

  move(delta) {
    if (this.hits.length === 0) return
    this.selected = (this.selected + delta + this.hits.length) % this.hits.length
    this.render()
  }

  query() {
    const q = this.inputTarget.value.trim()
    clearTimeout(this.timer)
    if (q === "") { this.renderEmpty(); return }
    this.timer = setTimeout(async () => {
      try {
        const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, { headers: { Accept: "application/json" } })
        this.result = await response.json()
        this.selected = 0
        this.render()
      } catch (_) {
        this.result = { groups: [], complete: false }
        this.render()
      }
    }, 120)
  }

  renderEmpty() {
    this.hits = []
    this.panelTarget.innerHTML = `<div class="foot"><span><span class="kbd">↑</span> <span class="kbd">↓</span> move</span><span><span class="kbd">enter</span> open</span><span><span class="kbd">esc</span> close</span><span class="right">type to search units, routes, tables and files</span></div>`
  }

  render() {
    const data = this.result || { groups: [], complete: true }
    this.hits = []
    let html = ""
    for (const group of data.groups) {
      html += `<div class="grp">${this.escape(group.name)}<span class="cnt">${group.items.length} of ${group.total}</span></div>`
      for (const item of group.items) {
        const href = item.href || null
        const index = this.hits.length
        this.hits.push({ href })
        html += `<a class="hit" role="option" href="${this.escape(href || "#")}" aria-selected="${index === this.selected}" data-index="${index}"><span>${this.mark(item.label, data.query)}</span><span class="path">${this.escape(item.detail || "")}</span></a>`
      }
    }
    if (data.groups.length === 0) html += `<div class="grp">no match for ${this.escape(data.query || "")}<span class="cnt">0</span></div>`
    html += `<div class="foot"><span><span class="kbd">↑</span> <span class="kbd">↓</span> move</span><span><span class="kbd">enter</span> open</span><span><span class="kbd">esc</span> close</span><span class="right">${data.complete ? "complete" : "partial"}${data.generation ? `, gen ${data.generation}` : ""}</span></div>`
    this.panelTarget.innerHTML = html
  }

  mark(label, query) {
    const at = label.toLowerCase().indexOf(query.toLowerCase())
    if (at < 0) return this.escape(label)
    return `${this.escape(label.slice(0, at))}<mark>${this.escape(label.slice(at, at + query.length))}</mark>${this.escape(label.slice(at + query.length))}`
  }

  escape(text) {
    return String(text).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]))
  }
}
