import { Controller } from "@hotwired/stimulus"

// ⎘ copies its text (a path, a Mermaid source, a focus URL) to the clipboard
// and says so for a moment through aria-live. A large Mermaid source is not
// in the page: url names its .mmd route and the text is fetched on copy.
export default class extends Controller {
  static values = { text: String, url: String }

  async copy(event) {
    try {
      if (this.urlValue) await this.copyFromUrl()
      else await navigator.clipboard.writeText(this.textValue || this.element.textContent)
      this.announce("Copied")
    } catch (_) {
      this.announce("Copy failed")
    }
  }

  // A ClipboardItem keeps the click's activation while the text arrives.
  async copyFromUrl() {
    const text = () => fetch(this.urlValue, { headers: { Accept: "text/plain" }, credentials: "same-origin" })
      .then((response) => { if (!response.ok) throw new Error(String(response.status)); return response.text() })
    if (window.ClipboardItem && navigator.clipboard.write) {
      const blob = text().then((body) => new Blob([body], { type: "text/plain" }))
      await navigator.clipboard.write([new ClipboardItem({ "text/plain": blob })])
    } else {
      await navigator.clipboard.writeText(await text())
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
