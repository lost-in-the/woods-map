import { Controller } from "@hotwired/stimulus"

// The reading trail in the breadcrumb band: the last units opened in this
// browser tab, newest first, kept in sessionStorage.
const KEY = "woods-map.trail"
const SIZE = 3

export default class extends Controller {
  static values = { title: String }
  static targets = ["list"]

  connect() {
    let trail = []
    try { trail = JSON.parse(sessionStorage.getItem(KEY) || "[]") } catch (_) { trail = [] }
    const here = { title: this.titleValue, href: window.location.pathname }
    trail = [here].concat(trail.filter((t) => t.href !== here.href)).slice(0, SIZE + 1)
    try { sessionStorage.setItem(KEY, JSON.stringify(trail)) } catch (_) {}
    const previous = trail.slice(1)
    const target = document.querySelector("[data-trail-target=list]")
    if (!target || previous.length === 0) return
    target.textContent = "trail: "
    previous.forEach((t, index) => {
      const a = document.createElement("a")
      a.href = t.href
      a.textContent = t.title
      target.appendChild(a)
      if (index < previous.length - 1) target.appendChild(document.createTextNode(" ‹ "))
    })
  }
}
