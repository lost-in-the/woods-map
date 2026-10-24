import { Controller } from "@hotwired/stimulus"

// Hover cards on references (B-3). The page carries one inert <template> per
// unit the code view links, rendered by the server with the page (the
// prefetched per-page data), so no request is made on hover. On connect each
// reference link in the code view gets its card as data-tip-html with a
// 100 ms delay; the one tooltip (D-16) then owns hover, focus, placement and
// Escape. Without JavaScript the templates stay inert and links navigate.
const LINKS = ".cv .src a[href]"

export default class extends Controller {
  static targets = ["card"]

  connect() {
    const cards = new Map(this.cardTargets.map((t) => [t.dataset.href, t.innerHTML.trim()]))
    if (cards.size === 0) return
    this.element.querySelectorAll(LINKS).forEach((link) => {
      const html = cards.get(link.getAttribute("href").split("#")[0])
      if (!html) return
      link.dataset.tipHtml = html
      link.dataset.tipDelay = "100"
    })
  }
}
