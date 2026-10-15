# Decision log

Decisions taken while producing the design study, in the order they were made.
Each entry records the question, the choice, and what it rules in or out. New
decisions go in GitHub issues labelled `needs-decision` and are copied here
when settled, with the issue link.

## Interview (14 October 2026)

| # | Question | Decision | Consequence |
|---|---|---|---|
| I-1 | Data source | Published index only | No live database, no runtime reflection, no git subprocess at read time. Everything the map shows is in a published generation or the snapshot store. |
| I-2 | Front-end delivery | Import map + Hotwire, no build step | All JavaScript vendored and pinned; no Node toolchain at development or release time. |
| I-3 | Audience | Development in-app, and shareable on staging for a team | Bearer token plus origin guard, read-only hardening, source-exposure threat model. |
| I-4 | V1 scope | Search + unit pages + code viewer, relationship graph, lifecycle flowcharts + ERD, git insight timeline | All four are must-haves; they are sliced across milestones, not dropped. |
| I-5 | LLM guide | Chat plus "explain this" actions | RubyLLM 2.1 agent with the Index MCP server attached; actions seeded from page context. |
| I-6 | Packaging | Separate gem | The gem is `woods-map`; Woods itself gains only extraction-side data (W-items). |
| I-7 | Deliverable | Shareable page | The design study was published as a page; this repository now holds the Markdown and HTML copies. |

## Revision 2 (15 October 2026)

| # | Question | Decision | Consequence |
|---|---|---|---|
| R-1 | Rails and Ruby floors | Match Woods: railties >= 6.0, Ruby >= 3.0 | No dependency on importmap-rails or turbo-rails (turbo-rails 2.x needs Rails 7.1). The Engine serves its own vendored JavaScript and emits a literal import map tag. The guide alone needs Ruby 3.2 and degrades to a notice below it. |
| R-2 | Direction | B, Field Guide, iterated twice toward code comprehension | Trail's lifecycle board is a first-class route; Atlas is a component (Graph tab, full-screen graph page). |
| R-3 | C4 model | Concepts yes, tools no | Zoom ladder (landscape, containers, components, code), C4 notation on boxes and arrows, dynamic view as a fourth rendering of flows. Drawn with Mermaid flowcharts or the map's own SVG; Structurizr DSL and LikeC4 are export formats only. |
| R-4 | Mermaid diagram vocabulary | Sequence first on Lifecycle tabs; ER and class on Schema; state for state machines; quadrant, sankey and mindmap on the overview; timeline and XY on History | One Ruby renderer per type, each with a copy-as-Mermaid action and a node budget. |

## Blocking decisions answered (15 October 2026)

| # | Question | Decision | Consequence |
|---|---|---|---|
| D-1 | Ownership of the change impact report | Woods gem | The report object, its Markdown, JSON and Mermaid renderers, the `woods:impact` task and the `change_impact` MCP tool live in Woods; the map renders the HTML page. |
| D-2 | How a review gets its base | One index, pinned generation, head extracted incrementally | `woods:pin[gen]` protects a base from retention; retention stays at three. No second index directory and no second host boot. |
| D-3 | Standalone launcher | None | The map is a Rails Engine only, like Woods it belongs inside a Rails application. The test application suite lives in `woods-testbed`. |
| D-4 | Staging authentication | Both: token-to-cookie exchange and a host hook | `config.authorize = ->(request) { ... }` lets Devise or SSO gate the mount; the token path works without host code. |
| D-5 | Mermaid version | Newest (12.x) | Unless a Rails 7 host shows an exceptional limitation; ES2024 browsers are required by Mermaid 12. |
| D-6 | Default code lens | As written, remembered per browser | The Effective-class lens is one click away; the choice persists in browser storage so it is set once. |
| D-7 | Guide transport | stdio to `woods-mcp` for v1 | In-process tool adapters sharing the request's pinned generation are a later optimisation. |
| D-8 | Flow precomputation | Best-effort mode | Woods gains `precompute_flows: :best_effort`, recording assembly failures in `skipped_files.json` instead of aborting the publish. |
| D-9 | Release slicing | 0.1 = M0, M1, M2, M4b; graph, Trail and the guide in 0.2 | On the condition that the full plan is created, audited, committed and tracked in the Woods Development project, starting with the design spec. See `plan.md`. |

## Defaults accepted without objection

| # | Default |
|---|---|
| F-1 | Mounting is explicit: `mount WoodsMap::Engine => "/woods"`. The Railtie injects nothing. |
| F-2 | Names: gem `woods-map`, module `WoodsMap`, mount path `/woods`. |
| F-3 | Reference spans are stored inline in unit JSON; a per-type sidecar only if payload size grows more than about 15 percent on a 5 000-unit application. |
| F-4 | Guide conversations are file-backed and ephemeral; no default model name, the host configures RubyLLM. |
| F-5 | The design study is committed to this repository for handoff; the full design is produced from it and tracked issue by issue. |

## Open

- Editor deep links: scheme and checkout path are per-browser settings; never guessed from the index.
- Server-sent events behind proxies: document Puma and nginx settings; fall back to polling Turbo Frames when the stream cannot open.
- Reference span size (F-3) must be measured on `woods-testbed` `rails-8.0-large` before M0 closes.
