// Real browser regression for the disambiguation popover (FR-4, B-1): the
// shipped controller opens the candidates under an ambiguous reference,
// moves focus with the arrow keys, and closes on Escape (focus back to the
// reference) or a click outside.
document.body.className = "wm page"
document.documentElement.className = "js"
document.body.innerHTML += `
  <div class="body"><div class="cv"><div class="src">x = <button type="button" class="const amb" aria-haspopup="dialog" aria-expanded="false" aria-controls="wm-amb-1">Notifier</button>.deliver</div></div>
  <div class="amb-pop" id="wm-amb-1" role="dialog" aria-label="Candidates for Notifier" hidden>
    <ul><li><a href="#one">Admin::Notifier</a></li><li><a href="#two">Notifier</a></li></ul>
  </div>
  <p><a href="#outside" id="outside">elsewhere</a></p></div>`

const failures = []
const check = (name, condition) => { if (!condition) failures.push(name) }
const root = document.querySelector(".body")
const button = root.querySelector("button.amb")
const popover = document.getElementById("wm-amb-1")
const controller = new DisambiguationController()
Object.assign(controller, { element: root, popoverTargets: [popover] })
controller.connect()
const key = (k) => document.activeElement.dispatchEvent(new KeyboardEvent("keydown", { key: k, bubbles: true, cancelable: true }))

button.focus()
controller.toggle({ currentTarget: button, preventDefault() {} })
check("opens", !popover.hidden && button.getAttribute("aria-expanded") === "true")
check("focuses the first candidate", document.activeElement.textContent === "Admin::Notifier")
check("places under the button", Math.abs(popover.getBoundingClientRect().top - (button.getBoundingClientRect().bottom + 4)) <= 1)
key("ArrowDown")
check("arrow down", document.activeElement.textContent === "Notifier")
key("ArrowDown")
check("wraps", document.activeElement.textContent === "Admin::Notifier")
key("ArrowUp")
check("arrow up wraps back", document.activeElement.textContent === "Notifier")
key("Escape")
check("escape closes", popover.hidden && button.getAttribute("aria-expanded") === "false")
check("escape returns focus", document.activeElement === button)

controller.toggle({ currentTarget: button, preventDefault() {} })
document.getElementById("outside").dispatchEvent(new PointerEvent("pointerdown", { bubbles: true }))
check("click outside closes", popover.hidden)

controller.toggle({ currentTarget: button, preventDefault() {} })
controller.toggle({ currentTarget: button, preventDefault() {} })
check("the button toggles it shut", popover.hidden && document.activeElement === button)

document.getElementById("result").textContent = JSON.stringify({ cases: 11, failures })
