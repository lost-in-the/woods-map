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
    this.onFocusout = (e) => { if (!this.element.contains(e.relatedTarget)) this.close() }
    this.element.addEventListener("focusout", this.onFocusout)
    this.request = 0
    this.selected = 0
    this.hits = []
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    this.element.removeEventListener("focusout", this.onFocusout)
    this.close()
  }

  globalKey(event) {
    if (event.key === "Escape" && !event.defaultPrevented && !this.wrapTarget.hidden) { this.dismiss(event); return }
    if (event.key !== "/" || event.target.matches("input, textarea, select, [contenteditable]")) return
    if (event.target.closest('[aria-modal="true"]') || !this.inputTarget.getClientRects().length) return
    event.preventDefault()
    this.inputTarget.focus()
    this.inputTarget.select()
    this.open()
  }

  open() {
    if (!this.inputTarget.getClientRects().length) return
    this.wrapTarget.hidden = false
    this.query()
  }

  reopen() {
    if (this.wrapTarget.hidden) this.open()
  }

  close() {
    clearTimeout(this.timer)
    this.request++
    this.wrapTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
  }

  dismiss(event) {
    if (this.wrapTarget.contains(document.activeElement)) this.inputTarget.focus()
    this.close()
    event.preventDefault()
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
    if (this.wrapTarget.hidden && event.key === "ArrowDown") this.reopen()
    if (this.wrapTarget.hidden) return
    if (event.key === "ArrowDown") { this.move(1); event.preventDefault() }
    else if (event.key === "ArrowUp") { this.move(-1); event.preventDefault() }
    else if (event.key === "Escape") this.dismiss(event)
  }

  move(delta) {
    if (this.hits.length === 0) return
    this.selected = (this.selected + delta + this.hits.length) % this.hits.length
    this.render()
  }

  query() {
    const q = this.inputTarget.value.trim()
    const request = ++this.request
    clearTimeout(this.timer)
    if (q === "") { this.renderEmpty(); return }
    this.hits = []
    this.renderPanel("", "searching…")
    this.timer = setTimeout(async () => {
      try {
        const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, { headers: { Accept: "application/json" } })
        const result = await response.json()
        if (request !== this.request) return
        this.result = result
        this.selected = 0
        this.render()
      } catch (_) {
        if (request !== this.request) return
        this.result = { groups: [], complete: false }
        this.render()
      }
    }, 120)
  }

  renderEmpty() {
    this.hits = []
    this.renderPanel("", "type to search units, routes, tables and files")
  }

  render() {
    const data = this.result || { groups: [], complete: true }
    this.hits = []
    let html = ""
    for (const group of data.groups) {
      html += `<div role="group" aria-label="${this.escape(group.name)}"><div class="grp" aria-hidden="true">${this.escape(group.name)}<span class="cnt">${group.items.length} of ${group.total}</span></div>`
      for (const item of group.items) {
        const href = item.href || null
        const index = this.hits.length
        this.hits.push({ href })
        html += `<a class="hit" role="option" id="${this.optionId(index)}" tabindex="-1" href="${this.escape(href || "#")}" aria-selected="${index === this.selected}" data-index="${index}"><span>${this.mark(item.label, data.query)}</span><span class="path">${this.escape(item.detail || "")}</span></a>`
      }
      html += "</div>"
    }
    const coverage = `${data.complete ? "complete" : "partial"}${data.generation ? `, gen ${data.generation}` : ""}`
    const status = this.hits.length ? coverage : `no match for ${this.escape(data.query || "")}; ${coverage}`
    this.renderPanel(html, status)
  }

  optionId(index) {
    return `${this.inputTarget.getAttribute("aria-controls")}-option-${index}`
  }

  renderPanel(html, status) {
    const id = this.escape(this.inputTarget.getAttribute("aria-controls"))
    this.panelTarget.innerHTML = `<div id="${id}" role="listbox" aria-label="Search palette"${this.hits.length ? "" : " hidden"}>${html}</div><div class="foot"><span><span class="kbd">↑</span> <span class="kbd">↓</span> move</span><span><span class="kbd">enter</span> open</span><span><span class="kbd">esc</span> close</span><span class="right" role="status">${status}</span></div>`
    const expanded = !this.wrapTarget.hidden && this.hits.length > 0
    this.inputTarget.setAttribute("aria-expanded", String(expanded))
    if (expanded) this.inputTarget.setAttribute("aria-activedescendant", this.optionId(this.selected))
    else this.inputTarget.removeAttribute("aria-activedescendant")
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
