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
| `/woods/units` | Units index, grouped by actual type with distinct typed counts | FR-3 | [M1 navigation note](notes/m1-indexed-navigation.md) | shared components; mounted acceptance separate |
| search palette, `/woods/search` | Name, path and full-text code search, completeness | FR-2, B-12 | [B8-Search](boards/B8-Search.html) | final |
| `/woods/units/model/Post` Code | Two lenses, outline, marginalia, peek, confidence marks, folds, concerns inlined | FR-3, FR-4, B-1, B-2, B-7 to B-11, B-15 | [B8-Code](boards/B8-Code.html) | final, amended by D-24: the view scrolls as one region ([woods-map#29](https://github.com/lost-in-the/woods-map/issues/29)) |
| hover card on a reference | Type, path, PageRank, last author, churn in 100 ms | B-3 | — | **none** (tooltip component exists, C5) |
| disambiguation popover | Candidates with types and paths for an ambiguous name | FR-4, B-1 | — | **none** |
| callers panel | Callers of the current method | B-13 | [B8-Code](boards/B8-Code.html) (margin "called from") | partial |
| unit diff across generations | Unified source diff with metadata changes | B-14, FR-7 | [B8-Impact-Changed](boards/B8-Impact-Changed.html) (diff component) | partial, no unit-page entry |
| Schema tab | ER one hop, associations, columns, database facts | FR-6 | [B6-Schema](boards/B6-Schema.html) | final |
| Lifecycle tab | Sequence / flowchart / lanes, numbered steps, state machine | FR-6, B-19, B-23 | [B6-Lifecycle](boards/B6-Lifecycle.html) | final; C4-dynamic rendering (B-23) missing from the view control |
| Graph tab | Neighbourhood, filters, depth, hubs | FR-5, A-1, A-2 | [B6-Graph](boards/B6-Graph.html) | final |
| History tab | Commit strip, commits with description rows, co-change, people | FR-7, B-6, C-5 | [B6-History](boards/B6-History.html) | final; generation picker not drawn |
| Controller: Routes tab | Routes, helpers, action sources | FR-3 | [Routes tab note](notes/routes-tab.md) | routes as declared joined to route units, named-route helpers, action sources, unresolvable-route findings; helper references are controller-level until [woods#795](https://github.com/lost-in-the/woods/issues/795) |
| Controller: Passage tab | Stages, filter matrix, callback ladder, mismatch flags, export | B-16 to B-20 | [B8-Passage](boards/B8-Passage.html) | final; the engine shows declared filter scopes (W-8 pending) and compares lexical template ivar mentions with W-7 assignments as advisory notes; missing action/template facts and truncated partial chains remain incomplete |
| Mailer: Passage and Templates | Mailer action passage, delivery, templates | B-17 | — | **none** (same component as the controller passage) |
| Unit pages: job, mailer, view, concern, serializer, table | Type-specific facts tiles | B-4 | [Published facts note](notes/published-type-facts.md) | bounded published-metadata tiles |
| `/woods/files/*path` | Indexed file ownership: primary and contributor paths, typed owners and unresolved membership | B-5 | [M1 navigation note](notes/m1-indexed-navigation.md) | shared components; mounted acceptance separate |
| `/woods/landscape` Context L1 | People and external systems | B-21 | [B8-Landscape](boards/B8-Landscape.html) (ladder only) | partial |
| Landscape Containers L2 | C4 containers, relationships, structural risk | B-21, W-9 | [B8-Landscape](boards/B8-Landscape.html) | final |
| Landscape Components L3 | Compound graph by package with container frame | B-22 | — | **none** |
| Landscape Hotspots | Quadrant, coupling matrix, sankey, treemap, structural risk | design study §7 | [B6-Overview](boards/B6-Overview.html) | final |
| Landscape Domains | Domain clusters | design study §7 | — | **none** |
| `/woods/graph` | Full-screen graph, domain clusters, list equivalent, flow overlay | FR-5, A-3 to A-6 | B5-Graph (tab only) | **none** for the page |
| `/woods/erd` | Whole database by chunk, findings | FR-6 | [B6-ERD](boards/B6-ERD.html) | final |
| `/woods/history` | Cross-unit timeline for a selected set, commit → node | FR-7, A-6 | — | **none** |
| `/woods/impact` Overview | The PR comment, rendered | E-7 | B5-Impact-Overview | v5 |
| Impact Changed | Units as subdivided rows, focus detail, diff | E-2, E-6 | [B8-Impact-Changed](boards/B8-Impact-Changed.html) | final |
| Impact Risks | Findings, rule registry | E-5 | [B8-Impact-Risks](boards/B8-Impact-Risks.html) | final |
| Impact Flows | Entry points through changed units, numbered steps, async boundaries | E-4 | [B6-Impact-Flows](boards/B6-Impact-Flows.html) | final |
| Impact Tests | Run first, gaps | E-5 | [B8-Impact-Tests](boards/B8-Impact-Tests.html) | final |
| Impact Graph | Changed, direct, transitive emphasis | E-3, E-8 | — | **none** |
| Impact Unknown | Unknowns and what each layer proves | E-4, E-10 | [B8-Impact-Unknown](boards/B8-Impact-Unknown.html) | final |
| `?since=` on any view | Changed lines, nodes, steps, columns highlighted | E-8 | [B8-States](boards/B8-States.html) (degraded), tree M badges | partial |
| pre-change mode | Blast radius from a unit or method, no range | E-9 | — | **none** (the impact frame with a focus title; the engine renders it that way from the Changed, Risks, Tests and Unknown boards) |
| Share menu | Focus URL, Markdown, JSON, Mermaid | E-6, E-7 | buttons only | partial |
| Trail board | Pinned units, lanes, flags, board state, export | C-1 to C-5 | — | **none** (release 0.2, M6) |
| Guide panel | Context chips, actions, tool cards, streamed answer, budget | FR-8 | [B8-Guide](boards/B8-Guide.html) | final; chat history list not drawn |
| settings | Editor URL scheme, lens, wrap and font size, per browser | B-15, D-6 | Code toolbar only | partial |
| keyboard help | `?` overlay listing every page's keys | NFR-3 | [Keyboard help note](notes/keyboard-help.md) | contextual modal and keyboard coverage |
| four widths | 1280 / 960 / 640 / 390 | D-19 | C1 to C5, [B8-Widths](boards/B8-Widths.html) | final |
| light and colour-vision themes | Same markup, `data-theme`, `data-cvd` | D-11 | C1, C2, [B9-Pele](boards/B9-Pele.html) | final for components; the engine draws diagrams with Pele from the `--pele-*` tokens in every theme (D-21, woods-map#5); the B6 boards keep their static dark renders |

## Gaps by milestone

The undesigned items above, grouped by the milestone issue that will build
them. Each is a comment on that issue, so the issue owns it.

- **M1 · Reading (woods-map#34, carried over from #2)**: units index and indexed ownership now have a [bounded design note](notes/m1-indexed-navigation.md) under [#34](https://github.com/lost-in-the/woods-map/issues/34); the Routes tab has a [design note](notes/routes-tab.md); remaining gaps include facts tiles for job, mailer, view, concern, serializer and table units; hover card; disambiguation popover; settings popover; keyboard help; Share menu contents.
- **M2 · Passage (woods-map#3)**: mailer passage with templates (reuse the controller passage).
- **M4b · Impact (woods-map#4)**: Overview tab at v8; Graph tab; pre-change mode; `?since=` highlighting on Code, Graph, Lifecycle, Passage, ERD and timeline views.
- **M3 · Diagrams (woods-map#5)**: Landscape Context L1, Components L3, Domains; C4-dynamic in the Lifecycle view control; the renderer decision (woods-map#25).
- **M4 · History (woods-map#6)**: `/woods/history` cross-unit timeline; generation picker; unit diff entry from the History tab.
- **M5 · Graph (woods-map#7)**: [neighbourhood JSON contract](notes/neighbourhood-json.md); full-screen graph, list equivalent and flow overlay remain separate.
- **M6 · Trail (woods-map#8)**: the board, end to end.
- **M7 · Guide (woods-map#9)**: chat history, pin and "open as investigation" handoff.

## Consistency rules checked across boards

- One global bar; `Landscape` owns Context, Containers, Components, Hotspots, Domains and Status as tabs (B6-Overview is the Hotspots tab).
- Model unit tabs: Code, Schema, Lifecycle, Graph, History; controller unit tabs: Code, Routes, Passage, Lifecycle, Graph, History; one count per tab.
- Impact tabs: Overview, Changed, Risks, Flows, Tests, Graph, Unknown, same counts on every tab board; the focus URL carries the tab's `lens`.
- One application: Blog, Rails 8.0, 412 units, 4 packages, gen 42 at `361468d`; the impact report compares gen 40 `a1b2c3d` to gen 42 `9f8e7d6`.
- The primary button on a unit page is *Code at L18* (open the code view at the definition); on the Code tab itself it becomes *In editor at L61*, which exists only when the host configures an editor URL scheme.
- *No retry_on* on `NotifySubscribersJob` is a warning (orange) everywhere; an unmatched template ivar mention is an advisory note: lexical metadata and analyzed action/filter bodies cannot prove a runtime value. The original board uses red; the engine qualifies that evidence.
