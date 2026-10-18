import { Controller } from "@hotwired/stimulus"

// ⎘ copies its text (a path, a Mermaid source, a focus URL) to the clipboard
// and says so for a moment through aria-live.
export default class extends Controller {
  static values = { text: String }

  async copy(event) {
    const text = this.textValue || this.element.textContent
    try {
      await navigator.clipboard.writeText(text)
      this.announce("Copied")
    } catch (_) {
      this.announce("Copy failed")
    }
  }

  announce(message) {
    let live = document.getElementById("wm-live")
    if (!live) {
      live = document.createElement("div")
      live.id = "wm-live"
      live.className = "sr-only"
      live.setAttribute("aria-live", "polite")
      document.body.appendChild(live)
    }
    live.textContent = ""
    setTimeout(() => { live.textContent = message }, 50)
    this.element.dataset.copied = "true"
    setTimeout(() => { delete this.element.dataset.copied }, 1200)
  }
}
