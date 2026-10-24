# Full-screen graph

Scope: FR-5, A-2, A-3, A-5 and E-9 tinting. Relates to #7.
Layouts are decided in #63. Domain clusters wait on woods#799.
The flow overlay (A-4) and the timeline (A-6) remain separate.

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

## Not built

**Domain clusters** need a generation from a Woods that publishes them (woods#799).
With them, `group=clusters` and a *clusters* layout box each cluster's drawn members
(see [landscape.md](landscape.md)). Without them, the rail links woods#799 and the page
draws none. It never derives clusters from namespaces itself.

**Flow overlay (A-4) and timeline (A-6).** Both need the flow index (W-13) and the
History work (M4). They stay on #7.

## Validation

| Check | Result |
|---|---|
| `bin/rake spec` with the Pele render spec and `WOODS_MAP_BROWSER` | green |
| `bin/rubocop` | no offenses |
| axe-core 4.14 on woods-testbed rails-8.0 after `woods:extract` | no violations at 1440, 960, 640 and 390, and in the light theme |

The axe pages were the hub list, an unknown centre, `Post` at depth 2 with and
without the tint, and the radial layout. The 300-unit timing is reported in the
pull request; on the shared sandbox it is over the 500 ms target.
