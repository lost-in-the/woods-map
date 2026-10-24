import { Controller } from "@hotwired/stimulus"

// The Graph tab's interactive neighbourhood (M5; FR-5, A-1, A-2, A-5).
//
// The page renders the filters, the Pele flowchart and the list equivalent on
// the server; this controller fetches the bounded neighbourhood JSON for the
// same query (identifiers, type, depth, direction and the filters only), draws
// it with the vendored Cytoscape, and hides the flowchart behind a toggle. The
// flowchart stays the no-JavaScript view and the Mermaid export (D-21).
//
// One layout, computed here rather than by a layout library (D-30,
// woods-map#63): the butterfly places this unit alone in the middle, the
// dependents left and the dependencies right in columns by signed traversal
// level, ordered by barycentre sweeps, which is linear in the elements and
// adds almost nothing to the draw. Edges between columns run orthogonally;
// each turns near its busier end, so a hub's edges share one trunk, and the
// edges between the same two units share one path and one label.
//
// Colours are the tokens: each unit type's tint is a --g custom property set
// in map.css on [data-gtype], read through a probe element, so the canvas, the
// legend and the theme agree. Hub and cycle marks come from graph_analysis per
// identifier, not per typed unit, and say so.
//
// Keyboard (A-5): the canvas is one tab stop; arrow keys move the selection
// along the edges in that direction, Enter opens the selected unit's graph,
// Home returns to this unit, + / − zoom and 0 fits. The list below the canvas
// is the screen-reader equivalent; ↑ / ↓ move between its rows and a row in
// focus lights its edge on the canvas.
//
// Guide context (M7): while the guide is ready (pick value), Shift+click (or
// Ctrl / Cmd+click) and Space on the canvas add a unit to, or take it from,
// the set the guide panel sends as context; a "woods-map:graph-pick" event
// carries the set and "woods-map:graph-pick-clear" empties it.
export default class extends Controller {
  static targets = ["panel", "canvas", "facts", "status", "message", "fallback", "flowchart", "positions", "list", "play", "scrub", "scrubFrom", "scrubTo", "window"]
  static values = { url: String, unitUrl: String, label: String, generation: Number, cache: String, blast: Array, emphasis: String, flow: Object, timeline: Array, pick: Boolean }

  static POSITIONS_KEY = "woods-map:graph-positions"
  static POSITIONS_KEPT = 24
  static ASSOCIATIONS = new Set(["belongs_to", "has_many", "has_one", "has_and_belongs_to_many", "through", "polymorphic"])
  static TINT = 0.18
  static DETAILED_NODES = 120
  static DETAILED_EDGES = 150
  static DETAIL_ZOOM = 0.5

  connect() {
    this.picked = new Map()
    this.onPickClear = () => this.clearPicks()
    if (this.pickValue) document.addEventListener("woods-map:graph-pick-clear", this.onPickClear)
    this.onListKey = this.onListKey.bind(this)
    this.onListFocus = this.onListFocus.bind(this)
    if (this.hasListTarget) {
      this.listTarget.addEventListener("keydown", this.onListKey)
      this.listTarget.addEventListener("focusin", this.onListFocus)
    }
    if (this.hasCanvasTarget) {
      this.canvasTarget.addEventListener("keydown", (event) => this.key(event))
      this.canvasTarget.addEventListener("focus", () => this.select(this.selectedId))
    }
    // The canvas paints with token values read at draw time; a theme or
    // colour-vision switch on the .wm root repaints it from the new tokens.
    const root = this.element.closest(".wm")
    if (root && window.MutationObserver) {
      this.themeObserver = new MutationObserver(() => this.restyle())
      this.themeObserver.observe(root, { attributes: true, attributeFilter: ["data-theme", "data-cvd"] })
    }
    if (this.hasUrlValue && this.urlValue) this.load()
  }

  restyle() {
    if (!this.cy || !this.payload) return
    const palette = this.palette(this.payload.elements.nodes)
    this.cy.batch(() => {
      this.cy.nodes().forEach((node) => node.data("fill", palette.get(this.byId.get(node.id())?.type)))
      this.cy.style(this.stylesheet(this.font()))
    })
  }

  disconnect() {
    document.removeEventListener("woods-map:graph-pick-clear", this.onPickClear)
    if (this.flowTimer) clearTimeout(this.flowTimer)
    this.themeObserver?.disconnect()
    if (this.hasListTarget) {
      this.listTarget.removeEventListener("keydown", this.onListKey)
      this.listTarget.removeEventListener("focusin", this.onListFocus)
    }
    this.cy?.destroy()
    this.cy = null
  }

  async load() {
    try {
      // The module loads, and its drawing path warms, while the request is in flight.
      const library = import("cytoscape").then(({ default: cytoscape }) => { this.warm(cytoscape); return cytoscape })
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" }, credentials: "same-origin" })
      if (!response.ok) throw new Error(`the neighbourhood endpoint answered ${response.status}`)
      const data = await response.json()
      const cytoscape = await library
      if (document.fonts) await document.fonts.ready
      if (!this.element.isConnected) return
      await this.draw(cytoscape, data)
    } catch (error) {
      this.fail(error)
    }
  }

  // A cold Cytoscape spends most of a first draw compiling its own code. One
  // small graph drawn off screen with the page's stylesheet, in both of its
  // modes, takes that cost while the neighbourhood is still on the network.
  // Cytoscape injects a <style> for its container unless an element with this
  // id exists; the policy (M8) refuses inline style elements, so map.css
  // carries the rule and an inert marker stands in for the injected sheet.
  guardStylesheet() {
    if (document.getElementById("__________cytoscape_stylesheet")) return
    const marker = document.createElement("meta")
    marker.id = "__________cytoscape_stylesheet"
    document.head.appendChild(marker)
  }

  warm(cytoscape) {
    this.guardStylesheet()
    try {
      const host = document.createElement("div")
      host.setAttribute("aria-hidden", "true")
      host.style.cssText = "position:absolute;left:-10000px;top:0;width:200px;height:120px;overflow:hidden"
      this.element.appendChild(host)
      const elements = []
      for (let i = 0; i < 24; i++) {
        elements.push({ group: "nodes", data: { id: `w${i}`, label: `w${i}\nwarm`, w: 80, h: 40, fill: "rgb(0, 0, 0)" }, position: { x: (i % 6) * 120, y: Math.floor(i / 6) * 60 }, classes: i % 2 ? "detail" : "" })
      }
      for (let i = 1; i < 24; i++) {
        elements.push({ group: "edges", data: { id: `we${i}`, source: `w${i - 1}`, target: `w${i}`, label: "via", turn: -16, off: 20 }, classes: i % 2 ? "detail dep taxi lt" : "assoc" })
      }
      const cy = cytoscape({ container: host, elements, style: this.stylesheet(this.font()), layout: { name: "preset", fit: true }, pixelRatio: 1 })
      cy.renderer().render()
      cy.destroy()
      host.remove()
    } catch (_error) {
      // Warming is an optimisation; the draw does not depend on it.
    }
  }

