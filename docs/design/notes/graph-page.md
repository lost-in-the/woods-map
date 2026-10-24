# Full-screen graph

Scope: FR-5, A-2 to A-6 and E-9 tinting. Relates to #7.
Layouts are decided in #63. The flow overlay (A-4) and the timeline (A-6) are on the
Graph tab and on this page alike.

No board designs this page; B6-Graph designs only the Graph tab. The page reuses
that tab's explorer unchanged:

- the filter rail;
- the Cytoscape canvas, with the Pele flowchart behind *flowchart*;
- the list equivalent.

The page itself adds:

- the canvas over the height of the viewport;
- the centre's title block with *Open unit*;
- a *blast radius* control.

`Graph` joins Units and Impact in the primary bar.

## Routes

`GET /woods/graph?centre=&type=&depth=&direction=&types[]=&via[]=&blast=1`
takes identifiers, a unit type and filter values only.

- Without a centre, the page lists the first 24 hubs from `graph_analysis.json`. Each one opens the page centred on it.
- An unknown centre names the miss.
- Clicking a node, or Enter on the canvas, re-centres the page. The identifier goes into the query string as a component.
- The Graph tab links here as *full-screen graph*, keeping depth and direction.

## Blast radius

`blast=1` runs `WoodsMap::BlastRadius`, the impact page's pre-change model (E-9). It
propagates over the reverse edges of the same generation, from the centre, to the
explorer's depth. Units it reaches are drawn with a coloured border:

| Distance | Border |
|---|---|
| reached directly | `--hot` |
| reached transitively | `--mod` |

- The header counts how many reached units are drawn.
- The list's notes say "a change here reaches it directly" or "in n hops".
- The status line announces the same.
- The impact page stays the full report; the rail links to it.

## Position cache (A-3)

Both layouts are deterministic, so revisiting a query never reshuffles. Units can be
dragged on both the tab and the page. A drag is kept in `localStorage` under a key
made of:

- the generation number;
- the unit type and identifier;
- the depth and direction;
- the type and mechanism filters;
- the layout.

At most 24 keys are kept; the oldest is dropped. A new generation starts from the
computed layout. *Reset positions* forgets the current key. Every storage access
is in `try`/`catch`; without storage the page draws the same and keeps nothing.

## Domain clusters

Domain clusters come from a Woods that publishes them (woods#799).
With them, `group=clusters` and a *clusters* layout box each cluster's drawn members
(see [landscape.md](landscape.md)). Without them, the rail links woods#799 and the page
draws none. It never derives clusters from namespaces itself.

## Flow overlay (A-4)

The rail's *flows* group lists the precomputed flows that expanded a step of the
centre. It reads `PublishedIndex#flow_entry_points` over `flows/by_unit.json` (W-13,
[woods#805](https://github.com/lost-in-the/woods/pull/805)). Each entry links the
same view with `?flow=`, and the filter form, depth and direction links keep it.

`GraphFlow` maps the selected document's steps onto what the explorer draws:

- A controller step (`PostsController#create`) is drawn as its controller's unit.
  Every other step is drawn as its own typed unit.
- A move from one step's unit to the next is matched to a drawn edge between them,
  in either direction. Two steps on the same unit need no edge.
- The canvas outlines the matched units and edges in the link colour. *Play the flow*
  lights them one step at a time, and the status line names each step. With reduced
  motion, the whole path is lit at once and named in one line.
- The side list, *Flow ⟨entry⟩*, has every step in document order. It shows the
  operation count, whether the canvas draws the step's unit at this depth, and the edge
  that reached it. A step with no graph edge from the step before is marked there.
  Nothing is drawn that the graph does not have.

The rail says why no flow is listed: none expands this unit (each flow stops at
its own depth), the generation publishes none (`precompute_flows` is off), the
artifacts are unreadable, or this Woods has no W-13 readers. Membership is bounded
flow evidence. It does not show that a request takes the path.

## Timeline (A-6)

`GraphTimeline` lists the commits in the generation's commit table (W-3) that touched
a drawn unit's `file_path` or `source_paths`, newest first. It keeps at most 80 and
says how many it left out. With a script, two range inputs pick a window of commits,
oldest first, and the units its commits touched are filled with `--mod`. A *tint*
button on each row narrows the window to that commit. Without a script, the commit
list names the drawn units each commit touched. A unit's inlined concerns count
through the concern's own node only. Without a commit table, the section says why.

## Not built

- The timeline as vis-timeline. As on `/woods/history`, no unmodified ESM build fits
  the no-build rule, so the window is two native range inputs.
- Operations inside a flow step, drawn on the canvas. The side list counts them; the
  unit's own pages read them.

## Validation

| Check | Result |
|---|---|
| `bin/rake spec` with the Pele render spec and `WOODS_MAP_BROWSER` | green |
| `bin/rubocop` | no offenses |
| axe-core 4.14 on woods-testbed rails-8.0 after `woods:extract` | no violations at 1440, 960, 640 and 390, and in the light theme |

The axe pages were the hub list, an unknown centre, `Post` at depth 2 with and
without the tint, and the radial layout. The 300-unit timing is reported in the
pull request; on the shared sandbox it is over the 500 ms target.
