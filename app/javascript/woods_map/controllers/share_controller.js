import { Controller } from "@hotwired/stimulus"

// The Share menu (E-6, E-7) is a native <details> disclosure: Enter or Space
// on the summary opens it, Escape or a click outside closes it and focus
// returns to the summary. On opening, the focus URL gains the line the
// address targets (#L…), and one copy tool appears per diagram panel on the
// page, copying the Mermaid text that panel already carries (D-21).
export default class extends Controller {
  static targets = ["url", "copyUrl", "diagrams"]

  connect() {
    this.base = this.urlTarget.textContent.trim()
    this.onOutside = (event) => { if (this.element.open && !this.element.contains(event.target)) this.element.open = false }
    document.addEventListener("click", this.onOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.onOutside)
  }

  toggle() {
    if (!this.element.open) return
    const url = this.base.split("#")[0] + (/^#L\d+(-L\d+)?$/.test(window.location.hash) ? window.location.hash : "")
    this.urlTarget.textContent = url
    this.copyUrlTarget.dataset.copyTextValue = url
    this.fillDiagrams()
  }

  key(event) {
    if (event.key !== "Escape" || !this.element.open) return
    event.preventDefault()
    event.stopPropagation()
    this.element.open = false
    this.element.querySelector("summary").focus()
  }

  fillDiagrams() {
    const list = this.diagramsTarget
    list.querySelectorAll("button").forEach((button) => button.remove())
    const panels = [...document.querySelectorAll(".dia")].filter((panel) => panel.querySelector('[data-diagram-target="source"]'))
    for (const panel of panels) {
      const text = panel.querySelector('[data-diagram-target="source"]').textContent
      const title = panel.querySelector(".dh b")?.textContent.trim() || "diagram"
      const button = document.createElement("button")
      button.type = "button"
      button.className = "tool"
      button.textContent = `⎘ ${title}`
      button.setAttribute("aria-label", `Copy the Mermaid text of ${title}`)
      button.dataset.controller = "copy"
      button.dataset.copyTextValue = text
      button.dataset.action = "copy#copy"
      list.appendChild(button)
    }
    list.hidden = panels.length === 0
  }
}
