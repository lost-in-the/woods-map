import { Controller } from "@hotwired/stimulus"

// The Passage's filter matrix: one toggle narrows the rows to the
// filters that run on this page's action (a ✓ in its column) and back; the
// status line says how many rows are shown. Without JavaScript every row shows.
export default class extends Controller {
  static targets = ["toggle", "status"]

  toggle() {
    const only = this.toggleTarget.getAttribute("aria-pressed") !== "true"
    const rows = [...this.element.querySelectorAll("tbody tr")]
    let shown = 0
    rows.forEach((row) => {
      row.hidden = only && !row.querySelector("td.cur.on")
      if (!row.hidden) shown += 1
    })
    this.toggleTarget.setAttribute("aria-pressed", String(only))
    if (this.hasStatusTarget) this.statusTarget.textContent = only ? `${shown} of ${rows.length} filters run on this action.` : `All ${rows.length} filters shown.`
  }
}
