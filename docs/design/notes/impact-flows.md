# Impact Flows and retention pins

How the impact page's Flows tab and the "pinned" state read Woods' published-index readers from [woods#805](https://github.com/lost-in-the/woods/pull/805). The map derives neither: flow membership is Woods' inverted flow index (W-13), and pins are Woods' retention pins (W-11).

## Flows tab (B6-Impact-Flows, E-4)

**Where entry points come from.**

- **Pre-change mode:** for each focus unit, `PublishedIndex#flow_entry_points(identifier, type:)` over the pinned generation's `flows/by_unit.json`. The tab count is the number of entry points through the focus. It costs no flow-document reads.
- **Range mode:** the report's own `flows` records, which Woods computed from the same inverse at each endpoint. The count is the report's.

**Rows.** One row per entry point:

- the route above the entry point (`GET /users/:id` over `UsersController#show`);
- the changed units it passes through, each with an M chip;
- *changed steps* as *k of n*;
- the layer: *precomputed, gen N*.

Range mode lights and opens the rows that pass through a unit the focus URL names. Pre-change mode opens the first row, because every row passes through the focus.

**Steps.** A row opens to the numbered steps component (C2-Table):

- The steps come from `PublishedIndex#flow_document(entry_point)` of the pinned generation only.
- Each step is a typed unit. A unit of this generation is a link; a changed unit gets an M chip; a reached unit carries its distance (*affected directly*, *affected at 2 hops*).
- Under each step are its operations:
  - calls with a constant target (`User.find`, line 12);
  - branches with their condition, and their arms indented;
  - responses (`302 redirect_to`).
- Calls without a target (framework filters, procs, dynamic sends) are counted as *untargeted calls* and not drawn. Their method strings can carry host paths of gems.
- Bounds: 100 entry points, 40 steps a flow and 12 operation lines a step. Anything past a bound is counted.

**Historical flows.** A range record of another generation keeps its route and changed units, but shows no steps. Its steps are in that generation's payload, and the page reads one generation (D-1).

**States, never a zero by accident.**

| State | What the tab says |
|---|---|
| available, none | *No precomputed flow expands the focus*; membership is bounded, so this does not prove that nothing reaches it. |
| absent | *No flow membership in this generation*: flows are precomputed only with `precompute_flows`. |
| unreadable | *Flow evidence unreadable*: Woods refused an artifact as corrupt. |
| unsupported | *This Woods cannot read flow membership* (woods#805). |

In the last three states the tab carries no count. Each state names the routes among the affected units as the nearest fact.

**Not built from the board.** The board's review-set checkboxes, the *through selection* filter, the per-flow sequence diagram and the async-hop boundaries are not built yet:

- Published flow documents are flat step lists. They have no call depth and no async marker, so the steps indent one level under the entry point.
- A sequence diagram per flow can follow from the same document as a Pele `sequenceDiagram`.

## Retention pins (W-11)

`PublishedIndex.retention_pins(index_dir)` is read once per request through `Repository#retention` (`WoodsMap::Retention`). Pins are read from the index root, never from a payload.

- **Status page:** a *pinned* row lists the pinned generations, *kept past retention until `woods:unpin[N]`*. A pin whose payload is gone is marked *payload missing*. With no pins, the row says how to pin. When the state is unreadable or this Woods has no reader, it says *unknown*, never *none*.
- **Generation pickers:**
  - the History tab's *from* and *to* options read *gen 1, pinned*;
  - the History tab's generation rail adds *pinned*;
  - the range selectors list the retained generations with a *pinned* chip.
- **Range rail:** the limits name the base generation's retention: *base gen 1 pinned* (kept past retention), or *base gen 1 not pinned* (`woods:pin[1]` keeps it). This replaces the W-11 limit.
- **`?since=` and unretained ranges:** after Woods' resolution message (which names the retained generations), the page adds the pinned generations, or how to pin a review base when none is pinned.

## W-10

Snapshot facets need no map code. The report's `changed[].facets` are shown as Woods computed them, on Changed and in the `?since=` banner. Which lines changed is still woods#802.
