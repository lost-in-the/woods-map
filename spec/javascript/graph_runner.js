// Real browser regression for the Graph tab's canvas (M5): the shipped graph controller
// draws a generated schema-version-1 neighbourhood at the endpoint's limits (300 units,
// 1,000 edges) with the vendored Cytoscape and times it, and the canvas is
// keyboard-operable: arrows move along edges, Enter opens, Home returns.
//
// Only the first draw is timed. It runs before any timer in the page has fired: once one
// has, Chromium's virtual time (--virtual-time-budget) stops performance.now() counting
// synchronous work, so later timings in this page would read zero.
document.body.className = "wm page"
document.body.dataset.theme = "dark"

// A depth-2 neighbourhood shaped like the endpoint's output: the focus, 45 units one hop
// out on either side, the rest two hops out, and extra edges that each touch a unit one
// hop out (every edge of a two-hop traversal does).
function neighbourhood(units, edgeCount) {
  let seed = 7
  const random = () => (seed = (seed * 16807) % 2147483647) / 2147483647
  const types = ["model", "controller", "view_template", "job", "concern", "route", "service"]
  const vias = ["belongs_to", "has_many", "code_reference", "render", "include", "job_enqueue", "route_dispatch"]
  const nodes = []
  for (let i = 0; i < units; i++) {
    nodes.push({ data: {
      id: `n_${i}`, identifier: i === 0 ? "Post" : `Generated::Unit${i}`, label: i === 0 ? "Post" : `Generated::Unit${i}`,
      type: i === 0 ? "model" : types[i % types.length], focus: i === 0, file_path: `app/generated/unit_${i}.rb`,
      pagerank: random() / 50, change_frequency: null, hub: i % 37 === 0, cycle: i % 53 === 0, package: null
    } })
  }
  const edges = []
  const near = Math.min(45, Math.floor(units / 3))
  const edge = (source, target, depth) => {
    edges.push({ data: { id: `e_${edges.length}`, source: `n_${source}`, target: `n_${target}`,
      via: vias[edges.length % vias.length], depth, through: null, cross_database: null } })
  }
  for (let i = 1; i < units; i++) {
    const parent = i <= near ? 0 : 1 + Math.floor(random() * near)
    if (random() < 0.5) edge(parent, i, i <= near ? 1 : 2)
    else edge(i, parent, i <= near ? 1 : 2)
  }
  while (edges.length < edgeCount) {
    const a = 1 + Math.floor(random() * near)
    const b = Math.floor(random() * units)
    if (a === b) continue
    if (random() < 0.5) edge(a, b, 2)
    else edge(b, a, 2)
  }
  return {
    schema_version: 1,
    query: { centre: "Post", type: "model", depth: 2, direction: "both", types: null, via: null, package: null, node_limit: 300, edge_limit: 1000 },
    provenance: { generation: 3, analysis_scope: "identifier" },
    elements: { nodes, edges },
    truncation: { truncated: true, node_limit: 300, edge_limit: 1000, total_nodes: 340, total_edges: 1100, omitted_nodes: 40, omitted_edges: 100,
      boundaries: [{ node_id: "n_3", hidden_edges: 9, hidden_nodes: 7 }] }
  }
}

