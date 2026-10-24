# Landscape

Scope: B-21, B-22 (by package, namespace or domain cluster), FR-6 exports, D-25.
Relates to #5 (M3) and #7 (M5). Boards: [B8-Landscape](../boards/B8-Landscape.html)
for Containers, Components and the group control, [B6-Overview](../boards/B6-Overview.html)
for Hotspots. B8-Landscape draws Context only as the first rung of the ladder; the
Context tab and the Domains tab have no board of their own, so this note covers them.

`/woods/landscape(/context|containers|components|hotspots|domains)` reads one pinned
generation; without a tab it opens Containers, as on the board.
`Landscape` joins the primary bar, between Units and Graph.

## Context (C4 level 1)

The board's ladder names L1 as "people, 1 system, external systems". The tab draws
exactly that, in the Containers tab's three columns:

- **People** come only from the host's `config.landscape_actors` (`name`, `description`,
  `uses`). The index does not know who uses the system. With none declared, the column
  says how to declare them.
- **The software system** is one box: the host's `config.system_name`, Rails from the
  BehavioralProfile unit, the number of application units, and a link to Containers.
- **External systems** are the ones Containers already draws: mail delivery and object
  storage from the BehavioralProfile unit, and each declared `external_consumer` unit.

Each person is linked to the system with their `uses` text, and the system to mail
delivery and object storage. A declared consumer is linked to the system as *reads
shared tables*. Each relationship names its source. The Pele diagram draws people as
stadiums, the system as a box and externals as subroutines.

