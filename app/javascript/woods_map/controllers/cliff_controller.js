import { Controller } from "@hotwired/stimulus"

// The scroll cliff: `more` on a .hscroll or .tblwrap only while content
// overflows to the right, `more-left` once it has been scrolled.
export default class extends Controller {
  connect() {
    this.update = this.update.bind(this)
    this.observer = new ResizeObserver(this.update)
    this.observer.observe(this.element)
    if (this.element.firstElementChild) this.observer.observe(this.element.firstElementChild)
    this.element.addEventListener("scroll", this.update, { passive: true })
    this.update()
  }

  disconnect() {
    this.observer.disconnect()
    this.element.removeEventListener("scroll", this.update)
  }

  update() {
    const el = this.element
    const overflow = el.scrollWidth - el.clientWidth
    el.classList.toggle("more", overflow > 1 && el.scrollLeft < overflow - 1)
    el.classList.toggle("more-left", el.scrollLeft > 1)
    // A region that scrolls must be reachable with the keyboard.
    if (overflow > 1) el.setAttribute("tabindex", "0")
    else el.removeAttribute("tabindex")
  }
}