function mount(id) {
  const body = document.createElement("div")
  body.id = id
  body.innerHTML = `
<div data-graph-target="layouts" hidden><button type="button" data-layout="butterfly" aria-pressed="true"></button><button type="button" data-layout="radial" aria-pressed="false"></button></div>
<div class="dia graph" hidden><div class="dh"><b>Neighbourhood</b><span class="gfacts"></span><span class="tools"><button class="tool" type="button" aria-pressed="false">flowchart</button></span></div>
<div class="gcanvas" tabindex="0" role="application" aria-label="Neighbourhood"></div><p class="gstatus" role="status"></p></div>
<p class="cap refusal" role="status" hidden></p>
<div class="fallback"><pre>flowchart LR</pre></div>
<section class="list"><table><tbody><tr data-edge="e_0"><td><a href="#a">a</a></td></tr><tr data-edge="e_1"><td><a href="#b">b</a></td></tr></tbody></table></section>`
  document.body.appendChild(body)
  const controller = new GraphController()
  const q = (selector) => body.querySelector(selector)
  Object.assign(controller, {
    element: body, urlValue: "", hasUrlValue: true, unitUrlValue: "/woods/units/__type__/__identifier__/graph?depth=2",
    generationValue: 3, hasGenerationValue: true, cacheValue: `3|model|Post|${id}`, hasCacheValue: true, blastValue: [], hasBlastValue: true,
    clustersValue: [], hasClustersValue: true, modeValue: "", hasModeValue: true,
    panelTarget: q(".dia.graph"), canvasTarget: q(".gcanvas"), hasCanvasTarget: true, factsTarget: q(".gfacts"), hasFactsTarget: true,
    statusTarget: q(".gstatus"), hasStatusTarget: true, messageTarget: q(".refusal"), hasMessageTarget: true,
    fallbackTarget: q(".fallback"), flowchartTarget: q(".tool"), hasFlowchartTarget: true,
    layoutsTarget: q("[data-graph-target=layouts]"), hasLayoutsTarget: true, layoutTargets: Array.from(body.querySelectorAll("[data-layout]")),
    listTarget: q(".list"), hasListTarget: true
  })
  controller.connect()
  return controller
}

function press(element, key) {
  const event = new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true })
  element.dispatchEvent(event)
  return event.defaultPrevented
}