  // Draw a schema-version-1 response. Resolves once the first frame is on the
  // canvas; the time from data in hand to that frame is kept on the element
  // (data-graph-render-ms) for the performance spec and the testbed probe.
  draw(cytoscape, data) {
    const started = performance.now()
    if (data?.schema_version !== 1) throw new Error("the neighbourhood response has an unknown schema version")
    this.payload = data
    this.panelTarget.hidden = false
    this.show(false)
    if (this.hasPositionsTarget) this.positionsTarget.hidden = false

    const nodes = data.elements.nodes
    const edges = data.elements.edges
    this.byId = new Map(nodes.map((node) => [node.data.id, node.data]))
    this.byIdentity = new Map(nodes.map((node) => [this.constructor.identity(node.data), node.data.id]))
    this.focusId = nodes.find((node) => node.data.focus)?.data.id || nodes[0]?.data.id
    const hidden = new Map((data.truncation?.boundaries || []).map((b) => [b.node_id, b]))
    const palette = this.palette(nodes)
    const font = this.font()
    const ranks = nodes.map((node) => node.data.pagerank).filter((rank) => typeof rank === "number")
    const maxRank = Math.max(0, ...ranks)

    const elements = []
    for (const node of nodes) {
      const d = node.data
      const meta = [d.type, d.hub ? "hub" : null, d.cycle ? "cycle" : null].filter(Boolean).join(", ")
      const boundary = hidden.get(d.id)
      const more = boundary ? `  +${boundary.hidden_nodes} hidden` : ""
      const name = d.label.length > 44 ? `${d.label.slice(0, 43)}…` : d.label
      const width = Math.ceil(Math.max(this.measure(name, font), this.measure(meta + more, font))) + 26
      const weight = maxRank > 0 && typeof d.pagerank === "number" ? Math.sqrt(d.pagerank / maxRank) : 0
      elements.push({
        group: "nodes",
        data: { id: d.id, label: `${meta}${more}\n${name}`, w: width, h: Math.round(40 + 16 * weight), fill: palette.get(d.type) },
        classes: [d.focus ? "focus" : "", boundary ? "boundary" : ""].join(" ").trim()
      })
    }
    const marks = { elements: performance.now() - started }
    const positions = this.constructor.butterfly(nodes, edges, this.focusId, elements)
    marks.layout = performance.now() - started
    this.butterflyPositions = positions
    // Copies: Cytoscape keeps the object it is given and moves it with the node.
    for (const element of elements) element.position = { ...positions.get(element.data.id) }

    // Overview mode: below DETAIL_ZOOM, where Cytoscape stops drawing unit
    // names (6px), units are drawn without names and edges without arrows,
    // dashes or labels; zooming in past it brings them in. A neighbourhood
    // that fits below that zoom starts in overview, and so does one past
    // DETAILED_NODES units or DETAILED_EDGES edges, which also draws with
    // the lighter renderer settings: measuring and drawing detail no one
    // can read is most of a cold draw. The status line and the list name
    // every unit and edge regardless.
    const heavy = nodes.length > this.constructor.DETAILED_NODES || edges.length > this.constructor.DETAILED_EDGES
    const fitted = this.constructor.view(this.constructor.extent(elements), [...positions.values()], positions.get(this.focusId) || { x: 0, y: 0 }, this.canvasTarget.clientWidth, this.canvasTarget.clientHeight)
    this.detailed = !heavy && fitted.zoom >= this.constructor.DETAIL_ZOOM
    this.overview = !this.detailed
    const labelFont = { css: `${font.size - 1.5}px ${font.family}` }
    const offset = (label) => (label ? Math.ceil(this.measure(label, labelFont) / 2) + 10 : 0)
    if (this.detailed) for (const element of elements) element.classes = `${element.classes} detail`.trim()
    const routes = this.constructor.routes(edges, positions, new Map(elements.map((e) => [e.data.id, e.data.w])), this.focusId)
    for (const edge of edges) {
      const d = edge.data
      const route = routes.get(d.id)
      elements.push({
        group: "edges",
        data: { id: d.id, source: d.source, target: d.target, via: d.via, label: route.label, turn: route.turn, off: this.detailed ? offset(route.label) : 0 },
        classes: [this.constructor.ASSOCIATIONS.has(d.via) ? "assoc" : "dep", this.detailed ? "detail" : "", route.classes].join(" ").trim()
      })
    }

    this.cy?.destroy()
    this.guardStylesheet()
    this.cy = cytoscape({
      container: this.canvasTarget,
      elements,
      style: this.stylesheet(font),
      layout: { name: "preset", fit: false },
      minZoom: 0.02,
      maxZoom: 1.6,
      userZoomingEnabled: false,
      boxSelectionEnabled: false,
      autoungrabify: false,
      autounselectify: true,
      pixelRatio: heavy ? 1 : "auto",
      textureOnViewport: heavy,
      hideEdgesOnViewport: heavy
    })
    this.cy.viewport(fitted)
    this.cy.on("zoom", () => {
      const detailed = this.cy.zoom() >= this.constructor.DETAIL_ZOOM
      if (detailed === this.detailed) return
      this.detailed = detailed
      this.cy.batch(() => {
        if (detailed) this.cy.edges().forEach((edge) => edge.data("off", offset(edge.data("label"))))
        this.cy.elements().toggleClass("detail", detailed)
      })
    })
    this.cy.on("tap", "node", (event) => {
      const pointer = event.originalEvent
      if (this.pickValue && pointer && (pointer.shiftKey || pointer.ctrlKey || pointer.metaKey)) this.togglePick(event.target.id())
      else this.open(event.target.id())
    })
    this.cy.on("mouseover", "node", (event) => { this.canvasTarget.style.cursor = "pointer"; this.light(event.target) })
    this.cy.on("mouseout", "node", () => { this.canvasTarget.style.cursor = ""; this.light(this.cy.nodes(".sel")) })
    this.cy.on("dragfree", "node", () => this.remember())
    this.restore()
    this.tint()
    this.overlayFlow()
    this.showScrub()
    this.picked.forEach((_, id) => this.cy.getElementById(id).addClass("pick"))

    marks.cytoscape = performance.now() - started
    this.facts()
    this.select(this.focusId, { announce: false })

    // Cytoscape emits "render" once the frame is on the canvas.
    return new Promise((resolve) => {
      this.cy.one("render", () => {
        const ms = performance.now() - started
        this.timings = { ...marks, frame: ms }
        this.element.dataset.graphRenderMs = ms.toFixed(1)
        // Since navigation began: what a reader waits for, network and warm-up included.
        this.element.dataset.graphReadyMs = performance.now().toFixed(1)
        this.element.dataset.graphDrawn = "true"
        resolve(ms)
      })
      this.cy.forceRender()
    })
  }

