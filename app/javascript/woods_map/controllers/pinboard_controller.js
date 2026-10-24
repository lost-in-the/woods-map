import { Controller } from "@hotwired/stimulus"

// The Trail's pin notes (notes/trail.md): free text stays in this browser,
// under the board's key, because a board's URL carries identifiers and
// generation numbers only. Storage can be absent (a private window, blocked
// site data); the notes then last as long as the page.
const PREFIX = "woods-map:trail-notes:"

export default class extends Controller {
  static targets = ["note", "status"]
  static values = { key: String }

  connect() {
    const notes = this.read()
    this.noteTargets.forEach((field) => { field.value = notes[field.dataset.pin] || "" })
  }

  save() {
    const notes = {}
    this.noteTargets.forEach((field) => { if (field.value.trim() !== "") notes[field.dataset.pin] = field.value })
    let kept = true
    try {
      if (Object.keys(notes).length === 0) localStorage.removeItem(this.storageKey())
      else localStorage.setItem(this.storageKey(), JSON.stringify(notes))
    } catch (_) { kept = false }
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = kept ? "Notes are kept in this browser for this board only." : "This browser does not keep notes; they last as long as the page."
    }
  }

  read() {
    try { return JSON.parse(localStorage.getItem(this.storageKey()) || "{}") || {} } catch (_) { return {} }
  }

  storageKey() {
    return `${PREFIX}${this.keyValue}`
  }
}
