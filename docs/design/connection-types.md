# Connection types in the Woods index

A renderer-agnostic inventory of every kind of connection the index records,
so that chart choice (Mermaid, PlantUML, Graphviz, Cytoscape, the map's own
SVG) is made per connection type rather than per syntax. Read this before
[`mermaid-diagram-types.md`](mermaid-diagram-types.md), which is one
renderer's view of the same inventory.

Sources: the `via` labels every extractor writes on `dependencies` edges
(`lib/woods/extractors/*`, 60 distinct labels plus the association macros),
unit metadata, flow documents, the snapshot store and the graph analysis, read
on 16 October 2026 at woods `main`.

## How to read the inventory

Each connection is classified by **topology**, which decides the drawing far
more than the Rails concept does:

| Topology | Shape | Natural drawings |
|---|---|---|
| **A · Directed dependency** | unit → unit, labelled by mechanism (`via`), may carry attributes (through, cross-database, cardinality) | Node-link graph (interactive), flowchart or class diagram (static), dot graph (large) |
| **B · Containment** | tree: a parent holds children | Compound nodes, nested subgraphs, mind map, tree view, treemap |
| **C · Ordered sequence** | steps in execution order, sometimes nested or branching | Sequence diagram, numbered list, activity diagram with partitions, flowchart |
| **D · State transition** | states with labelled transitions | State diagram |
| **E · Temporal** | events on a time axis | Timeline, interactive strip, XY chart |
| **F · Quantitative** | a measure per unit or per edge | Quadrant, bar or XY, sankey, treemap, radar |
| **G · Set membership** | units grouped by a property | Tints on a graph, lists, Venn only when two sets overlap |
| **H · Derived path** | a chain of A-edges with a distance | Directed flowchart, path list |
| **I · Data passage** | a bipartite chain across layers (params → action → variables → templates) | Lanes, flowchart LR, data-flow diagram |

A connection often belongs to two topologies (a callback is an ordered step
and a dependency). The inventory lists it once under the topology a reader
asks about first.

## A · Directed dependency edges (unit → unit)

Grouped by semantic family. "Interactive" is always the Cytoscape neighbourhood with the edge coloured by `via`; the "Static" column names the best text-rendered form.

### A1 · Data model