  // Columns by signed traversal level from the focus: a unit reached along an
  // outgoing edge sits one column right of the unit it was reached from, one
  // reached along an incoming edge one column left. The focus stands alone
  // in the middle of its column with a clear row above and below; units that
  // land in its column too (a dependency's other dependents, a dependent's
  // other dependencies) split above and below it. Rows follow discovery
  // order, then barycentre sweeps pull each unit toward its neighbours.
  static butterfly(nodes, edges, focusId, elements = []) {
    const size = new Map(elements.filter((e) => e.group === "nodes").map((e) => [e.data.id, [e.data.w || 160, e.data.h || 44]]))
    const out = new Map()
    const inn = new Map()
    const near = new Map()
    for (const { data } of edges) {
      if (!out.has(data.source)) out.set(data.source, [])
      if (!inn.has(data.target)) inn.set(data.target, [])
      out.get(data.source).push(data.target)
      inn.get(data.target).push(data.source)
      for (const [a, b] of [[data.source, data.target], [data.target, data.source]]) {
        if (!near.has(a)) near.set(a, [])
        near.get(a).push(b)
      }
    }
    const column = new Map([[focusId, 0]])
    let frontier = [focusId]
    while (frontier.length) {
      const next = []
      for (const id of frontier) {
        const at = column.get(id)
        for (const target of out.get(id) || []) {
          if (!column.has(target)) { column.set(target, at + 1); next.push(target) }
        }
        for (const source of inn.get(id) || []) {
          if (!column.has(source)) { column.set(source, at - 1); next.push(source) }
        }
      }
      frontier = next
    }
    // Units the returned edges do not connect to the focus (a package filter
    // can leave some) stand in one more column on the right.
    const reach = Math.max(0, ...column.values())
    for (const { data } of nodes) if (!column.has(data.id)) column.set(data.id, reach + 1)

    const columns = new Map()
    for (const { data } of nodes) {
      const c = column.get(data.id)
      if (!columns.has(c)) columns.set(c, [])
      columns.get(c).push(data.id)
    }
    const keys = [...columns.keys()].sort((a, b) => a - b)

    // A tall column wraps into sub-columns (lanes), filled row by row with
    // odd lanes half a row lower, so an edge from an outer lane passes
    // between the units of the lane beside it instead of through them. Two
    // lanes keep every edge clear, so a column takes two until it is 1.25
    // row limits tall; past that it takes a pair of lanes per two row
    // limits, rather than grow far taller than the canvas.
    const gap = 200
    const inner = 21
    const pitch = Math.max(...[...size.values()].map(([, h]) => h), 44) + inner
    const maxRows = Math.max(14, Math.round(Math.sqrt(nodes.length) * 2))
    const lanes = (count) => (count <= maxRows ? 1 : (count <= 2.5 * maxRows ? 2 : 2 * Math.ceil(count / (2 * maxRows))))
    const subs = new Map(keys.map((c) => [c, lanes(columns.get(c).length - (c === 0 ? 1 : 0))]))
    const y = new Map()
    const lane = new Map()
    // The k-th unit of a run of rows, as an offset in rows from the first.
    const at = (k, s) => Math.floor(k / s) + (s > 1 && (k % s) % 2 ? 0.5 : 0)
    const place = (c) => {
      const ids = columns.get(c)
      const s = subs.get(c)
      if (c !== 0) {
        const last = at(ids.length - 1, s)
        ids.forEach((id, i) => { y.set(id, (at(i, s) - last / 2) * pitch); lane.set(id, i % s) })
        return
      }
      const others = ids.filter((id) => id !== focusId)
      const half = Math.floor(others.length / 2)
      const above = others.slice(0, half)
      const below = others.slice(half)
      y.set(focusId, 0)
      lane.set(focusId, -1)
      above.forEach((id, i) => { const k = above.length - 1 - i; y.set(id, -(pitch + inner + at(k, s) * pitch)); lane.set(id, k % s) })
      below.forEach((id, k) => { y.set(id, pitch + inner + at(k, s) * pitch); lane.set(id, k % s) })
      ids.splice(0, ids.length, ...above, focusId, ...below)
    }
    for (const c of keys) place(c)
    const mean = (id, toward) => {
      const linked = (near.get(id) || []).filter((other) => toward.includes(column.get(other)))
      return linked.length ? linked.reduce((sum, other) => sum + y.get(other), 0) / linked.length : y.get(id)
    }
    const sweep = (order, both) => {
      for (const c of order) {
        if (!columns.has(c)) continue
        const toward = c === 0 ? [-1, 1] : (both ? [c - 1, c + 1] : [c > 0 ? c - 1 : c + 1])
        const ids = c === 0 ? columns.get(c).filter((id) => id !== focusId) : columns.get(c)
        const centre = new Map(ids.map((id) => [id, mean(id, toward)]))
        ids.sort((a, b) => centre.get(a) - centre.get(b) || y.get(a) - y.get(b))
        if (c === 0) columns.set(0, [...ids, focusId])
        place(c)
      }
    }
    const outward = keys.filter((c) => c !== 0).sort((a, b) => Math.abs(a) - Math.abs(b))
    sweep(outward, false)
    sweep([0], true)
    sweep(outward, true)
    sweep([...outward].reverse(), true)
    sweep(outward, false)

    // Columns are contiguous on each side of the focus, so each sits beside
    // the previous one; the first sub-column is the one nearest the focus.
    const unit = new Map(keys.map((c) => [c, Math.max(...columns.get(c).map((id) => (size.get(id) || [160])[0]))]))
    const w = (c) => (unit.has(c) ? subs.get(c) * unit.get(c) + (subs.get(c) - 1) * inner : 0)
    const x = new Map([[0, 0]])
    for (const c of keys.filter((k) => k > 0)) x.set(c, x.get(c - 1) + w(c - 1) / 2 + gap + w(c) / 2)
    for (const c of keys.filter((k) => k < 0).reverse()) x.set(c, x.get(c + 1) - w(c + 1) / 2 - gap - w(c) / 2)
    const positions = new Map()
    // Each unit's column extent, for the edge routes' trunks.
    positions.spans = new Map()
    for (const c of keys) {
      const step = unit.get(c) + inner
      const span = [x.get(c) - w(c) / 2, x.get(c) + w(c) / 2]
      for (const id of columns.get(c)) {
        positions.spans.set(id, span)
        const j = lane.get(id)
        if (j < 0 || subs.get(c) === 1) { positions.set(id, { x: x.get(c), y: y.get(id) }); continue }
        const offset = (j - (subs.get(c) - 1) / 2) * step
        positions.set(id, { x: x.get(c) + (c < 0 ? -offset : offset), y: y.get(id) })
      }
    }
    return positions
  }

