# Impact range: Overview, the report's tabs, saved reports and the Graph tab

Scope: M4b ([woods-map#4](https://github.com/lost-in-the/woods-map/issues/4)), E-1 to E-7 and E-10. D-1 and D-25 govern it.

This note is the v8 pass of B5-Impact-Overview, which was a v5 draft and is not in the repository. It covers the Overview tab and the range mode of the B8 Impact tabs. The Graph tab has no board, so this note designs it.

## The page

A range page shows Woods' schema 1 report from `WoodsMap::ImpactRange`. Three URLs reach it:

- `/woods/impact?from=gen:N&to=now`, through `Woods::Impact::Report.compare`;
- `/woods/impacts/<sha256>`, a saved report read through `Woods::Impact::Store#read` (E-6);
- either of the above with a `lens` and a `focus`.

The frame is the B8 Impact frame:

- the title is `gen N → gen M` and the subtitle is the endpoints' short SHAs;
- the controls are Share and the primary *⎘ copy focus URL*, which `y` also activates;
- the tabs are Overview, Changed, Risks, Flows, Tests, Graph and Unknown, each with one count, which is that section's record count in the report.

The rail lists the changed units (M, + or −), the first affected units and three limits:

- which lines changed: woods#802;
- flows not inverted: W-13, woods#763;
- no pinned review base: W-11, woods#761.

Per D-25 there is no *Markdown for PR* button and no Markdown or JSON anywhere on the page. The report's Markdown is the CI comment's, and Woods renders it.

## Overview

The report's summary laid out as the page's own sections, in the same order as Woods' PR comment:

1. A **summary table**: one row per section, with its record count, its coverage and its first entries. Each row links to its tab.
2. **Changed** and **affected** samples, six each.
3. **Retained flow evidence.**
4. **Endpoint provenance**: generation, selector, commit and manifest checksum per endpoint.
5. **Coverage and applied parameters.**
6. **Unknowns by kind.**
7. The **selectors** to compare another range. Saved reports have none.

When Woods does not declare the report complete, a `mod` banner says so, and every empty section says it is not a conclusive zero.

## The tabs in range mode

- **Changed:**
  - Changed units, each with facets, categories and payload generation. A row opens to the metadata keys that moved, the whole-source sizes (labelled as not changed lines, woods#802), and the affected units whose witness paths start at it.
  - Affected units, each with distance, weight (*unavailable*, never 0) and endpoint. A row opens to its witness paths.
  - The tables and templates the report involves.
- **Risks, Flows, Tests:** the report's records, each with the published evidence Woods attached.
- **Unknown:** unknowns grouped by kind with one example each, then the coverage table.

**Links.** A record links into the map only when its generation is the one the request pinned and that generation has the typed unit. Every other identity is escaped text with its generation chip, so historical identities still have no current-source links. Changed units link with `?since=gen:<from>`, so the unit page lights what moved.

**Focus.** `focus=<identifier>[,…]` lights the matching rows on every tab with `aria-current` and the select tint. On the Changed tab it also opens those rows, and each row has an anchor (`#changed-N`). The CI comment's focus link uses this: `/woods/impacts/<id>?lens=changed&focus=<template>`.

## Graph tab (E-3, E-8)

The Graph tab reuses the Graph tab's Cytoscape explorer (M5).

- **Centre:** the focused changed unit, otherwise the first changed unit the pinned generation has.
- **Emphasis:** the explorer's blast tint, fed from the report rather than from a `BlastRadius`:
  - changed units at distance 0 are filled with `--mod` (`chg`);
  - directly affected units get the `--hot` ring;
  - transitively affected units get the `--mod` ring.
- **Labels:** the legend, the list equivalent and the status line say *changed in this range*, *affected directly* or *affected transitively*.
- **Filters:** the filter form keeps the range or saved-report ID, the lens and the focus.
- **Navigation:** Enter on a node opens that unit's Graph tab with `?since=`.
- **No centre:** when no changed unit is in the pinned generation, an empty state says so.

The pre-change page also gains the Graph tab. It centres on the first focus unit, tinted by its `BlastRadius` as `/woods/graph?blast=1` is.

## Limits

- **Changed lines, hunks and the LINES column** wait on woods#802. The map never diffs two payloads.
- **Flows** are partial without the inverted index, W-13 (woods#763). W-10 (woods#760) is not on Woods main. The facets the report already carries are shown as Woods computed them, and the report's `snapshot_facets` coverage says how they were bound.
- **Retention:** a `from` the index no longer retains gets Woods' resolution message, which names the retained generations, plus the W-11 limit (woods#761).
- **Saved reports** live with the index that computed them. The map shows a missing ID as missing, not as empty.
