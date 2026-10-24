import { Controller } from "@hotwired/stimulus"

// One tooltip for the whole map (D-16): panel background, rule2 border, a
// caret at the anchor, below and left-aligned (above when there is no room),
// 300 ms delay on hover, at once on focus, Escape closes. A tooltip may hold a
// link, so it stays open while hovered or focused and is reachable with Tab.
//
// Lives on the .wm root. Triggers are abbr, .info and .who elements with a
// title (moved to data-tip so the native tooltip stays quiet) and anything
// with data-tip; data-tip-html carries server-rendered markup with links, and
// data-tip-delay overrides the hover delay (hover cards open at 100 ms, B-3).
const TRIGGERS = "abbr[title], .info[title], .who[title], .mg[title], .bar-fresh .why[title]"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  connect() {
    this.adopt()
    this.handlers = {
      mouseover: (e) => this.onOver(e),
      mouseout: (e) => this.onOut(e),
      focusin: (e) => this.onFocus(e),
      focusout: (e) => this.onOut(e),
      keydown: (e) => { if (e.key === "Escape") this.close() },
      click: (e) => this.onClick(e)
    }
    for (const [type, fn] of Object.entries(this.handlers)) this.element.addEventListener(type, fn)
    this.observer = new MutationObserver(() => this.adopt())
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    for (const [type, fn] of Object.entries(this.handlers)) this.element.removeEventListener(type, fn)
    this.observer.disconnect()
    this.close()
  }

  adopt() {
    this.element.querySelectorAll(TRIGGERS).forEach((el) => {
      el.dataset.tip = el.getAttribute("title")
      el.removeAttribute("title")
      if (!el.matches("a, button, input, [tabindex]")) el.tabIndex = 0
    })
  }

  trigger(target) {
    return target instanceof Element ? target.closest("[data-tip], [data-tip-html]") : null
  }

  onOver(event) {
    const trigger = this.trigger(event.target)
    if (trigger) this.schedule(trigger)
    else if (this.tip && this.tip.contains(event.target)) this.cancelClose()
  }

  onOut(event) {
    const trigger = this.trigger(event.target)
    if (trigger || (this.tip && this.tip.contains(event.target))) this.scheduleClose()
  }

  onFocus(event) {
    const trigger = this.trigger(event.target)
    if (trigger) this.open(trigger)
  }

  onClick(event) {
    const trigger = this.trigger(event.target)
    if (trigger) this.open(trigger)
    else if (this.tip && !this.tip.contains(event.target)) this.close()
  }

  schedule(trigger) {
    this.cancel()
    this.cancelClose()
    const delay = Number(trigger.dataset.tipDelay ?? this.delayValue)
    this.timer = setTimeout(() => this.open(trigger), delay)
  }

  scheduleClose() {
    this.cancel()
    this.closeTimer = setTimeout(() => this.close(), 150)
  }

  cancel() { clearTimeout(this.timer) }
  cancelClose() { clearTimeout(this.closeTimer) }

  open(trigger) {
    this.cancel()
    this.cancelClose()
    if (this.tip && this.anchor === trigger) return
    this.close()
    const tip = document.createElement("div")
    tip.className = "tip"
    tip.id = `wm-tip-${Date.now().toString(36)}`
    tip.setAttribute("role", "tooltip")
    if (trigger.dataset.tipHtml) tip.innerHTML = trigger.dataset.tipHtml
    else tip.textContent = trigger.dataset.tip
    // Inside the main landmark when there is one, so the tip is never content outside a region.
    ;(this.element.querySelector("main") || this.element).appendChild(tip)
    this.tip = tip
    this.anchor = trigger
    trigger.setAttribute("aria-describedby", tip.id)
    this.place(trigger, tip)
  }

  place(trigger, tip) {
    const root = this.element.getBoundingClientRect()
    const a = trigger.getBoundingClientRect()
    const gap = 8
    let left = a.left - root.left
    const maxLeft = this.element.clientWidth - tip.offsetWidth - gap
    if (left > maxLeft) left = Math.max(gap, maxLeft)
    const caret = Math.max(8, Math.min(a.left - root.left - left + a.width / 2 - 5, tip.offsetWidth - 18))
    let top = a.bottom - root.top + gap
    const roomBelow = window.innerHeight - a.bottom
    if (roomBelow < tip.offsetHeight + gap && a.top > tip.offsetHeight + gap) {
      top = a.top - root.top - tip.offsetHeight - gap
      tip.classList.add("above")
    }
    tip.style.left = `${Math.round(left)}px`
    tip.style.top = `${Math.round(top)}px`
    tip.style.setProperty("--caret", `${Math.round(caret)}px`)
  }

  close() {
    this.cancel()
    this.cancelClose()
    if (!this.tip) return
    this.anchor?.removeAttribute("aria-describedby")
    this.tip.remove()
    this.tip = null
    this.anchor = null
  }
}