  // Edge routes for the butterfly (D-30). Edges between the same two units
  // share one path and one label that names every mechanism on it. An edge
  // between columns turns near its busier end, the end with more partners
  // on that side, so a hub's edges bundle into one trunk just outside the
  // hub's column; the hubs of a column side take turns at the distance, so
  // neighbouring trunks stay apart. The label sits on the other end's own segment, or, when that end
  // is shared too, shows only while the edge is lit. Returns per edge id the
  // classes, the label ("" on all but the first edge of a pair) and the
  // taxi-turn in pixels (negative counts from the target).
  static routes(edges, positions, widths, focusId) {
    const BASE = 14
    const STEP = 7
    const SLOTS = 6
    const pairs = new Map()
    for (const { data } of edges) {
      const key = data.source < data.target ? `${data.source} ${data.target}` : `${data.target} ${data.source}`
      if (!pairs.has(key)) pairs.set(key, [])
      pairs.get(key).push(data)
    }
    const at = (id) => positions.get(id) || { x: 0, y: 0 }
    const span = (id) => positions.spans?.get(id) || [at(id).x, at(id).x]
    const across = (a, b) => a !== b && at(a).x !== at(b).x
    const side = (id, other) => `${id}${at(other).x < at(id).x ? "<" : ">"}`
    const fan = new Map()
    for (const [first] of pairs.values()) {
      if (!across(first.source, first.target)) continue
      for (const [id, other] of [[first.source, first.target], [first.target, first.source]]) fan.set(side(id, other), (fan.get(side(id, other)) || 0) + 1)
    }
    const centre = at(focusId).x
    const hubOf = new Map()
    const trunks = new Map()
    for (const [key, [first]] of pairs) {
      if (!across(first.source, first.target)) continue
      const [a, b] = [first.source, first.target]
      const fa = fan.get(side(a, b))
      const fb = fan.get(side(b, a))
      const inward = Math.abs(at(a).x - centre) <= Math.abs(at(b).x - centre)
      const hub = fa > fb || (fa === fb && inward) ? a : b
      const other = hub === a ? b : a
      hubOf.set(key, hub)
      const trunk = side(hub, other)
      if (!trunks.has(trunk)) trunks.set(trunk, { x: at(hub).x, y: at(hub).y, hub, side: trunk.slice(-1) })
    }
    // Hubs on the same side of the same column take turns, top to bottom.
    const slot = new Map()
    const lines = new Map()
    for (const [trunk, t] of trunks) {
      const line = `${span(t.hub).join(" ")}${t.side}`
      if (!lines.has(line)) lines.set(line, [])
      lines.get(line).push([trunk, t.y])
    }
    for (const list of lines.values()) list.sort((p, q) => p[1] - q[1]).forEach(([trunk], i) => slot.set(trunk, i % SLOTS))

    const routes = new Map()
    for (const [key, group] of pairs) {
      const label = this.pairLabel(group)
      const [first] = group
      if (!across(first.source, first.target)) {
        group.forEach((data, i) => routes.set(data.id, { classes: "", label: i ? "" : label, turn: 0 }))
        continue
      }
      const hub = hubOf.get(key)
      const leaf = hub === first.source ? first.target : first.source
      const space = Math.abs(at(hub).x - at(leaf).x) - ((widths.get(hub) || 0) + (widths.get(leaf) || 0)) / 2
      // From the hub's border to its column's edge on the leaf's side, then the slot.
      const edge = at(leaf).x < at(hub).x ? at(hub).x - (widths.get(hub) || 0) / 2 - span(hub)[0] : span(hub)[1] - at(hub).x - (widths.get(hub) || 0) / 2
      const own = span(hub) === span(leaf)
      const distance = own ? space / 2 : Math.max(10, Math.min(edge + BASE + slot.get(side(hub, leaf)) * STEP, space - 10))
      const loud = fan.get(side(leaf, hub)) === 1
      group.forEach((data, i) => {
        const end = !loud ? "quiet" : (leaf === data.source ? "ls" : "lt")
        routes.set(data.id, { classes: `taxi ${end}`, label: i ? "" : label, turn: hub === data.source ? distance : -distance })
      })
    }
    return routes
  }

  // One label for the edges between two units: the mechanism, with a count
  // when it repeats, or the first mechanisms and how many more.
  static pairLabel(group) {
    const vias = [...new Set(group.map((data) => data.via))]
    if (vias.length === 1) return group.length > 1 ? `${vias[0]} ×${group.length}` : vias[0]
    const two = `${vias[0]}, ${vias[1]}`
    if (vias.length === 2 && two.length <= 24) return two
    return `${vias[0]} +${vias.length - 1}`
  }

