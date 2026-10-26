import { Controller } from "@hotwired/stimulus"

// Brings the source line a #L<n> fragment names into view. The code view's rows
// are display:contents wrappers (they own no box), so the browser's own fragment
// scroll finds nothing to move to; the line's visible cell is scrolled instead.
export default class extends Controller {
  connect() {
    this.onHash = () => this.reveal()
    window.addEventListener("hashchange", this.onHash)
    requestAnimationFrame(this.onHash)
  }

  disconnect() {
    window.removeEventListener("hashchange", this.onHash)
  }

  reveal() {
    const match = /^#L(\d+)$/.exec(window.location.hash)
    if (!match) return
    const source = document.querySelector(`.cv [id="L${match[1]}"] .src`)
    if (source) source.scrollIntoView({ block: "center", inline: "nearest" })
  }
}
