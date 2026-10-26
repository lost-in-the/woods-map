- M5 Graph tab canvas (woods-map#7; FR-5, A-1, A-2, A-5): Cytoscape 3.34.3 is vendored as its unmodified ESM build (`vendor/javascript/cytoscape.esm.min.mjs`, MIT) and loaded on demand by a new `graph` controller. The controller draws the page's own neighbourhood query from `/woods/graph/neighbourhood`. Units are tinted by type from the tokens, sized by PageRank, and marked hub and cycle per identifier; truncated units are dashed. The butterfly layout puts dependents left and dependencies right; the radial layout is Cytoscape's built-in `concentric`. Neither needs a layout extension; fcose and dagre are deferred to woods-map#63. Other controls:
  - click, or Enter on the selection, opens a unit's graph;
  - arrow keys move along the edges, Home returns to this unit, and + / − / 0 zoom and fit;
  - list rows light their edge, and ↑ / ↓ move between them;
  - the toolbar has zoom, fit, copy Mermaid and a *flowchart* toggle.

  The Pele flowchart and the list stay the page without JavaScript and when the fetch fails.