  stylesheet(font) {
    const t = this.tokens()
    const mod = this.rgb(t.mod), panel = this.rgb(t.panel)
    const changedFill = mod && panel ? this.mix(mod, panel, 0.22) : t.panel
    const select = this.rgb(t.select)
    const focusFill = select && panel ? this.mix(select, panel, 0.24) : t.panel
    const lift = -Math.round(font.size * 0.75)
    return [
      { selector: "node", style: {
        shape: "round-rectangle", width: "data(w)", height: "data(h)",
        "background-color": "data(fill)", "border-width": 1, "border-color": t.rule2
      } },
      { selector: "node.detail, node.sel", style: {
        label: "data(label)", "text-wrap": "wrap", "text-valign": "center", "text-halign": "center",
        color: t.text, "font-family": font.family, "font-size": font.size, "line-height": 1.5,
        "min-zoomed-font-size": 6
      } },
      // This unit: alone in the middle of its column, filled with the
      // selection hue, a heavier ring and a bold name.
      { selector: "node.focus", style: { "background-color": focusFill, "border-color": t.select, "border-width": 3, color: t.bright, "font-weight": "bold" } },
      { selector: "node.boundary", style: { "border-style": "dashed" } },
      { selector: "node.br1", style: { "border-color": t.hot, "border-width": 2.5 } },
      { selector: "node.br2", style: { "border-color": t.mod, "border-width": 2 } },
      { selector: "node.chg", style: { "background-color": changedFill, "border-color": t.mod, "border-width": 2.5, color: t.bright } },
      { selector: "node.tl", style: { "background-color": changedFill, "border-color": t.mod, "border-width": 2.5, color: t.bright } },
      { selector: "node.flow", style: { "border-color": t.link, "border-width": 2.5 } },
      { selector: "node.flowcur", style: { "border-color": t.link, "border-width": 4, "overlay-color": t.link, "overlay-opacity": 0.16, "overlay-padding": 5, color: t.bright } },
      { selector: "node.sel", style: { "border-color": t.select, "border-width": 3, "overlay-color": t.select, "overlay-opacity": 0.12, "overlay-padding": 4, color: t.bright } },
      { selector: "node.pick", style: { "border-style": "double", "border-color": t.select, "border-width": 5 } },
      { selector: "edge", style: { width: 1, "line-color": t.dim, "curve-style": "haystack", "haystack-radius": 0 } },
      { selector: "edge.detail", style: {
        "target-arrow-color": t.dim, "target-arrow-shape": "triangle", "arrow-scale": 0.8,
        "curve-style": "bezier", "font-family": font.family, "font-size": font.size - 1.5,
        color: t.mut, "text-background-color": t.bg, "text-background-opacity": 1, "text-background-padding": 2,
        "min-zoomed-font-size": 8, label: "data(label)"
      } },
      { selector: "edge.detail.dep", style: { "line-style": "dashed", "line-dash-pattern": [4, 3] } },
      // A label sits on the outer unit's own segment (ls, lt), just above the
      // line since end labels take no backing; where both ends are shared it
      // shows mid-edge, backed, only while the edge is lit (quiet).
      { selector: "edge.taxi", style: { "curve-style": "taxi", "taxi-direction": "horizontal", "taxi-turn": "data(turn)", "taxi-turn-min-distance": 4 } },
      { selector: "edge.detail.ls", style: { label: "", "source-label": "data(label)", "source-text-offset": "data(off)", "source-text-margin-y": lift } },
      { selector: "edge.detail.lt", style: { label: "", "target-label": "data(label)", "target-text-offset": "data(off)", "target-text-margin-y": lift } },
      { selector: "edge.detail.quiet", style: { label: "" } },
      // A loop's step grows with its node: on the tallest (heaviest) nodes a
      // fixed 72px put the control points inside the node and Cytoscape
      // refused to draw the loop (a self redirect_to, seen at depth 1).
      { selector: "edge:loop", style: { "curve-style": "bezier", "target-arrow-shape": "triangle", "target-arrow-color": t.dim, "loop-direction": "-45deg", "loop-sweep": "-60deg", "control-point-step-size": (edge) => Math.max(72, Math.round(edge.source().height() * 2)) } },
      { selector: "edge.flow", style: { width: 2.5, "line-color": t.link, "target-arrow-color": t.link, "z-index": 9 } },
      { selector: "edge.flowcur", style: { width: 4, "line-color": t.link, "target-arrow-color": t.link, color: t.bright, "z-index": 11 } },
      { selector: "edge.lit", style: { width: 2, "line-color": t.select, "target-arrow-color": t.select, color: t.bright, "z-index": 10 } },
      { selector: "edge.detail.quiet.lit", style: { label: "data(label)" } }
    ]
  }

  // Layout stability (A-3): positions the reader dragged are kept in this
  // browser per generation and query, so a revisit does not reshuffle; a
  // new generation starts from the computed layout again, which is itself
  // deterministic. Storage is a convenience: every
  // read and write may fail and the page draws the same without it.
  positionsKey() {
    return this.hasCacheValue && this.cacheValue ? `${this.constructor.POSITIONS_KEY}:${this.cacheValue}` : null
  }

  remember() {
    const key = this.positionsKey()
    if (!key || !this.cy) return
    const positions = {}
    this.cy.nodes().forEach((node) => { const p = node.position(); positions[node.id()] = [Math.round(p.x), Math.round(p.y)] })
    try {
      const storage = window.localStorage
      const index = JSON.parse(storage.getItem(this.constructor.POSITIONS_KEY) || "[]").filter((k) => k !== key)
      index.push(key)
      while (index.length > this.constructor.POSITIONS_KEPT) storage.removeItem(index.shift())
      storage.setItem(key, JSON.stringify(positions))
      storage.setItem(this.constructor.POSITIONS_KEY, JSON.stringify(index))
      this.element.dataset.graphPositions = "kept"
    } catch (_error) { /* storage is a convenience */ }
  }

  restore() {
    const key = this.positionsKey()
    if (!key || !this.cy) return false
    let positions = null
    try { positions = JSON.parse(window.localStorage.getItem(key) || "null") } catch (_error) { return false }
    if (!positions || !this.cy.nodes().every((node) => Array.isArray(positions[node.id()]))) return false
    this.cy.nodes().positions((node) => ({ x: positions[node.id()][0], y: positions[node.id()][1] }))
    this.fit()
    this.element.dataset.graphPositions = "restored"
    return true
  }

  forget() {
    const key = this.positionsKey()
    try { if (key) window.localStorage.removeItem(key) } catch (_error) { /* storage is a convenience */ }
    delete this.element.dataset.graphPositions
    if (!this.cy) return
    const positions = this.butterflyPositions
    this.cy.nodes().positions((node) => ({ ...positions.get(node.id()) }))
    this.fit()
  }

