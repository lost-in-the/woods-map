import { Controller } from "@hotwired/stimulus"

// The Trail's pin notes (notes/trail.md): free text stays in this browser,
// under the board's key, because a board's URL carries identifiers and
// generation numbers only. Storage can be absent (a private window, blocked
// site data); the notes then last as long as the page.
//
// The handoff summary is Markdown built here from those notes and written to
// the clipboard on a click, and nowhere else: nothing is stored, fetched or
// put in a URL. The units link by the page's token-free focus URLs.
const PREFIX = "woods-map:trail-notes:"

export default class extends Controller {
  static targets = ["note", "status", "handoff"]
  static values = { key: String, title: String, url: String, generation: Number, units: Array }

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

  async copySummary() {
    let copied = true
    try { await navigator.clipboard.writeText(this.summary()) } catch (_) { copied = false }
    if (this.hasHandoffTarget) {
      this.handoffTarget.textContent = copied ? "Copied the handoff summary to the clipboard. Nothing was stored or sent." : "Copy failed: this browser did not allow clipboard access."
    }
  }

  summary() {
    const note = (name) => this.noteTargets.find((field) => field.dataset.pin === name)?.value.trim() || ""
    const lines = [`# Trail handoff: ${this.titleValue}`, "", `Read on gen ${this.generationValue}. Board: ${this.urlValue}`]
    const section = (heading, text) => { if (text) lines.push("", `## ${heading}`, text) }
    section("Conclusion", note("conclusion"))
    lines.push("", "## Cited units")
    for (const unit of this.unitsValue) {
      const label = unit.url ? `[${unit.label.replace(/[[\]]/g, "\\$&")}](${unit.url})` : unit.label
      const text = note(unit.pin).replace(/\n/g, "\n  ")
      lines.push(`- ${label}${text ? `: ${text}` : ""}`)
    }
    section("Open question", note("question"))
    return `${lines.join("\n")}\n`
  }

  read() {
    try { return JSON.parse(localStorage.getItem(this.storageKey()) || "{}") || {} } catch (_) { return {} }
  }

  storageKey() {
    return `${PREFIX}${this.keyValue}`
  }
}
