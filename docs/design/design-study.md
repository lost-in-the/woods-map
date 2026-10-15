# Woods Map Design Study

> Revision 4 of the design study produced on 14 and 15 October 2026, converted
> from the shareable page. Wireframes and the two SVG figures render only in
> [`design-study.html`](design-study.html); the text, tables, requirements and
> Mermaid diagrams are complete here. Where this study and
> [`decisions.md`](decisions.md) disagree (for example the standalone launcher,
> which was dropped), `decisions.md` wins. The milestone plan that follows from
> both is [`plan.md`](plan.md).

*Design study · woods-map · revision 4 · 15 October 2026*
# Woods Map Design Study

Three design directions for an in-app web explorer over the Woods index, the chosen direction iterated twice toward code comprehension, and the storage facts, requirements, tooling, build plan and RubyLLM 2.1 guide that go with them.

- Data source: Published index only
- Front-end delivery: Importmap + Hotwire, no build step
- Audience: Dev in-app, plus shareable staging / team
- V1 scope: Search + code, graph, flows + ERD, git timeline
- LLM: Chat plus "explain this" actions
- Packaging: Separate gem woods-map
- Floors: railties ≥ 6.0, Ruby ≥ 3.0, same as Woods
- Chosen direction: B · Field Guide, comprehension first (section 7)
- C4: Concepts yes, tools no (own SVG notation)
- Spike: Change impact with sharable focus URLs (section 8)
## 1 · How Woods stores data on extract
Every Woods entry point (full extract, incremental, refresh, the watch daemon) ends in one atomic publication. The writer fills an immutable payload directory, flushes it, then replaces the one-line pointer `generation.json` last. A reader that captures the pointer once has a complete, consistent snapshot; the explorer must read exactly that way and never mix files from two generations.
``` mermaid
flowchart LR
  subgraph root["index root  (tmp/woods)"]
    gen["generation.json\nnumber · token · payload"]
    woodsjson["woods.json (config)"]
    dumps["dumps/ (vector snapshots)"]
    tasks["tasks/, watch status, locks"]
    sqlite["woods.sqlite3\nwoods_snapshots · woods_snapshot_units"]
    subgraph payload["payloads/gen-N  (immutable)"]
      manifest["manifest.json"]
      graph["dependency_graph.json\nnodes · edges · reverse · reverse_via\nfile_map · type_index · variants"]
      ga["graph_analysis.json\norphans · hubs · cycles · bridges\nunmodelled_tables"]
      units["type/_index.json + one JSON per unit\nmodels/ controllers/ jobs/ mailers/ views/ …"]
      flows["flows/flow_index.json + flow docs\n(controller actions, opt-in)"]
      si["source_inputs.json · source_references.json\nskipped_files.json · SUMMARY.md"]
    end
  end
  gen -- "names" --> payload
  classDef dim fill:none,stroke-dasharray:3 3;
  class woodsjson,dumps,tasks dim
```
Only the structural payload and the snapshot database matter to the explorer. The vector dumps, config artifact, task records and locks have their own lifecycles and must never be read as if the pointer committed them.
### What each artifact gives the explorer
| Artifact                                | Shape (as written today)                                                                                                                                                                                                                                                                                                                                                                                                                                 | Feeds                                                 |
|-----------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
| `<type>/<unit>.json`                    | `type`, `identifier`, `file_path`, `namespace`, `source_code` (concerns inlined, schema/route headers prepended), `metadata`, `dependencies[{type,target,via}]`, `dependents[{type,identifier}]`, `chunks`, `source_hash`, `extracted_at`. `metadata.source_line_map` maps annotated lines back to file lines.                                                                                                                                           | Unit pages, code viewer, click-through, schema cards  |
| Model `metadata`                        | `table_name`, `database`, `columns`, `column_names`, `foreign_keys`, `associations` (macro, target, through, polymorphic, foreign_key, inverse_of, from_db/to_db), `validations`, `callbacks` (kind, filter, conditions, `side_effects` from CallbackAnalyzer), `scopes` (with source), `enums`, STI flags, `class_methods`, `instance_methods`, `inlined_concerns`, Active Storage / Action Text facts                                                  | ERD, lifecycle flows, model page                      |
| Controller `metadata`                   | `actions`, `action_sources` (per-action source and `declaration_line`), `routes`, `filters` (before/after/around with only/except), `responds_to`, `ancestors`, `included_concerns`, `flow_paths` when flows were precomputed                                                                                                                                                                                                                            | Request flow, "how data is passed" view, routes       |
| View template / mailer / job `metadata` | Views: `partials_rendered`, `instance_variables`, `helpers_called`, `template_engine`, `is_partial`. Mailers: `actions`, `templates`, `layout`, `delivery_method`. Jobs: `queue`, `job_type`, `sidekiq_options`.                                                                                                                                                                                                                                         | "Locate the views", mailer templates, job pages       |
| `dependency_graph.json`                 | Typed nodes keyed by `(identifier, type)`; forward edges carry `via` (about 45 labels: `belongs_to`, `has_many`, `render`, `link_to`, `redirect_to`, `form_action`, `job_enqueue`, `code_reference`, `include`, `reads_table`, `writes_table`, `mount`, `route_dispatch`, …) plus `through`/`through_db`/`disable_joins`; `reverse_via` gives inbound records per target; `file_map` maps a source path to its units.                                    | Relationship graph, blast radius, file → unit jump    |
| `graph_analysis.json`                   | `orphans`, `dead_ends`, `hubs`, `cycles`, `bridges`, `stats`, `unmodelled_tables`; PageRank is computed by `DependencyGraph#pagerank` and surfaced through the MCP `pagerank` tool and the Obsidian exporter.                                                                                                                                                                                                                                            | Node sizing, hub warnings, domain overview            |
| `flows/*.json`                          | `FlowDocument`: `entry_point`, `route`, ordered `steps[{unit,type,file_path,operations}]`. Operation types: `call`, `async` (job enqueue, with target and method), `transaction` (nested), `conditional` (nested), `response`, `dynamic_dispatch`; each carries a line. Precomputed only for controller actions and only when `precompute_flows` is on; `FlowAssembler` can assemble any unit (job, mailer, service) on demand from the unit JSON alone. | Lifecycle flowcharts                                  |
| `metadata.git` (per unit)               | `last_modified`, `last_author`, `commit_count`, `contributors` (top 5), `recent_commits` (last 5: sha, message, date, author), `change_frequency` (new / hot / active / stable / dormant). HEAD-reachable history, 365-day window.                                                                                                                                                                                                                       | "Who touched this", heat colouring, timeline rows     |
| Snapshot DB (SQLite)                    | `woods_snapshots` (git_sha, branch, extracted_at, unit counts, added/modified/deleted) and `woods_snapshot_units` (per-unit source/metadata/dependency hashes). MCP tools `list_snapshots`, `snapshot_diff`, `unit_history`, `snapshot_detail` already read it.                                                                                                                                                                                          | Generation-to-generation diffs on the timeline        |
| `manifest.json`, `source_inputs.json`   | Counts per extractor, provenance (branch, sha, rails/ruby versions, writer mode), captured source identities for freshness.                                                                                                                                                                                                                                                                                                                              | Status bar: generation, HEAD, "index is stale" banner |
<span class="eyebrow">Reading contract</span> Ruby readers go through `Woods::PublishedIndex` (pin one generation, `unit`, `units(type:)`, `edges(via:)`, `dependents_of`) or the MCP server's `IndexReader` (`find_unit`, `list_units`, `search`, `recent_changes`, `dependency_graph`, `graph_analysis`, `with_pinned_generation`). Both resolve every file through the payload the pointer names, hold a shared `flock` on the payload manifest so retention cannot delete it mid-read, and read JSON as UTF-8 through `AtomicFile`. The explorer should wrap each HTTP request in one pinned generation and never open a payload path it derived itself.
### Where the stored data falls short of the two scenarios
- **Click-through needs positions, not just names.** Units know which constants they depend on (`dependencies`) and which methods they define (`instance_methods`), but not *where* in the source each reference or definition sits. The source-reference pass collects constant reads with lexical context during extraction, and Prism is already in use, so emitting per-unit reference spans and a method table is a small extraction-side addition (see [section 10](#gaps)).
- **Git insight is five commits deep.** A cross-file timeline for a neighbourhood built from five commits per unit is lossy. `GitHistory` already streams every HEAD-reachable touched-path event for the 365-day window; writing the commit → paths table once per generation gives the explorer a complete local timeline with no git calls at read time.
- **Flows are precomputed for controllers only.** Job, mailer and model-callback entry points can be assembled on demand from unit JSON (`trace_flow` already does this), which keeps the explorer index-only, but the first request for each entry pays the parse. Cache per generation.
- **Model callbacks link to side effects, not to the job's own callbacks.** The chain *Post after_commit → NotifySubscribersJob → MailingListMailer → template* is three edges (`job_enqueue`, `code_reference`, mailer `templates`) that the explorer must stitch; nothing stores the stitched lifecycle today.
## 2 · Shared foundation (all three directions)
The directions differ in what the screen is organised around. They share the same gem, data access, delivery and security layer, so that choosing a direction is a UI decision and not a rewrite.
``` mermaid
flowchart TB
  subgraph host["Host Rails app (development / staging)"]
    engine["WoodsMap::Engine\nmounted at /woods"]
  end
  subgraph standalone["woods-map serve ./tmp/woods"]
    mini["Minimal Rails::Application\n(railties only) mounting the same Engine"]
  end
  engine --> auth
  mini --> auth
  auth["Woods::MCP::OriginGuard → BearerAuth\n(token exchanged for a signed cookie)"] --> ctrl
  ctrl["Controllers: units, search, graph, flows, erd, timeline, chat"] --> repo
  repo["WoodsMap::Repository\nPublishedIndex / IndexReader, one pinned generation per request\nper-generation caches: search index, neighbourhoods, mermaid, ERD"]
  repo --> payload["payloads/gen-N (read-only)"]
  repo --> sqlite["woods.sqlite3 snapshots"]
  ctrl --> views["Server-rendered ERB + Turbo Frames\nrouge highlighting · reference spans"]
  views --> js["importmap pins (vendored ESM)\nturbo · stimulus · cytoscape · mermaid · vis-timeline · highlight.js"]
  ctrl --> llm["WoodsMap::Guide (RubyLLM::Agent)\nIndex MCP server attached · SSE → Turbo Streams"]
  llm --> mcp["woods-mcp (stdio) or woods-mcp-http"]
  mcp --> payload
```
#### Gem and packaging

- `woods-map` depends on `woods ~> 2.1`, `railties >= 6.0` and `rouge`; nothing else at runtime. `ruby_llm ~> 2.1` is a soft dependency that activates when present and Ruby is 3.2 or newer; everything else runs on Ruby 3.0, matching Woods.
- No dependency on importmap-rails, turbo-rails or an asset pipeline (turbo-rails 2.x needs Rails 7.1, which would break the floor). The Engine serves its vendored JavaScript itself at `/woods/assets/*` with content-hash filenames and far-future caching, and its layout emits a literal `<script type="importmap">`. Import maps and Turbo's browser library need no Rails gem; hosts on Sprockets, Propshaft or Webpacker are untouched.
- Pattern still follows mission_control-jobs for layout and Stimulus controller organisation, with the asset-serving layer swapped for the engine's own route.
- Host mounts explicitly: `mount WoodsMap::Engine => "/woods"` inside `if Rails.env.development? || ENV["WOODS_EXPLORER"]`. Standalone: `woods-map serve DIR` boots a minimal `Rails::Application` defined in the gem so views, Turbo and the import map behave identically. `ActionController::Live` (used for guide streaming) exists since Rails 4.
#### Security posture (staging-capable)

- Reuses `Woods::MCP::OriginGuard` and `Woods::MCP::BearerAuth`. Browsers cannot send bearer headers on navigations, so a token-entry page exchanges the token for a signed, `HttpOnly`, `SameSite=Strict` cookie; every request still passes the origin guard.
- Loopback without a token boots with a warning; anything non-loopback refuses to boot without `WOODS_EXPLORER_TOKEN` (identical to `woods-mcp-http`).
- Strictly read-only: no live database, no git subprocess, no file system paths from the client. Routes take identifiers and generation numbers; files are reached only through `file_map`.
- The index already contains application source; the explorer exposes nothing the index does not. Document this in the host's threat model, and gate the LLM behind a second flag with a per-session token budget.
- CSP with `script-src 'self'` (all JS vendored, nothing from a CDN at runtime), CSRF on the chat POST, rate limit on search and chat.
#### Performance budgets

- Unit page server time under 150 ms with a warm per-generation cache; search under 100 ms (the IndexReader identifier index is built once per generation).
- Graph neighbourhood responses capped at 300 nodes / 1 500 edges by default (depth 1 to 2, type and `via` filters); the full graph is never shipped to the browser. Target hosts with up to 5 000 units.
- Mermaid diagrams split at about 150 nodes (ERD per namespace or database; flows per entry point); `maxTextSize` raised explicitly.
- Caches are keyed by `(generation number, token)` so a publication invalidates everything at once; `IndexReader#ensure_fresh!` already detects the pointer moving.
#### Common requirement spec

- **FR-1** Resolve exactly one published generation per request; show its number, HEAD sha, branch and age in a status bar; banner when `source_freshness` is `drifted`.
- **FR-2** Search by name, regex, prefix/suffix, type and file path with the MCP `search` completeness semantics (`complete` / `partial`).
- **FR-3** Unit page for every type with metadata cards, highlighted source, inlined concerns visibly delimited, file path with original line numbers via `source_line_map`.
- **FR-4** Click a constant, association, route helper, callback method or job class in source and land on the target unit, or a disambiguation list when several types share the name.
- **FR-5** Interactive graph around a unit with edges coloured by `via`, dependents/dependencies toggles, depth, type filters, PageRank sizing, hub and cycle badges.
- **FR-6** Lifecycle flowchart for any entry point (controller action, job, mailer, model callback) and an ERD for a model's neighbourhood or a whole database.
- **FR-7** Per-unit git card and a cross-unit timeline for a selected set; snapshot diff between two generations.
- **FR-8** LLM guide panel (section 11) seeded with page context, with "explain this" actions on units, flows and selections.
- **NFR-1** No Node toolchain at any point; all JS vendored and served by the engine. **NFR-2** Rails 6.0 to 8.x hosts and Ruby 3.0+, the same floors as Woods; the guide alone needs Ruby 3.2. **NFR-3** Keyboard navigable; graph and diagrams have list equivalents. **NFR-4** Every page works without JS except the canvas and diagrams.
## 3 · Direction A: Atlas (graph-first)
**Thesis.** The dependency graph is the home screen. You arrive at a unit's neighbourhood, see every relationship as a coloured edge, and everything else (code, schema, flow, history) is an inspector on the selected node. This is Obsidian's graph view with Woods' typed edges, built on Cytoscape.js.

**Navigation model.** Click a node to select it, double-click to re-centre the neighbourhood on it, shift-click to add it to the selection. Filters on the left narrow by unit type, edge `via`, depth and package. The bottom strip is a timeline of commits across the nodes currently visible.
*Wireframe*: Wireframe A1: Atlas home, centred on `Post` (model), depth 2, showing dependents and dependencies. (rendered in `design-study.html`)

1.  Global bar: search opens a command palette (units, files, routes, tables); generation and HEAD always visible.
2.  Filter rail drives the neighbourhood query; the URL encodes centre, depth, direction and filters so a view is shareable.
3.  Canvas: compound nodes group namespaces or Packwerk packages; a hub badge comes from `graph_analysis.hubs`; a cycle marker from `graph_analysis.cycles`. "Blast radius" tints every transitive dependent.
4.  Inspector tabs load as Turbo Frames from the same unit routes the other directions use; "Flow" renders Mermaid for the selected entry point; "Schema" renders a mini ERD of the node and its associations.
5.  Timeline rows are the visible nodes; items are commits from the generation's commit table; clicking a commit highlights every visible node it touched.
### How the four capabilities surface in Atlas
| Capability               | Atlas treatment                                                                                                                                                                                                                                                                      |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Search, unit pages, code | Search recentres the canvas. Full unit pages exist at `/woods/units/:type/:id` but the primary reading surface is the inspector's Code tab (narrow, with a "open full page" escape). Reference spans are clickable and re-centre the graph.                                          |
| Relationship graph       | Primary. Neighbourhood query, edge filters, blast radius, compound grouping, PageRank sizing, cycle/hub decoration, "butterfly" layout option (dependents left, dependencies right, dagre).                                                                                          |
| Flows and ERD            | Flow: selecting a controller action or job and pressing "Trace" animates the flow's path across the canvas (edges highlighted in step order) and shows the Mermaid flowchart in the inspector. ERD: the Schema tab renders a Mermaid `erDiagram` of the selected model plus one hop. |
| Git timeline             | Bottom strip bound to the visible node set. Nodes tint by `change_frequency`; "commit lens" dims every node a selected commit did not touch.                                                                                                                                         |
### Scenario walkthroughs
#### 1 · Plan auto-tagging on posts

1.  Search "Post", land on the neighbourhood. The `include ▶ Taggable` edge is immediately visible if a tagging concern already exists.
2.  Toggle "Blast radius" to see which controllers, views, jobs and serializers depend on Post: the surface area a new `tags` column will touch.
3.  Inspector → Schema shows the posts table and associations; Flow on `PostsController#create` highlights the path through validations, `after_commit` and the enqueued job, which is where a tagging job would attach.
4.  Filter to views, read `posts/show.html.erb` partials and instance variables to decide where to render tags.
5.  "Explain" asks the guide to summarise the lifecycle and propose the attachment points, with every unit it names linked back into the canvas.
#### 2 · Mailing list job failing after post creation

1.  Search the job, centre on it. Inbound `job_enqueue` edges show every enqueue site; a `Post after_commit` edge confirms the trigger.
2.  Trace from the job's `perform`: the canvas highlights `MailingListMailer → template → User` and the Flow tab lists operations in line order, including the conditional branches.
3.  The timeline strip shows two commits last week touching the mailer and the job together; selecting one highlights the touched nodes and the inspector's History tab shows author and message.
4.  Open the mailer's Code tab, click the template reference, read the ERB.
### Direction-specific requirements and technology
#### Requirements

- **A-1** Neighbourhood endpoint `/woods/graph/neighbourhood?centre=&type=&depth=&direction=&types[]=&via[]=` returning Cytoscape elements JSON with node attributes (type, pagerank, change_frequency, hub, cycle, package) and edge attributes (`via`, through, cross-database).
- **A-2** Server-side truncation with a visible "n more hidden" count and an "expand" affordance per boundary node.
- **A-3** Layout stability: cache fcose positions per (generation, query) so revisiting a view does not reshuffle.
- **A-4** Flow overlay: map flow steps to graph edges and animate in order; steps with no graph edge appear in a side list.
- **A-5** Keyboard: arrow keys move selection along edges; list view of the neighbourhood for screen readers.
- **A-6** Timeline bound to visible node set, with commit → node highlighting.
#### Technology

- Cytoscape.js 3.34 (ESM, MIT) with `cytoscape-fcose` for the overview and `@dagrejs/dagre` for the butterfly and flow overlays. fcose is UMD-only: ship it as a vendored classic script.
- vis-timeline 8.5 standalone ESM for the strip; Mermaid 12 for inspector diagrams; rouge server-side for code.
- Stimulus controllers: `graph`, `graph-filters`, `timeline`, `inspector`; Turbo Frames for inspector tabs.
- Escape hatch above about 3 000 visible nodes: sigma.js 3 (WebGL). Not needed with the neighbourhood cap.
<span class="eyebrow">Risks</span>Graph-first UIs read badly for code: a narrow inspector is a poor place to study a 180-line model, so Atlas needs a full-page fallback. Node clutter from `code_reference` edges is real; default those off. Layout jitter undermines spatial memory unless positions are cached. The approach shines for impact analysis and weakest for the "read the controller and the view" steps both scenarios end with.
## 4 · Direction B: Field Guide (document-first code navigator)
**Thesis.** A unit page is the home screen, built the way GitHub and Sourcegraph present a file: a tree on the left, highlighted source in the middle with hover cards and jump-to-definition on every resolved reference, and a context column on the right that answers "what is this, what touches it, who changed it" without leaving the code. Graphs and diagrams are embedded sections of the page, not a separate world.

**Navigation model.** Breadcrumbs and reference links. Every identifier in source, metadata or diagram is a link to the unit page it names; the browser's back button is the history. The right column's "Used by" and "Depends on" lists are the graph in list form; a "Graph" tab opens the same neighbourhood as Atlas when a picture is needed.
*Wireframe*: Wireframe B1: unit page for `Post`, Code tab, with a hover card open on a callback target. (rendered in `design-study.html`)

1.  Breadcrumb shows type and file path; the path copies to clipboard and links to the file's other units via `file_map`.
2.  Tree groups by type (default), file tree or Packwerk package; counts come from the manifest. Selected unit is marked; "hot" units carry a dot.
3.  Code: rouge-highlighted source with reference spans wrapped as links; a Stimulus hover card shows type, PageRank, enqueue method and last author; inlined concerns are collapsible blocks with their own file link. Method names in the class are anchors (`#notify_subscribers`).
4.  Context column cards are the same partials the other directions use in their inspectors; each list item is a link; counts are exact.
*Wireframe*: Wireframe B2: Lifecycle tab on `PostsController#create`. The flow document renders as a Mermaid flowchart beside the step table; both are generated from the same JSON. (rendered in `design-study.html`)
### How the four capabilities surface in Field Guide
| Capability               | Field Guide treatment                                                                                                                                                                                                                                                                                                                                                                                    |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Search, unit pages, code | Primary. Command palette search (<span class="kbd">/</span>), unit pages per type with type-specific metadata cards (schema for models, routes and filters for controllers, templates for mailers, queue for jobs, partials and ivars for views), rouge highlighting, reference spans with hover cards, "N definitions" popover for ambiguous short names, file-level view listing every unit in a file. |
| Relationship graph       | Graph tab on each unit page embedding the Atlas neighbourhood component at depth 1 (expandable), plus list-form "Used by" and "Depends on" grouped by type and `via`. A global `/woods/graph` page for domain clusters and hubs.                                                                                                                                                                         |
| Flows and ERD            | Lifecycle tab on controllers, jobs, mailers and models (model: one flow per callback event). Schema tab on models renders a Mermaid `erDiagram` of the model and one hop; `/woods/erd` renders a whole database or namespace, chunked.                                                                                                                                                                   |
| Git timeline             | History tab: GitHub-style hunk cards (author, message, age heat bar) using `recent_commits`, plus a "related files" timeline for the unit's neighbourhood; a generation picker diffs two snapshots and marks added/modified/deleted units in the tree.                                                                                                                                                   |
### Scenario walkthroughs
#### 1 · Plan auto-tagging on posts

1.  Type "Post", open the model. Schema card: no tags column; associations show no Tag. Context "Used by" lists the controllers, serializer and 9 views.
2.  Lifecycle tab on `PostsController#create` shows save → after_commit → job; the natural attachment point for an `AutoTagJob` is obvious and the mailer precedent is one click away.
3.  Click `PostsController` in "Used by": the routes header and filters show where params are permitted; the Code tab's `post_params` is where `tag_ids` would be added.
4.  Follow `render` links to `posts/show.html.erb` and `posts/_card.html.erb`; instance variables and partials tell you which template owns the layout.
5.  "Explain this model" produces a plan grounded in the units just visited.
#### 2 · Mailing list job failing after post creation

1.  Search the job. Its page shows queue, enqueue sites (inbound `job_enqueue` edges) and the mailer it calls.
2.  Lifecycle tab from `NotifySubscribersJob#perform`: the conditional around `user.subscribed?` and the `deliver_later` call are listed with lines; click into the mailer, then the template.
3.  History tab: the job and mailer were both touched in one commit 6 days ago by a teammate; the message names a "digest" refactor. Snapshot diff between gen 40 and gen 42 confirms the mailer's metadata hash changed.
4.  Click the commit's author to filter the timeline to their changes across the neighbourhood.
### Direction-specific requirements and technology
#### Requirements

- **B-1** Reference spans from the index (section 10) rendered as anchors with `data-target`, `data-type`, `data-kind`; unresolved or ambiguous names render as a popover listing candidates with types and paths.
- **B-2** Line gutter shows original file lines via `source_line_map`; annotated header and concern blocks are visibly separate and collapsible.
- **B-3** Hover card within 100 ms from a prefetched per-page JSON of referenced units (type, path, PageRank, last author, change_frequency).
- **B-4** Type-specific metadata cards defined as one partial per unit type with a generic fallback that renders any metadata hash.
- **B-5** File view (`/woods/files/*path` resolved through `file_map` only) listing each unit the file defines.
- **B-6** History tab hunk cards and a neighbourhood timeline; generation picker backed by the snapshot store.
#### Technology

- rouge 5.x for Ruby, ERB, Haml, Slim, YAML; line-table formatter; spans injected server-side by position after highlighting (token boundaries respected).
- Turbo Frames for tabs and the context column; Turbo Drive for navigation; three Stimulus controllers (`hovercard`, `palette`, `collapse`).
- Mermaid 12 for Lifecycle and Schema tabs (ESM pin); Cytoscape only inside the Graph tab (lazy import).
- vis-timeline or Observable Plot for the History tab; Plot is smaller if only dots and a heat strip are needed.
<span class="eyebrow">Why this direction fits the stated scenarios</span>Both scenarios start from a unit the developer already knows by name and end in code, a controller and a template. Field Guide makes those steps first class and treats graphs and diagrams as evidence on the page. It is also the cheapest to make accessible and the easiest to keep working without JavaScript.
## 5 · Direction C: Trail (investigation workbench)
**Thesis.** Developers arrive with a question, not a file. Trail starts from an entry point or a question ("what happens when a post is created?", "why does this job fail?") and builds a swimlane lifecycle across layers: request, controller, model callbacks, jobs, mailers, templates. Each step expands into code and history in place. Everything you touch is pinned into an investigation that persists in the URL, feeds the guide and can be exported as Markdown with Mermaid for a PR description or an issue.

**Navigation model.** Choose an entry (route, action, job, mailer, callback event or a free-text question the guide resolves to an entry). Expand steps inline. Pin units to the board. The board is the unit of sharing and the guide's working memory.
*Wireframe*: Wireframe C1: investigation "mailing list failures", entry `NotifySubscribersJob#perform`, swimlanes by layer, history strip scoped to pinned units. (rendered in `design-study.html`)

1.  The investigation name, pinned count and export are in the title bar; the whole board state is in the URL (entry, depth, pins, notes hash) so it can be pasted into an issue.
2.  Entry chooser accepts any unit the `FlowAssembler` can start from; the "Ask" option sends the question to the guide, which uses `search` and `trace_flow` and proposes entries.
3.  Swimlanes are the flow document regrouped by unit type; async hops (`perform_later`, `deliver_later`) are dashed boundaries between lanes. Flags are derived facts: a job without `retry_on`, a conditional with no else branch, an unresolved dynamic dispatch.
4.  The pinboard is the guide's context and the export's content. "Graph of pinned" opens the Atlas component on exactly those nodes.
5.  History strip is scoped to pinned units; a commit that touches two pinned units is drawn as a connected pair, which is the "who changed the mailer and the job together" question answered visually.
### How the four capabilities surface in Trail
| Capability               | Trail treatment                                                                                                                                                                                                                                          |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Search, unit pages, code | Search chooses entries and pins. Code appears as method-level excerpts inside expanded steps (the flow carries line numbers, so the excerpt is the called method, not the whole file), with a link to the full unit page (the Field Guide page, reused). |
| Relationship graph       | Secondary: "Graph of pinned" and "blast radius of entry" open the Atlas component scoped to the board; the swimlane itself is a directed, layered view of a slice of the graph.                                                                          |
| Flows and ERD            | Primary. The swimlane is the flow. A Mermaid export (flowchart with subgraphs per lane, or `sequenceDiagram` for the async hops) is one click; "ERD of pinned models" renders the models on the board and their tables.                                  |
| Git timeline             | Scoped to the board; co-change pairs are the headline feature. Snapshot diffs annotate steps that changed between two generations ("this mailer's metadata changed in gen 41").                                                                          |
### Scenario walkthroughs
#### 1 · Plan auto-tagging on posts

1.  New investigation "auto tagging", entry `Post after_commit(create)` and `PostsController#create` (a board can hold several entries).
2.  The lanes show where asynchronous work already attaches to post creation; pin the job, mailer and the views that render a post.
3.  "ERD of pinned models" gives the posts, users, comments tables to design a `tags`/`taggings` addition against.
4.  "Draft a fix plan" (here, an implementation plan) asks the guide to propose an `AutoTagJob` enqueued from the same callback, a migration, serializer and view changes, citing the pinned units.
5.  Export the board as Markdown with the Mermaid lifecycle for the planning issue.
#### 2 · Mailing list job failing after post creation

1.  Entry: the job. The lane view immediately flags "no retry_on / rescue_from" and a conditional with no else branch in the mailer.
2.  Expand the mailer step: the method excerpt shows `user.name`; expand the template step: it also reads `@user.preferences`.
3.  The history strip shows the job and mailer were changed together six days ago; expanding the commit shows message and author.
4.  Pin the two, write a note, share the URL in the incident thread; "Explain this investigation" summarises the evidence.
### Direction-specific requirements and technology
#### Requirements

- **C-1** Lifecycle builder: given an entry, assemble the flow (precomputed or on demand), then extend across async boundaries by following `job_enqueue` and mailer edges and the job's own `perform` flow, up to a depth budget; group steps into lanes by unit type.
- **C-2** Derived flags: missing `retry_on`/`discard_on`, callbacks with conditions, conditionals without else, `dynamic_dispatch`, cross-database association edges, hub units.
- **C-3** Board state serialised in the URL (compressed) with an optional server-side save under `<index>/explorer/boards/` for named investigations.
- **C-4** Export: Markdown with Mermaid flowchart and erDiagram, unit links as repository paths with line numbers.
- **C-5** Co-change detection: commits touching two or more pinned units, from the generation's commit table.
#### Technology

- Lanes are plain HTML/CSS grid (no graph library); step expansion is a Turbo Frame.
- Mermaid 12 for export and the optional diagram view; `@dagrejs/dagre` if a layered SVG of the lanes is wanted in-page.
- vis-timeline for the strip; Cytoscape only when "Graph of pinned" is opened.
- Ruby: a `LifecycleBuilder` over `FlowAssembler` + the graph; a `FlagDetector` over unit metadata (job `rescue_from`/`retry_on` facts must be present in job metadata; add if missing).
<span class="eyebrow">Risks</span>Trail is the most novel and the most dependent on flow quality: receiverless local calls can remain unexpanded and dynamic dispatch is opaque, so lanes will have gaps that must be shown honestly. It also needs job metadata that may not exist yet (retry and rescue declarations). As a sole surface it is weak for browsing; it is strongest as the page you reach once you know your entry point.
## 6 · Comparison and recommendation
| Criterion                                    | A · Atlas                                           | B · Field Guide                                | C · Trail                                   |
|----------------------------------------------|-----------------------------------------------------|------------------------------------------------|---------------------------------------------|
| Fit: scenario 1 (plan a feature around Post) | ●●○ blast radius is excellent; reading code is weak | ●●● every step is a page the developer expects | ●●○ great once the entry is chosen          |
| Fit: scenario 2 (debug a failing job)        | ●●○                                                 | ●●○ needs History + Lifecycle tabs together    | ●●● built for exactly this                  |
| Build cost to v1 (all four capabilities)     | High: graph UX, layout caching, flow overlay        | Medium: mostly server-rendered pages           | High: lifecycle builder, flags, board state |
| Works without JavaScript                     | No                                                  | Yes (except Graph tab and diagrams)            | Mostly (lanes are HTML)                     |
| Accessibility and keyboard                   | Hard                                                | Natural                                        | Natural                                     |
| Performance risk on 5 000-unit apps          | Medium (neighbourhood cap, layout cost)             | Low                                            | Medium (on-demand flow assembly)            |
| Dependence on new Woods data (section 10)    | commit table                                        | reference spans, method table, commit table    | job retry facts, commit table               |
| LLM synergy                                  | Medium: selection as context                        | Medium: page as context                        | High: the board is the context              |
| Shareability (URL as artefact)               | Good                                                | Good                                           | Best (board + export)                       |
| Novelty / differentiation                    | Familiar (Obsidian, CodeSee)                        | Familiar (GitHub, Sourcegraph)                 | New: lifecycle + co-change + guide          |
*Recommendation*
Build **Field Guide as the spine**, make **Trail's lifecycle board a first-class route** reached from any unit page, and ship **Atlas as a component** (the Graph tab, "graph of pinned", and a full-screen `/woods/graph` page) rather than as the home screen.

- Field Guide covers the most steps of both scenarios with the least JavaScript, and its unit pages and context cards are the partials the other two directions need anyway.
- Trail is where the product differentiates (lifecycle across async boundaries, co-change history, a board the guide reasons over). Making it a route instead of the home screen avoids its browsing weakness.
- Atlas as a component keeps the Cytoscape work bounded to one Stimulus controller and one JSON endpoint; promoting it to a home screen later is cheap if usage shows people start from the graph.
## 7 · Field Guide iterations: understanding the code first
Direction B is the chosen spine. The two iterations below push it toward one goal above all others: a developer standing in front of a model, controller, job or template understands what the code does, in Rails terms, faster and more reliably than by reading the file in an editor. Woods' advantage here is that its index records what Rails resolved at runtime (the callback chain in order, which filters apply to which action, which concern supplied a method, what a callback writes or enqueues), and almost none of that is visible in the file itself.
### Iteration 2 · Read the code as Rails runs it
The code viewer becomes the centre of the unit page rather than one tab among five. It offers two lenses over the same lines, keeps every Rails fact in the margin next to the line it belongs to, lets you peek at any referenced definition without leaving, and never asks you to guess whether a link is trustworthy.
*Wireframe*: Wireframe B3: reading mode for `Post` in the "Effective class" lens, with the outline open, marginalia on the right, and a peek drawer expanded under line 62. (rendered in `design-study.html`)

1.  Lens toggle: "As written" is the file's bytes with original numbering; "Effective class" is Woods' annotated source (schema header, concern bodies inlined and collapsible, superclass methods on request) mapped to the same file lines through `source_line_map`. The reading trail is a breadcrumb stack of the units you came through.
2.  Outline groups what the class *is* at runtime: callback chains per event in resolved order (with the owning concern), associations, methods grouped by owner, scopes. Clicking scrolls and highlights; the outline doubles as the keyboard map.
3.  Every reference is a link with a confidence mark. Click opens a peek drawer under the line showing the target method (sliced by the method table) with its own key facts; "open" navigates. Gutter heat uses the commit table.
4.  Marginalia are the Rails facts Woods already extracts, placed beside the line they explain: association storage facts, callback chain position and side effects, validation sets, filter applicability, route for an action, callers of a method.
#### What this adds for the two scenarios

- Scenario 1: the lifecycle outline shows where an `AutoTagJob` enqueue would sit in the create chain and whether a concern already owns tagging; the marginalia on `has_many :tags` reveals the join table and FK before any migration is written.
- Scenario 2: peeking from the `perform_later` line into the job shows "no retry_on" and the `find_each` loop over followers without ever leaving the model; the L61 margin shows a second, static caller the developer did not know about.
#### Requirements (extend B-1 to B-6)

- **B-7** Two lenses over one line model; the lens is remembered per browser; permalinks (`#L61-L64`) resolve in both lenses.
- **B-8** Outline with callback chains per event in resolved order, methods grouped by owner (class, each concern, superclass), associations, scopes, enums; keyboard navigation (<span class="kbd">j</span>/<span class="kbd">k</span>, <span class="kbd">gd</span> definition, <span class="kbd">gr</span> references, <span class="kbd">p</span> peek).
- **B-9** Peek drawer: slice the target's method by the method table; nested peeks up to depth 3; "open" pushes onto the reading trail.
- **B-10** Marginalia: a renderer per unit type mapping metadata facts to lines (callbacks, associations, validations, scopes, filters, routes, renders, enqueues); every fact links to its source unit.
- **B-11** Confidence marks on every link: runtime-verified (from the typed registry), static (collector only), ambiguous (candidate list). Never a silent wrong jump.
- **B-12** Full-text code search across units (the reader already supports `source_code` as a search field) with snippet results and a type filter.
- **B-13** Callers panel for the current method from method-level reference spans and flow operations.
- **B-14** Unit diff across retained generations (default three): unified diff of `source_code` with the metadata changes listed alongside.
- **B-15** Reading ergonomics: wrap, font size, copy `path:line`, configurable "open in editor" link scheme (a link only; the explorer never touches the file system).
### Iteration 3 · Follow the data across layers
Both scenarios end with the same question: how does data travel from request to template, or from callback to mail? Iteration 3 adds a "data passage" view for actions and mailers and a "callback ladder" for models. These are the places where the file alone misleads: a filter applies to an action it does not mention; a template reads an instance variable no action assigns; a callback runs under a condition declared in a concern.
*Wireframe*: Wireframe B4: data passage for `PostsController#show`. Filters above, then the passage from params through the action to the templates that read what it assigned. (rendered in `design-study.html`)
#### What this adds for the two scenarios

- Scenario 1: the passage for `show` and `index` names the exact template and partial that render a post and which locals they take, so "where do tags render" has a one-screen answer; the matrix shows which filters a new `tags` action inherits.
- Scenario 2: the mailer's passage shows the template reading `@user.preferences` while the mailer action assigns only `@user` and `@post`; a read with no assignment is the class of bug that fails "occasionally". The ladder shows the enqueue runs after commit, which rules out the rollback theory.
#### Requirements

- **B-16** Filter matrix per controller: filters in chain order (including inherited and concern-supplied) against actions, with resolved only/except and conditions shown on hover.
- **B-17** Data passage per action and per mailer action: params read and permitted, instance variables assigned (with owner method and line), render targets and partial chain with locals, instance variables and helpers read in each template, response formats and serializers.
- **B-18** Mismatch flags: template reads an unassigned instance variable; permitted param with no matching column or attribute; partial rendered with a local the partial never reads.
- **B-19** Callback ladder per model event in resolved chain order with owner, conditions and side effects; each row links into the Code tab at its line.
- **B-20** Mermaid export of a passage (`flowchart LR`) for issues and PRs.
*Extraction-side additions these iterations need*
- **W-6** Method-level targets in reference spans: when a receiver resolves to a unit, record `method` on the span (`NotifySubscribersJob.perform_later`, `MailingListMailer.new_post`), so callers panels and peeks can slice the right method.
- **W-7** Per-action controller and mailer facts: `assigns[{ivar, line, method}]`, `params[{key, permitted, line}]`, `renders[{template, partial, locals, line}]`, `redirects`, `respond_to` formats, from the action sources Woods already captures, with Prism. Views already record `instance_variables`, `helpers_called` and `partials_rendered`, so the passage is a join.
- **W-8** Filter applicability per action: the runtime filter chain already records only/except; publish the resolved action list per filter so the matrix needs no re-derivation.
- W-1 (spans), W-2 (method table) and W-3 (commit table) from section 9 remain prerequisites.
### C4 model: does it add useful context?
The C4 model (Simon Brown) describes a system at four zoom levels, Context, Containers, Components and Code, with a fixed notation per element (name, type, technology, one-line description) and two supplementary views: dynamic diagrams for a runtime scenario with numbered interactions, and deployment diagrams. Its value for the explorer is the *zoom ladder* and the *vocabulary*, not any particular tool. Today the explorer's charts live at Code level (units) and at a neighbourhood of Code level (the graph). They have no view of the system as a whole, and the lifecycle charts have no agreed notation for "which process does this run in". C4 supplies both.
| C4 level            | What it would show for a Rails app                                                                                    | Where Woods already has the facts                                                                                                                                                                                                                                   | Gap                                                                                                                              |
|---------------------|-----------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|
| L1 · System context | The application, its users (roles), and the external systems it talks to.                                             | `external_consumer` units (declared external calls), mailer `delivery_method`, Active Storage service, GraphQL and route surfaces for inbound APIs.                                                                                                                 | Users are not in the index; take them from Devise/Pundit role facts when present, otherwise from a host-provided list. Low cost. |
| L2 · Containers     | Web process, job runner, databases, cache, mail delivery, mounted engines, object storage.                            | The `BehavioralProfile` configuration unit records `database`, `background_processing`, `caching`, `email` and `frameworks_active`; model `database` and `database_table` units give multi-database layout; `engine` and `middleware` units give the request stack. | Deployment topology (how many processes, where) is not a Woods concern; L2 stays logical, not physical.                          |
| L3 · Components     | Packwerk packages, namespaces or detected domain clusters inside each container, with the relationships between them. | `package` units and `package_dependency` edges; `domain_clusters` from graph analysis; namespaces from unit metadata.                                                                                                                                               | None. This is the Cytoscape compound-node view with C4 labelling.                                                                |
| L4 · Code           | Classes, methods, templates, tables.                                                                                  | Every unit page.                                                                                                                                                                                                                                                    | None; C4 itself recommends generating this level from code rather than drawing it, which is exactly what Woods does.             |
| Dynamic             | One scenario across containers with numbered steps: request → controller → model → job → mailer → SMTP.               | Flow documents, extended across async hops by the Trail lifecycle builder; container membership from unit type and queue facts.                                                                                                                                     | None. Equivalent to the Trail swimlane, in a notation other teams already know.                                                  |
| Deployment          | Nodes, instances, infrastructure.                                                                                     | Not in the index.                                                                                                                                                                                                                                                   | Out of scope; the explorer is index-only.                                                                                        |
#### Can Mermaid draw the C4 notation natively?
Yes. The experimental C4 diagram type is the problem, not Mermaid. A plain flowchart with HTML labels, a subgraph for the system boundary and three `classDef`s reproduces the notation, follows the theme, lays out with dagre or ELK, and supports `click` links on every node when the explorer renders it with `securityLevel: "loose"` (trusted, self-generated text). The same text is the export. The newer `architecture` diagram (Mermaid 11.1+) is a second native option for the container level with built-in server, database and disk icons.
``` mermaid
flowchart LR
  author(["«person»
Author
Signs in, writes posts"])
  subscriber(["«person»
Subscriber
Receives the mailing list"])
  subgraph blog["Blog · Rails 8.0  [software system]"]
    direction LR
    web["«container»
Web process
[Rails, Puma]
Controllers, views, Turbo"]
    jobs["«container»
Job runner
[Solid Queue]
NotifySubscribersJob, PublishPostJob"]
    db[("«container · db»
Primary database
[PostgreSQL]")]
    cache[("«container · db»
Cache
[Solid Cache]")]
  end
  smtp["«external system»
Mail delivery
[SMTP via Action Mailer]"]
  s3["«external system»
Object storage
[Active Storage, S3]"]
  author -- "creates posts [HTTPS]" --> web
  web -- "enqueues [perform_later]" --> jobs
  web -- "reads, writes [Active Record]" --> db
  jobs -- "reads [Active Record]" --> db
  web -- "reads, writes [Rails.cache]" --> cache
  jobs -- "delivers [deliver_later]" --> smtp
  smtp -- "new-post email" --> subscriber
  web -- "uploads [Active Storage]" --> s3
  classDef person fill:#1f3d5c,color:#ffffff,stroke:#1f3d5c
  classDef container fill:#2f6b45,color:#ffffff,stroke:#2f6b45
  classDef ext fill:#6f766f,color:#ffffff,stroke:#6f766f
  class author,subscriber person
  class web,jobs,db,cache container
  class smtp,s3 ext
```

``` mermaid
architecture-beta
  group blog(cloud)[Blog Rails 8]
  service web(server)[Web process] in blog
  service jobs(server)[Job runner] in blog
  service db(database)[Primary database] in blog
  service cache(disk)[Cache] in blog
  service smtp(internet)[Mail delivery]
  service s3(disk)[Object storage]
  web:R --> L:jobs
  web:B --> T:db
  jobs:B --> T:cache
  jobs:R --> L:smtp
  web:L --> R:s3
```
What Mermaid cannot do natively is the free-form, numbered dynamic view with containers as lanes. For that the choices are a sequence diagram (below), Mermaid 12's swimlanes diagram once the explorer vendors Mermaid 12, or the explorer's own SVG shown next. The SVG examples stay as the fallback where edge routing must be controlled.
The same two views as the explorer's own SVG: each box carries stereotype, name, technology and one line of description; each arrow carries its mechanism. This is the fallback for views where edge routing must be controlled, such as the numbered dynamic view.
*Figure*: Container view of the blog, derived from `BehavioralProfile`, engines and external consumers. (SVG rendered in `design-study.html`)

*Figure*: Dynamic view of one flow document, "post created, mailing list sent", across two containers. Numbers are the flow's step order; dashed arrows are asynchronous hops. (SVG rendered in `design-study.html`)

#### Tooling for C4
| Tool                                                                                | Status                                                                                                                                                                                                                            | Fit for the explorer                                                                                                                                                                            |
|-------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Mermaid C4 (`C4Context`, `C4Container`, `C4Component`, `C4Dynamic`, `C4Deployment`) | Still marked experimental in the Mermaid docs; PlantUML-compatible syntax; fixed styling that ignores Mermaid themes; layout steered only by `UpdateLayoutConfig` row counts.                                                     | Tried in revision 3: overlapping labels, fixed colours that ignore the theme, and no control over edge routing. Export only.                                                                    |
| Structurizr                                                                         | Structurizr Lite is end of life, replaced by a `local` command in the consolidated self-hosted tool (Spring Boot, Java); the cloud service ends on 30 September 2026. The DSL and JSON workspace format remain the lingua franca. | Not embeddable in a Ruby gem. Worth an *export*: a Structurizr DSL workspace generated from L1 to L3 facts lets teams that already keep architecture in Structurizr ingest Woods' view.         |
| LikeC4                                                                              | MIT, TypeScript; flexible element types; CLI, VS Code extension, React components; exports Mermaid, D2, PlantUML, DrawIO.                                                                                                         | Needs Node, which the explorer does not have. Its DSL is a second useful export target; its interaction model (zoom into a container to see components, keep the frame) is the pattern to copy. |
| C4-PlantUML, IcePanel                                                               | Java renderer or Kroki server; commercial SaaS.                                                                                                                                                                                   | No.                                                                                                                                                                                             |
*Verdict*
Yes to the concepts, no to the C4 tools. Mermaid draws the notation natively with a flowchart; the explorer draws the dynamic view itself.

- **Adopt the zoom ladder.** Add a Landscape page at L1 and L2 as the explorer's front door, with L3 as the compound graph by package or namespace and L4 as the unit pages. Zooming keeps the parent frame visible (LikeC4's pattern), so a developer new to the app reads "which process, which database, which external system" before reading a class.
- **Adopt the notation.** Every box in the explorer's own diagrams carries name, type, technology and one line of description; every arrow carries its mechanism (`perform_later`, `belongs_to`, `render`, `deliver_later`). This is already what the `via` labels are; C4 gives it a shape readers recognise.
- **Adopt the dynamic view as an alternative rendering of flows.** The same flow document renders as the Trail swimlane, a Mermaid flowchart, a sequence diagram, or a C4 dynamic diagram; the dynamic form is the one to paste into architecture reviews.
- **Do not adopt a C4 tool.** Render the notation with a Mermaid flowchart (themed, linkable, exportable) or the architecture diagram; keep the explorer's own SVG for the numbered dynamic view; Structurizr DSL and LikeC4 DSL are export formats only.
#### Requirements

- **B-21** Landscape page (`/woods/landscape`): L1 and L2 derived from the `BehavioralProfile` unit, model and table database facts, engines, mailer delivery, external consumers; each container links to its L3 view and lists its unit counts by type.
- **B-22** L3 component view: the Cytoscape compound graph grouped by package, namespace or domain cluster, with C4-style labels and the parent container shown as a frame.
- **B-23** Flow renderings: swimlane, flowchart, sequence and C4 dynamic from one document, with a copy-as-Mermaid action for each.
- **B-24** Exports: Structurizr DSL workspace and LikeC4 model for L1 to L3; Mermaid C4 text for any view.
#### Extraction-side need

- **W-9** Container attribution per unit: the queue adapter a job runs under (from `background_processing` and per-job `queue`), the database a model or table belongs to (already present), the delivery method per mailer (already present). Publish it as `metadata.container` so L2 and the dynamic view need no re-derivation.
- Users and roles for L1 come from the host (`config.landscape_actors`) with an optional Devise/Pundit-derived default; the index does not know who uses the app.
### Mermaid diagram types mapped to Woods insights
Mermaid 11 and 12 ship far more than flowcharts. The table maps each insight the explorer produces to the diagram type that represents it best, with the Woods data it is generated from. Types marked 12 are new in Mermaid 12 (2026) and must be checked against the vendored version before the explorer offers them; the examples below render with the 11.4 build this page loads. Every diagram is generated text, so each one is also a copy-and-paste export for issues, pull requests and chat.
| Insight                                                  | Data                                                                                              | Diagram                                                                                                               | Fit and notes                                                                                                                                                                                              |
|----------------------------------------------------------|---------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Request or job lifecycle, in time order, with async hops | Flow document + job/mailer facts                                                                  | `sequenceDiagram` (pick)                                                                                              | Participants are units, `->>` synchronous calls, `-)` async enqueue and deliver, `loop` for `find_each`, `Note` for flags, `autonumber` matches the step table. Best single answer to "what happens when". |
| Lifecycle across containers as lanes                     | Flow document + container attribution (W-9)                                                       | `swimlanes` 12, else own HTML lanes                                                                                   | The Trail view natively; verify syntax and ELK layout once Mermaid 12 is vendored.                                                                                                                         |
| Lifecycle as branches and conditions                     | Flow document (conditional, transaction, response)                                                | `flowchart TD`                                                                                                        | Subgraphs per step, diamonds for conditionals, dashed edges for async; the existing `MermaidRenderer` is the base.                                                                                         |
| Table schema and relationships                           | Model columns, foreign keys, associations, `database_table` units                                 | `erDiagram` (pick)                                                                                                    | Cardinality from macro and `has_one`/`has_many`, keys as PK/FK/UK, chunked per namespace or database; polymorphic shown as a dashed relation to each candidate.                                            |
| Class structure: concerns, inheritance, STI, methods     | Model/service metadata, `inlined_concerns`, method table (W-2), `include`/`inheritance` edges     | `classDiagram` (pick)                                                                                                 | `<<concern>>` stereotype, `<|--` for STI, labelled associations with cardinality, methods grouped by owner. Complements the Effective-class lens.                                                          |
| State machines                                           | `state_machine` units (AASM, state_machines, Statesman) with events and callbacks                 | `stateDiagram-v2` (pick)                                                                                              | Transitions labelled with the event and the side effect (job enqueued); composite states for sub-machines.                                                                                                 |
| Hotspots: churn against dependents                       | `change_frequency` / commit counts, PageRank or dependent counts                                  | `quadrantChart` (pick)                                                                                                | "Review carefully" quadrant = hot and depended upon; feeds the impact risk flags and the review Markdown.                                                                                                  |
| Dependency volume between layers                         | Edges grouped by source type → target type and `via`                                              | `sankey-beta`                                                                                                         | Shows where coupling concentrates (views → models reads, controllers → jobs); also per package.                                                                                                            |
| Commits over time for a neighbourhood                    | Commit table (W-3), `recent_commits`                                                              | `xychart-beta`                                                                                                        | Bars per week with a line overlay; the History tab's non-interactive export of the vis-timeline strip.                                                                                                     |
| Generation history and what changed                      | Snapshot store, impact reports                                                                    | `timeline`                                                                                                            | One entry per generation with the headline change; links out to impact reports in the HTML form.                                                                                                           |
| Branch illustration for a review                         | Commit table (branch from manifest provenance)                                                    | `gitGraph`                                                                                                            | Small, illustrative only; the commit table is HEAD-reachable so unmerged branches are not available.                                                                                                       |
| Namespace, package and domain structure                  | Namespaces, `package` units, `domain_clusters`                                                    | `mindmap`; `treemap` 11.7+ sized by LOC or PageRank                                                                   | Mindmap for orientation; treemap when size matters (which package carries the code).                                                                                                                       |
| System landscape (C4 L1, L2)                             | `BehavioralProfile`, engines, external consumers                                                  | `flowchart` in C4 notation; `architecture-beta`                                                                       | Shown above. `block-beta` is a third option when a fixed grid is wanted.                                                                                                                                   |
| Change impact paths                                      | Impact report                                                                                     | `flowchart LR`                                                                                                        | Changed nodes on the left, affected to the right, `via` on edges, risk flags as notes; the Mermaid export in section 8.                                                                                    |
| Unit health at a glance                                  | LOC, callbacks, associations, dependents, churn, test coverage edges                              | `radar` 11.6+                                                                                                         | One polygon per unit, overlay two units to compare; verify availability.                                                                                                                                   |
| Unit type distribution, extraction counts                | `manifest.json` counts                                                                            | `pie`                                                                                                                 | Status page only.                                                                                                                                                                                          |
| File tree with unit ownership                            | `file_map`                                                                                        | `treeview` 12                                                                                                         | Export of the tree panel; verify.                                                                                                                                                                          |
| Events, commands and read models                         | Jobs, mailers, Active Support notifications (`event` units), `published_by`/`subscribed_by` edges | `event modeling` 12                                                                                                   | Promising for event-driven apps; verify syntax before committing.                                                                                                                                          |
| Not a fit                                                |                                                                                                   | `gantt`, `kanban`, `packet`, `venn`, `ishikawa`, `wardley`, `cynefin`, `requirement`, `journey`, `use case`, `zenuml` | Planning and workshop formats, or duplicates of the sequence diagram; the explorer does not generate them.                                                                                                 |
#### Rendered examples from the blog scenario
**Sequence diagram** of the same flow document as the dynamic view, with asynchronous hops as open arrows and the risk flag as a note. This is the form to offer first on every Lifecycle tab.
``` mermaid
sequenceDiagram
  autonumber
  actor Author
  participant C as PostsController#create
  participant P as Post
  participant DB as PostgreSQL
  participant Q as Solid Queue
  participant J as NotifySubscribersJob
  participant M as MailingListMailer
  Author->>C: POST /posts
  C->>P: Post.new(post_params).save
  activate P
  P->>P: before_validation, validations, before_save
  P->>DB: INSERT INTO posts
  P-)Q: after_commit: NotifySubscribersJob.perform_later(id)
  deactivate P
  C-->>Author: 302 redirect_to post_path
  Q-)J: perform(post_id)
  J->>DB: SELECT users WHERE follower of author
  loop each follower (find_each)
    J-)M: new_post(user, post).deliver_later
  end
  Note over J,M: no retry_on or discard_on declared
```
**Entity relationship** from model columns, foreign keys and associations (Schema tab, chunked by namespace).
``` mermaid
erDiagram
  USERS ||--o{ POSTS : author_id
  POSTS ||--o{ COMMENTS : post_id
  POSTS }o--o{ TAGS : taggings
  USERS ||--o| PREFERENCES : user_id
  POSTS {
    bigint id PK
    bigint author_id FK
    string title
    string slug UK
    text body
    datetime published_at
  }
  USERS {
    bigint id PK
    string email UK
    string name
  }
```
**Class diagram** with the concern as a stereotype, STI inheritance and labelled associations (the Effective-class lens as a picture).
``` mermaid
classDiagram
  class ApplicationRecord
  class Post {
    +String title
    +String slug
    +publish!()
    -notify_subscribers()
  }
  class Taggable {
    <<concern>>
    +tag_list()
    +tag_list=()
  }
  class Comment
  class User
  class NotifySubscribersJob
  ApplicationRecord <|-- Post
  Post ..|> Taggable : include
  Post "1" --> "*" Comment : has_many
  Post "*" --> "1" User : belongs_to author
  Post ..> NotifySubscribersJob : after_commit enqueues
```
**State diagram** from a state machine unit; transitions carry the event and the side effect.
``` mermaid
stateDiagram-v2
  [*] --> draft
  draft --> review : submit
  review --> published : approve / NotifySubscribersJob
  review --> draft : reject
  published --> archived : archive
  archived --> [*]
```
**Hotspot quadrant**: change frequency against dependents. Top-right is where review attention goes.
``` mermaid
quadrantChart
  title Hotspots: churn vs dependents
  x-axis Few dependents --> Many dependents
  y-axis Stable --> Hot
  quadrant-1 Review carefully
  quadrant-2 Churning leaves
  quadrant-3 Quiet
  quadrant-4 Stable hubs
  Post: [0.82, 0.78]
  User: [0.9, 0.35]
  NotifySubscribersJob: [0.3, 0.85]
  MailingListMailer: [0.25, 0.7]
  Comment: [0.4, 0.2]
  ApplicationController: [0.95, 0.15]
```
**Sankey** of dependency edges between layers: where coupling concentrates.
``` mermaid
sankey-beta

controllers,models,38
controllers,views,41
controllers,jobs,5
views,models,22
views,helpers,17
models,jobs,6
jobs,mailers,4
mailers,views,9
```
**Commits per week** touching the Post neighbourhood, from the commit table.
``` mermaid
xychart-beta
  title "Commits touching the Post neighbourhood, 12 weeks"
  x-axis [w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12]
  y-axis "commits" 0 --> 12
  bar [2, 1, 0, 3, 5, 2, 1, 0, 4, 9, 7, 3]
  line [2, 1, 0, 3, 5, 2, 1, 0, 4, 9, 7, 3]
```
**Timeline** of index generations with the headline change of each, the History tab's export.
``` mermaid
timeline
  title Index generations on main
  gen 40 · a1b2c3d, 6 days ago : MailingListMailer and NotifySubscribersJob changed together ("digest refactor")
  gen 41 · c4d5e6f, 3 days ago : Post callback moved from after_save to after_commit
  gen 42 · 9f8e7d6, today : new_post.html.erb reads @user.preferences
```
*Decisions for the explorer*
- Vendor Mermaid 12 (ELK default, swimlanes, treemap, radar) and verify each 12-only type against the vendored build in a spec that renders every generated diagram headlessly.
- Every Lifecycle tab offers sequence first, then flowchart, swimlane and C4-notation flowchart; every Schema tab offers ER and class; state machine units get a state diagram; the Landscape page renders the C4-notation flowchart; History offers timeline and XY; the overview offers quadrant, sankey and mindmap.
- One Ruby renderer per type extends `Woods::RubyAnalyzer::MermaidRenderer`; each has a "copy Mermaid" action and a size guard that chunks or refuses above the node budget.
## 8 · Spike: change highlighting and blast radius
Two questions turn out to be the same report read in opposite directions. *What changed between A and B, and what does it affect?* (review, after the fact) and *what will changing this affect?* (planning, before the fact). Both produce a set of changed or focused units, a propagation through the dependency graph, the flows, tables, templates and tests that propagation reaches, and risk flags. The deliverable is a sharable URL that opens with the interesting part already highlighted, plus the same report as Markdown for a pull request and JSON for an agent.
### What the index can already answer
| Question                                     | Source today                                                                                                                                                                                                                                         | Limit                                                                                                                   |
|----------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| Which units changed between two extractions? | Snapshot store: per unit and per generation, `source_hash`, `metadata_hash`, `dependencies_hash` keyed by git sha; `SnapshotStore#diff` returns added, modified and deleted. MCP already exposes `snapshot_diff`, `unit_history`, `snapshot_detail`. | Says *that* a unit changed, not which facet; needs a tiny change to report which of the three hashes moved (W-10).      |
| What exactly changed in a unit?              | Retained payloads (three generations by default) hold full `source_code` and `metadata`, so a real diff of source, schema, callbacks, filters, routes and edges is a payload-to-payload comparison.                                                  | Only for retained generations; a review base older than that needs the base extracted again or a pinned payload (W-11). |
| What depends on a changed unit?              | `reverse_via` gives inbound records with source type and `via`; transitive closure with depth from the graph; PageRank for weighting; `graph_analysis` for hubs, bridges, cycles.                                                                    | Unit level. Method-level propagation needs reference spans with method targets (W-1, W-6).                              |
| Which entry points run through it?           | Flow documents (precomputed or assembled) list every unit a flow touches; invert to "flows per unit"; controller `routes` turn that into verbs and paths.                                                                                            | Flow assembly is static; receiverless and dynamic calls are gaps the report must label.                                 |
| Which tests cover it?                        | `test_mapping` units and `test_coverage` edges link specs and tests to units.                                                                                                                                                                        | Heuristic mapping; good enough for "tests to run first".                                                                |
| Who changed it and when?                     | `metadata.git` per unit; the commit table (W-3) for the full window.                                                                                                                                                                                 | W-3 is needed for "commits in this range touching these files".                                                         |
### Report pipeline

``` mermaid
flowchart LR
  A["from: gen 40 / sha a1b2c3d\nto: gen 42 / sha 9f8e7d6\n(or: focus set, no range)"] --> D["1 · Diff units\nsnapshot facets + payload compare"]
  D --> K["2 · Classify each change\nschema · behaviour · routing · template · edges · tests"]
  K --> P["3 · Propagate\nreverse_via depth N · flows per unit\ntables · templates · tests · PageRank weight"]
  P --> R["4 · Risk flags\nhub · bridge · cycle · cross-db\nside-effect change · filter chain change\nnew ivar mismatch · job without retry"]
  R --> O["5 · Render\nHTML with focus URL · Markdown · JSON · Mermaid"]
  O --> S["saved as impact JSON\nunder index/explorer/impacts"]
```
*Wireframe*: Wireframe E1: change impact for a pull request that changed `MailingListMailer`, its template and `NotifySubscribersJob`; opened from a focus URL. (rendered in `design-study.html`)

1.  Header carries the range (generation numbers and shas) and the counts; depth is a control, not a hidden default.
2.  Changed units with the facets that moved (source, schema, callbacks, filters, routes, templates, dependencies, tests), then the direct dependents grouped by how they depend (`via`).
3.  The impact graph is the Atlas component in a directed layout, changed on the left; node emphasis encodes changed, direct, transitive; the same tints apply in every other view when opened with `?since=`.
4.  Focus panel: the diff for a changed unit (from retained payloads) or the "why affected" path for an affected one, the risk flags with their evidence, and the tests that cover the focused unit.
5.  Affected flows are the entry points whose documents pass through a changed unit, as lanes with the changed steps outlined; routes come from controller metadata.
6.  Share bar: the focus URL, and the same report as Markdown, JSON or Mermaid. The guide's "review this change" action takes the JSON as context.
### Sharable URL grammar

    /woods/impact?from=gen:40&to=gen:42                  # range by generation number
    /woods/impact?from=a1b2c3d&to=9f8e7d6                 # range by git sha (resolved through the snapshot store)
    /woods/impact?from=a1b2c3d                            # to = current generation ("since")
    /woods/impact?focus=Post%23publish!&depth=2            # no range: blast radius of a planned change
    /woods/impact/9f8e7d6?from=a1b2c3d&focus=new_post.html.erb&depth=2&types=controller,view&lens=flows
    /woods/impacts/7c1e…                                  # a saved report, stable after restarts and retention
    /woods/units/view_template/new_post.html.erb?since=gen:40#L38-L40   # any unit page lights changed lines and marginalia
    /woods/graph?centre=Post&since=a1b2c3d                 # any graph view tints changed and affected nodes
`focus` opens the page with those units selected and the paths to them highlighted; `lens` chooses which panel is expanded first (changed, graph, flows, tests, risks). The saved form writes `impact.json` under `<index>/explorer/impacts/` so a link in a pull request still resolves after the payloads it was computed from are retired.
### Output formats
| Format                   | For                                        | Contents                                                                                                                                                                                                                                                                                                                 |
|--------------------------|--------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| HTML page                | People, from a link                        | Wireframe E1; every element links into the explorer; the lens and focus come from the URL.                                                                                                                                                                                                                               |
| Markdown                 | Pull request comment, issue, review thread | Summary line; table of changed units with facets; "directly affected" grouped by `via`; affected routes and jobs; risk flags with one-line evidence; "tests to run first"; focus links back to the explorer; a collapsed Mermaid flowchart of the paths. Sized to a PR comment (about 60 lines, longer lists collapsed). |
| JSON (`impact.json`)     | Agents, CI, the guide                      | `range`, `changed[{identifier,type,facets,diff_stats}]`, `affected[{identifier,type,distance,paths[{via…}],weight}]`, `flows[{entry_point,route,changed_steps}]`, `tables`, `templates`, `tests`, `risks[{kind,unit,evidence}]`, `unknowns` (unexpanded calls, ambiguous names). Versioned schema.                       |
| Mermaid                  | Docs and chat                              | `flowchart LR` of changed → affected paths to the focus, with `via` edge labels; swimlane-free so it renders anywhere Mermaid does.                                                                                                                                                                                      |
| MCP tool `change_impact` | Editor agents during review                | `from`, `to`, `focus`, `depth`, `format` (markdown or json); wiring-conditional on the snapshot store like the existing snapshot tools; read-only.                                                                                                                                                                       |
### Where it shows up in the rest of the explorer
#### Highlighting with `?since=`

- Unit tree and search results: A / M / D badges and a "changed since" filter.
- Code viewer: a diff gutter against the base generation in either lens; changed marginalia (a callback added, a filter condition changed) are marked, not only changed lines.
- Graph: changed nodes filled, direct dependents ringed, transitive faded; a "show only radius" toggle.
- Lifecycle and passage views: changed steps outlined; a newly unassigned instance variable is a flag with a link to the diff that introduced it.
- ERD: added and removed columns and associations coloured; a dropped foreign key is a risk flag.
- History timeline: the compared range shaded; commits inside it listed with the units they touched.
#### Agents and CI

- **Review recipe.** CI restores the cached index for the base commit, runs `woods:incremental` with `CHANGED_FILES` from the pull request diff (both generations then live in one index), then `woods:impact[base_sha,head_sha]` writes `impact.json` and prints the Markdown for the PR comment. No second host boot.
- **Editor agents.** The `change_impact` tool answers "what does my diff affect" before a commit, using the working tree generation the watch daemon keeps current against the last published one.
- **The guide.** A "review this change" action takes `impact.json` as context and is restricted to the read-only tools; it drafts the review comment with links, never posts it.
- **Pre-change mode.** From any unit or method, "blast radius" is the same report with an empty range; with reference spans it works at method level (`Post#publish!`).
#### Requirements

- **E-1** Range resolution by generation number, git sha or "now"; sha resolves through the snapshot store; unknown shas fail with a message naming the nearest snapshots.
- **E-2** Facet classification per unit type (schema, behaviour, routing, template, edges, tests) from payload comparison, with diff stats.
- **E-3** Propagation with depth, type and `via` filters, PageRank weighting, and path recording so every affected unit can explain itself.
- **E-4** Flows per changed unit, inverted from flow documents, with routes; unexpanded calls reported as unknowns, never dropped.
- **E-5** Risk flags with evidence links: hub, bridge, cycle, cross-database edge, callback side-effect change, filter chain change, new instance-variable mismatch, job without retry touched, dropped foreign key.
- **E-6** Focus URL grammar above; saved reports immutable and addressable.
- **E-7** Markdown, JSON and Mermaid renderers from one report object; the MCP tool uses the same renderers.
- **E-8** `?since=` highlighting in tree, code, graph, lifecycle, passage, ERD and timeline views.
- **E-9** Pre-change mode from any unit or method.
- **E-10** A report never claims completeness: counts carry "of which unknown" and the page says which generations it was computed from.
#### Woods-side needs

- **W-10** `SnapshotStore#diff` returns which facet hashes moved per modified unit (source, metadata, dependencies).
- **W-11** Pin a generation against retention (`woods:pin[gen]`) so a review base survives until the report is saved; today the shared `flock` protects a payload only while a reader holds it.
- **W-12** `woods:impact[from,to]` rake task and the `impact.json` schema in the woods gem, so CI and the explorer share one implementation; the explorer only renders.
- **W-13** Flow index inverted per unit (`flows/by_unit.json`) written with precomputed flows, so "flows through this unit" is a lookup; assembled on demand otherwise.
- W-1, W-3 and W-6 from section 10 for method-level radius and commit lists in the range.
<span class="eyebrow">Spike verdict</span>The data for a credible first version exists in the index today: unit-level diffs, dependents with `via`, flows, tests and risk inputs. The missing pieces are small and extraction-side (facet reporting, generation pinning, an inverted flow index, the commit table). The thing to build first is the report object and its three renderers, because the HTML page, the PR comment and the agent tool are the same report. Method-level radius and "since you last looked" highlighting follow once reference spans land.
## 9 · Tooling and open-source landscape
Versions and dates were checked against the npm and RubyGems registries on 14 October 2026. "No build" means the package ships a self-contained ES module or a classic script that an importmap engine can vendor and pin without Node. Picks are marked.
### Graph rendering
| Library                                 | Version · license · last release              | No build?                                         | Assessment                                                                                                                                                               |
|-----------------------------------------|-----------------------------------------------|---------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Cytoscape.js (pick)                     | 3.34.3 · MIT · 2026-09                        | Yes (ESM file, ~1 MB)                             | Canvas renderer, compound nodes for namespaces/packages, selector-based styling by edge `via`. Comfortable to about 3 000 nodes, which the neighbourhood cap guarantees. |
| cytoscape-fcose / @dagrejs/dagre (pick) | 2.2.0 · MIT · 2023 / 3.1.1 · MIT · 2026-08    | fcose UMD (classic script); dagre ESM             | fcose for organic overviews, dagre for butterfly and flow-overlay layouts. Never use the unscoped, abandoned `dagre`.                                                    |
| sigma.js + graphology                   | 4.0.2 · MIT · 2026-10 (3.0.2 is the safe pin) | ESM, about 8 pins                                 | WebGL2; the escape hatch above 3 000 visible nodes. Not needed for v1.                                                                                                   |
| vis-network                             | 10.1.2 · Apache-2.0/MIT · 2026-08             | Yes (standalone ESM)                              | Easiest single pin with built-in clustering; slows past about 1 500 nodes and styles less precisely than Cytoscape.                                                      |
| AntV G6, force-graph, elkjs             | 5.1.1 MIT · 1.52 MIT · 0.12 EPL-2.0/GPL-3.0   | G6 UMD; force-graph UMD+ESM; elkjs bundled script | G6 is heavy; force-graph is pretty but weak for labelled edges; elkjs is useful for layered layouts but EPL licensing deserves a note if vendored.                       |
### Diagrams as text
| Library                     | Version · license · last release     | No build?                                 | Assessment                                                                                                                                                                                                                                                                                                     |
|-----------------------------|--------------------------------------|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Mermaid (pick)              | 12.2.0 · MIT · 2026-10               | Yes (ESM file; ELK loads as a lazy chunk) | `erDiagram`, `flowchart`, `sequenceDiagram`, `gitGraph`, `timeline` client-side. v12 made ELK the default layout and requires ES2024 browsers. Raise `maxTextSize` and `maxEdges`; chunk ERDs by namespace. Woods already has a `RubyAnalyzer::MermaidRenderer` for call graphs and dependency maps to extend. |
| @viz-js/viz (Graphviz WASM) | 3.31.0 · MIT · 2026-09               | Yes (ESM with inlined WASM, ~2 MB)        | Fallback for large dot graphs where Mermaid chokes (1 000+ nodes). Optional.                                                                                                                                                                                                                                   |
| D2, PlantUML, Kroki         | 0.1.33 MPL · 1.2026.8 MIT · 0.33 MIT | D2/PlantUML huge; Kroki needs a server    | Skip.                                                                                                                                                                                                                                                                                                          |
### Code viewing and navigation
| Library                                                                 | Version · license · last release                 | No build?                  | Assessment                                                                                                                                                                                                             |
|-------------------------------------------------------------------------|--------------------------------------------------|----------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| rouge (gem) (pick)                                                      | 5.1.0 · MIT · 2026-08                            | Server-side                | Best Ruby/ERB lexers, line tables, zero JS. Reference spans are injected after highlighting by position.                                                                                                               |
| highlight.js                                                            | 11.12 · BSD-3 · 2026-08                          | Yes (two ESM pins)         | Only for client-side snippets inside LLM answers.                                                                                                                                                                      |
| Shiki / CodeMirror 6 / Monaco                                           | 4.5 MIT · 6.0.2 MIT · 0.57 MIT                   | Fiddly (many pins) / heavy | Shiki needs a rewriting CDN or many pins; CodeMirror only if in-page editing is wanted later; Monaco is far too large.                                                                                                 |
| Precise Ruby navigation (scip-ruby, ruby-lsp, Solargraph, stack-graphs) | 0.5 Apache · 0.26 MIT · 0.61 MIT · archived 2025 | Server/CLI only            | No OSS does in-browser Ruby jump-to-definition. GitHub itself uses search-based navigation for Ruby. Woods' own runtime-verified reference pass is the better source: precompute spans at extraction time (section 8). |
### Git history visualisation
| Library                                | Version · license · last release | No build?            | Assessment                                                                       |
|----------------------------------------|----------------------------------|----------------------|----------------------------------------------------------------------------------|
| vis-timeline (pick)                    | 8.5.4 · Apache-2.0/MIT · 2026-08 | Yes (standalone ESM) | Grouped, zoomable rows (units) with items (commits); maintained.                 |
| Observable Plot                        | 0.6.17 · ISC · 2025-02           | Yes                  | Smaller alternative for dot timelines and `Plot.cell` change-frequency heatmaps. |
| Mermaid gitGraph                       | 12.2.0                           | Yes                  | Illustrative branch diagrams up to about 50 commits; not interactive.            |
| gitgraph.js, @gitgraph/js, cal-heatmap | 2019 / 2021 / 2023               | Yes                  | Unmaintained; skip.                                                              |
### Rails precedents and prior art
| Project                                              | Status                | What to take                                                                                                                                     |
|------------------------------------------------------|-----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| mission_control-jobs 1.3.1 (pick)                    | MIT · 2026-09         | Engine with its own `Importmap::Map`, vendored Turbo/Stimulus, `pin_all_from`, assets path registration, Propshaft or Sprockets. Copy wholesale. |
| web-console 4.3, letter_opener_web 3.0, rails_db 2.5 | MIT                   | Dev-only mounting conventions and the "inert in production" posture.                                                                             |
| rails-mermaid_erd 0.8.2                              | MIT · 2026-10         | The closest existing "ERD in the browser" for Rails; Woods' index already has richer facts (databases, polymorphic, through).                    |
| Rubrowser 2.11, visualize_packs, railroady           | Dead 2021 · CLI · GPL | Rubrowser was the only prior Ruby codebase-explorer UI (D3 force graph, static parse). Nothing current fills this gap.                           |
| Avo, Motor Admin                                     | LGPL/commercial, MIT  | The "prebuilt bundle in the gem" alternative we decided against.                                                                                 |
### Interaction patterns worth borrowing
#### From code hosts

- **GitHub blame**: consecutive lines grouped into hunks with one gutter card (avatar, message, relative date), an age heat bar and "view prior to this change".
- **GitHub search-based navigation**: a "N definitions" panel instead of a wrong jump for ambiguous names.
- **Sourcegraph**: a precise versus search-based confidence badge on each reference.
#### From graph tools

- **Dependency Cruiser**: `--focus`, `--reaches`, `--highlight` as query-driven focus+context instead of panning.
- **Understand**: butterfly layout, callers left and callees right.
- **CodeSee**: overlay "what this change touched" on the map (our snapshot diff).
- **CodeCharta**: metric encodings (change frequency → colour, PageRank → size).
- **Aider repo-map**: PageRank personalised by the identifiers in the question, for the guide's context selection.
## 10 · What we must build ourselves
No open-source tool matches the whole need, and three pieces of data are missing from the index. The plan below keeps the explorer index-only by moving every computation that needs source or git into Woods extraction, and keeps the UI work in `woods-map`.
### Extraction-side additions (woods gem, through the normal review gate)
| Item                                           | What                                                                                                                                                                                                                                                                           | How                                                                                                                                                                                                                                                                                                                                                                                                                     | Unblocks                                                      |
|------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------|
| **W-1** Reference spans                        | `metadata.references`: `[{line, column, length, target, target_type, kind, confidence}]` in annotated-source coordinates (map to file lines through `source_line_map`). Kinds: constant, association, route_helper, callback_method, job_class, mailer_action, partial, scope. | The source-reference pass already collects constant reads with lexical context during extraction and resolves them against the typed registry; retain positions and publish the admitted ones. Association, callback and route-helper spans come from the metadata the extractors already produce plus a position scan of the same source. Ambiguous short names publish all candidates with `confidence: "ambiguous"`. | FR-4, B-1, click-through in every direction                   |
| **W-2** Method table                           | `metadata.methods`: `[{name, kind, line, end_line, visibility, owner}]` including methods inlined from concerns (owner = concern).                                                                                                                                             | One Prism walk per unit source; the AST layer and `SourceNesting` already handle nesting. Flow operations already carry lines, so method excerpts in Trail become a slice.                                                                                                                                                                                                                                              | Method anchors, method excerpts, "jump to def" within a class |
| **W-3** Commit table                           | Payload artifact `git_commits.json`: `commits[{sha, author, date, message}]` and `paths{path → [sha…]}` for the 365-day HEAD-reachable window, plus a config to raise `recent_commits` per unit.                                                                               | `GitHistory` already streams touched-path events for every indexed path; aggregate instead of truncating to five. Written by full runs; incremental runs refresh touched paths. Honour the same provenance rules (`GitProvenance`, `WOODS_GIT_DIR`).                                                                                                                                                                    | FR-7, timelines, co-change detection                          |
| **W-4** Job resilience facts                   | Job `metadata`: `retry_on`, `discard_on`, `rescue_from`, `around_perform` callbacks.                                                                                                                                                                                           | Runtime introspection of `ActiveJob::Base` descendants (`rescue_handlers`, callback chains) with a regex fallback for Sidekiq workers.                                                                                                                                                                                                                                                                                  | Trail flags C-2                                               |
| **W-5** Lifecycle entries for models           | Allow `trace_flow`/`FlowAssembler` to start from `Model@after_commit(create)`, expanding the callback methods for that event in chain order.                                                                                                                                   | Model units already carry resolved callbacks with filters; the assembler needs an entry-point grammar for events.                                                                                                                                                                                                                                                                                                       | FR-6, scenario 1 step 2                                       |
| **W-6** Method-level span targets              | Add `method` to a reference span when the receiver resolves to a unit (`Job.perform_later`, `Mailer.new_post`, `Service.call`).                                                                                                                                                | Same Prism walk as W-1; the call node's method name is adjacent to the constant read.                                                                                                                                                                                                                                                                                                                                   | Callers panel, peek slicing (B-9, B-13)                       |
| **W-7** Per-action controller and mailer facts | `metadata.actions[name]` gains `assigns`, `params`, `renders` (with locals), `redirects`, `formats`, each with lines.                                                                                                                                                          | Prism over the captured `action_sources`; filters' assigns attributed to the filter method. Views already carry `instance_variables`, `helpers_called`, `partials_rendered`.                                                                                                                                                                                                                                            | Data passage and mismatch flags (B-17, B-18)                  |
| **W-8** Resolved filter applicability          | `metadata.filters[].applies_to`: the action list after only/except, with owner (class, superclass or concern).                                                                                                                                                                 | The runtime filter chain already exposes the action set via ActionFilter duck-typing; publish it per filter.                                                                                                                                                                                                                                                                                                            | Filter matrix (B-16)                                          |
### Explorer-side components (woods-map)
| Component                                               | Responsibility                                                                                                                                                              | Notes                                                                                                                        |
|---------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| `Repository`                                            | One pinned generation per request over `PublishedIndex`/`IndexReader`; per-generation memoised caches (search index, neighbourhoods, rendered source, diagrams, ERD facts). | Keyed by `(number, token)`; drops caches when the pointer moves; exposes `freshness` for the status bar.                     |
| `SourceRenderer`                                        | rouge highlight + line table + span injection + concern block delimiting + original-line gutter.                                                                            | Spans are inserted by character offset after highlighting, splitting tokens where needed so markup stays valid.              |
| `Neighbourhood`                                         | Graph query (centre, depth, direction, type and `via` filters, package) → Cytoscape elements JSON with truncation metadata.                                                 | Uses `reverse_via` for inbound edges; marks hubs, cycles, cross-database and undeclared package edges from `graph_analysis`. |
| `LifecycleBuilder`                                      | Flow document (precomputed or assembled) → lanes; follows async edges into job/mailer flows; applies `FlagDetector`.                                                        | Depth budget; honest "unexpanded" markers for receiverless or dynamic calls.                                                 |
| `Diagrams::Erd`, `Diagrams::Flow`, `Diagrams::Sequence` | Mermaid text from model facts and flow documents.                                                                                                                           | Extend `Woods::RubyAnalyzer::MermaidRenderer`; chunking rules; identifier sanitising already exists there.                   |
| `Timeline`                                              | Commit table + unit set → vis-timeline groups/items; co-change pairs; snapshot diff overlay.                                                                                | Falls back to `recent_commits` when `git_commits.json` is absent (older indexes), with a visible "5 most recent only" note.  |
| `Auth`                                                  | Token → signed cookie exchange; wraps `Woods::MCP::BearerAuth` and `OriginGuard`; loopback rules.                                                                           | Same env var conventions as `woods-mcp-http`.                                                                                |
| `Standalone`                                            | `woods-map serve DIR`: minimal `Rails::Application` with the Engine mounted, Puma via rackup.                                                                          | Needs railties, importmap-rails and a Rack server in the environment; documents that it boots no host code.                  |
| `Guide`                                                 | Section 11.                                                                                                                                                                 |                                                                                                                              |
## 11 · The RubyLLM guide
RubyLLM 2.1 (released 8 October 2026; 2.1.1 on 11 October) has a native MCP client, so the Woods Index MCP server that agents already use can be attached to a chat without adapters. The guide is one agent, one tool allow-list, one streaming channel, and a set of page-aware actions. It is off by default and needs two things from the host: `ruby_llm` in the bundle with a provider configured, and `config.guide_enabled = true`.
*Wireframe*: Wireframe D1: the guide panel docked beside a unit page, with an "explain this" action running. (rendered in `design-study.html`)

1.  Tool calls render as cards from `before_tool_call` / `after_tool_result` callbacks, with duration; answer tokens stream in as they arrive.
2.  Unit identifiers in answers become links by matching against the generation's identifier set; unknown names are left plain, so the guide cannot invent a link.
3.  Every answer offers "pin" and "open as investigation", which hands the units to Trail.
### Wiring

    class WoodsMap::Guide < RubyLLM::Agent
      model { WoodsMap.config.guide_model }          # host chooses provider + model
      instructions <<~TXT
        You answer questions about one Rails application using only the Woods index
        tools. Cite units by exact identifier. Say when a flow step is unexpanded.
        Never claim runtime behaviour the index cannot prove.
      TXT
      mcp do
        server WoodsMap::IndexMcp,                   # RubyLLM::MCP subclass
               only: %w[woods_status search lookup structure dependencies dependents
                        trace_flow recent_changes graph_analysis pagerank
                        domain_clusters codebase_retrieve]
      end
    end

    class WoodsMap::IndexMcp < RubyLLM::MCP
      command 'bundle', 'exec', 'woods-mcp', WoodsMap.config.index_dir   # dev, stdio
      # or: url WoodsMap.config.mcp_url                                   # staging, woods-mcp-http
    end
#### Transport and tools

- Development: stdio to `woods-mcp` over the same index directory. Staging: Streamable HTTP to a deployed `woods-mcp-http` with its bearer token. Both expose exactly the tools agents use, so answers in the UI and answers in an editor agree.
- Allow-list excludes every operator, feedback, snapshot-write and Notion tool; the explorer never lets the guide trigger extraction.
- A later optimisation wraps the same handlers in-process as `RubyLLM::Tool` classes so the chat shares the request's pinned generation; not needed for v1.
- `ruby_llm-mcp` is not used: it pins RubyLLM 1.x and is superseded by the native client.
#### Streaming without Action Cable

- Chat POST returns a Turbo Frame with the message shell; the browser opens an SSE connection (`EventSource`) and hands it to `Turbo.connectStreamSource`, so the server streams Turbo Stream actions with no cable. Works identically in the Engine and in standalone mode.
- Server side: `ActionController::Live`; `chat.ask(question) { |chunk| }` appends content; `before_tool_call` and `after_tool_result` broadcast tool cards. Ordering is guaranteed by the single SSE stream.
- Cancel button calls `chat.cancel`; disconnects stop generation.
#### Context seeding

- Each page contributes a compact context block: generation, HEAD, the unit's identifier, type, path, summary metadata (not full source), and for Trail the board's pinned identifiers and notes. The guide reads full source through `lookup` only when it needs it.
- Selection-aware: a highlighted range in the code viewer or a selected set of graph nodes is passed as context.
- Personalised retrieval (Aider's idea): PageRank restricted to the identifiers in the question ranks which units to mention first.
#### "Explain this" actions

- **Explain this unit**: role, relationships, callbacks and side effects, who maintains it.
- **Explain this method** (from a selected range or outline entry): what it does, what calls it, what it writes or enqueues, using the method table slice as context.
- **Explain this passage**: narrates how data moves from params through filters and the action into templates, naming every flagged mismatch.
- **Explain lifecycle**: narrates a flow document step by step with the async boundaries called out.
- **Summarise blast radius**: transitive dependents grouped by type with risk notes (hubs, cycles, cross-database).
- **Plan a feature rooted here**: proposes attachment points, migrations, controller params, views and tests, each citing a unit; output is Markdown ready for an issue.
- **Why might this fail?** (jobs, mailers, actions): walks conditionals, missing retry/rescue, nil-prone calls visible in source, recent co-changes.
- Actions are prompt templates stored in the gem and overridable by the host (`config/woods_explorer/prompts/*.md`).
#### Persistence

- Default: ephemeral conversations kept in memory for the browser session and written as JSON under `<index>/explorer/chats/` (same file-store pattern as the session tracer), never in the host database.
- Optional: hosts that already run `ruby_llm:install` can set `config.guide_persistence = :active_record` to use `acts_as_chat` tables.
#### Safety and cost

- Off unless enabled; staging additionally requires the auth token. Index-only tools mean the model sees application source but never live data.
- Per-session token budget and a per-answer tool-call cap (default 12) with a visible counter; model and provider are the host's choice through RubyLLM configuration, including Ollama for fully local use.
- Answers are rendered from Markdown with links rewritten only to known identifiers; raw HTML is stripped.
- Prompts and chat logs are excluded from extraction (they live outside the payload) and from the Obsidian/Notion exporters.
## 12 · Roadmap
| Milestone     | Scope                                                                                                                                                                                                                                                                                | Repository     | Exit criterion                                                                                                                                     |
|---------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| M0 · Data     | W-1 reference spans, W-2 method table, W-3 commit table, W-4 job facts, W-5 model lifecycle entries, W-6 method targets, W-7 per-action facts, W-8 filter applicability, W-9 container attribution, W-10 facet diff, W-11 generation pin, W-12 impact task, W-13 inverted flow index | woods          | Published by full and incremental runs; incremental equivalence spec green; verified on testbed rails-8.0, 7.2 and 6.0                             |
| M1 · Reading  | Gem skeleton, Engine + standalone, self-served assets and import map, auth, Repository, search palette and full-text code search, unit pages for all types, two-lens code viewer with marginalia, outline, peek, confidence marks, reading trail, file view                          | woods-map | Both scenarios navigable by clicking only on a Rails 6.0 and an 8.0 host; works with JS disabled except peek and hover                             |
| M2 · Passage  | Filter matrix, data passage for actions and mailers, mismatch flags, callback ladder, passage export                                                                                                                                                                                 | woods-map | The unassigned-ivar flag reproduces on a seeded testbed bug                                                                                        |
| M3 · Diagrams | Lifecycle tab (controllers, jobs, mailers, model events) with swimlane, flowchart, sequence and C4 dynamic renderings; Schema tab and `/woods/erd`; Landscape page (L1, L2); Mermaid, Structurizr DSL and LikeC4 exports                                                             | woods-map | Flowchart and ERD match the flow document and model facts on the testbed; chunking verified on a 300-model fixture                                 |
| M4 · History  | History tab hunk cards, gutter heat, neighbourhood timeline, snapshot picker, unit diff across retained generations                                                                                                                                                                  | woods-map | Co-change query answers scenario 2 step 3 from the commit table                                                                                    |
| M4b · Impact  | Report object with Markdown, JSON and Mermaid renderers; `woods:impact` task and `change_impact` MCP tool; impact page with focus URLs; `?since=` highlighting across views; pre-change blast radius                                                                                 | both           | A PR in the testbed gets a Markdown impact comment from CI; the focus link opens the page with the changed template highlighted                    |
| M5 · Graph    | Neighbourhood endpoint, Cytoscape component, Graph tab, full-screen graph page, blast radius, butterfly layout                                                                                                                                                                       | woods-map | 300-node neighbourhood renders under 500 ms on the testbed; keyboard list equivalent                                                               |
| M6 · Trail    | LifecycleBuilder across async hops, lanes, flags, board state, export                                                                                                                                                                                                                | woods-map | Scenario 2 reproducible end to end from one URL                                                                                                    |
| M7 · Guide    | RubyLLM agent, MCP attachment, SSE streaming, seven actions, budgets                                                                                                                                                                                                                 | woods-map | All actions produce linked answers on the testbed with one provider; disabled by default verified; unavailable below Ruby 3.2 with a clear message |
| M8 · Staging  | Threat-model doc, CSP, rate limits, deployment guide beside `MCP_HTTP_TRANSPORT.md`                                                                                                                                                                                                  | both           | Non-loopback boot refuses without token; origin guard tests                                                                                        |
M1 and M2 are the comprehension core and ship first. M3, M4 and M5 can proceed in parallel after M1; M6 depends on M3 and M4; M7 depends on M1 only but is most useful after M2. The testbed is the validation host for every milestone, with a seeded "blog" scenario (Post, Comment, Tag, NotifySubscribersJob, MailingListMailer and templates, plus one deliberate unassigned instance variable in a mailer template) added to `apps/rails-8.0` and mirrored in 6.0 so both walkthroughs and the floor are real.
## 13 · Open questions
- **Floors (settled).** railties 6.0 and Ruby 3.0, the same as Woods, by serving assets from the engine instead of depending on importmap-rails or turbo-rails. The guide alone needs Ruby 3.2 and says so in the status bar when absent.
- **Editor deep links.** "Open in editor" needs the host checkout path and a URL scheme (`vscode://file`, `idea://open`, `txmt://`). Make both a per-browser setting; never guess paths from the index.
- **Streaming on old stacks.** `ActionController::Live` over SSE behind some proxies buffers; document the Puma and nginx settings, and fall back to polling Turbo Frames when the stream cannot open.
- **Testbed realism.** The rails-8.0 variant has users and microposts but no mailer-after-create chain. Add the blog scenario above before M1 so wireframes are tested against real extraction output.
- **Standalone rendering.** Booting a minimal Rails application for `woods-map serve` is the lowest-risk way to share views with the Engine. The alternative (plain Rack + ERB with the Engine as a thin wrapper) halves the dependency surface but duplicates view helpers. Decide before M1.
- **Reference span cost.** W-1 adds per-unit JSON size (roughly 40 to 120 bytes per reference). Measure on a 5 000-unit app; if large, publish spans as a sidecar per type directory rather than inside each unit.
- **Precompute flows by default?** Trail and the Lifecycle tab are faster when `precompute_flows` is on. It fails closed on any assembly error, which is why it is off. Consider a `precompute_flows: :best_effort` mode that records failures in `skipped_files.json` instead of aborting.
Sources: Woods source and docs at `lost-in-the/woods` main (361468d); gem floors from the RubyGems API on 15 October 2026 (importmap-rails 2.2.3 railties ≥ 6.0, turbo-rails 2.0.23 railties ≥ 7.1, stimulus-rails 1.3.4 railties ≥ 6.0), in particular `docs/INDEX_LAYOUT.md`, `docs/PUBLISHED_INDEX.md`, `docs/EXTRACTOR_REFERENCE.md`, `docs/MCP_SERVERS.md`, `docs/MCP_HTTP_TRANSPORT.md`, `docs/OBSIDIAN_INTEGRATION.md`, `lib/woods/mcp/server.rb`, `lib/woods/flow_assembler.rb`, `lib/woods/extractors/*`; npm and RubyGems registries, Mermaid, sigma.js and RubyLLM release notes, mission_control-jobs source, checked 14 October 2026.