| Connection (`via`) | From → to | Attributes | Reader asks | Static form | Notes |
|---|---|---|---|---|---|
| `belongs_to`, `has_one`, `has_many`, `has_and_belongs_to_many` | model → model | `through`, `through_db`, `polymorphic`, `foreign_key`, `inverse_of`, `from_db`/`to_db`, `disable_joins` | How are these records related, with what cardinality and key? | Entity relationship (crow's foot) for cardinality; class diagram for the Ruby view | Polymorphic targets are several candidates; draw dashed to each. Cross-database edges are a risk flag. |
| `foreign_key` | model or table → table | constraint name, columns | What does the database itself enforce? | Entity relationship | Distinct from the association: a FK without an association, or an association without a FK, is a finding. |
| `table`, `table_name`, `reads_table`, `writes_table`, `migrates` | model, database view, migration, job → table | database | Who reads or writes this table, and which migration shaped it? | Flowchart LR grouped by database; a table-centred neighbourhood | `unmodelled_tables` in graph analysis are tables with no model edge. |
| `polymorphic_interface` | model → interface name | | Which models implement this polymorphic interface? | Class diagram with an interface node | |
| `dependent` | model → model | `:destroy`, `:nullify`, ... | What cascades when this is deleted? | ER with the option as the edge label; a deletion-cascade tree | Worth its own "delete radius" view; a cascade is a blast radius. |
| `data_dependency` | unit → unit | | Which data does this computation depend on? | Flowchart | From the dataflow analyzer; conservative. |

### A2 · Code structure

| Connection (`via`) | From → to | Reader asks | Static form | Notes |
|---|---|---|---|---|
| `inheritance` | class → superclass | What does this inherit, including STI? | Class diagram (`<|--`) | STI children of a base model form a tree (topology B as well). |
| `include`, `extend` | class → concern or module | Where did this method or callback come from? | Class diagram with `<<concern>>`; the Effective-class lens in the code viewer | The inlined-concern view answers it better than any picture. |
| `code_reference`, `type_reference`, `method_call`, `call`, `delegation`, `definition_of`, `dependency` | unit → unit (or method) | What does this code use? | Flowchart for a slice; dot graph for a package | `code_reference` is the noisiest family; default it off in overviews, on in a unit's own neighbourhood. |
| `decoration` | decorator → model | What presents this model? | Class diagram | |
| `helper_method`, `helper_call` | controller or view → helper | Which helpers does this view rely on? | Flowchart LR (view → helpers) | Part of the data passage (topology I). |
| `configuration`, `reads_config`, `behavioral_profile` | unit → config unit | Which settings change this unit's behaviour? | List; a config-centred neighbourhood | Few readers want a picture; a list with the resolved values wins. |

### A3 · Request and navigation

| Connection (`via`) | From → to | Reader asks | Static form | Notes |
|---|---|---|---|---|
| `route_dispatch`, `engine_route`, `draw`, `drawn_in`, `mount` | route or route file → controller action, engine | Which code handles this path? | Flowchart LR route → action; a routes table | Routes are also a tree (topology B) by namespace and scope. |
| `render`, `view_render`, `view_source`, `slot` | controller or view → template, partial, component | Which templates and partials make this page? | Flowchart LR as a render tree | A render tree is strictly containment-like (B); draw it nested when the depth is more than two. |
| `link_to`, `redirect_to`, `form_action`, `url_helper`, `html_attribute` | view or controller → controller action | Where can the user go from here, and where does a form post? | Flowchart LR between pages; the "navigation map" of the app | The only user-facing graph in the index; a candidate for a site-map view. |
| `exercises_route`, `action_source` | test or action → route | Which tests exercise this route? | List | Coverage view, topology G. |

### A4 · Asynchronous and execution

| Connection (`via`) | From → to | Reader asks | Static form | Notes |
|---|---|---|---|---|
| `job_enqueue` | model, controller, service, job → job | What runs later because of this, and with what queue? | Sequence diagram with `-)` async arrows; dashed edge in a flowchart | Carries `perform_later`, `perform_async`, `perform_in`; the enqueue method matters to the reader. |
| `scheduled` | scheduler config → job | What runs on a schedule? | Table (cron, job, queue); timeline if periods matter | |
| `state_machine`, `state_machine_callback` | model → state machine, transition → callback target | What happens on a transition? | State diagram with the side effect on the transition label | Topology D. |
| `published_by`, `subscribed_by` | event → publisher, subscriber | Who emits and who listens? | Event modeling or a bipartite flowchart (publishers → event → subscribers) | Only for apps with event units. |
| `external_call` | unit → external consumer | What leaves the system? | C4 context (L1) as a flowchart in C4 notation | Lands on the Landscape page. |
| `task_invoke`, `task_dependency` | rake task → task | What runs when I run this task? | Flowchart TD (dependency DAG) | Small graphs; a list usually suffices. |
| `special` | runtime-specific edge | | Treat as `code_reference` | Documented in the extractor that emits it. |

### A5 · Cross-cutting

| Connection (`via`) | From → to | Reader asks | Static form | Notes |
|---|---|---|---|---|
| `validation` | model → validator class | What custom validation runs? | Class diagram; the callback ladder (topology C) | |
| `serialization` | serializer → model | What shape leaves the API? | Class diagram (serializer → model) | |
| `authorization`, `policy_evaluation` | controller or view → policy | Who may do this? | Flowchart LR action → policy | Pundit-style. |
| `package_dependency` | package → package, including undeclared | Which boundaries are crossed? | Flowchart or dot graph of packages; sankey of edge counts between packages | Undeclared edges are a risk flag. |
| `test_coverage`, `factory_for`, `factory_parent`, `factory_association`, `behaves_like` | test or factory → unit | What covers this, and what builds its fixtures? | Lists; a coverage tint on the graph | Topology G. |
| `fragment_spread`, `root_field` | GraphQL operation → fragment, schema → root field | How is this query composed? | Flowchart TD of operation → fragments → types | GraphQL only. |
| `all` | wildcard marker | | Not drawn | Internal. |

## B · Containment (trees)

| Connection | Parent → children | Source | Reader asks | Best form |
|---|---|---|---|---|
| Namespace → units | `Admin::` → `Admin::PostsController` ... | `namespace` on units | What lives where? | Compound nodes in the graph; mind map; tree panel |
| Package → units, package → package | Packwerk packages | `package` units, `metadata.package` | Which package owns this, and what does the package expose? | Compound nodes; treemap by size |
| File → units | one file, several units (class plus file-profile units) | `file_map` | What does this file define? | Tree view; file page |
| Engine → routes, units | mounted engines | `engine` units, `mount` edges | What does this engine add? | Nested subgraph on the Landscape |
| Container → units (W-9) | web, job runner, mailer delivery, databases | `metadata.container` | Which process runs this? | C4 container notation (flowchart with subgraphs) |
| Database → tables → columns | multi-database apps | model `database`, `database_table` units, `columns` | Where does this data live? | Entity relationship per database; ER chunk per namespace |
| Model → inlined concerns → methods | | `inlined_concerns`, method table (W-2) | Which concern supplied this method? | Outline panel; class diagram with concern stereotypes |
| Flow → steps → operations | | flow documents | What is inside this step? | Nested sequence or numbered list |
| STI base → subclasses | | `is_sti_base`, `parent_class` | What specialises this model? | Class diagram tree |
| Routes → scopes → resources → actions | | route units | How is the URL space organised? | Tree view; routes table |

## C · Ordered sequences

| Connection | Order source | Branching or nesting | Reader asks | Best form |
|---|---|---|---|---|
| Callback chain per event | resolved runtime chain (`callbacks` with kind, filter, conditions, side effects) | conditions per step | What runs, in what order, when a record is created? | Callback ladder (numbered table); sequence diagram with self-messages |
| Filter chain per action | resolved `filters` with only/except (W-8) | per-action applicability | Which filters run before this action? | Filter matrix (filters × actions) |
| Flow operations | flow documents: `call`, `async`, `transaction` (nested), `conditional` (nested), `response`, `dynamic_dispatch` | yes: conditionals, transactions, async hops | What happens when this request runs? | Sequence diagram first; flowchart for branches; lanes by container; activity diagram with partitions in PlantUML |
| Middleware stack | `middleware` units in stack order | none | What touches every request before the router? | Numbered list; a vertical flowchart |
| Migration history | `migration` units by version | none | How did the schema get here? | Timeline (topology E) or list |
| Session trace steps (runtime) | session tracer timeline with unit refs and side effects | none | What did this request actually do? | Sequence diagram with real timings |
| Rake task invocation order | `task_dependency` | DAG | What runs first? | Flowchart TD |

## D · State transitions

| Connection | Source | Reader asks | Best form |
|---|---|---|---|
| State → state on event, with guards and callbacks | `state_machine` units, `state_machine_callback` edges | What moves this record between states and what fires on the way? | State diagram; composite states for nested machines |

## E · Temporal

| Connection | Source | Reader asks | Best form |
|---|---|---|---|
| Commit → files → units | `metadata.git.recent_commits`, commit table (W-3), `file_map` | Who changed this and when? | Interactive timeline strip (vis-timeline); XY chart export; hunk cards in the code viewer |
| Co-change: commit touching two units | commit table | Which units move together? | Pairs listed, or connected marks on the timeline |
| Generation → generation | snapshot store (sha, date, counts, facet hashes) | What changed between extractions? | Timeline; impact report |
| Change frequency per unit | `change_frequency`, commit counts | Where is the churn? | Heat tint on graph nodes and the code gutter; quadrant (topology F) |
| Branch structure | commit table, manifest branch | Which branch is this from? | Git graph export (illustrative only; HEAD-reachable history) |

## F · Quantitative

| Measure | Source | Reader asks | Best form |
|---|---|---|---|
| PageRank, dependent count | graph | What is structurally central? | Node size in the graph; ranked list |
| Churn versus dependents | commit counts × dependents | What needs careful review? | Quadrant |
| Edge volume between layers or packages | edges grouped by source type → target type | Where does coupling concentrate? | Sankey |
| Units by type, by package, by LOC | manifest, `loc`, packages | Where is the code? | Treemap (size); pie (status page only) |
| Unit health measures | LOC, callbacks, associations, dependents, churn, tests | How does this unit compare? | Radar (normalised 0 to 100) |
| Commits per period | commit table | Is this area active? | XY chart |
| Impact distance | impact report `distance` per affected unit | How far does a change reach? | Graph tint by distance; counts per distance |

## G · Set membership

| Set | Source | Reader asks | Best form |
|---|---|---|---|
| Domain clusters | `domain_clusters` | Which units form a domain? | Compound nodes or tints; mind map |
| Hubs, bridges, cycles, orphans, dead ends | `graph_analysis` | Where is structural risk? | Badges on nodes; lists with reasons |
| Blast radius of a change or unit | impact report | What is affected? | Tints on the graph (changed, direct, transitive) |
| Test-covered versus uncovered | `test_coverage` edges | What lacks a safety net? | Tint; list |
| Investigation pinboard | Trail board state | What am I looking at? | List; graph of pinned |
| Overlap of two sets | any two above | What is in both? | A list. A Venn only when exactly two or three sets and the overlap count is the point |

## H · Derived paths

| Path | Source | Reader asks | Best form |
|---|---|---|---|
| Why affected: changed unit → ... → focus | impact report `paths` | Through what mechanism does the change reach this? | Flowchart LR with `via` labels; a breadcrumb list |
| Flows through a unit | inverted flow index (W-13) | Which entry points run this? | List of routes and jobs; lanes with the unit highlighted |
| Delete cascade | `dependent` edges transitively | What disappears with this record? | Tree (topology B) |
| Reachability from a route | route → action → flow → async → mailer | What can a request ultimately trigger? | Sequence or lanes |

## I · Data passage

| Link | Source | Reader asks | Best form |
|---|---|---|---|
| params → permitted keys → model attributes | W-7 `params`, model `columns` | What input reaches the database? | Flowchart LR; flags for unknown attributes |
| action or filter → instance variables assigned | W-7 `assigns` | Where is `@post` set? | Passage lanes; marginalia in the code viewer |
| template → instance variables and helpers read | view `instance_variables`, `helpers_called` | What does this template need? | Passage lanes; mismatch flags |
| template → partials with locals | `partials_rendered`, W-7 `renders` locals | How is the page composed, and what is passed down? | Render tree (B) with locals on edges |
| mailer action → templates | mailer `templates`, `layout` | What does this email render? | Passage lanes |
| action → response formats → serializers | `responds_to`, `serialization` edges | What shape goes out per format? | Flowchart LR |

## Renderer fit by topology

| Topology | Cytoscape (interactive) | Mermaid | PlantUML | Graphviz (dot) | Map's own SVG or HTML |
|---|---|---|---|---|---|
| A · Dependency graph, neighbourhood up to about 300 nodes | **Best**: pan, filter, tint, click | Flowchart for slices under about 150 nodes | Class or component diagram, dot layout under the hood; good to a few hundred nodes server-side | **Best static** for large graphs; `viz.js` WASM in the browser or `dot` server-side | No |
| A1 · Schema cardinality | No | ER diagram (crow's foot, PK/FK/UK) | ER via `entity` and IE notation; comparable | Possible with record shapes; clumsy | No |
| B · Containment | Compound nodes | Subgraphs, mind map, tree view, treemap | Packages, namespaces, WBS, mind map | Clusters | Tree panel (HTML) |
| C · Sequences | No | Sequence diagram (activation, alt/opt/loop/par, notes, autonumber); swimlanes beta | Sequence diagram with the same constructs plus `ref`, `return`, groups; **activity diagram with partitions** is mature where Mermaid swimlanes is beta | No | Lanes (HTML), callback ladder, filter matrix |
| D · States | No | State diagram v2 | State diagram, with composite states and notes | Possible | No |
| E · Temporal | vis-timeline (interactive) | Timeline, XY chart, git graph | Gantt and timing diagrams only; no git graph | No | Hunk cards, gutter heat |
| F · Quantitative | Node size and colour | Quadrant, sankey, XY, treemap, radar, pie | **None**: PlantUML draws no charts | No | Stat tiles |
| G · Sets | Tints and badges | Tints via classDef; Venn | Styling via skinparam; no Venn | Styling | Lists |
| H · Paths | Highlighted path | Flowchart LR | Activity or component diagram | dot | Breadcrumb list |
| I · Data passage | No | Flowchart LR | Activity diagram with partitions, or object diagram | No | **Best**: lanes with flags |

## Is PlantUML better suited?

**Where PlantUML wins.** UML fidelity: class diagrams with packages, visibility, stereotypes and hidden links for layout control; sequence diagrams with `ref`, `return` and groups; a mature activity diagram with partitions (the swimlane that Mermaid only added as beta in 11.16); object and component diagrams; C4 through C4-PlantUML, which is the de facto C4 tooling; a preprocessor (`!include`, `!define`) for shared styling; server-side rendering to SVG with hyperlinks on every element, which means a cacheable, non-JavaScript picture per generation that still links into the map.

**Where PlantUML loses for this gem.** It is a Java program. The host would need a JRE, a PlantUML jar and either Graphviz or the pure-Java `smetana` layout, or a network call to a PlantUML or Kroki server, which the map's "no network at render time" and "no runtime dependency beyond Ruby" rules forbid by default; the browser build (`@plantuml/core`, about 7.7 MB plus a classic `viz-global.js` script) is far outside the vendored-JS budget. It draws no quantitative charts at all (topology F). GitHub, GitLab and most chat tools render Mermaid in Markdown and do not render PlantUML, so every PlantUML export is a picture, not text a reviewer can edit. Dark mode means a second server-side render per diagram. The map's interactive needs (topology A at scale, E, G) are not served by either text syntax; they are Cytoscape and vis-timeline either way.

**Assessment.** For the connections that matter most here, Mermaid covers the same ground as PlantUML (sequence, ER, class, state) at the cost of layout finesse, and covers ground PlantUML does not (charts, git graph, timeline, treemap, sankey) with no runtime cost beyond vendored JavaScript. PlantUML's genuine advantages, dot-quality layout for large class or package diagrams and a mature partitioned activity diagram, are also available more cheaply: Graphviz through `viz.js` for the first, and the map's own HTML lanes for the second.

**Recommendation.** Keep Mermaid as the default text renderer and Cytoscape, vis-timeline and the map's own HTML and SVG for the interactive and lane views. Make the renderer a backend behind one intermediate model per topology (a graph model for A, B, G and H; a sequence model for C; a state model for D; a series model for E and F; a passage model for I), so that a PlantUML backend, a DOT backend or a Structurizr export is an adapter and not a rewrite. Offer PlantUML and DOT as optional backends for teams that already run a Kroki or PlantUML server or have `dot` installed, configured explicitly and off by default. This is a decision for the log (proposed D-10) and changes the renderer constraint in `mermaid-diagram-types.md` from "one Ruby renderer per Mermaid type" to "one model per topology, one adapter per syntax".
