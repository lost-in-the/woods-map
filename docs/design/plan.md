# Woods Map plan

The milestone plan derived from the [design study](design-study.md) and the
[decision log](decisions.md); [coverage.md](coverage.md) maps each page to its design board. GitHub issues own the live status of every item
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
| M0 · Data | woods | W-1 reference spans, W-2 method table, W-3 commit table, W-4 job facts, W-5 model lifecycle entries, W-6 method-level span targets, W-7 per-action controller and mailer facts, W-8 filter applicability, W-9 container attribution, W-10 facet diff, W-11 generation pin, W-12 `woods:impact` and `impact.json`, W-13 inverted flow index, W-14 best-effort flow precomputation | Published by full and incremental runs; incremental equivalence spec green; verified on testbed rails-8.0, 7.2 and 6.0 | [woods#750](https://github.com/lost-in-the/woods/issues/750) |
| M1 · Reading | woods-map | Gem skeleton, Engine with self-served assets and import map, authentication (token exchange and host hook), Repository over one pinned generation, search palette and full-text code search, unit pages for all types, two-lens code viewer (as-written default, remembered per browser) with marginalia, outline, peek, confidence marks, reading trail, file view | Both design-study scenarios navigable by clicking only on a Rails 6.0 and an 8.0 testbed host; works with JavaScript disabled except peek and hover | [woods-map#2](https://github.com/lost-in-the/woods-map/issues/2), closed |
| M2 · Passage | woods-map | Filter matrix, data passage for actions and mailers, mismatch flags, callback ladder, passage export | The unassigned instance-variable flag reproduces on a seeded testbed bug | [woods-map#3](https://github.com/lost-in-the/woods-map/issues/3), closed |
| M4b · Impact | woods-map (page) + woods (report) | Impact page with focus URLs, `?since=` highlighting across views, pre-change blast radius; consumes W-12 | A range focus URL (two retained generations) opens the impact page with the changed template highlighted, and `?since=` highlights it on the Code tab. A CI pull-request comment is out of the map's scope: Woods owns `woods:impact` output (D-1, D-25) | [woods-map#4](https://github.com/lost-in-the/woods-map/issues/4), report in [woods#762](https://github.com/lost-in-the/woods/issues/762) |
| M3 · Diagrams | woods-map | Lifecycle tab with sequence, flowchart, swimlane and C4-notation renderings; Schema tab and `/woods/erd`; Landscape page (L1, L2); Mermaid, Structurizr DSL and LikeC4 exports | Diagrams match the flow document and model facts on the testbed; chunking verified on a 300-model fixture | [woods-map#5](https://github.com/lost-in-the/woods-map/issues/5) |
| M4 · History | woods-map | History tab hunk cards, gutter heat, neighbourhood timeline, snapshot picker, unit diff across retained generations | Co-change query answers design-study scenario 2 step 3 from the commit table | [woods-map#6](https://github.com/lost-in-the/woods-map/issues/6) |
| M5 · Graph | woods-map | [Bounded neighbourhood endpoint](notes/neighbourhood-json.md), Cytoscape component, Graph tab, full-screen graph page, blast radius, butterfly layout | 300-node neighbourhood renders under 500 ms on the testbed; keyboard list equivalent | [woods-map#7](https://github.com/lost-in-the/woods-map/issues/7) |
| M6 · Trail | woods-map | LifecycleBuilder across async hops, lanes, flags, board state, export | Design-study scenario 2 reproducible end to end from one URL | [woods-map#8](https://github.com/lost-in-the/woods-map/issues/8) |
| M7 · Guide | woods-map | RubyLLM agent, MCP attachment over stdio, SSE streaming (EventSource, no Turbo; see the M7 note), the actions of #9, budgets | All actions produce linked answers on the testbed with one provider; disabled by default; unavailable below Ruby 3.2 with a clear message | [woods-map#9](https://github.com/lost-in-the/woods-map/issues/9) |
| M8 · Staging | woods-map + woods | Threat-model document, CSP, rate limits, deployment guide beside `MCP_HTTP_TRANSPORT.md` | Non-loopback boot refuses without a token; origin guard tests | [woods-map#10](https://github.com/lost-in-the/woods-map/issues/10), closed |
| T · Testbed suite | woods-testbed | Blog scenario (Post, Comment, Tag, NotifySubscribersJob, MailingListMailer, templates, one deliberate unassigned instance variable) in rails-8.0, mirrored in rails-6.0; the map mounted in every variant; smoke scripts under `scripts/` | Both scenarios run unchanged against every variant | [woods-testbed#38](https://github.com/lost-in-the/woods-testbed/issues/38) |

## Dependencies

- M1 depends on M0 (W-1, W-2, W-3 at least) and T.
- The design-system epic (woods-map#23) implements D-10 to D-20 inside M1; M3 to M6 compose their views from its partials.
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
| M1 | FR-1, FR-2, FR-3, FR-4, NFR-1 to NFR-4, B-1 to B-15, design decisions D-10 to D-20 |
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

| Item | Issue |
|---|---|
| Design spec handoff | [woods-map#1](https://github.com/lost-in-the/woods-map/issues/1) |
| M0 epic | [woods#750](https://github.com/lost-in-the/woods/issues/750) |
| W-1 reference spans (closed; [woods#791](https://github.com/lost-in-the/woods/pull/791), [woods#792](https://github.com/lost-in-the/woods/pull/792), [woods#808](https://github.com/lost-in-the/woods/pull/808)) | [woods#751](https://github.com/lost-in-the/woods/issues/751) |
| W-2 method table (closed; [woods#808](https://github.com/lost-in-the/woods/pull/808)) | [woods#752](https://github.com/lost-in-the/woods/issues/752) |
| W-3 commit table (closed; [woods#801](https://github.com/lost-in-the/woods/pull/801)) | [woods#753](https://github.com/lost-in-the/woods/issues/753) |
| W-4 job resilience facts | [woods#754](https://github.com/lost-in-the/woods/issues/754) |
| W-5 model lifecycle entries | [woods#755](https://github.com/lost-in-the/woods/issues/755) |
| W-6 method-level span targets (closed; [woods#808](https://github.com/lost-in-the/woods/pull/808)) | [woods#756](https://github.com/lost-in-the/woods/issues/756) |
| W-7 per-action facts (closed; [woods#772](https://github.com/lost-in-the/woods/pull/772), filter facts from W-8 in [woods#807](https://github.com/lost-in-the/woods/pull/807)) | [woods#757](https://github.com/lost-in-the/woods/issues/757) |
| W-8 filter applicability (closed; [woods#800](https://github.com/lost-in-the/woods/pull/800); the Passage filter matrix consumes it) | [woods#758](https://github.com/lost-in-the/woods/issues/758) |
| W-9 container attribution (closed; [woods#803](https://github.com/lost-in-the/woods/pull/803)) | [woods#759](https://github.com/lost-in-the/woods/issues/759) |
| W-10 facet diff (closed; [woods#773](https://github.com/lost-in-the/woods/pull/773)) | [woods#760](https://github.com/lost-in-the/woods/issues/760) |
| W-11 generation pin (closed; [woods#774](https://github.com/lost-in-the/woods/pull/774), readers in [woods#805](https://github.com/lost-in-the/woods/pull/805)) | [woods#761](https://github.com/lost-in-the/woods/issues/761) |
| W-12 impact report (closed; [woods#780](https://github.com/lost-in-the/woods/pull/780), [woods#786](https://github.com/lost-in-the/woods/pull/786), [woods#790](https://github.com/lost-in-the/woods/pull/790)) | [woods#762](https://github.com/lost-in-the/woods/issues/762) |
| W-13 inverted flow index (closed; [woods#775](https://github.com/lost-in-the/woods/pull/775), readers in [woods#805](https://github.com/lost-in-the/woods/pull/805)) | [woods#763](https://github.com/lost-in-the/woods/issues/763) |
| Model attribute writers for the permitted-param flag (B-18), closed | [woods#797](https://github.com/lost-in-the/woods/issues/797), published by [woods#806](https://github.com/lost-in-the/woods/pull/806), [design note](notes/passage-mismatch-limits.md) |
| Partial locals passed and read for the partial-local flag (B-18), closed | [woods#798](https://github.com/lost-in-the/woods/issues/798), published by [woods#806](https://github.com/lost-in-the/woods/pull/806), [design note](notes/passage-mismatch-limits.md) |
| W-14 best-effort flows | [woods#764](https://github.com/lost-in-the/woods/issues/764) |
| M4 History: History tab from the commit table (strip, commits with detail blocks, people, co-change), per-file gutter heat, generation picker and unit diff from Woods' report, `/woods/history` timeline, timeline and XY exports | [woods-map#6](https://github.com/lost-in-the/woods-map/issues/6), [note](notes/history.md) |
| Commit table line counts and hunks (B6-History `+6 −1`, *hunks*) | [woods#804](https://github.com/lost-in-the/woods/issues/804) |
| Changed line ranges per modified unit in the impact report (unified unit diff, B-14, and the `?since=` diff gutter) | [woods#802](https://github.com/lost-in-the/woods/issues/802) |
| Engine scaffold (the M1 skeleton: gem, Engine, Repository, authentication, states, token sheet served) | [woods-map#11](https://github.com/lost-in-the/woods-map/pull/11) |
| Bounded M1 units index and indexed file ownership (FR-3, B-5); other M1 follow-ups remain separate | [woods-map#34](https://github.com/lost-in-the/woods-map/issues/34), [design note](notes/m1-indexed-navigation.md) |
| Keyboard help (NFR-3), with focus and shortcut browser coverage | [woods-map#34](https://github.com/lost-in-the/woods-map/issues/34), [contract](notes/keyboard-help.md) |
| M1 to M8 | woods-map#2 to #10 as listed in the milestone table |
| M1 follow-up: the undesigned reading pieces (units index, file view, Routes tab, type tiles, hover card, disambiguation, settings, keyboard help, share menu), closed | [woods-map#34](https://github.com/lost-in-the/woods-map/issues/34) |
| Controller Routes tab (FR-3); helper- and action-level references from [woods#795](https://github.com/lost-in-the/woods/issues/795) | [woods-map#34](https://github.com/lost-in-the/woods-map/issues/34), [contract](notes/routes-tab.md) |
| Code navigation: disambiguation popover (FR-4, B-1), method-level links, callers panel (B-13) and outline from the method table (B-8), on Woods W-1/W-2/W-6 ([woods#751](https://github.com/lost-in-the/woods/issues/751), [woods#752](https://github.com/lost-in-the/woods/issues/752), [woods#756](https://github.com/lost-in-the/woods/issues/756)) | [woods-map#34](https://github.com/lost-in-the/woods-map/issues/34), [contract](notes/code-navigation.md) |
| Hover card on a reference (B-3), prefetched with the Code tab | [woods-map#34](https://github.com/lost-in-the/woods-map/issues/34), [contract](notes/hover-card.md) |
| Reading settings (B-15, D-6): lens, wrap, font size and editor link per browser | [woods-map#34](https://github.com/lost-in-the/woods-map/issues/34), [contract](notes/settings.md) |
| Share menu (E-6, E-7): focus URL and the page's Mermaid, per D-25 | [woods-map#34](https://github.com/lost-in-the/woods-map/issues/34), [contract](notes/share-menu.md), [woods-map#57](https://github.com/lost-in-the/woods-map/issues/57) |
| Type-specific facts tiles (B-4); other M1 follow-ups remain separate | [woods-map#34](https://github.com/lost-in-the/woods-map/issues/34), [contract](notes/published-type-facts.md) |
| Design system epic (tokens, fonts, components, responsive tiers) | [woods-map#23](https://github.com/lost-in-the/woods-map/issues/23) |
| D-22 Inline links need a cue besides colour (settled, amends D-11), closed | [woods-map#26](https://github.com/lost-in-the/woods-map/issues/26) |
| D-23 Token contrast corrections for AA (settled, amends D-11), closed; the hover tint follow-up [woods-map#49](https://github.com/lost-in-the/woods-map/issues/49) is closed | [woods-map#27](https://github.com/lost-in-the/woods-map/issues/27) |
| M3 first slice: the Pele renderer, Schema ER, Lifecycle sequence and Graph neighbourhood panels with their budgets (R-4); other M3 work remains on #5 | [woods-map#5](https://github.com/lost-in-the/woods-map/issues/5), [woods-map#37](https://github.com/lost-in-the/woods-map/pull/37) |
| Landscape: Containers (W-9) with Mermaid, Structurizr DSL and LikeC4 exports, Hotspots, Domains ([design note](notes/landscape.md)); M3 scope | [woods-map#5](https://github.com/lost-in-the/woods-map/issues/5) |
| M5 flow overlay (A-4) from W-13 flow membership and the graph's commit timeline (A-6) from W-3, on the Graph tab and the full-screen graph | [woods-map#7](https://github.com/lost-in-the/woods-map/issues/7), [woods#805](https://github.com/lost-in-the/woods/pull/805), [note](notes/graph-page.md) |
| Landscape Components (L3) by package, namespace or domain cluster with the group control; Hotspots quadrant and forward-flow sankey; the Share menu with every diagram's text (D-25); M3 scope | [woods-map#5](https://github.com/lost-in-the/woods-map/issues/5), [note](notes/landscape.md) |
| Woods Map data: source line counts per unit, for the Hotspots treemap of packages by LOC | [woods#810](https://github.com/lost-in-the/woods/issues/810) |
| M5 full-screen graph page: blast tint, position cache, hubs, the clusters layout from woods#799 ([design note](notes/graph-page.md)) | [woods-map#7](https://github.com/lost-in-the/woods-map/issues/7) |
| Woods Map data: domain clusters in `graph_analysis.json` (M5 full-screen graph), closed; [woods#803](https://github.com/lost-in-the/woods/pull/803) | [woods#799](https://github.com/lost-in-the/woods/issues/799) |
| M5 Graph tab layouts without fcose or dagre: a computed butterfly and Cytoscape's concentric radial (needs-decision) | [woods-map#63](https://github.com/lost-in-the/woods-map/issues/63) |
| M3 Mermaid export: copy and a `.mmd` link from every diagram's tools; each diagram's text is served as `text/plain` from a stable `.mmd` URL (constraint 3, D-25). Structurizr DSL and LikeC4 export the Landscape from W-9 | [woods-map#5](https://github.com/lost-in-the/woods-map/issues/5) |
| M3 Lifecycle views: flowchart and lanes beside the sequence, state diagrams for published state machines (FR-6, B-19, R-4); C4 dynamic (B-23) from W-9 containers, on Lifecycle and on a controller's Passage | [woods-map#5](https://github.com/lost-in-the/woods-map/issues/5), [note](notes/lifecycle-views.md) |
| State machine transition callbacks as structured entries (Lifecycle per-transition columns) | [woods#796](https://github.com/lost-in-the/woods/issues/796) |
| M3 `/woods/erd`: the whole database by chunk (namespace or database, at most 40 tables each, R-4) with schema findings, verified on a generated 300-model index; ERD in the global bar | [woods-map#5](https://github.com/lost-in-the/woods-map/issues/5) |
| Passage and impact coverage: unresolved render targets and partials stay incomplete (M2 B-17, B-18; M4b E-5) | [woods-map#47](https://github.com/lost-in-the/woods-map/issues/47), fixed by [woods-map#51](https://github.com/lost-in-the/woods-map/pull/51) |
| M4b range mode: Overview (v8 of the v5 board), Changed, Risks, Flows, Tests, Graph and Unknown tabs over Woods' schema 1 report, saved reports at `/woods/impacts/<id>`, and the pre-change Graph tab | [woods-map#4](https://github.com/lost-in-the/woods-map/issues/4), [note](notes/impact-range.md) |
| M4b `?since=<generation>` on Code, Graph, Lifecycle, Passage and ERD from Woods' range report only; unretained generations say so (W-11) | [woods-map#4](https://github.com/lost-in-the/woods-map/issues/4), [note](notes/since.md), [woods#761](https://github.com/lost-in-the/woods/issues/761) |
| M4b Flows tab from Woods' inverted flow membership (W-13) with the pinned generation's steps, and retention pins (W-11) on status, pickers and fallbacks, through the published-index readers | [woods-map#4](https://github.com/lost-in-the/woods-map/issues/4), [note](notes/impact-flows.md), [woods#805](https://github.com/lost-in-the/woods/pull/805) |
| M4b exit criterion re-scoped to the map side; the CI pull-request comment is out of scope (Woods owns `woods:impact` output, D-1, D-25) | [woods-map#4](https://github.com/lost-in-the/woods-map/issues/4), [screenshots](screenshots/README.md) |
| D-24 Code view scrolls as one region, not a line at a time (settled, amends B8-Code), closed | [woods-map#29](https://github.com/lost-in-the/woods-map/issues/29) |
| M7 guide: RubyLLM agent over the Index MCP server (stdio, D-7), SSE panel, eight actions, budgets; a real provider run, history and the Trail handoff remain on #9 | [woods-map#9](https://github.com/lost-in-the/woods-map/issues/9), [note](notes/m7-guide.md) |
| D-25 Share menu: focus URL and Mermaid only, no Markdown or JSON (settled in [decisions](decisions.md), merged with [woods-map#70](https://github.com/lost-in-the/woods-map/pull/70); the issue is still open) | [woods-map#57](https://github.com/lost-in-the/woods-map/issues/57) |
| M8: CSP, rate limits, origin guard and loopback Host, tested under Puma; threat model and deployment guide; closed | [woods-map#10](https://github.com/lost-in-the/woods-map/issues/10), [note](notes/m8-staging.md) |
| M8 open choices: the 429 state, the loopback Host rule, no style attributes (needs-decision, open) | [woods-map#59](https://github.com/lost-in-the/woods-map/issues/59) |
| M8 threat model and deployment guide beside Woods' `MCP_HTTP_TRANSPORT.md`, closed | [woods-map#10](https://github.com/lost-in-the/woods-map/issues/10), [THREAT_MODEL.md](../THREAT_MODEL.md), [DEPLOYMENT.md](../DEPLOYMENT.md) |
| Share output that pastes cleanly into a GitHub pull-request comment: Mermaid GitHub can render, a copy-for-PR block, `config.public_url` (backlog; would amend D-25) | [woods-map#76](https://github.com/lost-in-the/woods-map/issues/76) |
| M1 exit criterion: both design-study scenarios walked by clicking only, JavaScript on and off, on testbed rails-8.0 and rails-6.0 (woods-testbed `scripts/support/woods_map_walks.json`); scroll regions focusable without JavaScript | [woods-testbed#38](https://github.com/lost-in-the/woods-testbed/issues/38) |
| Lifecycle tab on controllers, jobs and mailers: entry flows instead of model event chains (FR-6, needs-decision) | [woods-map#91](https://github.com/lost-in-the/woods-map/issues/91) |
| History: filter the timeline by a commit's author (scenario 2 step 4) | [woods-map#92](https://github.com/lost-in-the/woods-map/issues/92) |
| D-10 Source of truth for visual tokens | [woods-map#12](https://github.com/lost-in-the/woods-map/issues/12) |
| D-11 Colour meaning | [woods-map#13](https://github.com/lost-in-the/woods-map/issues/13) |
| D-12 Typefaces | [woods-map#14](https://github.com/lost-in-the/woods-map/issues/14) |
| D-13 Spacing, borders and radii | [woods-map#15](https://github.com/lost-in-the/woods-map/issues/15) |
| D-14 Heading hierarchy | [woods-map#16](https://github.com/lost-in-the/woods-map/issues/16) |
| D-15 Dates and shorthand | [woods-map#17](https://github.com/lost-in-the/woods-map/issues/17) |
| D-16 Tooltip | [woods-map#18](https://github.com/lost-in-the/woods-map/issues/18) |
| D-17 Tables | [woods-map#19](https://github.com/lost-in-the/woods-map/issues/19) |
| D-18 Navigation chrome | [woods-map#20](https://github.com/lost-in-the/woods-map/issues/20) |
| D-19 Responsiveness | [woods-map#21](https://github.com/lost-in-the/woods-map/issues/21) |
| D-20 Glyphs over assets | [woods-map#22](https://github.com/lost-in-the/woods-map/issues/22) |
| D-21 Diagram renderer: Pele in the browser, supersedes D-5 (settled) | [woods-map#25](https://github.com/lost-in-the/woods-map/issues/25) |
| T testbed suite | [woods-testbed#38](https://github.com/lost-in-the/woods-testbed/issues/38) |

The GitHub integration available to the session that created these issues
could not add them to the Woods Development project (organization project
fields are not accessible to it). Add them from the project board, or enable
the project's auto-add workflow for the three repositories, and record the
result in [woods-map#1](https://github.com/lost-in-the/woods-map/issues/1).
