import { Controller } from "@hotwired/stimulus"

// The Share menu (E-6, E-7) is a native <details> disclosure: Enter or Space
// on the summary opens it, Escape or a click outside closes it and focus
// returns to the summary. On opening, the focus URL gains the line the
// address targets (#L…), and each diagram export on the page gets a copy of
// its Mermaid text, a link to its stable .mmd URL (D-25) and a copy of it as a
// GitHub pull-request comment, or the reason a comment cannot hold it (#76).
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

  // One row per diagram export on the page (components/mermaid_tools): copy
  // its Mermaid text, link its stable .mmd URL when the page has one, and copy
  // it for a pull-request comment, or say why a comment cannot hold it.
  fillDiagrams() {
    const list = this.diagramsTarget
    list.querySelectorAll("button, a, .lyr").forEach((node) => node.remove())
    const key = (tool) => `${tool.dataset.mermaidName}\u0000${tool.dataset.mermaidHref || ""}`
    const outside = (tool) => !this.element.contains(tool)
    const comments = new Map()
    for (const tool of document.querySelectorAll("[data-pr-comment], [data-pr-comment-refusal]")) {
      if (outside(tool) && !comments.has(key(tool))) comments.set(key(tool), tool)
    }
    // One row per distinct text: the Graph tab's canvas and its flowchart fallback export the same diagram.
    const seen = new Set()
    const tools = [...document.querySelectorAll("[data-mermaid-name][data-copy-text-value]:not([data-pr-comment])")].filter((tool) => {
      const text = `${tool.dataset.copyTextValue}\u0000${tool.dataset.mermaidHref || ""}`
      if (!outside(tool) || seen.has(text)) return false
      seen.add(text)
      return true
    })
    for (const tool of tools) {
      const title = tool.dataset.mermaidName
      list.appendChild(this.copyButton(`⎘ ${title}`, `Copy the Mermaid text of ${title}`, tool.dataset.copyTextValue))
      if (tool.dataset.mermaidHref) {
        const link = document.createElement("a")
        link.className = "tool"
        link.href = tool.dataset.mermaidHref
        link.type = "text/plain"
        link.textContent = "⤓ .mmd"
        link.setAttribute("aria-label", `${title} as Mermaid text, ${tool.dataset.mermaidHref}`)
        list.appendChild(link)
      }
      const comment = comments.get(key(tool))
      if (comment?.dataset.prComment !== undefined) {
        list.appendChild(this.copyButton("⎘ for PR comment", `for PR comment: copy ${title} as a GitHub pull-request comment`, comment.dataset.copyTextValue))
      } else if (comment) {
        const note = document.createElement("span")
        note.className = "lyr"
        note.textContent = `${title}: ${comment.dataset.prCommentRefusal}`
        list.appendChild(note)
      }
    }
    list.hidden = tools.length === 0
  }

  copyButton(text, label, value) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "tool"
    button.textContent = text
    button.setAttribute("aria-label", label)
    button.dataset.controller = "copy"
    button.dataset.copyTextValue = value
    button.dataset.action = "copy#copy"
    return button
  }
}
