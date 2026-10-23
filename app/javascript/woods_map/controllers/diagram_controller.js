import { Controller } from "@hotwired/stimulus"

// Draws a diagram panel's Mermaid text with Pele (D-21). The text stays in
// the page: without JavaScript, or when Pele refuses the text, the panel
// shows it as it did before; once drawn, "Mermaid text" swaps back to it.
// Pele is loaded on the first panel that needs it, so pages without a
// diagram never fetch it. Colours and fonts come from the --pele-* tokens.
export default class extends Controller {
  static targets = ["source", "canvas", "toggle", "scroller", "message"]
  static values = { label: String }

  async connect() {
    try {
      const { mount } = await import("pele")
      if (document.fonts) await document.fonts.ready
      if (!this.element.isConnected) return

      // Natural width, never wrapped to the panel or scaled down: the body
      // scrolls sideways (C4). The text size is the --dia-fs token.
      const fontSize = parseFloat(getComputedStyle(this.element).getPropertyValue("--dia-fs")) || undefined
      this.mounted = mount(this.canvasTarget, this.sourceTarget.textContent, {
        links: false,
        images: false,
        responsive: false,
        autoDirection: false,
        maxWidth: Infinity,
        fontSize,
        onError: (error) => this.fail(error)
      })
      if (this.mounted.error) return this.fail(this.mounted.error)

      this.label()
      this.show(true)
    } catch (error) {
      this.fail(error)
    }
  }

  disconnect() {
    this.mounted?.destroy()
    this.mounted = null
  }

  toggle() {
    this.show(this.sourceTarget.hidden === false)
  }

  // Name the drawing for assistive technology; the text beside it carries the detail.
  label() {
    const svg = this.canvasTarget.querySelector("svg")
    if (!svg) return
    svg.setAttribute("aria-label", this.labelValue)
  }

  show(drawn) {
    this.canvasTarget.hidden = !drawn
    this.sourceTarget.hidden = drawn
    if (this.hasToggleTarget) {
      this.toggleTarget.hidden = false
      this.toggleTarget.setAttribute("aria-pressed", String(!drawn))
    }
    // The cliff watches the scroller; the swap changes its width.
    this.scrollerTarget.dispatchEvent(new Event("scroll"))
  }

  // Pele refused the text (too long, a syntax it does not know) or could
  // not load: say so above the text, as a refusal would. textContent keeps
  // the renderer's message inert.
  fail(error) {
    this.canvasTarget.hidden = true
    this.sourceTarget.hidden = false
    if (this.hasToggleTarget) this.toggleTarget.hidden = true
    this.element.dataset.diagramError = error?.code || "error"
    if (this.hasMessageTarget) {
      const reason = error?.message ? `: ${String(error.message).replace(/\.\s*$/, "")}` : ""
      this.messageTarget.textContent = `The diagram could not be drawn${reason}. The Mermaid text is shown instead.`
      this.messageTarget.hidden = false
    }
    console.warn("woods-map: diagram left as text", error)
  }
}
