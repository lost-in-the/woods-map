import { Controller } from "@hotwired/stimulus"

// Below 960 the tree and the rail share one entry point: ☰ at the top left
// opens a sheet (files first, this page's sections below). The sheet borrows
// the page's own nav.tree and nav.rail elements and gives them back on close,
// so there is one copy of each. Escape or a tap outside closes.
//
// Lives on the .wm root; the ☰ button calls sheet#open.
export default class extends Controller {
  static targets = ["overlay", "body", "close"]

  connect() {
    this.onKey = (e) => { if (e.key === "Escape" && this.isOpen) this.close() }
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
    if (this.isOpen) this.close()
  }

  get isOpen() { return this.hasOverlayTarget && !this.overlayTarget.hidden }

  open(event) {
    if (!this.hasOverlayTarget || this.isOpen) return
    this.opener = event?.currentTarget
    this.borrowed = []
    this.element.querySelectorAll("nav.tree, nav.rail").forEach((nav) => {
      this.borrowed.push({ nav, parent: nav.parentNode, next: nav.nextSibling })
      this.bodyTarget.appendChild(nav)
    })
    this.overlayTarget.hidden = false
    this.opener?.setAttribute("aria-expanded", "true")
    if (this.hasCloseTarget) this.closeTarget.focus()
  }

  close() {
    if (!this.isOpen) return
    for (const { nav, parent, next } of this.borrowed.reverse()) parent.insertBefore(nav, next)
    this.borrowed = []
    this.overlayTarget.hidden = true
    this.opener?.setAttribute("aria-expanded", "false")
    this.opener?.focus()
  }

  outside(event) {
    if (event.target === this.overlayTarget) this.close()
  }
}
