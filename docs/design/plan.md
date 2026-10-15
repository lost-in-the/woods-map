# Woods Map plan

The milestone plan derived from the [design study](design-study.md) and the
[decision log](decisions.md). GitHub issues own the live status of every item
below; this file is the map of the plan, not a second status board. When an
issue is created, closed or re-scoped, update the matching row here in the
same pull request. Every issue is tracked in the
[Woods Development project](https://github.com/orgs/lost-in-the/projects/1/views/1).

Release 0.1 is M0, M1, M2 and M4b. Release 0.2 is M3, M5, M6, M7 and M8.
M0 lives in the `woods` repository; everything else lives here, with the
testbed suite in `woods-testbed`.

## Milestones

| Milestone | Repository | Scope | Exit criterion | Tracking |
|---|---|---|---|---|
| M0 · Data | woods | W-1 reference spans, W-2 method table, W-3 commit table, W-4 job facts, W-5 model lifecycle entries, W-6 method-level span targets, W-7 per-action controller and mailer facts, W-8 filter applicability, W-9 container attribution, W-10 facet diff, W-11 generation pin, W-12 `woods:impact` and `impact.json`, W-13 inverted flow index, W-14 best-effort flow precomputation | Published by full and incremental runs; incremental equivalence spec green; verified on testbed rails-8.0, 7.2 and 6.0 | epic in woods (see links below) |
| M1 · Reading | woods-map | Gem skeleton, Engine with self-served assets and import map, authentication (token exchange and host hook), Repository over one pinned generation, search palette and full-text code search, unit pages for all types, two-lens code viewer (as-written default, remembered per browser) with marginalia, outline, peek, confidence marks, reading trail, file view | Both design-study scenarios navigable by clicking only on a Rails 6.0 and an 8.0 testbed host; works with JavaScript disabled except peek and hover | issue |
| M2 · Passage | woods-map | Filter matrix, data passage for actions and mailers, mismatch flags, callback ladder, passage export | The unassigned instance-variable flag reproduces on a seeded testbed bug | issue |
| M4b · Impact | woods-map (page) + woods (report) | Impact page with focus URLs, `?since=` highlighting across views, pre-change blast radius; consumes W-12 | A pull request in the testbed gets a Markdown impact comment from CI; the focus link opens the page with the changed template highlighted | issue |
| M3 · Diagrams | woods-map | Lifecycle tab with sequence, flowchart, swimlane and C4-notation renderings; Schema tab and `/woods/erd`; Landscape page (L1, L2); Mermaid, Structurizr DSL and LikeC4 exports | Diagrams match the flow document and model facts on the testbed; chunking verified on a 300-model fixture | issue |
| M4 · History | woods-map | History tab hunk cards, gutter heat, neighbourhood timeline, snapshot picker, unit diff across retained generations | Co-change query answers design-study scenario 2 step 3 from the commit table | issue |
| M5 · Graph | woods-map | Neighbourhood endpoint, Cytoscape component, Graph tab, full-screen graph page, blast radius, butterfly layout | 300-node neighbourhood renders under 500 ms on the testbed; keyboard list equivalent | issue |
| M6 · Trail | woods-map | LifecycleBuilder across async hops, lanes, flags, board state, export | Design-study scenario 2 reproducible end to end from one URL | issue |
| M7 · Guide | woods-map | RubyLLM agent, MCP attachment over stdio, SSE streaming into Turbo Streams, seven actions, budgets | All actions produce linked answers on the testbed with one provider; disabled by default; unavailable below Ruby 3.2 with a clear message | issue |
| M8 · Staging | woods-map + woods | Threat-model document, CSP, rate limits, deployment guide beside `MCP_HTTP_TRANSPORT.md` | Non-loopback boot refuses without a token; origin guard tests | issue |
| T · Testbed suite | woods-testbed | Blog scenario (Post, Comment, Tag, NotifySubscribersJob, MailingListMailer, templates, one deliberate unassigned instance variable) in rails-8.0, mirrored in rails-6.0; the map mounted in every variant; smoke scripts under `scripts/` | Both scenarios run unchanged against every variant | issue |

## Dependencies

- M1 depends on M0 (W-1, W-2, W-3 at least) and T.
- M2 depends on M1 and M0 (W-7, W-8).
- M4b depends on M1 and M0 (W-10 to W-13); the woods side of M4b is W-12.
- M3, M4 and M5 can proceed in parallel after M1.
- M6 depends on M3 and M4; M7 depends on M1 and is most useful after M2; M8 closes 0.2.

## Requirement map

Requirement identifiers come from the design study. Each milestone issue lists
the identifiers it closes; a requirement is done when its issue closes with
evidence.

| Milestone | Requirements |
|---|---|
| M1 | FR-1, FR-2, FR-3, FR-4, NFR-1 to NFR-4, B-1 to B-15 |
| M2 | B-16 to B-20 |
| M4b | FR-7 (impact part), E-1 to E-10 |
| M3 | FR-6, B-21 to B-24, Mermaid decisions R-4 |
| M4 | FR-7 (history part), B-6 |
| M5 | FR-5, A-1 to A-6 |
| M6 | C-1 to C-5 |
| M7 | FR-8, guide section of the study |
| M8 | security posture section of the study |

## Audit checklist

Run this before a milestone issue is opened and again before it closes.

1. The issue names the requirement identifiers it covers and links this file.
2. The data it needs exists in a published generation, or the W-item that adds it is linked and merged.
3. The exit criterion is reproducible on a named testbed variant.
4. The decision log has no open entry that would change the scope.
5. The issue is on the Woods Development project board.

## Issue links

Filled in as issues are created.
