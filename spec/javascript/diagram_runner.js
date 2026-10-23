// Real browser regression for the diagram controller (D-21): the shipped controller
// source draws with the vendored Pele, and a text Pele refuses (over its 50,000-character
// limit, labels carrying markup) keeps the Mermaid text and says why in an inert status line.
document.body.className = "wm page"
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
    sourceVisible: !controller.sourceTarget.hidden, toggleVisible: !controller.toggleTarget.hidden,
    messageVisible: !message.hidden, message: message.textContent, messageChildren: message.children.length,
    error: controller.element.dataset.diagramError || null
  }
}

const drawn = panel("drawn", "flowchart LR\n  A[\"Post\"] -->|belongs_to| B[\"User\"]")
// The Lifecycle tab's lanes (swimlane-beta) and state diagram draw in the browser too.
const lanes = panel("lanes", 'swimlane-beta TB\n  subgraph l_transaction ["in the transaction"]\n    s1["1 · before_save set_slug"]\n  end\n  subgraph l_async ["another process"]\n    a0["NotifySubscribersJob"]\n  end\n  s1 -.->|enqueues| a0')
const machine = panel("state", 'stateDiagram-v2\n  state "draft" as s0\n  state "published" as s1\n  [*] --> s0\n  s0 --> s1 : publish')
const refused = panel("refused", "flowchart LR\n" + '  A["<img src=x onerror=window.pwned=1>"]-->B\n'.repeat(1500))

Promise.all([drawn.connect(), lanes.connect(), machine.connect(), refused.connect()]).then(() => {
  document.getElementById("result").textContent = JSON.stringify({
    drawn: state(drawn), lanes: state(lanes), state: state(machine), refused: state(refused), pwned: window.pwned === 1
  })
})