  // Blast radius tint (E-9): units a change to this one reaches, from the
  // page's WoodsMap::BlastRadius over the same generation. On the impact
  // page's range Graph tab (emphasis "range") distance 0 marks the units
  // Woods' report records as changed, and the rest are what it reached (E-3).
  tint() {
    if (!this.cy || !this.hasBlastValue || !this.blastValue.length) return
    const distance = new Map(this.blastValue.map((unit) => [`${unit.type}\u0000${unit.identifier}`, unit.distance]))
    let drawn = 0
    this.cy.batch(() => {
      this.cy.nodes().forEach((node) => {
        const d = this.byId.get(node.id())
        const hops = d && distance.get(`${d.type}\u0000${d.identifier}`)
        if (hops == null) return
        drawn += 1
        node.addClass(hops === 0 ? "chg" : (hops === 1 ? "br1" : "br2"))
      })
    })
    this.blastDrawn = drawn
    this.facts()
  }

static identity(d) {
  return `${d.type}\u0000${d.identifier}`
}

// Flow overlay (A-4): the selected flow's drawn steps, in document order,
// and the drawn edge that reached each, outlined in the link colour. Steps
// the canvas cannot show are in the page's flow list, not drawn here.
overlayFlow() {
  this.flowSteps = []
  if (!this.cy || !this.hasFlowValue || !Array.isArray(this.flowValue?.steps)) return
  const id = (pair) => pair && this.byIdentity.get(this.constructor.identity({ identifier: pair[0], type: pair[1] }))
  for (const step of this.flowValue.steps) {
    const node = this.byIdentity.get(this.constructor.identity(step))
    if (!node) continue
    const source = id(step.from), target = id(step.to)
    const edge = source && target ? this.cy.edges().filter((e) => e.source().id() === source && e.target().id() === target).first() : null
    this.flowSteps.push({ ...step, node, edge: edge?.nonempty() ? edge : null })
  }
  this.cy.batch(() => {
    for (const step of this.flowSteps) {
      this.cy.getElementById(step.node).addClass("flow")
      step.edge?.addClass("flow")
    }
  })
  this.facts()
}

// Walks the flow one step at a time, lighting each unit and the edge that
// reached it and naming it in the status line and the flow list. With
// reduced motion the whole path is lit at once and named in one line.
playFlow() {
  if (!this.cy || !this.flowSteps?.length) return
  this.stopFlow()
  const total = this.flowValue.total || this.flowSteps.length
  const name = (step) => `${step.position}. ${step.identifier}`
  if (window.matchMedia?.("(prefers-reduced-motion: reduce)").matches) {
    this.cy.batch(() => this.flowSteps.forEach((step) => this.lightStep(step, false)))
    this.statusTarget.textContent = `Flow ${this.flowValue.entry_point}, ${this.flowSteps.length} of ${total} steps drawn: ${this.flowSteps.map(name).join(" → ")}`
    return
  }
  let index = 0
  const show = () => {
    const step = this.flowSteps[index]
    this.lightStep(step, true)
    this.announce(step.node, `flow ${this.flowValue.entry_point}, step ${step.position} of ${total}`)
    index += 1
    if (index >= this.flowSteps.length) { this.flowTimer = null; return }
    this.flowTimer = setTimeout(show, 900)
  }
  show()
}

lightStep(step, only) {
  if (only) this.cy.elements(".flowcur").removeClass("flowcur")
  this.cy.getElementById(step.node).addClass("flowcur")
  step.edge?.addClass("flowcur")
  this.element.querySelectorAll("tr[data-flow-step]").forEach((row) => {
    if (only) row.classList.toggle("focus", row.dataset.flowStep === String(step.position))
    else if (row.dataset.flowStep === String(step.position)) row.classList.add("focus")
  })
}

stopFlow() {
  if (this.flowTimer) clearTimeout(this.flowTimer)
  this.flowTimer = null
  this.cy?.elements(".flowcur").removeClass("flowcur")
}

// Timeline (A-6): with a script the window of commits is scrubbed with two
// range inputs, oldest first, and the units its commits touched are filled
// in the modified hue; the commit list names them without a script.
showScrub() {
  if (!this.hasScrubTarget || !this.hasTimelineValue || !this.timelineValue.length) return
  this.scrubTarget.hidden = false
}

scrub() {
  let from = Number(this.scrubFromTarget.value), to = Number(this.scrubToTarget.value)
  if (from > to) [from, to] = [to, from]
  this.tintWindow(from, to)
}

pickCommit(event) {
  const index = Number(event.currentTarget.dataset.commit)
  if (!Number.isInteger(index)) return
  this.scrubFromTarget.value = index
  this.scrubToTarget.value = index
  this.tintWindow(index, index)
}

clearWindow() {
  if (!this.hasScrubTarget) return
  this.scrubFromTarget.value = 0
  this.scrubToTarget.value = this.timelineValue.length - 1
  this.cy?.nodes(".tl").removeClass("tl")
  this.element.querySelectorAll("tr[data-commit].focus").forEach((row) => row.classList.remove("focus"))
  this.windowTarget.textContent = "Move the window to tint the units its commits touched."
  this.windowDrawn = null
}

tintWindow(from, to) {
  const commits = this.timelineValue.slice(from, to + 1)
  if (!commits.length) return
  const touched = new Set(commits.flatMap((commit) => commit.units.map((unit) => this.constructor.identity(unit))))
  let drawn = 0
  this.cy?.batch(() => {
    this.cy.nodes(".tl").removeClass("tl")
    this.cy.nodes().forEach((node) => {
      const d = this.byId.get(node.id())
      if (d && touched.has(this.constructor.identity(d))) { node.addClass("tl"); drawn += 1 }
    })
  })
  this.element.querySelectorAll("tr[data-commit]").forEach((row) => {
    const index = Number(row.dataset.commit)
    row.classList.toggle("focus", index >= from && index <= to)
  })
  const first = commits[0], last = commits[commits.length - 1]
  const span = first === last ? `${first.sha}, ${first.date}, ${first.message}` : `${commits.length} commits, ${first.date} to ${last.date}`
  this.windowDrawn = drawn
  this.windowTarget.textContent = `${span}: ${drawn} ${drawn === 1 ? "unit" : "units"} drawn changed`
}

  fit() {
    if (!this.cy) return
    const focus = this.cy.getElementById(this.focusId)
    if (!focus.nonempty()) { this.cy.fit(undefined, 21); return }
    const box = this.cy.nodes().boundingBox({ includeLabels: false, includeOverlays: false })
    this.cy.viewport(this.constructor.view(box, this.cy.nodes().map((node) => node.position()), focus.position(), this.cy.width(), this.cy.height()))
  }

  // The fitted view with this unit in the middle of the canvas. The zoom
  // takes the extent symmetrically around the focus, but gives up at most
  // a quarter of the plain fit for it; the focus then moves toward the
  // middle as far as keeps every unit in view. A neighbourhood with units
  // on one side only has no middle to keep, and takes the plain fit.
  static view(box, points, focus, width, height) {
    const pad = 21
    const room = [Math.max(1, width - 2 * pad), Math.max(1, height - 2 * pad)]
    const clamp = (zoom) => Math.min(1.6, Math.max(0.02, zoom))
    const plain = clamp(Math.min(room[0] / Math.max(1, box.x2 - box.x1), room[1] / Math.max(1, box.y2 - box.y1)))
    const half = [Math.max(focus.x - box.x1, box.x2 - focus.x, 1), Math.max(focus.y - box.y1, box.y2 - focus.y, 1)]
    const centred = clamp(Math.min(room[0] / (2 * half[0]), room[1] / (2 * half[1])))
    const sides = points.some((p) => p.x < focus.x) && points.some((p) => p.x > focus.x)
    const zoom = sides ? Math.max(centred, 0.75 * plain) : plain
    const pan = (size, at, low, high) => {
      const ideal = size / 2 - zoom * at
      const most = pad - zoom * low
      const least = size - pad - zoom * high
      return least <= most ? Math.min(most, Math.max(least, ideal)) : ideal
    }
    return { zoom, pan: { x: pan(width, focus.x, box.x1, box.x2), y: pan(height, focus.y, box.y1, box.y2) } }
  }

