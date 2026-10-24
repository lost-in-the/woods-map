import { Controller } from "@hotwired/stimulus"

// The Graph tab's interactive neighbourhood (M5; FR-5, A-1, A-2, A-5).
//
// The page renders the filters, the Pele flowchart and the list equivalent on
// the server; this controller fetches the bounded neighbourhood JSON for the
// same query (identifiers, type, depth, direction and the filters only), draws
// it with the vendored Cytoscape, and hides the flowchart behind a toggle. The
// flowchart stays the no-JavaScript view and the Mermaid export (D-21).
//
// Layouts are computed here, not by a layout library: "butterfly" places the
// dependents left and the dependencies right in columns by signed traversal
// level, ordered by barycentre sweeps, which is linear in the elements and
// adds almost nothing to the draw; "radial" runs Cytoscape's built-in
// concentric layout with this unit at the centre and one ring per hop
// (woods-map#7; the layout decision is woods-map#63).
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
export default class extends Controller {
  static targets = ["panel", "canvas", "facts", "status", "message", "fallback", "flowchart", "layouts", "layout", "list", "play", "scrub", "scrubFrom", "scrubTo", "window"]
  static values = { url: String, unitUrl: String, label: String, generation: Number, cache: String, blast: Array, emphasis: String, clusters: Array, mode: String, flow: Object, timeline: Array }

  static LAYOUT_KEY = "woods-map:graph-layout"
  static POSITIONS_KEY = "woods-map:graph-positions"
  static POSITIONS_KEPT = 24
  static ASSOCIATIONS = new Set(["belongs_to", "has_many", "has_one", "has_and_belongs_to_many", "through", "polymorphic"])
  static TINT = 0.18
  static DETAILED_NODES = 120
  static DETAILED_EDGES = 150
  static DETAIL_ZOOM = 0.7

