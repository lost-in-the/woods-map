# Landscape

Scope: B-21 and B-22 (by domain cluster), FR-6 exports, D-25. Relates to #5
(M3) and #7 (M5). Boards: [B8-Landscape](../boards/B8-Landscape.html) for
Containers, [B6-Overview](../boards/B6-Overview.html) for Hotspots. The
Domains tab has no board; this note covers it.

`/woods/landscape(/containers|hotspots|domains)` reads one pinned generation.
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

## Hotspots (B6-Overview)

**Built**
- Tiles for hubs, bridges, cycles, undeclared package edges, orphans and uncovered
  hubs. A hub is uncovered when no `test_coverage` edge reaches it.
- A churn × dependents ranking from node commit counts. When the generation has no
  git enrichment, this is an empty state.
- The layer coupling matrix: typed edges, leaving out test, route-exercise,
  documentation and migration bookkeeping.
- The structural-risk table.

**Not built**
- The quadrant chart.
- The forward-flow sankey.
- The LOC treemap. LOC per package is not published.

## Domains

The list of `graph_analysis.json` `domain_clusters` (woods#799): hub, size, types and
entry points. Each row opens `/woods/graph?group=clusters`. The graph's clusters layout
draws each cluster as a compound box around its members, and unclustered units share
one block. Clusters are identifier-level, as Woods publishes them.

## Not built

- Context (L1) and Status as separate tabs; Context sits inside Containers.
- Components (L3) by Packwerk package.
- The board's `group` control.
- The Share menu.
