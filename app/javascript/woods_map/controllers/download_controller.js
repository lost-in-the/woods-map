import { Controller } from "@hotwired/stimulus"

// ⤓ saves a diagram's Mermaid text as a .mmd file. The text is the one the
// page already carries: the value when given, else the panel's source. No
// request is made; the file is built in the browser.
export default class extends Controller {
  static values = { text: String, filename: String }

  save() {
    const source = this.element.closest(".dia")?.querySelector('[data-diagram-target="source"], pre.cmd')
    const text = this.textValue || source?.textContent || ""
    const url = URL.createObjectURL(new Blob([text.endsWith("\n") ? text : `${text}\n`], { type: "text/plain;charset=utf-8" }))
    const link = document.createElement("a")
    link.href = url
    link.download = this.filenameValue || "diagram.mmd"
    link.hidden = true
    document.body.appendChild(link)
    link.click()
    link.remove()
    setTimeout(() => URL.revokeObjectURL(url), 0)
  }
}