// The drawing, timed: everything here is synchronous in the module's top level, so it all
// happens before the load event, when --dump-dom reads the page, and no virtual time is
// involved. The frame is rendered synchronously through Cytoscape's renderer instead of
// waiting for the next animation frame; it is the same drawing work.
function drawing(cytoscape) {
  // A fixed loop, timed, so a reader can tell a slow machine from a slow draw.
  const calibrationStarted = performance.now()
  let sum = 0
  for (let i = 0; i < 5e7; i++) sum += i % 7
  const calibrationMs = performance.now() - calibrationStarted + (sum < 0 ? 1 : 0)

  const data = neighbourhood(300, 1000)
  const big = mount("big")
  // What load() does while the request is in flight; the draw is timed from data in hand.
  const warmStarted = performance.now()
  big.warm(cytoscape)
  const warmMs = performance.now() - warmStarted
  const opened = []
  big.open = (id) => opened.push(big.byId.get(id).identifier)
  const started = performance.now()
  big.draw(cytoscape, data)
  big.cy.renderer().render()
  const wall = performance.now() - started

  // Keyboard: focus selects this unit; Right moves to a dependency, Home returns, Enter opens.
  big.canvasTarget.focus()
  const focusSelected = big.selectedId
  const handled = press(big.canvasTarget, "ArrowRight")
  const right = big.byId.get(big.selectedId)
  const rightIsDependency = big.cy.getElementById(focusSelected).outgoers("node").some((node) => node.id() === big.selectedId)
  press(big.canvasTarget, "Enter")
  press(big.canvasTarget, "Home")
  const home = big.selectedId
  const status = big.statusTarget.textContent

  // List rows: a row in focus lights its edge.
  big.listTarget.querySelector("a").focus()
  const lit = big.cy.edges(".lit").map((edge) => edge.id())
  press(big.listTarget.querySelector("a"), "ArrowDown")
  const listMoved = document.activeElement === big.listTarget.querySelectorAll("a")[1]

  const radialStarted = performance.now()
  big.layout({ currentTarget: big.layoutTargets[1] })
  const radialMs = performance.now() - radialStarted
  const moved = (id) => big.cy.getElementById(id).position().x !== big.butterflyPositions.get(id).x
  const radialMoved = moved("n_1") || moved("n_2")

  // Layout stability (A-3): a dragged position is kept per generation and query and
  // restored by the next draw of the same query; forgetting it lays out afresh.
  const small = neighbourhood(40, 80)
  const first = mount("kept")
  first.draw(cytoscape, small)
  first.cy.getElementById("n_5").position({ x: 4321, y: -1234 })
  first.remember()
  const again = mount("kept")
  again.draw(cytoscape, small)
  const kept = again.cy.getElementById("n_5").position()
  const restored = again.element.dataset.graphPositions === "restored" && kept.x === 4321 && kept.y === -1234
  again.forget()
  const forgotten = again.cy.getElementById("n_5").position().x !== 4321

  // Blast radius tint: units the page's BlastRadius reaches get their distance's class.
  const blasted = mount("blasted")
  blasted.blastValue = [{ identifier: "Generated::Unit1", type: "controller", distance: 1 },
    { identifier: "Generated::Unit2", type: "view_template", distance: 2 }, { identifier: "Elsewhere", type: "model", distance: 2 }]
  blasted.draw(cytoscape, small)
  const tinted = { direct: blasted.cy.nodes(".br1").map((n) => n.id()), transitive: blasted.cy.nodes(".br2").map((n) => n.id()),
    facts: blasted.factsTarget.textContent }

  // Domain clusters: the clusters layout boxes each published cluster's members; leaving it removes the boxes.
  const clustered = mount("clustered")
  clustered.clustersValue = [["Generated::Unit1", "controller", "Billing"], ["Generated::Unit2", "view_template", "Billing"],
    ["Generated::Unit3", "job", "Shipping"]]
  clustered.modeValue = "clusters"
  clustered.draw(cytoscape, small)
  const boxes = clustered.cy.nodes(".cluster").map((n) => n.data("label")).sort()
  const boxed = clustered.cy.getElementById("n_1").parent().data("label")
  clustered.layout({ currentTarget: clustered.layoutTargets[0] })
  const unboxed = clustered.cy.nodes(".cluster").length === 0 && clustered.cy.getElementById("n_1").parent().empty()
  const clusters = { boxes, boxed, unboxed }

  // On the full-screen page a node re-centres the page: the identifier is a query value.
  blasted.unitUrlValue = "/woods/graph?centre=__identifier__&type=__type__&depth=2"
  const recentre = blasted.unitUrl({ type: "route", identifier: "GET /users/:id?x=1&y" })

  return {
    restored, forgotten, tinted, recentre, clusters,
    ms: Number(big.element.dataset.graphRenderMs), wall, calibrationMs, warmMs, timings: big.timings, radialMs, radialMoved,
    drawn: big.element.dataset.graphDrawn === "true",
    nodes: big.cy.nodes().length, edges: big.cy.edges().length,
    panelVisible: !big.panelTarget.hidden, fallbackVisible: !big.fallbackTarget.hidden, layoutsVisible: !big.layoutsTarget.hidden,
    canvases: big.canvasTarget.querySelectorAll("canvas").length,
    facts: big.factsTarget.textContent,
    focusSelected: big.byId.get(focusSelected).identifier, handled, rightIsDependency, rightType: right?.type,
    opened, home: big.byId.get(home).identifier, status, lit, listMoved,
    radialPressed: big.layoutTargets[1].getAttribute("aria-pressed"),
    url: big.unitUrl({ type: "route", identifier: "GET /users/:id" })
  }
}

// A failed request leaves the flowchart and the list and says why (asynchronous: run
// under virtual time, in a page of its own).
async function failure() {
  const failed = mount("failed")
  failed.urlValue = "file:///nonexistent/neighbourhood.json"
  await failed.load()
  return { panelVisible: !failed.panelTarget.hidden, fallbackVisible: !failed.fallbackTarget.hidden,
    messageVisible: !failed.messageTarget.hidden, message: failed.messageTarget.textContent, error: failed.element.dataset.graphError || null }
}

const output = (result) => { document.getElementById("result").textContent = JSON.stringify(result) }
try {
  if (location.hash === "#failure") failure().then(output, (error) => output({ error: String(error && error.stack || error) }))
  else output({ ...drawing(cytoscape), injectedStyles: document.querySelectorAll("style#__________cytoscape_stylesheet").length })
} catch (error) {
  output({ error: String(error && error.stack || error) })
}
