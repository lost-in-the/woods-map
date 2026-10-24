import { Controller } from "@hotwired/stimulus"

// The disambiguation popover (FR-4, B-1): an ambiguous reference in the code
// view is a button; it opens the list of every candidate the index published,
// placed under the button. Focus moves to the first candidate; ↑/↓ move
// between them; Escape, a click outside or focus leaving closes it and
// returns focus to the button. Without JavaScript the lists follow the code.
export default class extends Controller {
  static targets = ["popover"]

  connect() {
    this.onKey = (e) => this.key(e)
    this.onPointer = (e) => this.outside(e)
    this.onScroll = () => this.close(false)
    document.addEventListener("keydown", this.onKey)
    document.addEventListener("pointerdown", this.onPointer)
    this.element.addEventListener("focusout", (e) => this.focusOut(e))
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
    document.removeEventListener("pointerdown", this.onPointer)
    window.removeEventListener("scroll", this.onScroll, true)
  }

  toggle(event) {
    event.preventDefault()
    const button = event.currentTarget
    const open = this.button === button
    this.close(open)
    if (!open) this.open(button)
  }

  open(button) {
    const popover = document.getElementById(button.getAttribute("aria-controls"))
    if (!popover) return
    this.button = button
    this.popover = popover
    popover.hidden = false
    const rect = button.getBoundingClientRect()
    const width = popover.offsetWidth
    popover.style.top = `${Math.round(rect.bottom + 4)}px`
    popover.style.left = `${Math.round(Math.max(8, Math.min(rect.left, window.innerWidth - width - 8)))}px`
    button.setAttribute("aria-expanded", "true")
    window.addEventListener("scroll", this.onScroll, true)
    this.links()[0]?.focus()
  }

  close(restore = true) {
    if (!this.popover) return
    this.popover.hidden = true
    this.button.setAttribute("aria-expanded", "false")
    window.removeEventListener("scroll", this.onScroll, true)
    if (restore) this.button.focus()
    this.popover = null
    this.button = null
  }

  links() {
    return this.popover ? [...this.popover.querySelectorAll("a[href]")] : []
  }

  key(event) {
    if (!this.popover) return
    if (event.key === "Escape") { event.preventDefault(); this.close(); return }
    if (event.key !== "ArrowDown" && event.key !== "ArrowUp") return
    const links = this.links()
    const index = links.indexOf(document.activeElement)
    if (index < 0) return
    event.preventDefault()
    const step = event.key === "ArrowDown" ? 1 : -1
    links[(index + step + links.length) % links.length].focus()
  }

  outside(event) {
    if (!this.popover) return
    if (this.popover.contains(event.target) || this.button.contains(event.target)) return
    this.close(false)
  }

  focusOut(event) {
    if (!this.popover) return
    const next = event.relatedTarget
    if (next && (this.popover.contains(next) || this.button === next)) return
    if (next) this.close(false)
  }
}
