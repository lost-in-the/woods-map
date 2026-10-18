import { Controller } from "@hotwired/stimulus"

// The file-tree explorer (D-18): fold directories, filter paths in place with
// the matches marked and the counts turned into "3 of 398", collapse to the
// 28px strip and back (persisted per browser), keep the current file in view.
// Keys: ↑ ↓ move, ← → fold, Enter opens, t toggles the strip.
const STORAGE = "woods-map.tree"

export default class extends Controller {
  static targets = ["filter", "row", "head"]

  connect() {
    this.onKey = this.onKey.bind(this)
    this.element.addEventListener("keydown", this.onKey)
    try { if (localStorage.getItem(STORAGE) === "strip") this.element.classList.add("strip") } catch (_) {}
    this.revealCurrent()
  }

  // Bring the current file into view inside the nearest scrolling box (the
  // sidebar or the sheet) without moving the page itself.
  revealCurrent() {
    const current = this.element.querySelector("[aria-current]")
    if (!current) return
    let box = this.element
    while (box && box !== document.body) {
      const overflow = getComputedStyle(box).overflowY
      if ((overflow === "auto" || overflow === "scroll") && box.scrollHeight > box.clientHeight) break
      box = box.parentElement
    }
    if (!box || box === document.body) return
    const target = current.getBoundingClientRect().top - box.getBoundingClientRect().top + box.scrollTop
    box.scrollTop = Math.max(0, target - box.clientHeight / 2)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.onKey)
  }

  fold(event) {
    const dir = event.currentTarget
    this.setFold(dir, dir.getAttribute("aria-expanded") !== "true")
  }

  setFold(dir, open) {
    dir.setAttribute("aria-expanded", String(open))
    const chevron = dir.querySelector(".c")
    if (chevron) chevron.textContent = open ? "▾" : "▸"
    const level = this.level(dir)
    let row = dir.nextElementSibling
    let hiddenBelow = Infinity
    while (row && this.level(row) > level) {
      const rowLevel = this.level(row)
      if (rowLevel <= hiddenBelow) hiddenBelow = Infinity
      const parentClosed = rowLevel > hiddenBelow
      row.hidden = !open || parentClosed || row.dataset.filtered === "out"
      if (row.classList.contains("d") && row.getAttribute("aria-expanded") === "false" && !row.hidden) hiddenBelow = rowLevel
      row = row.nextElementSibling
    }
  }

  filter() {
    const query = this.filterTarget.value.trim().toLowerCase()
    const rows = this.rowTargets
    const counts = new Map()
    rows.forEach((row) => {
      const name = row.querySelector(".nm")
      if (!name) return
      name.textContent = name.dataset.name || name.textContent
      name.dataset.name = name.textContent
      if (!row.classList.contains("f")) return
      const path = (row.dataset.path || "").toLowerCase()
      const hit = query === "" || path.includes(query)
      row.dataset.filtered = hit ? "in" : "out"
      row.hidden = !hit
      if (hit && query !== "") {
        const at = name.dataset.name.toLowerCase().indexOf(query)
        if (at >= 0) name.innerHTML = `${this.escape(name.dataset.name.slice(0, at))}<mark>${this.escape(name.dataset.name.slice(at, at + query.length))}</mark>${this.escape(name.dataset.name.slice(at + query.length))}`
        this.ancestors(row).forEach((dir) => counts.set(dir, (counts.get(dir) || 0) + 1))
      }
    })
    rows.filter((row) => row.classList.contains("d")).forEach((dir) => {
      const count = dir.querySelector(".ct")
      if (count && !count.dataset.count) count.dataset.count = count.textContent
      if (query === "") {
        dir.dataset.filtered = "in"
        dir.hidden = false
        if (count) count.textContent = count.dataset.count
        return
      }
      const hits = counts.get(dir) || 0
      dir.dataset.filtered = hits > 0 ? "in" : "out"
      dir.hidden = hits === 0
      if (count) count.textContent = hits > 0 ? `${hits} of ${count.dataset.count}` : count.dataset.count
      if (hits > 0) this.setFold(dir, true)
    })
  }

  toggleStrip() {
    const strip = this.element.classList.toggle("strip")
    try { localStorage.setItem(STORAGE, strip ? "strip" : "open") } catch (_) {}
    if (!strip) this.revealCurrent()
  }

  onKey(event) {
    if (event.target === this.filterTarget) return
    const row = event.target.closest(".d, .f")
    if (event.key === "t") { this.toggleStrip(); return }
    if (!row) return
    const visible = this.rowTargets.filter((r) => !r.hidden)
    const index = visible.indexOf(row)
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      const next = visible[index + (event.key === "ArrowDown" ? 1 : -1)]
      if (next) { next.focus(); event.preventDefault() }
    } else if ((event.key === "ArrowRight" || event.key === "ArrowLeft") && row.classList.contains("d")) {
      this.setFold(row, event.key === "ArrowRight")
      event.preventDefault()
    }
  }

  ancestors(row) {
    const found = []
    let level = this.level(row)
    let prev = row.previousElementSibling
    while (prev && level > 0) {
      if (prev.classList.contains("d") && this.level(prev) < level) { found.push(prev); level = this.level(prev) }
      prev = prev.previousElementSibling
    }
    return found
  }

  level(row) { return parseInt(row.dataset.level || "0", 10) }

  escape(text) {
    return text.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]))
  }
}
