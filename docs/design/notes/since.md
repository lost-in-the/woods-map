# `?since=` highlighting

Scope: E-8 ([woods-map#4](https://github.com/lost-in-the/woods-map/issues/4)), on the file tree, Code, Graph, Lifecycle, Passage, the ERD, the History tab and the `/woods/history` timeline.

`?since=gen:N` (or a retained commit SHA) on a unit page or `/woods/erd` asks Woods for the range report from that selector to now: `Woods::Impact::Report.compare` through `WoodsMap::ImpactRange`. `WoodsMap::Since` reads it.

- The report is built once per request, on first use (`SinceParam#current_since`).
- The map never compares payloads itself.
- A malformed selector is refused before Woods is asked.

**The banner.** It sits under the tabs, in one of these states:

| State | Banner |
|---|---|
| Changed | *Modified, added or removed since gen N.* Names the facets and metadata keys that moved and the report's line counts (`source_changes`, woods#802), or why lines are not marked: the source did not move, it moved past Woods' line-diff bounds, or the report's `now` is not the page's generation. |
| Affected | *Affected since gen N.* The unit is unchanged itself and sits *k* hops from a change. |
| Unchanged | *Unchanged since gen N.* No change and not reached. |
| No comparison | Woods' resolution message, which names the retained generations, then the pinned generations (W-11), or how to pin a review base when none is. |

Each banner has *open the report* (the range page focused on this unit) and *clear*. The page's tabs keep `since`.

**What is marked.**

- **Code, diff gutter:** the report's `source_changes` for the unit gives changed ranges in the `to` side's annotated `source_code`, which is the page's own source when the report's `now` is the pinned generation (`Since#line_marks`; otherwise nothing is marked and the banner says so). Each changed line gets the `--mod` rule in the gutter (B8-Code's `.row-chg`) and *changed since gen N* for screen readers, in either lens: concern lines carry their composite line too. A pure removal puts a `--mod` underline under the line it follows, titled with the count. `truncated` marks the ranges Woods kept and says so; `too_large` marks none.
- **Code, changed marginalia:** a marginal note names the metadata it reads: associations, callbacks, validations or concerns. It gets an `M` chip (and its row the rule) when its own line changed, or when the report's `metadata_keys` include that metadata, with a screen-reader sentence naming which. The metadata rule is per key: the report does not say which association or callback moved.
- **File tree:** each file owning a changed unit gets an `M` chip, and the tree head counts them.
- **History tab and `/woods/history`:** a commit whose first retained table is newer than gen N (`CommitLedger`) is marked `M` with the `--mod` rule, and the caption counts them. A commit only known to be at or before a generation is never claimed. History links keep `since`.
- **Graph:** the explorer's report emphasis, as on the impact Graph tab: changed filled, reached ringed by distance.
- **Passage:** each template the report records as changed gets an `M` chip, and its link keeps `since`. A filter-matrix row is marked M when the changed lines touch the filter's declaration (`declaration` on the W-8 entry, [woods#820](https://github.com/lost-in-the/woods/issues/820)) or its method's extent in this controller's source; an inherited filter's declaration lives in another unit and is not marked here. The callback ladder marks steps as the Lifecycle does.
- **ERD:** a banner counts the changed tables, and each changed table in the chunk list gets the `--mod` rule and an `M` chip. Its columns cell lists the columns the report names (`column_changes`, [woods#821](https://github.com/lost-in-the/woods/issues/821)) as `+added ~modified −removed`, and the diagram draws added and modified columns with a comment (`"added since gen N"`), even in the keys-only view.
- **Schema tab:** a model's columns the report names (its own record, else its table's) get the rule and an `M` chip saying added or modified; removed columns are listed under the table.
- **Lifecycle:** a step is marked M (row rule, chip, screen-reader words naming which) when the changed lines touch its method's published extent (`metadata.methods`, W-2, `line`..`end_line`) or its declaration (`declaration` on the callback entry, [woods#817](https://github.com/lost-in-the/woods/issues/817)), both in the annotated source the line ranges address (`Since#changed_members`). The flowchart and lanes outline those nodes (`class sN chg`, map.css); the sequence has no node classes, so its legend points to the steps table. The Passage ladder marks steps the same way. A method named by two owners is matched to the step's owner first.

**Limits.**

- **The schema header fold and an added unit's lines** are not line-marked: the header is folded, and an added unit has no `before` (the banner says *Added*).
- **Sequence steps and graph nodes inside diagrams** are not marked per entry: a sequence has no node classes, and Pele's ER and graph texts carry no class for a node. Removed columns cannot be drawn and are listed instead. A step whose method or declaration Woods does not publish (a proc, a framework callback, a metaprogrammed or ambiguous declaration) is not marked; the banner still names the moved keys.
- **Cost:** a comparison per page view. It is opt-in by the parameter, and Woods bounds it with the report's own budgets.