**Limits, named on the page.**
- People are host configuration.
- External services come only from Woods (woods#814), from two sources:
  - the Gemfile unit's `external_services`, the catalogued client gems declared for
    runtime;
  - the `service_call` edges from units that call a client constant (`Stripe::Charge`,
    `Aws::S3::Client`).

  Each service is an external box on Context and Containers, with its category and
  gems, or *no client gem in the Gemfile*, and the number of units calling it. The web
  and job processes whose units call a service get a relationship to it on Containers.
  Calls from shared code are counted on the box, not drawn from a process. The map
  keeps no gem-to-service table of its own. Uncatalogued gems and generic HTTP clients
  (Faraday, `Net::HTTP`) are not drawn. On a generation without this data, the page
  counts the Gemfile's runtime gems and names the limit.
- Inbound callers other than declared table consumers, such as webhooks and API
  clients, aren't recorded.

## Containers (C4 level 2)

**Sources**
- Membership comes from each graph node's `container` (W-9, woods#759).
- Technologies come from the BehavioralProfile configuration unit:
  - `database.adapter` for the primary database;
  - `background_processing.adapter` for the job runner;
  - `caching.store` for the cache;
  - `email.delivery_method` for mail delivery;
  - `frameworks_active.active_storage` for object storage.
- `external_consumer` units become external systems, and engines are listed.
- People are not in the index. Hosts declare them as `config.landscape_actors`
  (`[{ name:, description:, uses: }]`). The application's name is `config.system_name`.

**Relationships**
- Edges from a process's units (web, jobs) to another container's are counted by
  mechanism. "enqueues" means an async mechanism into the job runner; "reads, writes"
  means Active Record into a database.
- Edges that leave a database are not drawn. The process that runs a model's callback
  is not in the index.
- Cache, mail delivery and uploads rows come from configuration, and are marked so.

**Without W-9.** A generation with no `container` on any node shows a banner and no
boxes. Hotspots and Domains still read.

## Exports (D-25)

The container diagram is drawn by Pele from Mermaid text built in Ruby
(`LandscapeExport#mermaid`). The same model also produces Structurizr DSL and LikeC4.
All three are plain text at stable URLs, with an `X-Woods-Generation` header and a file
name in `Content-Disposition`. A generation without W-9 answers 422.

| Format | URL | Content |
|---|---|---|
| Mermaid | `/woods/landscape.mmd` | flowchart, the system as a subgraph |
| Structurizr DSL | `/woods/landscape.dsl` | workspace with the host's people; a `systemContext` view and a container view, `Database` cylinder |
| LikeC4 | `/woods/landscape.c4` | specification, model with the host's people, `context` and `containers of app` views |
| Mermaid | `/woods/landscape/context.mmd` | the Context flowchart |
| Mermaid | `/woods/landscape/components.mmd?group=package\|namespace\|cluster` | the Components flowchart |
| Mermaid | `/woods/landscape/quadrant.mmd` | the Hotspots quadrant |
| Mermaid | `/woods/landscape/sankey.mmd` | the Hotspots forward flow |
| Mermaid | `/woods/landscape/treemap.mmd` | the Hotspots treemap |

A diagram the generation cannot draw answers 422 with the reason: no packages, no
clusters, no commit counts, no source sizes, or no forward edge.

**Share menu.** Every Landscape tab has the Share menu: the token-free focus URL (tab and
`group` included) and the tab's text exports as plain links, so the menu works without a
script. With a script it also copies each diagram's Mermaid, as on the unit pages.

## Components (C4 level 3)

The board's `group` control picks one of three published groupings:

- **package**: the `package` Woods writes on each graph node from `package.yml`
  (Packwerk or pks, Woods #280). It is the default when any unit has one. Each box names
  the packages its `package.yml` declares, from the package unit's `package_dependency`
  edges. A relationship that `graph_analysis.json` lists in `undeclared_package_edges`
  is marked *undeclared*.
- **namespace**: the top-level segment of each node's `namespace`. Units with none
  share *(top level)*. This is the default without packages.
- **domain cluster**: `graph_analysis.json` `domain_clusters` (woods#799). Units in no
  cluster share *(no cluster)*.

Members are application units: a relative source file and a type that is code. Routes,
migrations, configuration, framework sources, engines, packages and test mappings are
left out. Relationships count published edges between members of two groups, leaving
out test coverage, route exercise, documentation, migration and package-declaration
edges.

**Limits.** A generation with no packages, asked for packages, says so and links
the other two groupings. The same applies to clusters before woods#799. The map never
infers a package from a directory or a cluster from names. The flowchart stops at 40
components (R-4), and the tables still list every one.

## Hotspots (B6-Overview)

**Built**
- Tiles for hubs, bridges, cycles, undeclared package edges, orphans and uncovered
  hubs. A hub is uncovered when no `test_coverage` edge reaches it.
- The churn × dependents **quadrant** (Pele `quadrantChart`) above the ranked list of
  the same 18 units. x is commits against the most changed unit; y is dependents on a
  log scale against the most depended upon. Points stay inside 0.02 to 0.98, and
  names keep only characters the grammar reads (`::` becomes `.`). Without git
  enrichment this is an empty state.
- The layer coupling matrix: typed edges, leaving out test, route-exercise,
  documentation and migration bookkeeping.
- The **forward flow** (Pele `sankey`): the matrix's edges from a layer to a later one
  (controllers, views, components, jobs, mailers, models), so the flow has no cycle.
  Edges that run back up the layers stay in the matrix.
- The structural-risk table.

- **Where the code is** (Pele `treemap`): lines of code by package, then by unit type.
  With Packwerk packages it reads `graph_analysis.json` `package_sizes` (woods#810).
  Without packages the application is one block, summed over the graph nodes' `loc`
  with each distinct file once, the way Woods totals a package. A table under the
  diagram has the same figures. A generation without source sizes shows an empty
  state that links woods#810.
- The board's other treemap sizes, `?size=units` and `?size=pagerank`, use the same
  blocks. They count the application's units (nodes with a container, W-9, and a
  source file) or sum their PageRank × 1000. `treemap.mmd` takes the same `size`.

## Domains

The list of `graph_analysis.json` `domain_clusters` (woods#799): hub, size, types and
entry points. Each row opens `/woods/graph?group=clusters`. The graph's clusters layout
draws each cluster as a compound box around its members, and unclustered units share
one block. Clusters are identifier-level, as Woods publishes them.

A Pele **mindmap** sits above the list. The system is at the root, each cluster on the
first ring, and the cluster's members on the second, hub first. At most 8 members are
drawn per cluster, then a count of the rest. The mindmap stops at 30 clusters (R-4).
The text is at `/woods/landscape/mindmap.mmd`.

## Status

The Status tab lists each published fact the Landscape reads, with:
- whether this generation publishes it;
- what it holds here;
- the Woods work behind it (W-9, woods#799, woods#810, woods#814, Woods #280, git
  enrichment);
- what the tabs draw from it.

The tab's count is how many of the nine facts are present. The index's own state,
freshness and generations stay on `/woods`.

## Not built

- Inbound integrations (webhooks, API clients) and services outside Woods' catalogue.
- The board's *period* control on Hotspots. Commit counts are the generation's own
  git enrichment, with no window to choose.