  connect() {
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
      this.units().forEach((node) => node.data("fill", palette.get(this.byId.get(node.id())?.type)))
      this.cy.style(this.stylesheet(this.font()))
    })
  }

  disconnect() {
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
        elements.push({ group: "edges", data: { id: `we${i}`, source: `w${i - 1}`, target: `w${i}`, label: "via", dy: 0, off: 20 }, classes: i % 2 ? "detail dep taxi lt" : "assoc" })
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
    if (this.hasLayoutsTarget) this.layoutsTarget.hidden = false
    this.mode = this.hasModeValue && this.modeValue === "clusters" && this.clustersValue.length ? "clusters" : this.storedLayout()
    this.pressLayout()

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

    // Overview mode (more than DETAILED_NODES units or DETAILED_EDGES edges):
    // until the reader zooms in to DETAIL_ZOOM, units are drawn without
    // labels and edges as straight haystack lines without arrows or names.
    // At the fitted zoom of such a neighbourhood none of that is legible,
    // and measuring and routing it is most of a cold draw. The status line
    // and the list name every unit and edge regardless.
    this.detailed = nodes.length <= this.constructor.DETAILED_NODES && edges.length <= this.constructor.DETAILED_EDGES
    this.overview = !this.detailed
    const labelFont = { css: `${font.size - 1.5}px ${font.family}` }
    if (this.detailed) for (const element of elements) element.classes = `${element.classes} detail`.trim()
    // Labels sit just above their line (end labels have no backing), and
    // edges between the same two units, which share one orthogonal path,
    // step their labels below it a line at a time.
    const pairs = new Map()
    for (const edge of edges) {
      const d = edge.data
      const pair = [d.source, d.target].sort().join(" ")
      const nth = pairs.get(pair) || 0
      pairs.set(pair, nth + 1)
      elements.push({
        group: "edges",
        data: { id: d.id, source: d.source, target: d.target, label: d.via, dy: (nth === 0 ? -0.75 : nth) * Math.round(font.size * 1.1), off: this.detailed ? Math.ceil(this.measure(d.via, labelFont) / 2) + 16 : 0 },
        classes: [this.constructor.ASSOCIATIONS.has(d.via) ? "assoc" : "dep", this.detailed ? "detail" : "", this.edgeClasses(d.source, d.target)].join(" ").trim()
      })
    }

    this.cy?.destroy()
    this.guardStylesheet()
    this.cy = cytoscape({
      container: this.canvasTarget,
      elements,
      style: this.stylesheet(font),
      layout: { name: "preset", fit: true, padding: 21 },
      minZoom: 0.02,
      maxZoom: 1.6,
      userZoomingEnabled: false,
      boxSelectionEnabled: false,
      autoungrabify: false,
      autounselectify: true,
      pixelRatio: this.overview ? 1 : "auto",
      textureOnViewport: this.overview,
      hideEdgesOnViewport: this.overview
    })
    if (this.overview) {
      this.cy.on("zoom", () => {
        const detailed = this.cy.zoom() >= this.constructor.DETAIL_ZOOM
        if (detailed === this.detailed) return
        this.detailed = detailed
        this.cy.batch(() => {
          if (detailed) this.cy.edges().forEach((edge) => edge.data("off", Math.ceil(this.measure(edge.data("label"), labelFont) / 2) + 16))
          this.cy.elements().toggleClass("detail", detailed)
        })
      })
    }
    this.cy.on("tap", "node", (event) => this.open(event.target.id()))
    this.cy.on("mouseover", "node", (event) => { this.canvasTarget.style.cursor = "pointer"; this.light(event.target) })
    this.cy.on("mouseout", "node", () => { this.canvasTarget.style.cursor = ""; this.light(this.cy.nodes(".sel")) })
    this.cy.on("dragfree", "node", () => this.remember())
    if (this.mode !== "butterfly") this.arrange()
    this.restore()
    this.tint()
    this.overlayFlow()
    this.showScrub()

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
  // reached along an incoming edge one column left. Rows follow discovery
  // order, then two barycentre sweeps pull each unit toward its neighbours.
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
    const levels = new Map([[focusId, 0]])
    let frontier = [focusId]
    while (frontier.length) {
      const next = []
      for (const id of frontier) {
        const at = column.get(id)
        for (const other of near.get(id) || []) if (!levels.has(other)) levels.set(other, levels.get(id) + 1)
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
    const row = new Map()
    const index = () => {
      for (const c of keys) {
        const ids = columns.get(c)
        // The focus keeps the middle of its column; siblings stack around it.
        if (c === 0) {
          const others = ids.filter((id) => id !== focusId)
          const half = Math.floor(others.length / 2)
          ids.splice(0, ids.length, ...others.slice(0, half), focusId, ...others.slice(half))
        }
        ids.forEach((id, i) => row.set(id, i - (ids.length - 1) / 2))
      }
    }
    index()
    const sweep = (order) => {
      for (const c of order) {
        if (c === 0) continue
        const ids = columns.get(c)
        const toward = c > 0 ? c - 1 : c + 1
        const centre = new Map(ids.map((id) => {
          const linked = (near.get(id) || []).filter((other) => column.get(other) === toward)
          const mean = linked.length ? linked.reduce((sum, other) => sum + row.get(other), 0) / linked.length : row.get(id)
          return [id, mean]
        }))
        ids.sort((a, b) => centre.get(a) - centre.get(b) || row.get(a) - row.get(b))
        ids.forEach((id, i) => row.set(id, i - (ids.length - 1) / 2))
      }
    }
    const outward = keys.filter((c) => c !== 0).sort((a, b) => Math.abs(a) - Math.abs(b))
    sweep(outward)
    sweep(outward)

    // A tall column wraps into sub-columns, row by row, so the canvas keeps
    // a readable aspect; the first sub-column is the one nearest the focus.
    const gap = 190
    const inner = 21
    const maxRows = Math.max(12, Math.round(Math.sqrt(nodes.length) * 1.5))
    const unit = new Map(keys.map((c) => [c, Math.max(...columns.get(c).map((id) => (size.get(id) || [160])[0]))]))
    const subs = new Map(keys.map((c) => [c, Math.ceil(columns.get(c).length / maxRows)]))
    const w = (c) => (unit.has(c) ? subs.get(c) * unit.get(c) + (subs.get(c) - 1) * inner : 0)
    // Columns are contiguous on each side of the focus, so each sits beside the previous one.
    const x = new Map([[0, 0]])
    for (const c of keys.filter((k) => k > 0)) x.set(c, x.get(c - 1) + w(c - 1) / 2 + gap + w(c) / 2)
    for (const c of keys.filter((k) => k < 0).reverse()) x.set(c, x.get(c + 1) - w(c + 1) / 2 - gap - w(c) / 2)
    const pitch = Math.max(...[...size.values()].map(([, h]) => h), 44) + inner
    const positions = new Map()
    for (const c of keys) {
      const ids = columns.get(c)
      const sub = subs.get(c)
      const rows = Math.ceil(ids.length / sub)
      const step = unit.get(c) + inner
      ids.forEach((id, i) => {
        const j = i % sub
        const left = x.get(c) - w(c) / 2 + unit.get(c) / 2
        const cx = c < 0 ? x.get(c) + w(c) / 2 - unit.get(c) / 2 - j * step : left + j * step
        positions.set(id, { x: cx, y: (Math.floor(i / sub) - (rows - 1) / 2) * pitch })
      })
    }
    positions.levels = levels
    return positions
  }

  stylesheet(font) {
    const t = this.tokens()
    const mod = this.rgb(t.mod), panel = this.rgb(t.panel)
    const changedFill = mod && panel ? this.mix(mod, panel, 0.22) : t.panel
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
      { selector: "node.focus", style: { "border-color": t.select, "border-width": 2, color: t.bright } },
      { selector: "node.boundary", style: { "border-style": "dashed" } },
      { selector: "node.br1", style: { "border-color": t.hot, "border-width": 2.5 } },
      { selector: "node.br2", style: { "border-color": t.mod, "border-width": 2 } },
      { selector: "node.cluster", style: {
        shape: "round-rectangle", "background-color": t.panel, "background-opacity": 1, "border-color": t.rule2, "border-width": 1,
        label: "data(label)", "text-valign": "top", "text-halign": "center", "text-margin-y": -4, color: t.mut,
        "font-family": font.family, "font-size": font.size, padding: 13, events: "no"
      } },
      { selector: "node.chg", style: { "background-color": changedFill, "border-color": t.mod, "border-width": 2.5, color: t.bright } },
      { selector: "node.tl", style: { "background-color": changedFill, "border-color": t.mod, "border-width": 2.5, color: t.bright } },
      { selector: "node.flow", style: { "border-color": t.link, "border-width": 2.5 } },
      { selector: "node.flowcur", style: { "border-color": t.link, "border-width": 4, "overlay-color": t.link, "overlay-opacity": 0.16, "overlay-padding": 5, color: t.bright } },
      { selector: "node.sel", style: { "border-color": t.select, "border-width": 3, "overlay-color": t.select, "overlay-opacity": 0.12, "overlay-padding": 4, color: t.bright } },
      { selector: "edge", style: { width: 1, "line-color": t.dim, "curve-style": "haystack", "haystack-radius": 0 } },
      { selector: "edge.detail", style: {
        "target-arrow-color": t.dim, "target-arrow-shape": "triangle", "arrow-scale": 0.8,
        "curve-style": "bezier", "font-family": font.family, "font-size": font.size - 1.5,
        color: t.mut, "text-background-color": t.bg, "text-background-opacity": 1, "text-background-padding": 2,
        "min-zoomed-font-size": 8, label: "data(label)", "text-margin-y": "data(dy)"
      } },
      { selector: "edge.detail.dep", style: { "line-style": "dashed", "line-dash-pattern": [4, 3] } },
      { selector: "edge.detail.taxi", style: { "curve-style": "taxi", "taxi-direction": "horizontal", "taxi-turn": "50%" } },
      { selector: "edge.detail.ls", style: { label: "", "source-label": "data(label)", "source-text-offset": "data(off)", "source-text-margin-y": "data(dy)" } },
      { selector: "edge.detail.lt", style: { label: "", "target-label": "data(label)", "target-text-offset": "data(off)", "target-text-margin-y": "data(dy)" } },
      { selector: "edge:loop", style: { "curve-style": "bezier", "target-arrow-shape": "triangle", "target-arrow-color": t.dim, "loop-direction": "-45deg", "loop-sweep": "-60deg", "control-point-step-size": 72 } },
      { selector: "edge.flow", style: { width: 2.5, "line-color": t.link, "target-arrow-color": t.link, "z-index": 9 } },
      { selector: "edge.flowcur", style: { width: 4, "line-color": t.link, "target-arrow-color": t.link, color: t.bright, "z-index": 11 } },
      { selector: "edge.lit", style: { width: 2, "line-color": t.select, "target-arrow-color": t.select, color: t.bright, "z-index": 10 } }
    ]
  }

  // Butterfly edges that run between columns go orthogonal, as on B6-Graph,
  // with the mechanism on the outer unit's own segment so labels never pile
  // up at the turn; the rest (siblings in one column, the radial layout)
  // stay curved with the label mid-edge.
  edgeClasses(source, target) {
    if (this.mode !== "butterfly") return ""
    const positions = this.butterflyPositions
    const a = positions.get(source)
    const b = positions.get(target)
    if (!a || !b || a.x === b.x) return ""
    const centre = positions.get(this.focusId)?.x || 0
    return Math.abs(a.x - centre) > Math.abs(b.x - centre) ? "taxi ls" : "taxi lt"
  }

  edgeStyle() {
    this.cy.batch(() => {
      this.cy.edges().forEach((edge) => {
        const classes = this.edgeClasses(edge.source().id(), edge.target().id())
        edge.toggleClass("taxi", classes.includes("taxi"))
        edge.toggleClass("ls", classes.includes("ls"))
        edge.toggleClass("lt", classes.includes("lt"))
      })
    })
  }

  // Cytoscape's built-in concentric layout: this unit at the centre, then
  // the units one hop out, then two; heavier units (PageRank) come first. A
  // hop with more units than a ring holds spills into the next ring out, so
  // a large neighbourhood is a disc rather than one enormous circle.
  radial() {
    const levels = this.butterflyPositions.levels
    const rank = (id) => this.byId.get(id)?.pagerank || 0
    const byLevel = new Map()
    this.cy.nodes().forEach((node) => {
      const level = levels.has(node.id()) ? levels.get(node.id()) : Infinity
      if (!byLevel.has(level)) byLevel.set(level, [])
      byLevel.get(level).push(node.id())
    })
    const ring = new Map()
    let index = 0
    for (const level of [...byLevel.keys()].sort((a, b) => a - b)) {
      const ids = byLevel.get(level).sort((a, b) => rank(b) - rank(a))
      for (let start = 0; start < ids.length; index++) {
        const capacity = index === 0 ? 1 : 10 + 8 * index
        ids.slice(start, start + capacity).forEach((id) => ring.set(id, index))
        start += capacity
      }
    }
    const rings = index
    this.cy.layout({
      name: "concentric", animate: false, fit: true, padding: 21, avoidOverlap: true, minNodeSpacing: 13,
      concentric: (node) => (rings - ring.get(node.id())) * 10000 + rank(node.id()) * 999,
      levelWidth: () => 1000
    }).run()
  }

  // Domain clusters (woods#799): each published cluster a compound box of
  // the units drawn here, packed in rows by size; units in no cluster share
  // one box-less block at the end. Identifier-level, as Woods publishes them.
  grouped() {
    if (!this.cy || !this.hasClustersValue) return
    const byKey = new Map(this.clustersValue.map(([identifier, type, name]) => [`${type}\u0000${identifier}`, name]))
    const blocks = new Map()
    this.units().forEach((node) => {
      const d = this.byId.get(node.id())
      const name = d ? byKey.get(`${d.type}\u0000${d.identifier}`) : null
      const key = name || ""
      if (!blocks.has(key)) blocks.set(key, [])
      blocks.get(key).push(node)
    })
    const order = [...blocks.keys()].sort((a, b) => (a === "") - (b === "") || blocks.get(b).length - blocks.get(a).length || a.localeCompare(b))
    const cellW = Math.max(...this.units().map((n) => n.data("w"))) + 21
    const cellH = Math.max(...this.units().map((n) => n.data("h"))) + 21
    const rowWidth = Math.max(4, Math.ceil(Math.sqrt(this.units().length) * 1.6)) * cellW
    let x = 0
    let y = 0
    let rowHeight = 0
    this.cy.batch(() => {
      for (const key of order) {
        const nodes = blocks.get(key)
        const cols = Math.ceil(Math.sqrt(nodes.length))
        const width = cols * cellW + 34
        const height = Math.ceil(nodes.length / cols) * cellH + 55
        if (x > 0 && x + width > rowWidth) { x = 0; y += rowHeight + 34; rowHeight = 0 }
        const parent = key ? this.cy.add({ group: "nodes", data: { id: `cluster:${key}`, label: key, w: 1, h: 1, fill: "rgb(0, 0, 0)" }, classes: "cluster" }) : null
        nodes.sort((a, b) => String(this.byId.get(a.id())?.identifier).localeCompare(String(this.byId.get(b.id())?.identifier)))
        nodes.forEach((node, i) => {
          if (parent) node.move({ parent: parent.id() })
          node.position({ x: x + 17 + (i % cols) * cellW + cellW / 2, y: y + 38 + Math.floor(i / cols) * cellH + cellH / 2 })
        })
        x += width + 34
        rowHeight = Math.max(rowHeight, height)
      }
    })
    this.cy.fit(undefined, 21)
  }

  // The drawn units, without the clusters layout's boxes.
  units() {
    return this.cy.nodes().not(".cluster")
  }

  ungroup() {
    if (!this.cy) return
    const parents = this.cy.nodes(".cluster")
    if (parents.empty()) return
    this.cy.batch(() => {
      parents.children().move({ parent: null })
      parents.remove()
    })
  }

  butterflyLayout() {
    const positions = this.butterflyPositions
    this.cy.nodes().positions((node) => ({ ...positions.get(node.id()) }))
    this.cy.fit(undefined, 21)
  }

  layout(event) {
    const mode = event.currentTarget.dataset.layout
    if (!this.cy || mode === this.mode) return
    this.mode = mode
    try { window.localStorage.setItem(this.constructor.LAYOUT_KEY, mode) } catch (_error) { /* storage is a convenience */ }
    this.pressLayout()
    this.arrange()
  }

  arrange() {
    this.ungroup()
    if (this.mode === "radial") this.radial()
    else if (this.mode === "clusters") this.grouped()
    else this.butterflyLayout()
    this.edgeStyle()
    this.restore()
  }

  // Layout stability (A-3): positions the reader dragged are kept in this
  // browser per generation, query and layout, so a revisit does not
  // reshuffle; a new generation starts from the computed layout again. The
  // layouts themselves are deterministic. Storage is a convenience: every
  // read and write may fail and the page draws the same without it.
  positionsKey() {
    return this.hasCacheValue && this.cacheValue ? `${this.constructor.POSITIONS_KEY}:${this.cacheValue}|${this.mode}` : null
  }

  remember() {
    const key = this.positionsKey()
    if (!key || !this.cy) return
    const positions = {}
    this.units().forEach((node) => { const p = node.position(); positions[node.id()] = [Math.round(p.x), Math.round(p.y)] })
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
    if (!positions || !this.units().every((node) => Array.isArray(positions[node.id()]))) return false
    this.units().positions((node) => ({ x: positions[node.id()][0], y: positions[node.id()][1] }))
    this.cy.fit(undefined, 21)
    this.element.dataset.graphPositions = "restored"
    return true
  }

  forget() {
    const key = this.positionsKey()
    try { if (key) window.localStorage.removeItem(key) } catch (_error) { /* storage is a convenience */ }
    delete this.element.dataset.graphPositions
    if (this.cy) this.arrange()
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

  storedLayout() {
    try {
      const stored = window.localStorage.getItem(this.constructor.LAYOUT_KEY)
      if (stored === "clusters" && this.hasClustersValue && this.clustersValue.length) return "clusters"
      return stored === "radial" ? "radial" : "butterfly"
    } catch (_error) {
      return "butterfly"
    }
  }

  pressLayout() {
    this.layoutTargets.forEach((button) => button.setAttribute("aria-pressed", String(button.dataset.layout === this.mode)))
  }

  fit() { this.cy?.fit(undefined, 21) }
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
    const pick = best(from.neighborhood().nodes().not(".cluster")) || best(this.units().not(from))
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
      `${query.centre}, depth ${query.depth}, ${query.direction}`,
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
    if (this.hasLayoutsTarget) this.layoutsTarget.hidden = true
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