  // The extent of the units about to be drawn, from their positions and sizes.
  static extent(elements) {
    const box = { x1: Infinity, y1: Infinity, x2: -Infinity, y2: -Infinity }
    for (const { group, data, position } of elements) {
      if (group !== "nodes" || !position) continue
      box.x1 = Math.min(box.x1, position.x - data.w / 2)
      box.x2 = Math.max(box.x2, position.x + data.w / 2)
      box.y1 = Math.min(box.y1, position.y - data.h / 2)
      box.y2 = Math.max(box.y2, position.y + data.h / 2)
    }
    return Number.isFinite(box.x1) ? box : { x1: 0, y1: 0, x2: 1, y2: 1 }
  }

  zoomIn() { this.zoom(1.25) }
  zoomOut() { this.zoom(0.8) }

  zoom(factor) {
    if (!this.cy) return
    const extent = this.cy.extent()
    this.cy.zoom({ level: this.cy.zoom() * factor, position: { x: (extent.x1 + extent.x2) / 2, y: (extent.y1 + extent.y2) / 2 } })
  }

  // The flowchart (Pele, D-21) under the canvas: the Mermaid view of the same edges.
  flowchart() {
    this.show(this.fallbackTarget.hidden)
  }

  show(flowchart) {
    this.fallbackTarget.hidden = !flowchart
    if (this.hasFlowchartTarget) this.flowchartTarget.setAttribute("aria-pressed", String(flowchart))
  }

