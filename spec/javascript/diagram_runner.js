// Real browser regression for the diagram controller (D-21): the shipped controller
// source draws with the vendored Pele, and a text Pele refuses (over its 50,000-character
// limit, labels carrying markup) keeps the Mermaid text and says why in an inert status line.
document.body.className = "wm page"
// The page runs under the engine's style policy: any style attribute Pele's output carried would be
// refused and reported here, and the drawing would lose its theme.
const violations = []
document.addEventListener("securitypolicyviolation", (event) => violations.push(`${event.effectiveDirective} ${event.sample || event.blockedURI}`))
document.body.dataset.theme = "dark"

function panel(id, text) {
  const dia = document.createElement("div")
  dia.className = "dia"
  dia.id = id
  dia.innerHTML = `<div class="dh"><b>${id}</b><span class="tools"><button class="tool" type="button" hidden aria-pressed="false">Mermaid text</button></span></div>
<div class="dw hscroll"><p class="cap refusal" role="status" hidden></p><div class="pele-host" hidden></div><pre class="cmd" role="region" aria-label="Mermaid source"></pre></div>`
  dia.querySelector("pre").textContent = text
  document.body.appendChild(dia)
  const controller = new DiagramController()
  Object.assign(controller, {
    element: dia, labelValue: `${id} diagram`,
    sourceTarget: dia.querySelector("pre"), canvasTarget: dia.querySelector(".pele-host"),
    scrollerTarget: dia.querySelector(".dw"),
    toggleTarget: dia.querySelector(".tool"), hasToggleTarget: true,
    messageTarget: dia.querySelector(".refusal"), hasMessageTarget: true
  })
  return controller
}

function state(controller) {
  const message = controller.messageTarget
  const svg = controller.canvasTarget.querySelector("svg")
  return {
    drawn: !controller.canvasTarget.hidden && !!svg, svgLabel: svg ? svg.getAttribute("aria-label") : null,
    svgStyled: !!svg && svg.style.length > 0 && !svg.querySelector("[data-pele-style]"),
    sourceVisible: !controller.sourceTarget.hidden, toggleVisible: !controller.toggleTarget.hidden,
    messageVisible: !message.hidden, message: message.textContent, messageChildren: message.children.length,
    error: controller.element.dataset.diagramError || null
  }
}

const drawn = panel("drawn", "flowchart LR\n  A[\"Post\"] -->|belongs_to| B[\"User\"]")
const refused = panel("refused", "flowchart LR\n" + '  A["<img src=x onerror=window.pwned=1>"]-->B\n'.repeat(1500))

Promise.all([drawn.connect(), refused.connect()]).then(() => new Promise((resolve) => setTimeout(resolve, 50))).then(() => {
  document.getElementById("result").textContent = JSON.stringify({
    drawn: state(drawn), refused: state(refused), pwned: window.pwned === 1, violations
  })
})
