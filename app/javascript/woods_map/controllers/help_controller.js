import { Controller } from "@hotwired/stimulus"

// A native modal makes the page inert; the opener gets focus back on every
// dismissal path. Help never steals typing or another modal's keyboard.
export default class extends Controller {
  static targets = ["dialog", "close"]

  connect() {
    this.onKey = (event) => this.key(event)
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
    if (this.dialogTarget.open) this.close()
  }

  key(event) {
    if (this.dialogTarget.open) {
      if (event.key === "Escape") { event.preventDefault(); this.close() }
      // Close is the only focusable control; contain synthetic and native Tab alike.
      if (event.key === "Tab") { event.preventDefault(); this.closeTarget.focus() }
      return
    }
    if (event.key !== "?" || event.defaultPrevented || event.repeat || event.isComposing) return
    if (event.metaKey || event.ctrlKey || event.altKey) return
    if (event.target.closest('input, textarea, select, [contenteditable]:not([contenteditable="false"])')) return
    if (this.otherModal()) return
    event.preventDefault()
    this.open()
  }

  open() {
    if (this.dialogTarget.open || this.otherModal()) return
    this.opener = document.activeElement
    this.dialogTarget.showModal()
    this.closeTarget.focus()
  }

  close() { this.dialogTarget.close() }

  restore() {
    if (this.opener?.isConnected) this.opener.focus()
  }

  outside(event) {
    if (event.target !== this.dialogTarget) return
    const box = this.dialogTarget.getBoundingClientRect()
    if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) this.close()
  }

  otherModal() {
    return [...document.querySelectorAll('dialog[open], [aria-modal="true"]')]
      .some((modal) => modal !== this.dialogTarget && modal.getClientRects().length > 0)
  }
}
