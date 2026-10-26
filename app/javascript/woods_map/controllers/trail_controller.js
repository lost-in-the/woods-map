import { Controller } from "@hotwired/stimulus"

// The reading trail in the breadcrumb band: the last units opened in this
// browser tab, newest first, kept in sessionStorage. An entry is the page's
// canonical path and query (the url value, never a token), so a return keeps
// the investigation it left. One entry per URL, and one per title across
// paths, so a unit's tabs (Code, Schema, Graph, ...) are one step, at the
// latest tab read. An entry stored as a bare path still draws. A page without a title value is named from its document title, and
// an entry without a name is never drawn.
const KEY = "woods-map.trail"
const SIZE = 3
const SUFFIX = / · Woods Map$/

export default class extends Controller {
  static values = { title: String, url: String }
  static targets = ["list"]

  connect() {
    let trail = []
    try { trail = JSON.parse(sessionStorage.getItem(KEY) || "[]") } catch (_) { trail = [] }
    const title = (this.titleValue || document.title.replace(SUFFIX, "")).trim()
    const here = { title, href: this.urlValue || window.location.pathname }
    const pathOf = (href) => href.split("?", 1)[0]
    const named = (t) => t && typeof t.title === "string" && t.title.trim() !== "" && typeof t.href === "string"
    trail = trail.filter(named).filter((t) => t.href !== here.href && t.title !== here.title)
    if (named(here)) trail.unshift(here)
    trail = trail.slice(0, SIZE + 1)
    try { sessionStorage.setItem(KEY, JSON.stringify(trail)) } catch (_) {}
    const previous = trail.filter((t) => t.href !== here.href).slice(0, SIZE)
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
