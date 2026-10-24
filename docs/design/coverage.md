# Design coverage

Every page and panel the map needs, the requirement it answers, the board that
designs it and how far that board is from final. This is a map of the design
artefacts, not a status board: issues own the work. Boards are in [boards/](boards/README.md) as HTML and PNG, and on the Design
canvas ([Woods Map pages](https://claude.ai/artifact/Vm2Sp2izRie5wyZ26Q6gWr)) with the review comments:
B6 and B8 boards are built on `foundations/tokens.css` (v7 and v8), C1 to C5
are the component specimens, B5 and earlier are superseded iterations kept for
the record.

States: **final** = v7/v8 on tokens, reviewed; **v5** = designed before the
token system, needs a v8 pass; **partial** = part of the page exists;
**none** = not designed.

## Page map

Global bar: Units, Landscape, Graph, ERD, Impact, History; search palette on
every page; Guide panel docks on the right; `☰ files` in the breadcrumb band
opens the file tree.

| Route | Page | Requirements | Board | State |
|---|---|---|---|---|
| `/woods` | Status page (generation, HEAD, freshness, extractors, host) | FR-1 | [B8-States](boards/B8-States.html) (stale panel) | final |
| `/woods?token=` refused, no index, drifted, stale, degraded, empty results, guide unavailable | States and banners | FR-1, D-4, R-1, E-10 | [B8-States](boards/B8-States.html) | final |
| 429 pacing, DNS-rebinding refusal | Rate-limit and loopback-Host states (M8) | D-4 | [M8 staging note](notes/m8-staging.md), the 403 panel of [B8-States](boards/B8-States.html) | note; [woods-map#59](https://github.com/lost-in-the/woods-map/issues/59) |
| `/woods/units` | Units index, grouped by actual type with distinct typed counts | FR-3 | [M1 navigation note](notes/m1-indexed-navigation.md) | shared components; mounted acceptance separate |
| search palette, `/woods/search` | Name, path and full-text code search, completeness | FR-2, B-12 | [B8-Search](boards/B8-Search.html) | final |
| `/woods/units/model/Post` Code | Two lenses, outline, marginalia, peek, confidence marks, folds, concerns inlined | FR-3, FR-4, B-1, B-2, B-7 to B-11, B-15 | [B8-Code](boards/B8-Code.html) | final, amended by D-24: the view scrolls as one region ([woods-map#29](https://github.com/lost-in-the/woods-map/issues/29)) |
| hover card on a reference | Type, path, PageRank, last author, churn in 100 ms | B-3 | [Hover card note](notes/hover-card.md) | prefetched with the page as inert templates, shown by the C5 tooltip on hover (100 ms) and focus |
| disambiguation popover | Candidates with types and paths for an ambiguous name | FR-4, B-1 | — | **none** |
| callers panel | Callers of the current method | B-13 | [B8-Code](boards/B8-Code.html) (margin "called from") | partial |
| unit diff across generations | Unified source diff with metadata changes | B-14, FR-7 | [B8-Impact-Changed](boards/B8-Impact-Changed.html) (diff component), [History note](notes/history.md) | partial: entered from the History tab's generation picker; shows the unit's record in Woods' report (status, facets, categories, metadata keys, source lines); the unified diff waits on [woods#802](https://github.com/lost-in-the/woods/issues/802) |
| Schema tab | ER one hop, associations, columns, database facts | FR-6 | [B6-Schema](boards/B6-Schema.html) | final |
| Lifecycle tab | Sequence / flowchart / lanes, numbered steps, state machine | FR-6, B-19, B-23 | [B6-Lifecycle](boards/B6-Lifecycle.html), [lifecycle views note](notes/lifecycle-views.md) | final; the flowchart and lanes renderings follow the note; C4-dynamic (B-23) needs W-9 and is not offered; per-transition callbacks wait on [woods#796](https://github.com/lost-in-the/woods/issues/796) |
| Graph tab | Neighbourhood, filters, depth, hubs | FR-5, A-1, A-2 | [B6-Graph](boards/B6-Graph.html) | final; built with the Cytoscape canvas, the second layout is *radial* rather than *organic* pending [woods-map#63](https://github.com/lost-in-the/woods-map/issues/63) |
| History tab | Commit strip, commits with description rows, co-change, people | FR-7, B-6, C-5 | [B6-History](boards/B6-History.html), [History note](notes/history.md) | final; built from the commit table (W-3); the generation picker follows the note; line counts and hunks wait on [woods#804](https://github.com/lost-in-the/woods/issues/804); no facets-moved column or *by generation* toggle |
| Controller: Routes tab | Routes, helpers, action sources | FR-3 | [Routes tab note](notes/routes-tab.md) | routes as declared joined to route units, named-route helpers, action sources, unresolvable-route findings; helper references are controller-level until [woods#795](https://github.com/lost-in-the/woods/issues/795) |
| Controller: Passage tab | Stages, filter matrix, callback ladder, mismatch flags, export | B-16 to B-20 | [B8-Passage](boards/B8-Passage.html) | final; the engine shows declared filter scopes (W-8 pending) and compares lexical template ivar mentions with W-7 assignments as advisory notes; missing action/template facts and truncated partial chains remain incomplete; permitted keys are matched to published model facts and unmatched ones stay unverified (woods#797), partial locals are a named limit (woods#798), see [note](notes/passage-mismatch-limits.md) |
| Mailer: Passage and Templates | Mailer action passage, delivery, templates | B-17 | — | **none** (same component as the controller passage) |
| Unit pages: job, mailer, view, concern, serializer, table | Type-specific facts tiles | B-4 | [Published facts note](notes/published-type-facts.md) | bounded published-metadata tiles |
| `/woods/files/*path` | Indexed file ownership: primary and contributor paths, typed owners and unresolved membership | B-5 | [M1 navigation note](notes/m1-indexed-navigation.md) | shared components; mounted acceptance separate |
| `/woods/landscape` Context L1 | People and external systems | B-21 | [B8-Landscape](boards/B8-Landscape.html) (ladder only) | partial; people from `config.landscape_actors`, inside the Containers tab ([note](notes/landscape.md)) |
| Landscape Containers L2 | C4 containers, relationships, structural risk | B-21, W-9 | [B8-Landscape](boards/B8-Landscape.html) | final; built from W-9 with Mermaid, Structurizr DSL and LikeC4 exports ([note](notes/landscape.md)) |
| Landscape Components L3 | Components by package, namespace or domain cluster, with the board's group control | B-22 | [B8-Landscape](boards/B8-Landscape.html) (group control, ladder) | built: boxes, Pele component diagram, relationships with undeclared package edges; by package only for Packwerk apps (Woods #280) ([note](notes/landscape.md)) |
| Landscape Hotspots | Quadrant, coupling matrix, sankey, treemap, structural risk | design study §7 | [B6-Overview](boards/B6-Overview.html) | final; tiles, the churn × dependents quadrant and ranking, coupling matrix, forward-flow sankey and risk built; the LOC treemap waits on [woods#810](https://github.com/lost-in-the/woods/issues/810) ([note](notes/landscape.md)) |
| Landscape Domains | Domain clusters | design study §7 | [design note](notes/landscape.md) | built from woods#799, with the graph's clusters layout |
| `/woods/graph` | Full-screen graph, domain clusters, list equivalent, flow overlay | FR-5, A-3 to A-6 | B5-Graph (tab only); [design note](notes/graph-page.md) | built: page, list equivalent, blast tint, position cache, clusters layout (woods#799), flow overlay from W-13 ([woods#805](https://github.com/lost-in-the/woods/pull/805)) and the commit timeline from W-3; layouts pending [woods-map#63](https://github.com/lost-in-the/woods-map/issues/63) |
| `/woods/erd` | Whole database by chunk, findings | FR-6 | [B6-ERD](boards/B6-ERD.html) | final; the engine cuts chunks at the ER budget of 40 tables (R-4), not the board's ~15, lists relations to other chunks instead of drawing their far table, and leaves out the board's commits column and polymorphic candidates (W-23) |
| `/woods/history` | Cross-unit timeline for a selected set, commit → node | FR-7, A-6 | [History note](notes/history.md) | note; server-rendered lanes with changed-together pairs, a picker of the most-changed units, the `timeline` export |
| `/woods/impact` Overview | The report's summary as the page's sections (no Markdown, D-25) | E-7 | [Impact range note](notes/impact-range.md) (v8 pass of B5-Impact-Overview) | summary table, samples, provenance, coverage, unknowns; range and saved reports (`/woods/impacts/:id`) |
| Impact Changed | Units as subdivided rows, focus detail, diff | E-2, E-6 | [B8-Impact-Changed](boards/B8-Impact-Changed.html) | final |
| Impact Risks | Findings, rule registry | E-5 | [B8-Impact-Risks](boards/B8-Impact-Risks.html) | final |
| Impact Flows | Entry points through changed units, numbered steps, async boundaries | E-4 | [B6-Impact-Flows](boards/B6-Impact-Flows.html) | final |
| Impact Tests | Run first, gaps | E-5 | [B8-Impact-Tests](boards/B8-Impact-Tests.html) | final |
| Impact Graph | Changed, direct, transitive emphasis | E-3, E-8 | [Impact range note](notes/impact-range.md) | Cytoscape explorer with the report's emphasis (range) or the blast radius (pre-change) |
| Impact Unknown | Unknowns and what each layer proves | E-4, E-10 | [B8-Impact-Unknown](boards/B8-Impact-Unknown.html) | final |
| `?since=` on any view | Changed lines, nodes, steps, columns highlighted | E-8 | [Since note](notes/since.md), [B8-States](boards/B8-States.html) (degraded), tree M badges | Code (marginalia by metadata key), Graph, Passage templates, ERD tables and a banner on every unit tab, from Woods' report only; changed lines wait on [woods#802](https://github.com/lost-in-the/woods/issues/802); tree and timeline not done |
| pre-change mode | Blast radius from a unit or method, no range | E-9 | — | **none** (the impact frame with a focus title; the engine renders it that way from the Changed, Risks, Tests and Unknown boards) |
| Share menu | Focus URL and Mermaid (D-25) | E-6, E-7 | [Share menu note](notes/share-menu.md) | the token-free focus URL, and for each diagram panel its Mermaid copy and stable `.mmd` link, on unit and impact pages; settled by D-25 ([woods-map#57](https://github.com/lost-in-the/woods-map/issues/57)); Markdown and JSON stay with Woods |
| Trail board | Pinned units, lanes, flags, board state, export | C-1 to C-5 | — | **none** (release 0.2, M6) |
| Guide panel | Context chips, actions, tool cards, streamed answer, budget | FR-8 | [B8-Guide](boards/B8-Guide.html), [M7 note](notes/m7-guide.md) | final; chat history list not drawn; the engine streams with EventSource and no Turbo |
| settings | Editor URL scheme, lens, wrap and font size, per browser | B-15, D-6 | [Settings note](notes/settings.md) | modal from the code-view header; wrap opt-in in the one scroll region (D-24); *In editor at L…* only with a configured editor |
| keyboard help | `?` overlay listing every page's keys | NFR-3 | [Keyboard help note](notes/keyboard-help.md) | contextual modal and keyboard coverage |
| four widths | 1280 / 960 / 640 / 390 | D-19 | C1 to C5, [B8-Widths](boards/B8-Widths.html) | final |
| light and colour-vision themes | Same markup, `data-theme`, `data-cvd` | D-11 | C1, C2, [B9-Pele](boards/B9-Pele.html) | final for components; the engine draws diagrams with Pele from the `--pele-*` tokens in every theme (D-21, woods-map#5); the B6 boards keep their static dark renders |

## Gaps by milestone

The undesigned items above, grouped by the milestone issue that will build
them. Each is a comment on that issue, so the issue owns it.

- **M1 · Reading (woods-map#34, carried over from #2)**: units index and indexed ownership now have a [bounded design note](notes/m1-indexed-navigation.md) under [#34](https://github.com/lost-in-the/woods-map/issues/34); the Routes tab has a [design note](notes/routes-tab.md); remaining gaps include facts tiles for job, mailer, view, concern, serializer and table units; the hover card has a [design note](notes/hover-card.md); disambiguation popover; the settings popover has a [design note](notes/settings.md); keyboard help; Share menu contents ([design note](notes/share-menu.md), D-25).
- **M2 · Passage (woods-map#3)**: mailer passage with templates (reuse the controller passage).
- **M4b · Impact (woods-map#4)**: Overview and Graph tabs and `?since=` on Code, Graph, Lifecycle, Passage and ERD have design notes ([impact range](notes/impact-range.md), [since](notes/since.md)); changed lines and the diff wait on [woods#802](https://github.com/lost-in-the/woods/issues/802); `?since=` on the tree and timeline remains.
- **M3 · Diagrams (woods-map#5)**: Landscape Context L1 as its own tab; the LOC treemap (woods#810); C4-dynamic in the Lifecycle view control (needs W-9); the renderer decision (woods-map#25). The flowchart and lanes views follow the [lifecycle views note](notes/lifecycle-views.md).
- **M4 · History (woods-map#6)**: `/woods/history` cross-unit timeline; generation picker; unit diff entry from the History tab. Built from the [History note](notes/history.md).
- **M5 · Graph (woods-map#7)**: [neighbourhood JSON contract](notes/neighbourhood-json.md); the Graph tab's Cytoscape canvas, layouts pending [woods-map#63](https://github.com/lost-in-the/woods-map/issues/63); the [full-screen graph](notes/graph-page.md) with clusters, the flow overlay (A-4) and the commit timeline (A-6).
- **M6 · Trail (woods-map#8)**: the board, end to end.
- **M7 · Guide (woods-map#9)**: chat history, pin and "open as investigation" handoff.

## Consistency rules checked across boards

- One global bar; `Landscape` owns Context, Containers, Components, Hotspots, Domains and Status as tabs (B6-Overview is the Hotspots tab).
- Model unit tabs: Code, Schema, Lifecycle, Graph, History; controller unit tabs: Code, Routes, Passage, Lifecycle, Graph, History; one count per tab.
- Impact tabs: Overview, Changed, Risks, Flows, Tests, Graph, Unknown, same counts on every tab board; the focus URL carries the tab's `lens`.
- One application: Blog, Rails 8.0, 412 units, 4 packages, gen 42 at `361468d`; the impact report compares gen 40 `a1b2c3d` to gen 42 `9f8e7d6`.
- The primary button on a unit page is *Code at L18* (open the code view at the definition); on the Code tab itself it becomes *In editor at L61*, which exists only when the host configures an editor URL scheme.
- *No retry_on* on `NotifySubscribersJob` is a warning (orange) everywhere; an unmatched template ivar mention is an advisory note: lexical metadata and analyzed action/filter bodies cannot prove a runtime value. The original board uses red; the engine qualifies that evidence.
