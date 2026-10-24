# `?since=` highlighting

Scope: E-8 ([woods-map#4](https://github.com/lost-in-the/woods-map/issues/4)), on Code, Graph, Lifecycle, Passage and the ERD. The tree, History and timeline views remain separate.

`?since=gen:N` (or a retained commit SHA) on a unit page or `/woods/erd` asks Woods for the range report from that selector to now: `Woods::Impact::Report.compare` through `WoodsMap::ImpactRange`. `WoodsMap::Since` reads it.

- The report is built once per request, on first use (`SinceParam#current_since`).
- The map never compares payloads itself.
- A malformed selector is refused before Woods is asked.

**The banner.** It sits under the tabs, in one of these states:

| State | Banner |
|---|---|
| Changed | *Modified, added or removed since gen N.* Names the facets and metadata keys that moved, and says which lines changed is not in the report (woods#802). |
| Affected | *Affected since gen N.* The unit is unchanged itself and sits *k* hops from a change. |
| Unchanged | *Unchanged since gen N.* No change and not reached. |
| No comparison | Woods' resolution message, which names the retained generations, then the pinned generations (W-11), or how to pin a review base when none is. |

Each banner has *open the report* (the range page focused on this unit) and *clear*. The page's tabs keep `since`.

**What is marked.**

- **Code:** a marginal note names the metadata it reads: associations, callbacks, validations or concerns. When the report's `metadata_keys` include that metadata, the row gets the `--mod` rule and the note an `M` chip with a screen-reader sentence. This is per metadata key: the report does not say which association or callback moved.
- **Graph:** the explorer's report emphasis, as on the impact Graph tab: changed filled, reached ringed by distance.
- **Passage:** each template the report records as changed gets an `M` chip, and its link keeps `since`.
- **ERD:** a banner counts the changed tables, and each changed table in the chunk list gets the `--mod` rule and an `M` chip.
- **Lifecycle:** the banner only. Which step moved needs per-callback evidence the report does not carry.

**Limits.**

- **Diff gutter and changed lines:** wait on woods#802.
- **Steps, columns and diagram nodes** are not marked inside the Mermaid diagrams. Pele draws the current text, and per-entry change evidence is not in the report.
- **Cost:** a comparison per page view. It is opt-in by the parameter, and Woods bounds it with the report's own budgets.