  key(event) {
    if (!this.cy || event.metaKey || event.ctrlKey || event.altKey) return
    const directions = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }
    if (directions[event.key]) {
      const next = this.neighbour(this.selectedId, ...directions[event.key])
      if (next) this.select(next)
      else this.announce(this.selectedId, "nothing further that way")
    } else if (event.key === "Enter") {
      this.open(this.selectedId)
    } else if (event.key === " " && this.pickValue) {
      this.togglePick(this.selectedId)
    } else if (event.key === "Home") {
      this.select(this.focusId)
    } else if (event.key === "+" || event.key === "=") {
      this.zoomIn()
    } else if (event.key === "-") {
      this.zoomOut()
    } else if (event.key === "0") {
      this.fit()
    } else {
      return
    }
    event.preventDefault()
    event.stopPropagation()
  }

  // The unit an arrow reaches: among the selected unit's neighbours on the
  // canvas, the nearest one in that direction (within 60° of it); failing
  // that, the nearest unit in that direction at all.
  neighbour(id, dx, dy) {
    const from = this.cy.getElementById(id)
    if (!from.nonempty()) return null
    const origin = from.position()
    const score = (node) => {
      const p = node.position()
      const vx = p.x - origin.x
      const vy = p.y - origin.y
      const along = vx * dx + vy * dy
      if (along <= 0) return Infinity
      const across = Math.abs(vx * dy - vy * dx)
      if (across > along * Math.tan(Math.PI / 3)) return Infinity
      return along + across * 2
    }
    const best = (collection) => {
      let pick = null
      let low = Infinity
      collection.forEach((node) => {
        const s = score(node)
        if (s < low) { low = s; pick = node }
      })
      return pick
    }
    const pick = best(from.neighborhood().nodes()) || best(this.cy.nodes().not(from))
    return pick ? pick.id() : null
  }

  select(id, { announce = true } = {}) {
    if (!this.cy || !id) return
    this.cy.nodes(".sel").removeClass("sel")
    const node = this.cy.getElementById(id)
    if (!node.nonempty()) return
    this.selectedId = id
    if (!announce) return
    node.addClass("sel")
    this.light(node)
    const extent = this.cy.extent()
    const p = node.position()
    if (p.x < extent.x1 || p.x > extent.x2 || p.y < extent.y1 || p.y > extent.y2) this.cy.center(node)
    this.announce(id)
  }

  light(node) {
    if (!this.cy) return
    this.cy.edges(".lit").removeClass("lit")
    if (node?.nonempty?.()) node.connectedEdges().addClass("lit")
  }

  announce(id, extra = null) {
    const d = this.byId?.get(id)
    if (!d || !this.hasStatusTarget) return
    const node = this.cy.getElementById(id)
    const outgoing = node.outgoers("edge").length
    const incoming = node.incomers("edge").length
    const marks = [d.hub ? "hub" : null, d.cycle ? "in a cycle" : null].filter(Boolean)
    const parts = [
      `${d.identifier}, ${d.type}${d.focus ? ", this unit" : ""}`,
      marks.length ? `${marks.join(", ")} (graph_analysis, per identifier)` : null,
      this.emphasisNote(this.cy.getElementById(id)),
      `${outgoing} ${outgoing === 1 ? "dependency" : "dependencies"} and ${incoming} ${incoming === 1 ? "dependent" : "dependents"} drawn`,
      extra,
      d.focus ? "arrows move along edges" : "Enter opens its graph"
    ]
    this.statusTarget.textContent = parts.filter(Boolean).join("; ")
  }

  emphasisNote(node) {
    const range = this.hasEmphasisValue && this.emphasisValue === "range"
    if (node.hasClass("chg")) return "changed in this range"
    if (node.hasClass("br1")) return range ? "affected directly" : "a change here reaches it directly"
    if (node.hasClass("br2")) return range ? "affected transitively" : "a change here reaches it transitively"
    return null
  }

  // Add a unit to the guide's context, or take it out, and tell the panel.
  togglePick(id) {
    const d = this.byId?.get(id)
    if (!this.cy || !d || !d.identifier) return
    const node = this.cy.getElementById(id)
    const added = !this.picked.has(id)
    if (added) {
      if (this.picked.size >= 20) { this.announce(id, "the guide takes at most 20 units"); return }
      this.picked.set(id, { identifier: d.identifier, type: d.type })
    } else {
      this.picked.delete(id)
    }
    node.toggleClass("pick", added)
    this.firePick()
    const count = this.picked.size
    this.announce(id, `${added ? "added to" : "taken from"} the guide's context, ${count} ${count === 1 ? "unit" : "units"} selected`)
  }

  clearPicks() {
    if (this.picked.size === 0) return
    this.cy?.nodes(".pick").removeClass("pick")
    this.picked.clear()
    this.firePick()
    if (this.hasStatusTarget) this.statusTarget.textContent = "Graph selection cleared from the guide's context."
  }

  firePick() {
    document.dispatchEvent(new CustomEvent("woods-map:graph-pick", { detail: { units: [...this.picked.values()] } }))
  }

  open(id) {
    const d = this.byId?.get(id)
    if (!d || d.focus) return
    window.location.assign(this.unitUrl(d))
  }

  // Rails route globbing escapes everything outside RFC 3986's unreserved
  // and sub-delimiter sets, keeping ":", "@" and "/"; this matches it.
  unitUrl(d) {
    const escape = (value) => Array.from(new TextEncoder().encode(value), (byte) => {
      const ch = String.fromCharCode(byte)
      return byte < 128 && /[A-Za-z0-9\-._~!$&'()*+,;=:@/]/.test(ch) ? ch : `%${byte.toString(16).toUpperCase().padStart(2, "0")}`
    }).join("")
    // In a query string (the full-screen page re-centres) values are components.
    const query = this.unitUrlValue.indexOf("?")
    const inQuery = (marker) => query >= 0 && this.unitUrlValue.indexOf(marker) > query
    const encode = (marker, value) => (inQuery(marker) ? encodeURIComponent(value) : escape(value))
    return this.unitUrlValue.replace("__type__", encode("__type__", d.type)).replace("__identifier__", encode("__identifier__", d.identifier))
  }

  facts() {
    if (!this.hasFactsTarget) return
    const t = this.payload.truncation || {}
    const nodes = this.payload.elements.nodes.length
    const edges = this.payload.elements.edges.length
    const query = this.payload.query || {}
    const facts = [
      query.summary || `${query.centre}, depth ${query.depth}, ${query.direction}`,
      `${nodes} ${nodes === 1 ? "unit" : "units"}`,
      `${edges} ${edges === 1 ? "edge" : "edges"}`
    ]
    if (this.blastDrawn != null) {
      const total = this.blastValue.length
      if (this.hasEmphasisValue && this.emphasisValue === "range") {
        const changed = this.blastValue.filter((unit) => unit.distance === 0).length
        facts.push(`${changed} changed and ${total - changed} affected in the report, ${this.blastDrawn} drawn`)
      } else {
        facts.push(`a change here reaches ${total} ${total === 1 ? "unit" : "units"}, ${this.blastDrawn} drawn`)
      }
    }
    if (this.flowSteps?.length) facts.push(`flow ${this.flowValue.entry_point}, ${this.flowSteps.length} of ${this.flowValue.total || this.flowSteps.length} steps drawn`)
    if (t.truncated) facts.push(`${t.omitted_nodes} more units and ${t.omitted_edges} edges hidden past the ${t.node_limit}-unit limit; dashed units have more`)
    const generation = this.payload.provenance?.generation
    if (this.hasGenerationValue && generation != null && generation !== this.generationValue) {
      facts.push(`drawn from gen ${generation}, newer than this page's gen ${this.generationValue}: reload`)
    }
    this.factsTarget.replaceChildren(...facts.map((text) => {
      const span = document.createElement("span")
      span.textContent = text
      return span
    }))
  }

  // List equivalent: ↑ / ↓ move between the rows' first links; a row in focus
  // lights its edge on the canvas.
  onListKey(event) {
    if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return
    const row = event.target.closest("tbody tr")
    if (!row) return
    const rows = Array.from(this.listTarget.querySelectorAll("tbody tr")).filter((tr) => tr.querySelector("a"))
    const next = rows[rows.indexOf(row) + (event.key === "ArrowDown" ? 1 : -1)]
    if (!next) return
    next.querySelector("a").focus()
    event.preventDefault()
  }

  onListFocus(event) {
    if (!this.cy) return
    const id = event.target.closest("tr")?.dataset.edge
    if (!id) return
    this.cy.edges(".lit").removeClass("lit")
    this.cy.getElementById(id).addClass("lit")
  }

  fail(error) {
    this.cy?.destroy()
    this.cy = null
    this.panelTarget.hidden = true
    if (this.hasPositionsTarget) this.positionsTarget.hidden = true
    this.fallbackTarget.hidden = false
    this.element.dataset.graphError = "error"
    if (this.hasMessageTarget) {
      const reason = error?.message ? `: ${String(error.message).replace(/\.\s*$/, "")}` : ""
      this.messageTarget.textContent = `The interactive graph could not be drawn${reason}. The flowchart and the list show the same edges.`
      this.messageTarget.hidden = false
    }
    console.warn("woods-map: graph left to the flowchart and the list", error)
  }

  // --- tokens -------------------------------------------------------------

  tokens() {
    const style = getComputedStyle(this.canvasTarget)
    const read = (name) => style.getPropertyValue(`--${name}`).trim()
    return Object.fromEntries(["bg", "panel", "text", "bright", "mut", "dim", "rule2", "select", "hot", "mod", "link"].map((name) => [name, read(name)]))
  }

  font() {
    const style = getComputedStyle(this.canvasTarget)
    const size = parseFloat(style.getPropertyValue("--dia-fs")) || 12
    const family = style.getPropertyValue("--ff-data").trim() || "monospace"
    return { size, family, css: `${size}px ${family}` }
  }

  measure(text, font) {
    if (!this.ruler) this.ruler = document.createElement("canvas").getContext("2d")
    this.ruler.font = font.css
    return this.ruler.measureText(text).width
  }

  // Each type's tint: the --g its [data-gtype] rule sets in map.css, mixed
  // into the panel colour as the legend's swatches mix it.
  palette(nodes) {
    const panel = this.rgb(getComputedStyle(this.canvasTarget).getPropertyValue("--panel"))
    const probe = document.createElement("i")
    probe.hidden = true
    this.canvasTarget.appendChild(probe)
    const tints = new Map()
    for (const type of new Set(nodes.map((node) => node.data.type))) {
      probe.dataset.gtype = type || ""
      const hue = this.rgb(getComputedStyle(probe).getPropertyValue("--g"))
      tints.set(type, hue && panel ? this.mix(hue, panel, this.constructor.TINT) : getComputedStyle(this.canvasTarget).getPropertyValue("--panel").trim())
    }
    probe.remove()
    return tints
  }

  rgb(value) {
    const text = String(value || "").trim()
    let match = text.match(/^#([0-9a-f]{6})$/i)
    if (match) return [0, 2, 4].map((i) => parseInt(match[1].slice(i, i + 2), 16))
    match = text.match(/^#([0-9a-f]{3})$/i)
    if (match) return [...match[1]].map((c) => parseInt(c + c, 16))
    match = text.match(/^rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)/i)
    return match ? match.slice(1, 4).map(Number) : null
  }

  mix(hue, base, amount) {
    const channel = (i) => Math.round(hue[i] * amount + base[i] * (1 - amount))
    return `rgb(${channel(0)}, ${channel(1)}, ${channel(2)})`
  }
}
