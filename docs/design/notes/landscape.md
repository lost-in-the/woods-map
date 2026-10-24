# Landscape

Scope: B-21, B-22 (by package, namespace or domain cluster), FR-6 exports, D-25.
Relates to #5 (M3) and #7 (M5). Boards: [B8-Landscape](../boards/B8-Landscape.html)
for Containers, Components and the group control, [B6-Overview](../boards/B6-Overview.html)
for Hotspots. The Domains tab has no board; this note covers it.

`/woods/landscape(/containers|components|hotspots|domains)` reads one pinned generation.
`Landscape` joins the primary bar, between Units and Graph.

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
| Structurizr DSL | `/woods/landscape.dsl` | workspace, one container view, `Database` cylinder |
| LikeC4 | `/woods/landscape.c4` | specification, model, `containers of app` view |
| Mermaid | `/woods/landscape/components.mmd?group=package\|namespace\|cluster` | the Components flowchart |
| Mermaid | `/woods/landscape/quadrant.mmd` | the Hotspots quadrant |
| Mermaid | `/woods/landscape/sankey.mmd` | the Hotspots forward flow |

A diagram the generation cannot draw answers 422 with the reason: no packages, no
clusters, no commit counts, or no forward edge.

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

**Not built**
- The LOC treemap. Woods publishes no size per unit, so a package's size can't be
  summed without reading host files. That data is filed as
  [woods#810](https://github.com/lost-in-the/woods/issues/810).

## Domains

The list of `graph_analysis.json` `domain_clusters` (woods#799): hub, size, types and
entry points. Each row opens `/woods/graph?group=clusters`. The graph's clusters layout
draws each cluster as a compound box around its members, and unclustered units share
one block. Clusters are identifier-level, as Woods publishes them.

## Not built

- Context (L1) and Status as separate tabs; Context sits inside Containers.
- The treemap (woods#810).
- The board's *period* control on Hotspots. Commit counts are the generation's own
  git enrichment, with no window to choose.
