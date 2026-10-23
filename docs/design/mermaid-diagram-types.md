# Mermaid diagram types for Woods Map

Handoff for the design agent working milestone M3 (Diagrams, woods-map#5) and
the diagram parts of M4b, M5 and M6. It lists every diagram type Mermaid ships,
says whether and where Woods Map generates it, names the Woods data each one is
built from, and records the constraints the renderers must respect.

Source of the type list: the Diagram Syntax sidebar of the Mermaid docs
(`packages/mermaid/src/docs/.vitepress/config.ts` on `develop`, read on
16 October 2026), which mirrors the list at
[mermaidstudio.dev/docs/diagram-types/overview](https://mermaidstudio.dev/docs/diagram-types/overview/).
Version facts come from the Mermaid changelog and the per-type syntax pages in the same repository (`packages/mermaid/src/docs/syntax/*.md`); the current release is 12.2.0. The docs hosts themselves (mermaid.js.org, mermaid.ai, mermaidstudio.dev) were not reachable from the session that wrote this, so every "confirmed syntax" note below cites the repository copy of the page.
Decision D-5 vendors the newest Mermaid, so every type below is available to
the map; availability is not the question, fit is.

The connection inventory in [`connection-types.md`](connection-types.md) is the renderer-agnostic view of the same question and proposes one intermediate model per topology with Mermaid as the default backend; read it first when deciding whether a type is the right drawing at all.

## Verdicts at a glance

| Verdict | Meaning |
|---|---|
| **Core** | Generated and shown in the map's own pages; has a Ruby renderer, a node budget and a headless render spec. |
| **Secondary** | Generated on demand or as an alternative rendering; same renderer discipline, lower priority. |
| **Export** | Produced as copyable text only (issues, pull requests, chat), never rendered in-page. |
| **Verify** | Promising fit; the design agent must confirm syntax and layout against the vendored build before promising it. |
| **No** | Not generated. The data or the question does not exist in Woods, or another type already answers it. |

## The full list

| # | Diagram | Keyword | Since | Verdict | Woods data | Where in the map | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Flowchart | `flowchart` | 8.x | **Core** | Flow documents (`steps`, `operations`: call, async, transaction, conditional, response), impact report paths, `BehavioralProfile` + engines + external consumers for the landscape | Lifecycle tab (branching view), Impact page (changed → affected paths), Landscape page (C4 notation via HTML labels, subgraphs and `classDef`) | The workhorse. `htmlLabels: true` for the C4 box notation; `click` links need `securityLevel: "loose"` on trusted, self-generated text. ELK is the default layout in 12.x. |
| 2 | Swimlanes | `swimlane-beta` (+ direction `TB`/`LR`) | 11.16.0, beta | **Verify** | Flow documents + container attribution (W-9) | Lifecycle tab, lanes view; the Trail board | Confirmed from the docs: each top-level `subgraph id [Label]` is a lane, nodes and edges use flowchart syntax, edges may cross lanes, `-.->` is dotted (dotted plus a label is not shown in the docs, so test it for async hops), `classDef` works. Beta: the syntax may change. Still to verify on the vendored build: label wrapping, three or more lanes with back-edges, and the layered orthogonal layout on a real flow. Keep the map's own HTML lanes as the fallback. |
| 3 | Sequence | `sequenceDiagram` | 8.x | **Core** | Flow documents; job and mailer facts (queue, `deliver_later`); W-4 retry facts for notes | Lifecycle tab, offered first; "explain lifecycle" guide answers; PR comments | Participants are units, `->>` sync calls, `-)` async enqueue and deliver, `loop` for `find_each`, `Note` for risk flags, `autonumber` matching the step table. Cap participants at about 12 per diagram; split by async boundary beyond that. |
| 4 | Class | `classDiagram` | 8.x | **Core** | Model and service metadata, `inlined_concerns`, W-2 method table, `include` and `inheritance` edges, association cardinality | Schema tab (structure view), unit pages for services and POROs | `<<concern>>` stereotype, `<|--` for STI and superclass, labelled associations with cardinality, methods grouped by owner. One model and one hop by default. |
| 5 | State | `stateDiagram-v2` | 8.x | **Core** | `state_machine` units (events, transitions, callbacks, `state_machine_callback` edges) | Unit page of any model with a state machine; Lifecycle tab when the entry is an event | Transition labels carry the event and the side effect; composite states for nested machines. Only for units that have a state machine. |
| 6 | Entity relationship | `erDiagram` | 8.x | **Core** | Model `columns`, `foreign_keys`, `associations` (macro, through, polymorphic, from_db/to_db), `database_table` units | Schema tab (one model + one hop), `/woods/erd` (per namespace or per database) | Cardinality from macros; PK, FK and UK markers; polymorphic drawn as a dashed relation to each candidate type; cross-database associations styled distinctly. Chunk at about 40 tables; raise `maxTextSize`. |
| 7 | User journey | `journey` | 8.x | **No** | None (requires actors and satisfaction scores) | | Woods has no user or satisfaction data. A route-by-role journey could be faked from Pundit facts but would mislead. |
| 8 | Gantt | `gantt` | 8.x | **No** | None | | Planning format. Generation history is a `timeline`, not a schedule. |
| 9 | Pie | `pie` | 8.x | **Secondary** | `manifest.counts` by type; `graph_analysis.stats` | Status page only | Unit distribution at a glance. Never for anything a reader compares precisely. |
| 10 | Quadrant | `quadrantChart` | 10.2 | **Core** | `change_frequency` or commit counts (W-3) against dependent counts or PageRank | Overview page (hotspots); impact report risk context | "Review carefully" quadrant = hot and depended-upon. Label at most about 25 points; link each point to its unit in the HTML form. |
| 11 | Requirement | `requirementDiagram` | 8.x | **No** | None | | SysML requirements tracing; nothing in the index maps to it. |
| 12 | Use case | `usecase-beta` | 12.0.0, beta | **Verify** | Routes grouped by controller; actor roles from a host-supplied list or Devise/Pundit facts (Landscape L1) | Landscape page, L1 alternative | Confirmed syntax: actors must be declared (`actor ID("Label")`), use cases are `ID("label")`, `systemBoundary ID["Title"] ... end` is one level deep with relationships outside it, `-->` association, `..> : include` and `..> : extend`. Only worth it if the host supplies actors; otherwise the C4-notation flowchart already covers L1. |
| 13 | Git graph | `gitGraph` (+ `LR:`, `TB:`, `BT:`) | 8.x | **Export** | Commit table (W-3), manifest branch | History tab export, review write-ups | Illustrative branch picture for a handful of commits: `commit id: tag: type:` (NORMAL, REVERSE, HIGHLIGHT), `branch`, `checkout`, `merge`, `cherry-pick`, `parallelCommits`; theme variables cover eight branches before colours repeat. The commit table is HEAD-reachable, so unmerged branches cannot be drawn; say so in the export. HIGHLIGHT is a natural mark for the commits an impact range covers. |
| 14 | C4 | `C4Context` and friends | 8.x (experimental) | **Export** | Landscape facts, container attribution | Export only | Tried in the design study: fixed styling that ignores the theme, overlapping labels, no edge routing control. The map draws C4 notation with a flowchart instead (section 7 of the design study). |
| 15 | Mind map | `mindmap` | 9.3 | **Secondary** | Namespaces, `package` units, `domain_clusters` | Overview page (structure orientation); tree panel export | Hierarchy of namespaces or packages with unit counts. Mind maps do not carry links in the SVG reliably; use for orientation, the tree panel for navigation. |
| 16 | Timeline | `timeline` | 9.4 | **Core** | Snapshot store (generations, shas, dates, added/modified/deleted), impact report headlines | History tab (generation history), impact page header | One entry per generation with the headline change; links to impact reports in the HTML form. |
| 17 | ZenUML | `zenuml` | 10.1 | **No** | Same as sequence | | An alternative sequence syntax that needs an extra package and offers nothing the sequence diagram lacks here. |
| 18 | Sankey | `sankey-beta` | 10.3 | **Secondary** | Edges grouped by source type → target type and `via`; package → package edges | Overview page (coupling between layers or packages); architecture review exports | Shows where coupling concentrates. Edge counts come straight from `dependency_graph.json`. |
| 19 | XY chart | `xychart-beta` | 10.6 | **Secondary** | Commit table (W-3): commits per week for a unit or neighbourhood | History tab export, review write-ups | The non-interactive export of the vis-timeline strip. Bars with a line overlay. |
| 20 | Block | `block-beta` | 10.9, beta | **Verify** | Landscape facts | Landscape page, alternative L2 layout | A fixed grid of containers reads cleanly when the flowchart's ELK layout wanders. Decide after seeing the flowchart version on the testbed. |
| 21 | Packet | `packet-beta` | 11.0, beta | **No** | None | | Byte-layout diagrams; no protocol data in the index. |
| 22 | Kanban | `kanban` | 11.4 | **No** | None | | Task boards. The investigation pinboard in Trail is a list, not a kanban. |
| 23 | Architecture | `architecture-beta` | 11.1 | **Secondary** | `BehavioralProfile` (database, queue adapter, cache, mail), engines, external consumers, W-9 | Landscape page, L2 alternative with icons | Built-in `server`, `database`, `disk`, `internet`, `cloud` icons; further icon packs load over the network, which the map's CSP forbids, so stay with the built-ins. Group syntax matches containers well. |
| 24 | Radar | `radar-beta` | 11.6, beta | **Secondary** (0.2) | Per-unit measures: LOC, callbacks, associations, dependents, change frequency, mapped tests | Unit page health card; comparing two units | Confirmed syntax: `axis a["Label"], b, c` and `curve id["Label"]{v1, v2, ...}` or `{a: v, b: v}`; several curves overlay; `min` and `max` set the scale and there is no built-in normalisation, so the renderer scales every measure to 0 to 100 itself and the card states the formula. |
| 25 | Event modeling | `eventmodeling` | 11.15.0 | **Verify** | `event` units, `published_by` and `subscribed_by` edges, controller actions as UI frames, services and jobs as commands or processors, serializers and views as read models | Lifecycle tab for event-driven apps (Active Support notifications, pub/sub gems) | Confirmed syntax: numbered time frames `tf 01 ui Name`, `cmd`, `pcr`, `rmo`, `evt`, three default swimlanes (UI/Automation, Command/Read Model, Events), a namespace prefix opens another lane, relations inferred in order or set with `->>`, `rf` reset frames, reusable `data` blocks. The mapping from Rails units is plausible; prototype against a testbed variant that has `event` units before committing, and skip it if the result is a decorated sequence diagram. |
| 26 | Treemap | `treemap-beta` | 11.x, beta | **Secondary** | Packages or namespaces sized by LOC, unit count or PageRank sum | Overview page (which package carries the code) | Size is the point; use when the mind map's equal-sized nodes hide it. |
| 27 | Venn | `venn-beta` | 11.13.0, beta | **No** | None with overlapping sets worth drawing | | Overlap of two unit sets (for example, units in two domain clusters) is a short list, not a picture. |
| 28 | Ishikawa | `ishikawa-beta` | 11.13.0, beta | **No** | None | | Root-cause brainstorming format; the bug-diagnosis path uses flows and history, not cause categories. |
| 29 | Wardley | `wardley-beta` | 11.14.0, beta | **No** | None | | Strategy mapping (visibility against evolution); no index facts place a unit on either axis honestly. |
| 30 | Cynefin | `cynefin-beta` | 11.16.0, beta | **No** | None | | Decision-making framework; not a representation of code. |
| 31 | TreeView | `treeView-beta` | 11.14.0, beta | **Export** | `file_map`, unit tree by type, package or file | Tree panel export; file view export | Confirmed syntax: nesting by indentation, a trailing `/` marks a folder, `## text` adds an italic annotation per node (unit type and count fit there), `:::highlight` marks changed nodes for a `?since=` export. Icons need packs that are not bundled, so render with `showIcons: false`. |
| 32 | Agentflow | `agentflow-beta` (+ direction) | 12.0.0, beta, hidden from the docs nav | **Verify** | Guide tool-call traces (M7): tools called, results, decisions | Guide panel transcript export | Confirmed syntax: `flow Name ... end` containers (nestable), `global ... end`, shape aliases `task`, `tool`, `input`, `decision`, `refdoc`, `action`, edges `-->` sequence, `-.-` reference, `--x` failure, YAML metadata in `@{ ... }` (model, instruction, params, returns), `connector` for external systems. Maps directly onto a guide session (agent, MCP tools, decisions, failures). Beta with announced breaking changes ahead; keep the HTML transcript as the primary form. |

## What the map renders, by page

| Page or tab | First rendering | Alternatives (one click) | Export only |
|---|---|---|---|
| Lifecycle tab (controller action, job, mailer, model event) | Sequence (3) | Flowchart (1), Swimlanes (2, if verified), map's own lanes, C4 dynamic in own SVG | C4 (14) |
| Schema tab (model) | Entity relationship (6) | Class (4) | |
| Unit page, state machine present | State (5) | | |
| `/woods/erd` | Entity relationship (6), chunked | | |
| Landscape page | Flowchart in C4 notation (1) | Architecture (23), Block (20, if verified), Use case (12, if actors exist) | C4 (14), Structurizr DSL, LikeC4 |
| Overview page | Quadrant (10) | Sankey (18), Mind map (15), Treemap (26), Pie (9) | |
| History tab | Timeline (16) | | XY chart (19), Git graph (13) |
| Impact page | Flowchart LR of paths (1) | | Markdown, JSON (W-12) |
| Trail board | Map's own lanes | Swimlanes (2, if verified), Sequence (3) | Flowchart (1) |
| Unit health card | (none in 0.1) | Radar (24, release 0.2) | |
| Tree panel, file view | (HTML) | | TreeView (31) |
| Guide transcript | (HTML) | | Agentflow (32, if verified) |

## Constraints every renderer follows

1. **One Ruby renderer per type**, extending `Woods::RubyAnalyzer::MermaidRenderer` (it already sanitises identifiers and escapes labels). Renderers take unit JSON, flow documents or graph data and return text; nothing in the map builds Mermaid text inline in a view.
2. **A node budget per type** (flowchart and sequence about 150 nodes, ER about 40 tables, quadrant about 25 points, sankey about 40 links). Above the budget the renderer chunks (by namespace, database, package or async boundary) or refuses with a message naming the budget; it never truncates silently.
3. **Every diagram has a copy-as-Mermaid action** and the same text is the export. The copied text must render in GitHub Markdown, which lags the vendored Mermaid; mark types newer than GitHub's renderer as "may not render on GitHub" in the copy affordance.
4. **A headless render spec** renders every generated type with the vendored build in CI (a JSDOM or Playwright run) so a Mermaid upgrade that breaks a syntax fails a test, not a page.
5. **Security and theme**: `securityLevel: "loose"` only for text the map generated from the index; `htmlLabels: true`; theme variables from the map's own tokens for light and dark; `maxTextSize` and `maxEdges` raised explicitly.
6. **Layout**: ELK by default in 12.x; dagre selectable per diagram for the butterfly and impact layouts where ELK's wandering hurts reading. Record the choice per renderer.
7. **No network at render time**: architecture icon packs, fonts and ELK chunks are vendored or not used.
8. **Honesty markers**: an unexpanded flow step, an ambiguous identifier or a truncated chunk is drawn as such (a dashed node, a note, a count), never dropped.

## Open verifications for the design agent

- [x] Swimlanes (2): lane syntax, async edge styling, label wrapping, behaviour on 3+ lanes with back-edges. Verified on the vendored Pele 1.6.0 (D-21), which draws the Lifecycle lanes view; see [notes/lifecycle-views.md](notes/lifecycle-views.md).
- [ ] Block (20): whether a fixed grid beats the ELK flowchart for L2 on the testbed landscape.
- [ ] Radar (24): the 0 to 100 normalisation formula per measure, shown in the card; axis label clipping on long names.
- [ ] Event modeling (25): fit on a testbed variant with `event` units; skip if the result is a decorated sequence diagram.
- [ ] Use case (12): only if the host supplies actors; decide with the Landscape L1 design.
- [ ] Agentflow (32): render one real guide transcript; revisit when it enters the public docs nav and its syntax is declared stable.
- [ ] GitHub's Mermaid version at the time of M3, to mark which exports render in pull requests.

Record each outcome in `decisions.md` with the testbed variant and the Mermaid version used.
