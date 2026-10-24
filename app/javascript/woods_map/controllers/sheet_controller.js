import { Controller } from "@hotwired/stimulus"

// ☰ at the top left (and *files* in the crumbs) opens a sheet: below 960 the
// primary nav first, then files, then this page's sections. The file tree is
// fetched the first time the sheet opens, from a URL that names the
// generation, and the page's own file is marked current there. The sheet
// borrows the page's nav.rail and gives it back on close, so there is one
// copy. Escape or a tap outside closes.
//
// Lives on the .wm root; the ☰ button calls sheet#open.
export default class extends Controller {
  static targets = ["overlay", "body", "close", "scroll", "tree", "treeStatus"]

  connect() {
    this.onKey = (event) => {
      if (!this.isOpen) return
      if (event.key === "Escape") this.close()
      else if (event.key === "Tab") this.trapFocus(event)
    }
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
    if (this.isOpen) this.close()
  }

  get isOpen() { return this.hasOverlayTarget && !this.overlayTarget.hidden }

  // A modal keeps Tab within its visible controls; Escape restores its opener.
  trapFocus(event) {
    const controls = [...this.overlayTarget.querySelectorAll("button, a[href], input, select, textarea, [tabindex]")]
      .filter((element) => !element.disabled && element.tabIndex >= 0 && element.getClientRects().length > 0)
    if (controls.length === 0) return
    const first = controls[0]
    const last = controls[controls.length - 1]
    const active = document.activeElement
    const outside = !this.overlayTarget.contains(active)
    if (outside || (!event.shiftKey && active === last) || (event.shiftKey && active === first)) {
      event.preventDefault()
      const target = event.shiftKey ? last : first
      target.focus()
    }
  }

  open(event) {
    if (!this.hasOverlayTarget || this.isOpen) return
    this.opener = event?.currentTarget
    this.borrowed = []
    this.element.querySelectorAll("nav.tree, nav.rail").forEach((nav) => {
      if (this.overlayTarget.contains(nav)) return
      this.borrowed.push({ nav, parent: nav.parentNode, next: nav.nextSibling })
      this.bodyTarget.appendChild(nav)
    })
    this.overlayTarget.hidden = false
    if (this.hasScrollTarget) this.scrollTarget.scrollTop = 0
    this.opener?.setAttribute("aria-expanded", "true")
    if (this.hasCloseTarget) this.closeTarget.focus()
    this.loadTree()
  }

  // The tree arrives once per page; the browser keeps the response per
  // generation, so the next page's first open is a cache hit.
  async loadTree() {
    if (!this.hasTreeTarget || this.treeLoading || this.treeTarget.querySelector("nav.tree")) return
    this.treeLoading = true
    const status = this.hasTreeStatusTarget ? this.treeStatusTarget : null
    if (status) status.textContent = "Loading the file tree…"
    try {
      const response = await fetch(this.treeTarget.dataset.src, { headers: { Accept: "text/html" }, credentials: "same-origin" })
      if (!response.ok) throw new Error(`the tree answered ${response.status}`)
      const holder = document.createElement("div")
      holder.innerHTML = await response.text()
      const nav = holder.querySelector("nav.tree")
      if (!nav) throw new Error("the tree response had no tree")
      if (this.treeTarget.dataset.current) nav.dataset.treeCurrentValue = this.treeTarget.dataset.current
      status?.remove()
      this.treeTarget.appendChild(nav)
    } catch (error) {
      if (status) status.textContent = `The file tree could not be loaded (${error.message}). Close and open the sheet to try again.`
    } finally {
      this.treeLoading = false
    }
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
