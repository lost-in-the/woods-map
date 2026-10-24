# Woods Map

Rails Engine that mounts a code-comprehension web explorer over a published
[Woods](https://github.com/lost-in-the/woods) index. Developers read a unit's
code as Rails runs it, follow references, data passages and lifecycles, see
relationship graphs, schema and history, and get change-impact reports with
sharable focus URLs. It reads the published index only: no live database, no
runtime reflection, no git subprocess at request time.

Status: scaffold, design system, M1 Reading, M2 Passage, M4b Impact on the map (pre-change and range modes, saved reports, `?since=`; the CI comment lives in the testbed), the Pele renderer slice of M3 Diagrams, the neighbourhood endpoint, Graph tab canvas and full-screen graph page of M5 Graph, the CSP, rate-limit and origin-guard slice of M8 Staging, the M7 Guide panel (no real-provider run yet) and M4 History (History tab, gutter heat, generation picker and unit diff, `/woods/history`) landed. The design study, decision log, boards
and milestone plan live in `docs/design/` and are the source of truth for
scope; `docs/design/foundations/tokens.css` is the stylesheet the engine ships
verbatim (a spec keeps the two copies identical).

## Commands

```bash
bin/setup                    # bundle install (woods comes from a sibling checkout or git)
bin/rake spec                # unit and request specs against spec/dummy
bin/rubocop -a               # lint + autofix
```

Integration validation happens in a host application from
[`lost-in-the/woods-testbed`](https://github.com/lost-in-the/woods-testbed):
mount the engine in a variant, run `woods:extract`, open `/woods`.

## Non-negotiables

- **Floors match Woods**: railties >= 6.0, Ruby >= 3.0. Only the RubyLLM guide needs Ruby 3.2 and it degrades to a notice below that.
- **No build step, no asset-pipeline dependency**: every JavaScript library is vendored under `vendor/javascript/`, served by the engine's own assets route under one content digest for the whole set (so relative URLs between files work), and pinned by a literal `<script type="importmap">` in the layout. No importmap-rails, no turbo-rails, no Node.
- **One token sheet**: `tokens.css` is the design's file and ships verbatim (a spec compares the two copies); engine-only rules go in `map.css`; views never hard-code a colour or a size and compose from the partials under `app/views/woods_map/shared/` and `components/`. Every page must pass axe (colour contrast, names) at 1440, 960, 640 and 390.
- **Engine only**: there is no standalone launcher. The map belongs inside a Rails application, like Woods.
- **Index only**: every read goes through `Woods::PublishedIndex` or `Woods::MCP::IndexReader` pinned to one generation per request. Never resolve a payload path yourself; never read `manifest.json` from the index root.
- **Read-only and gated**: loopback without a token boots with a warning; anything else refuses without `WOODS_MAP_TOKEN`; `config.authorize` lets the host add its own gate. Unit routes take typed identifiers. File routes admit only exact permitted `file_map` keys; never resolve those keys on the host filesystem.
- **Mounting is explicit**: `mount WoodsMap::Engine => "/woods"`; the Railtie injects nothing.

## Architecture (see docs/design/plan.md for what is still planned)

```
lib/woods_map.rb                 # module, Configuration (boot_warning)
lib/woods_map/engine.rb          # Rails::Engine, isolate_namespace WoodsMap, after_initialize warning
lib/woods_map/repository.rb      # one pinned generation per request: units, graph, analysis, search (string keys), freshness
lib/woods_map/unit_facts.rb       # type-specific tiles from published unit metadata
lib/woods_map/{unit_page,code_view,composite_source,highlighter,marginalia,references,outline}.rb  # the unit page and Code tab
lib/woods_map/{history_view,commit_rows,commit_strip,commit_ledger,unit_co_changes,unit_paths,path_heat,history_mermaid,history_timeline,unit_diff,repository_history}.rb  # M4 History: the tab, the strip, the generation ledger, co-change, gutter heat, exports, /woods/history, the unit diff
lib/woods_map/hover_card.rb      # B-3 hover cards: graph node, PageRank place and metadata.git of each linked unit
lib/woods_map/{schema_view,lifecycle,neighbourhood}.rb  # the Schema, Lifecycle and Graph tabs
lib/woods_map/{lifecycle_chart,state_machine_view}.rb  # the Lifecycle flowchart and lanes; a model's published state machines
lib/woods_map/erd.rb             # /woods/erd: database_table units chunked at the ER budget, relations, schema findings (cached per generation)
lib/woods_map/passage.rb         # the Passage tab: declared filters, templates by the view_render edge, the ladder's model and event
lib/woods_map/routes_view.rb     # the controller Routes tab: declared routes joined to route units, helpers, action sources, helper references
lib/woods_map/permitted_attributes.rb  # permitted keys against the model's published columns, associations, attachments, rich text, writers
lib/woods_map/{neighbourhood_query,neighbourhood_response,graph_elements}.rb  # bounded JSON projection of existing traversal
lib/woods_map/{blast_radius,impact_review}.rb  # the impact page's pre-change mode: reverse-edge propagation with paths; rules, tests, gaps, unknowns
lib/woods_map/{impact_range,range_report,since}.rb  # Woods' range or saved report, its tabs, and ?since= evidence for unit pages (E-6 to E-8)
lib/woods_map/{search_results,palette,file_tree}.rb  # search modes, the palette's groups, the per-generation file tree
lib/woods_map/assets.rb          # engine-served files: roots, content digests, content types
lib/woods_map/{content_security_policy,rate_limiter}.rb  # M8: the engine's CSP header, the in-process per-client budget
lib/woods_map/guide.rb + guide/  # M7: status/backend (RubyLLM optional), actions + prompts/, context, store, budget, runner, answer; agent.rb only with ruby_llm
lib/woods_map/importmap.rb       # pins for vendored modules, the literal import map
app/controllers/concerns/woods_map/authentication.rb  # token, cookie and loopback gate (D-4)
lib/woods_map/glyphs.rb          # the glyph vocabulary (D-20)
app/controllers/woods_map/       # application (gate order, 403 panel, primary_nav), status, sessions, assets, guidelines, units (History tab in concerns/unit_history), search, impact, erd, graphs, neighbourhoods, history
app/helpers/woods_map/           # asset URLs, date shorthand (D-15), short SHA; components (glyphs, chips, ⓘ, people)
app/assets/stylesheets/woods_map/ # tokens.css (verbatim from docs/design/foundations), fonts.css, map.css (engine-only rules)
app/javascript/woods_map/        # Stimulus controllers: cliff, tooltip, rows, tree, sheet, copy, share, palette, peek, card, settings, trail, keys, help, diagram (Pele, D-21), graph (Cytoscape canvas, M5)
app/views/woods_map/shared/      # the frame: bar, crumbs, ident, tabs, status, sheet
app/views/woods_map/components/  # table, steps, detail, rail, tree, facts, legend, diagram, banner, empty state
app/views/woods_map/guidelines/  # the C1 to C5 boards rendered from the partials above
app/views/woods_map/{units,search,impact,erd,history}/ # unit pages (Code, Routes, Passage, Schema, Lifecycle, Graph, History, peek, 404), search, impact lenses, the ERD, /woods/history and the commit strip
app/views/woods_map/graphs/       # the explorer partial shared by the Graph tab and /woods/graph, the page and its hub picker
vendor/javascript/               # stimulus, pele, cytoscape (vendored); turbo, vis-timeline, highlight.js as milestones land them
vendor/fonts/                    # Inter (latin subsets) and the complete Fira Code, WOFF2 (D-12)
docs/design/                     # design study, decisions, boards, foundations, plan
```

## Gotchas

- `Woods::MCP::IndexReader#search` answers with symbol keys and rows of identifier, type and match_field only; `Repository#search` stringifies the keys and adds `file_path` from the graph nodes. Read search results through the repository.
- Freshness is `Woods::SourceInputs::Status` over the index root (`PublishedIndex#index_dir`), never the payload dir; a quick check that finds no changes can still say `unknown` when Woods could not verify the boot boundary, and the bar reports Woods' reasons rather than upgrading the verdict.
- File navigation uses stable ownership pages through `Repository#file_owners`, matching both `file_path` and `source_paths` across primary nodes and variants. File pages never reconstruct source. `file_owner` is retained for existing source-line links only. A bare identifier alone cannot choose the correct unit type for a file. File-tree caches include the index identity and pinned generation.
- `Neighbourhood` receives the selected unit type from its route and traverses typed identities, including variant edges. Type filters apply to the endpoint first reached by each breadth-first edge visit; missing type metadata on older graphs falls back to the primary node. Graph-analysis notes retain their published identifier-level scope.
- `Lifecycle` keeps only callbacks whose method the unit's source or an inlined concern defines; framework callbacks and procs are counted as a limit, not drawn as steps. `?view=` picks the sequence (default), flowchart or lanes (`swimlane-beta`) text from the same steps. State diagrams come only from published `state_machine` units reached by a reverse `state_machine` edge (`StateMachineView.for_model`); transition callbacks are listed as recorded, never parsed (woods#796).
- `Outline`, `SchemaView` and `Neighbourhood` read the generation at construction, so a view may use them after the repository block closes. `HistoryView` and `HistoryTimeline` read lazily and are rendered inside the repository block.
- History reads only `Repository#git_commits` (`PublishedIndex#git_commits`, Woods W-3); absence (`commit_table_state` :absent, :unreadable, :unsupported) falls back to `metadata.git` and is named as a limit, never treated as "no commits". The *gen* column and *generations touching* come from `CommitLedger`, which compares the sha lists of retained generations' tables (`Repository#with_generation`), never code. Heat is per file (`PathHeat`); the unit diff is Woods' report record (`UnitDiff` over `ImpactRange`), never a map-side diff. Line counts and hunks wait on woods#804, changed line ranges on woods#802. See `docs/design/notes/history.md`.
- `Passage` shows filter scopes as declared (`only`/`except` lists) and never resolves the chain (W-8). Assigns, params and renders come only from Woods' `metadata.action_facts` (W-7, `WoodsMap::ActionFacts`); without them it ties templates to actions through the `view_render` edge or a mailer's template list and raises no flag. Admitted actions missing facts, absent template ivar metadata, partial chains beyond the traversal limit, dynamic render targets (W-7 renders keyed `object`) and a template's `metadata.unresolved_partials` stay incomplete and are named (`PassageTemplates#unresolved`); format, `head` and redirect responses are complete. Template ivars are lexical mentions: unmatched mentions are advisory, with no claim about a runtime value. Shared partial focus follows reverse render edges to find its owners. A fact the index lacks is named as a limit, not derived; the map never parses host source.
- `RoutesView` (the controller Routes tab) lists the controller's `metadata.routes` joined by `VERB path` to route units, plus `route_dispatch` route units the metadata omits. Helpers are `<name>_path`/`<name>_url` of the published route name. Findings come only from graph analysis's `unresolvable_routes` for that controller, shown as notes (woods#726 tracks implicit-render false positives). `route_file` nodes carry no source, so the `routes.rb` line is text, never a link. Navigation edges name the controller only; helper- and action-level use is woods#795.
- The impact page computes nothing a range needs: `BlastRadius` propagates over `reverse_via` of one generation and `ImpactReview` runs only the rules that generation can answer, listing the rest with what they need (W-7, W-8, a range). A range delegates to `Woods::Impact::Report.compare` (W-12, decision D-1), optionally loaded from `woods/impact/report`; a saved report (`/woods/impacts/:id`, E-6) is read through `Woods::Impact::Store#read`, never a path the map builds. `RangeReport` turns either into the Overview, Changed, Risks, Flows, Tests, Graph and Unknown tabs from the string-keyed schema version 1 evidence without deriving another diff or traversal. A record links only when its generation is the pinned one and the generation has the typed unit; other identities stay text with their generation. Missing capability, unreadable evidence and missing saved reports are explicit states. Manifest checksums cover manifests only; source sizes are not changed-line counts (woods#802). Never render, offer or hand through Markdown or JSON reports (D-25).
- `?since=` (E-8) is `SinceParam#current_since`: one `ImpactRange` from the selector to now per request, read by `WoodsMap::Since`. Pages mark only what the report's records say: marginal notes by the metadata key they read (`Marginalia::Note#area`), changed templates on the Passage, changed tables on the ERD, the report's emphasis on the Graph canvas (distance 0 is changed). Never compare payloads in the map.
- The guide (M7) never makes RubyLLM a dependency: only `WoodsMap::Guide.backend` requires `ruby_llm` and `woods_map/guide/agent`, and only when `guide_enabled` is set on Ruby 3.2+. Everything else (runner, store, answer) works with any chat that has RubyLLM's step-wise surface; specs use `FakeGuideChat` (`config.guide_chat_factory`), and `spec/woods_map/guide_agent_spec.rb` runs the real agent against an in-process fake provider and the real `woods-mcp`. The model sees `Guide::TOOLS` only. Context is rebuilt server-side from the pinned generation; answers link only identifiers in `Repository#identifier_index`. Streams run in `GuideStreamsController` (`ActionController::Live`) without holding the manifest lock; the answer's links are rendered from a fresh `Repository.open` when it ends. A turn streams once (`Store#claim`).
- `PermittedAttributes` matches permitted keys only against published model facts (columns, associations, collection `_ids`, attachments, rich text, class-body writers); an unmatched key is unverified, never flagged, until Woods publishes every writer a model accepts (woods#797). Partial locals passed by templates and read by partials are not published (woods#798), so the partial-local flag is a named limit. See `docs/design/notes/passage-mismatch-limits.md`.
- Every engine response carries the engine's Content-Security-Policy (`WoodsMap::ContentSecurityPolicy`, M8): scripts, styles and fonts only from `<mount>/assets/<digest>/`, inline scripts only with `content_security_policy_nonce`, no `'unsafe-inline'`. Views and helpers never write a `style` attribute (a spec greps for it): add a class to `map.css`; varying geometry takes a bounded class (tree `data-level`, step `data-depth`, `TABLE_MIN_WIDTHS`) or a presentational hint (`<th width>`). Pele's SVG styles go through the diagram controller's CSSOM `sanitize` hook; text Pele refuses is caught by `parse` before mount. `config.content_security_policy` amends (callable) or hands the header back to the host (`false`).
- Search with the palette, graph JSON, impact and the `.mmd` text routes (plain-text 429) are counted against `config.rate_limit` per `rate_limit_key` (`woods_map_rate_limit`, not Rails 7.2's `rate_limit`); the 429 is the 403 panel's plain page, served before the repository opens. The token-less loopback mode also requires a loopback `Host` (`Woods::MCP::OriginPolicy`, DNS rebinding) or a host in `config.allowed_origins`; request specs default to `host! 'localhost'`. Writes check Origin, then Referer, then Sec-Fetch-Site. `WOODS_MAP_RUN_HTTP_SERVER=1` runs the gate under Puma.
- Diagrams are drawn in the browser by Pele (D-21) from the Mermaid text the page carries; Ruby builds the text (`#mermaid` on the view objects, never inline in a view) and the panel keeps it as the fallback. Pass `mermaid:` and `label:` to the diagram partial, and `refusal:` when the type's budget (R-4) is exceeded: `Neighbourhood::NODE_BUDGET`, `SchemaView::TABLE_BUDGET`, `Lifecycle::SEQUENCE_BUDGET`, `Lifecycle::FLOWCHART_BUDGET` (flowchart and lanes), `StateMachineView::STATE_BUDGET`. A runtime refusal by Pele shows in the panel's status line, never only in the console. Every Mermaid panel renders its own ⎘ copy and ⤓ `.mmd` link (`components/_mermaid_tools`, `WoodsMap::MermaidExport`). Pass `name:` and `mermaid_url:`, and never add a copy tool of your own. The `.mmd` routes (D-25, [note](docs/design/notes/mermaid-text-urls.md)) answer the same text as `text/plain` through `MermaidText#render_mermaid`. Only a route default (`mmd: '1'`) makes a request `.mmd`, never a query parameter. The routes sit ahead of the glob routes, behind the same gate, and never exchange a URL token. A refused diagram is 422 with the reason, never truncated; build refusals with the view object's `#refusal`. Structurizr DSL and LikeC4 exports need W-9 and are not built. `spec/diagrams/pele_render_spec.rb` draws every generated text with the vendored build in Node: a text Pele refuses fails there, not on a page.
- `/woods/erd` (`Erd`) reads only `database_table` units and the model units that map them. Chunks group tables by database and model namespace (or by database) and are cut along relations at `SchemaView::TABLE_BUDGET`. A relation whose other end lies in another chunk is listed, never drawn. The route takes a chunk number, and `by` and `columns` are closed choices. Chunk numbers belong to one generation. `spec/support/large_schema_index.rb` generates the 300-model index in a temporary directory; do not check one in. The global bar comes from `ApplicationController#primary_nav`.
- Hover cards (B-3) are rendered with the Code tab as inert `<template data-card-target="card" data-href=…>` elements, one per linked unit (`CodeView#linked_targets`), and handed to the one tooltip as `data-tip-html` with `data-tip-delay="100"`. Hovering makes no request. Card markup must stay free of `abbr`, `[title]` and ⓘ, because the tooltip would open a nested tip.
- Reading settings (B-15) live in `localStorage["woods_map.settings"]` behind `try/catch`; the lens stays on its `?lens=` cookie. Wrap is an opt-in (`data-code-wrap=on` on `.wm`) that fits the source column to the one scroll region, never an automatic narrow-width wrap. *In editor at L…* is rendered hidden on the Code tab and shown only when this browser's editor template resolves; never build an editor URL from the index alone, and refuse `javascript:`/`data:`/`vbscript:` templates.
- The Share menu (`shared/_share`, E-6) is a `<details>` disclosure with the page's `focus_url`, which never carries `token`, and, from each `components/mermaid_tools` copy tool (`data-mermaid-name`, `data-mermaid-href`), the page's Mermaid text and its absolute `.mmd` URL. It offers no Markdown or JSON report, not even Woods output handed through (D-25). The `y` key skips copy tools inside `.share`.
- The Graph tab's canvas (`graph` controller) fetches `/woods/graph/neighbourhood` for the page's own query and draws it with the vendored Cytoscape; the Pele flowchart and the list stay the no-JavaScript page and the Mermaid export. Layouts are the controller's butterfly (signed traversal columns) and Cytoscape's built-in `concentric` (woods-map#63): no layout extension is vendored. Type tints are `--g` on `[data-gtype]` in `map.css`, read through a probe and mixed into `--panel`, so canvas and legend agree; a theme switch repaints. List rows carry `data-edge` (`GraphElements.edge_id`), the JSON's edge id. Above 150 edges the mechanism labels appear only when zoomed in. `spec/woods_map_graph_browser_spec.rb` times a 300-unit draw synchronously before load (virtual time freezes `performance.now()` once a timer fires); set `WOODS_MAP_GRAPH_BUDGET_MS` to enforce a budget. The tab and `/woods/graph` share `graphs/_explorer`; dragged positions are kept in `localStorage` per generation, query and layout (A-3), and the page's blast tint comes from `BlastRadius`, never from the client. Domain clusters are not drawn until Woods publishes them (woods#799).
- The code view is one scroll region (`.cvwrap`, D-24, woods-map#29): the source column grows to its longest line and the gutters are sticky. Do not reintroduce `overflow-x:auto` on `.src`.
- Code links consume only published `metadata.references` with `kind: constant` and `confidence: verified`, resolved by exact target and target type in the pinned generation. Their 1-based lines address annotated `source_code`; columns and lengths count UTF-8 bytes, including original newlines. Only unchanged file rows can carry links. Missing/invalid metadata and hidden or transformed rows stay unlinked; the internal reference cache is not a public link source. `source_line_map` runs contain annotated start, original start and length, not an ending line. Verification describes the published typed-registry evidence, not complete runtime call coverage.

## Conventions

- `frozen_string_literal: true` on every file; YARD on every public method and class.
- RuboCop with the same posture as Woods (`NewCops: enable`, target Ruby 3.0).
- Always `rescue StandardError`, never bare `rescue`.
- JSON output uses string keys, snake_case.
- Specs: unit specs with mocks plus request specs against `spec/dummy`; anything that needs a real index uses the fixture under `spec/fixtures/index/` (a minimal published generation) or a testbed variant.

## Work tracking

GitHub issues own active work and acceptance criteria. Every milestone and
requirement in `docs/design/plan.md` maps to an issue on the
[Woods Development project](https://github.com/orgs/lost-in-the/projects/1/views/1).
Rules:

1. Before opening a milestone issue, run the audit checklist in `plan.md` and name the requirement identifiers (FR, NFR, A, B, C, E, W) the issue covers.
2. When an issue is created, closed or re-scoped, update the matching row and the issue-links section of `plan.md` in the same pull request.
3. Record decisions in issues labelled `needs-decision`, then copy the settled decision into `docs/design/decisions.md` with the issue link.
4. Do not create a local task queue or copy issue status into a file; `plan.md` is a map, not a status board.
5. Data the map needs from extraction is a Woods issue (W-item), not a workaround in this gem.
