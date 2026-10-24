import { Controller } from "@hotwired/stimulus"

// Pick a span of days on a commit strip or timeline (B6-History "drag to
// pick a range"): drag across the bars, or focus a bar and extend with
// Shift+← / Shift+→, then Enter. The page reloads with ?span=first..last,
// which the server filters by; Escape cancels. A click without a drag keeps
// the bar's own link. The band is an SVG rect placed by attributes (no style
// attribute, CSP); an aria-live line says what is selected.
export default class extends Controller {
  connect() {
    this.buckets = JSON.parse(this.element.dataset.brushBuckets || "[]")
    this.svg = this.element.querySelector("svg")
    this.band = this.element.querySelector("[data-brush-band]")
    this.status = this.element.querySelector("[data-brush-status]")
    this.unit = this.element.dataset.brushUnit || "week"
    this.anchor = null
    this.cursor = null
    this.dragged = false
    this.onDown = this.onDown.bind(this)
    this.onMove = this.onMove.bind(this)
    this.onUp = this.onUp.bind(this)
    this.onClick = this.onClick.bind(this)
    this.onKey = this.onKey.bind(this)
    if (!this.svg || !this.buckets.length) return
    this.svg.addEventListener("pointerdown", this.onDown)
    this.svg.addEventListener("pointermove", this.onMove)
    this.svg.addEventListener("pointerup", this.onUp)
    this.svg.addEventListener("click", this.onClick, true)
    this.element.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    if (!this.svg) return
    this.svg.removeEventListener("pointerdown", this.onDown)
    this.svg.removeEventListener("pointermove", this.onMove)
    this.svg.removeEventListener("pointerup", this.onUp)
    this.svg.removeEventListener("click", this.onClick, true)
    this.element.removeEventListener("keydown", this.onKey)
  }

  // The bucket under a pointer, by its share of the plot's width.
  indexAt(clientX) {
    const box = this.svg.getBoundingClientRect()
    if (!box.width) return 0
    const share = (clientX - box.left) / box.width
    return Math.min(this.buckets.length - 1, Math.max(0, Math.floor(share * this.buckets.length)))
  }

  onDown(event) {
    if (event.button !== 0) return
    this.anchor = this.indexAt(event.clientX)
    this.cursor = this.anchor
    this.dragged = false
    this.pointer = true
    if (this.svg.setPointerCapture && event.pointerId !== undefined) {
      try { this.svg.setPointerCapture(event.pointerId) } catch (_) {}
    }
  }

  onMove(event) {
    if (!this.pointer) return
    const index = this.indexAt(event.clientX)
    if (index === this.cursor) return
    this.cursor = index
    this.dragged = this.cursor !== this.anchor
    this.paint(false)
  }

  onUp(event) {
    if (!this.pointer) return
    this.pointer = false
    if (this.dragged) {
      event.preventDefault()
      this.apply()
    } else {
      this.clear()
    }
  }

  // A drag that ends on a bar must not also follow that bar's link.
  onClick(event) {
    if (!this.dragged) return
    event.preventDefault()
    event.stopPropagation()
  }

  onKey(event) {
    if (event.shiftKey && (event.key === "ArrowLeft" || event.key === "ArrowRight")) {
      if (this.anchor === null) {
        const bar = event.target.closest && event.target.closest("[data-index]")
        if (!bar) return
        this.anchor = Number(bar.dataset.index)
        this.cursor = this.anchor
      }
      const step = event.key === "ArrowLeft" ? -1 : 1
      this.cursor = Math.min(this.buckets.length - 1, Math.max(0, this.cursor + step))
      event.preventDefault()
      this.paint(true)
    } else if (event.key === "Enter" && this.anchor !== null && this.cursor !== this.anchor) {
      event.preventDefault()
      this.apply()
    } else if (event.key === "Escape" && this.anchor !== null) {
      event.preventDefault()
      this.clear()
      this.say("Selection cancelled.")
    }
  }

  // [first, last] bucket indices in order.
  range() {
    return [Math.min(this.anchor, this.cursor), Math.max(this.anchor, this.cursor)]
  }

  span() {
    const [a, b] = this.range()
    return `${this.buckets[a][0]}..${this.buckets[b][1]}`
  }

  paint(keyboard) {
    const [a, b] = this.range()
    const count = b - a + 1
    if (this.band) {
      this.band.setAttribute("x", `${(100 * a / this.buckets.length).toFixed(3)}%`)
      this.band.setAttribute("width", `${(100 * count / this.buckets.length).toFixed(3)}%`)
      this.band.setAttribute("visibility", "visible")
    }
    const what = `${count} ${this.unit}${count === 1 ? "" : "s"} selected, ${this.buckets[a][0]} to ${this.buckets[b][1]}.`
    this.say(keyboard ? `${what} Press Enter to list their commits, Escape to cancel.` : what)
  }

  clear() {
    this.anchor = null
    this.cursor = null
    if (this.band) this.band.setAttribute("visibility", "hidden")
  }

  apply() {
    const url = (this.element.dataset.brushUrl || "").replace("__SPAN__", encodeURIComponent(this.span()))
    this.say(`Listing the commits from ${this.span().replace("..", " to ")}.`)
    this.navigate(url)
  }

  navigate(url) {
    window.location.assign(url)
  }

  say(text) {
    if (this.status) this.status.textContent = text
  }
}
