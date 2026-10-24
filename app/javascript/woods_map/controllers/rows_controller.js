import { Controller } from "@hotwired/stimulus"

// Subdivided rows (D-17): a bare + / − opens the detail block under the row,
// the checkbox selects it (tint on the toggle cell only), one expand-all
// control per section, which reads "collapse all" while every block is open
// and then collapses them. Keys inside the table: j / k move between rows,
// Enter toggles, e expands all, E collapses all (Space checks natively).
//
// Lives on the section that holds the header tools and the table. Without
// JavaScript every detail block is open (html.no-js in map.css).
export default class extends Controller {
  connect() {
    this.onKey = this.onKey.bind(this)
    this.element.addEventListener("keydown", this.onKey)
    this.syncAll()
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.onKey)
  }

  toggle(event) {
    const button = event.currentTarget
    this.set(button, button.getAttribute("aria-expanded") !== "true")
  }

  // The section's expand-all control: expands every block, or collapses
  // them when all are already open.
  expandAll(event) {
    const open = !(event?.currentTarget && this.allOpen())
    this.toggles().forEach((button) => this.set(button, open))
  }

  collapseAll() { this.toggles().forEach((button) => this.set(button, false)) }

  allOpen() {
    const toggles = this.toggles()
    return toggles.length > 0 && toggles.every((button) => button.getAttribute("aria-expanded") === "true")
  }

  syncAll() {
    const open = this.allOpen()
    this.element.querySelectorAll('[data-action~="rows#expandAll"]').forEach((control) => {
      control.textContent = open ? "collapse all" : "expand all"
      control.setAttribute("aria-expanded", String(open))
    })
  }

  check(event) {
    const input = event.currentTarget
    const row = input.closest("tr")
    row.classList.toggle("chk", input.checked)
    const sub = this.subOf(row)
    if (sub) sub.classList.toggle("chk", input.checked)
  }

  onKey(event) {
    if (event.target.matches("input, textarea, select")) return
    const row = event.target.closest("tr")
    if (!row) return
    const rows = this.rows()
    const index = rows.indexOf(row)
    if (event.key === "j" || event.key === "k") {
      const next = rows[index + (event.key === "j" ? 1 : -1)]
      if (next) { this.focusRow(next); event.preventDefault() }
    } else if (event.key === "Enter") {
      const button = row.querySelector(".tgl")
      if (button) { this.set(button, button.getAttribute("aria-expanded") !== "true"); event.preventDefault() }
    } else if (event.key === "e") {
      this.expandAll()
    } else if (event.key === "E") {
      this.collapseAll()
    }
  }

  set(button, open) {
    button.setAttribute("aria-expanded", String(open))
    button.setAttribute("aria-label", open ? "Collapse details" : "Expand details")
    const row = button.closest("tr")
    row.classList.toggle("grp", open)
    const sub = this.subOf(row)
    if (sub) sub.classList.toggle("open", open)
    this.syncAll()
  }

  subOf(row) {
    const next = row.nextElementSibling
    return next && next.classList.contains("sub") ? next : null
  }

  rows() {
    return Array.from(this.element.querySelectorAll("tbody > tr:not(.sub)"))
  }

  toggles() {
    return Array.from(this.element.querySelectorAll("tbody .tgl[aria-expanded]"))
  }

  focusRow(row) {
    const target = row.querySelector(".tgl, input, a, button") || row
    if (target === row && !row.hasAttribute("tabindex")) row.tabIndex = -1
    target.focus()
  }
}
