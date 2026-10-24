# Decision log

Decisions taken while producing the design study, in the order they were made.
Each entry records the question, the choice, and what it rules in or out. New
decisions go in GitHub issues labelled `needs-decision` and are copied here
when settled, with the issue link.

## Interview (14 October 2026)

| # | Question | Decision | Consequence |
|---|---|---|---|
| I-1 | Data source | Published index only | No live database, no runtime reflection, no git subprocess at read time. Everything the map shows is in a published generation or the snapshot store. |
| I-2 | Front-end delivery | Import map + Hotwire, no build step | All JavaScript vendored and pinned; no Node toolchain at development or release time. |
| I-3 | Audience | Development in-app, and shareable on staging for a team | Bearer token plus origin guard, read-only hardening, source-exposure threat model. |
| I-4 | V1 scope | Search + unit pages + code viewer, relationship graph, lifecycle flowcharts + ERD, git insight timeline | All four are must-haves; they are sliced across milestones, not dropped. |
| I-5 | LLM guide | Chat plus "explain this" actions | RubyLLM 2.1 agent with the Index MCP server attached; actions seeded from page context. |
| I-6 | Packaging | Separate gem | The gem is `woods-map`; Woods itself gains only extraction-side data (W-items). |
| I-7 | Deliverable | Shareable page | The design study was published as a page; this repository now holds the Markdown and HTML copies. |

## Revision 2 (15 October 2026)

| # | Question | Decision | Consequence |
|---|---|---|---|
| R-1 | Rails and Ruby floors | Match Woods: railties >= 6.0, Ruby >= 3.0 | No dependency on importmap-rails or turbo-rails (turbo-rails 2.x needs Rails 7.1). The Engine serves its own vendored JavaScript and emits a literal import map tag. The guide alone needs Ruby 3.2 and degrades to a notice below it. |
| R-2 | Direction | B, Field Guide, iterated twice toward code comprehension | Trail's lifecycle board is a first-class route; Atlas is a component (Graph tab, full-screen graph page). |
| R-3 | C4 model | Concepts yes, tools no | Zoom ladder (landscape, containers, components, code), C4 notation on boxes and arrows, dynamic view as a fourth rendering of flows. Drawn with Mermaid flowcharts or the map's own SVG; Structurizr DSL and LikeC4 are export formats only. |
| R-4 | Mermaid diagram vocabulary | Sequence first on Lifecycle tabs; ER and class on Schema; state for state machines; quadrant, sankey and mindmap on the overview; timeline and XY on History | One Ruby renderer per type, each with a copy-as-Mermaid action and a node budget. |

## Blocking decisions answered (15 October 2026)

| # | Question | Decision | Consequence |
|---|---|---|---|
| D-1 | Ownership of the change impact report | Woods gem | The report object, its Markdown, JSON and Mermaid renderers, the `woods:impact` task and the `change_impact` MCP tool live in Woods; the map renders the HTML page. |
| D-2 | How a review gets its base | One index, pinned generation, head extracted incrementally | `woods:pin[gen]` protects a base from retention; retention stays at three. No second index directory and no second host boot. |
| D-3 | Standalone launcher | None | The map is a Rails Engine only, like Woods it belongs inside a Rails application. The test application suite lives in `woods-testbed`. |
| D-4 | Staging authentication | Both: token-to-cookie exchange and a host hook | `config.authorize = ->(request) { ... }` lets Devise or SSO gate the mount; the token path works without host code. |
| D-5 | Mermaid version | Newest (12.x) | Unless a Rails 7 host shows an exceptional limitation; ES2024 browsers are required by Mermaid 12. |
| D-6 | Default code lens | As written, remembered per browser | The Effective-class lens is one click away; the choice persists in browser storage so it is set once. |
| D-7 | Guide transport | stdio to `woods-mcp` for v1 | In-process tool adapters sharing the request's pinned generation are a later optimisation. |
| D-8 | Flow precomputation | Best-effort mode | Woods gains `precompute_flows: :best_effort`, recording assembly failures in `skipped_files.json` instead of aborting the publish. |
| D-9 | Release slicing | 0.1 = M0, M1, M2, M4b; graph, Trail and the guide in 0.2 | On the condition that the full plan is created, audited, committed and tracked in the Woods Development project, starting with the design spec. See `plan.md`. |

## Defaults accepted without objection

| # | Default |
|---|---|
| F-1 | Mounting is explicit: `mount WoodsMap::Engine => "/woods"`. The Railtie injects nothing. |
| F-2 | Names: gem `woods-map`, module `WoodsMap`, mount path `/woods`. |
| F-3 | Reference spans are stored inline in unit JSON; a per-type sidecar only if payload size grows more than about 15 percent on a 5 000-unit application. Measured on `woods-testbed` `rails-8.0-large` with the span kinds, method targets and method tables of [woods#808](https://github.com/lost-in-the/woods/pull/808): unit JSON +2.25%, the whole published payload +2.19% (3,546,468 to 3,624,067 bytes, 449 units), so spans stay inline and no sidecar is built ([woods#751](https://github.com/lost-in-the/woods/issues/751)). |
| F-4 | Guide conversations are file-backed and ephemeral; no default model name, the host configures RubyLLM. |
| F-5 | The design study is committed to this repository for handoff; the full design is produced from it and tracked issue by issue. |

## Design foundations (16 October 2026)

Settled on the Design canvas ([Woods Map pages](https://claude.ai/artifact/Vm2Sp2izRie5wyZ26Q6gWr),
page *Brand Guidelines & Components*, boards B7 and C1 to C5) while iterating
the B6 unit-page boards. Each row links the `needs-decision` issue that records
it; the implementation is tracked by the design-system epic.

| # | Question | Decision | Consequence |
|---|---|---|---|
| D-10 | Source of truth for visual tokens | One stylesheet, `woods/tokens.css`, shipped by the Engine and used by every view; the design boards inline the same file | Colours, fonts, sizes, spacing and radii are custom properties on the `.wm` root. Views never hard-code a colour or a pixel size; themes switch by `data-theme` and `data-cvd` attributes on that root. [woods-map#12](https://github.com/lost-in-the/woods-map/issues/12) |
| D-11 | Colour meaning | Palette roles are assigned by severity, the same on every page: purple+ `--select` is the selection, focus and the one primary action; cobalt+ `--link` is a link and nothing else; sun `--mod` means modified (least severe); orange′ `--hot` means hot or warning; beak `--risk` means risk, blocking or error and is always bold with a glyph; forest+ `--fresh` means fresh, passing or added. Hover is a neutral `--hover` tint, never a palette colour | Orange is lifted from `#E66747` to `#EF8A3C` so sun, orange and beak stay apart under deuteranopia and protanopia. Light mode uses the true pigeon colours (`#7E4384`, `#4D597A`, `#7A5200`, `#B9561D`, `#C0392B`, `#436961`) on `#FCFCFD`; `data-cvd=on` moves `--mod` to cobalt in light mode. Every role pairs colour with a glyph or weight so no meaning rests on hue alone. [woods-map#13](https://github.com/lost-in-the/woods-map/issues/13) |
| D-12 | Typefaces | Inter for interface text and headings, Fira Code for every data value and all code; ligatures are enabled only inside `.codeview` | Two font families, both vendored. Table cells, identifiers, counts, dates, SHAs, paths and the search field are Fira Code; labels, headings, hints, legends and prose are Inter. No third face. [woods-map#14](https://github.com/lost-in-the/woods-map/issues/14) |
| D-13 | Spacing, borders and radii | Golden-ratio spacing scale from 3px (3, 5, 8, 13, 21, 34, 55); hairline borders are 1px in `--rule`, emphasised borders 1px in `--rule2`; radii are 2px for chips and 3px for controls and panels; the only thicker edge is the 3px selection bar | No 4/8 grid, no 4px or larger radius, no coloured borders except the selection bar and the one primary button. Detail blocks sit on `--panel` with no left bar. [woods-map#15](https://github.com/lost-in-the/woods-map/issues/15) |
| D-14 | Heading hierarchy | Page title 24px, section 18px, sub-section 15px, eyebrow 11px uppercase tracked; one `h1` per page, sections are `h2`, every table or diagram inside a section is an `h3` | Explanatory captions under headings are replaced by an ⓘ control on the heading that opens the explanation in a tooltip. Screen readers get the outline; sighted readers scan by size. [woods-map#16](https://github.com/lost-in-the/woods-map/issues/16) |
| D-15 | Dates and shorthand | Relative dates use the git convention with no space (`3d`, `5w`, `7mo`, `1y`, `1y 2mo`); every shorthand is an `<abbr>` with a dotted underline on hover and a tooltip holding the long form (`3 days ago, 2026-10-13`); abbreviations in headers get the same treatment | Hint text under tables is removed; the tooltip is the hint. Counts and dates never wrap; a cell that would wrap scrolls the table instead. [woods-map#17](https://github.com/lost-in-the/woods-map/issues/17) |
| D-16 | Tooltip | One tooltip component: `--panel` background, `--rule2` border, a caret pointing at the trigger, may contain links, opens on hover and on focus, dismisses on Escape | Used by ⓘ headers, abbreviations, truncated authors, rail items and diagram legends. No native `title` tooltips in the interface except as the fallback text inside `<abbr>`. [woods-map#18](https://github.com/lost-in-the/woods-map/issues/18) |
| D-17 | Tables | Tables are fixed-layout and scroll horizontally past a visible cliff rather than breaking words; every table has one champion column, the column that names what the row is about (step, message, entry point, table, column), set in bold and placed first after the toggle and the number gutter wherever the table allows; rows that can be subdivided (steps, flows, commits) carry a 34px toggle column, padded 8px, whose checkbox selects and whose bare `+` / `−` (no box) opens a detail block; detail blocks are closed by default with one *expand all* control; the selection tint applies to the toggle cell only, never to the content cells; group parity striping applies to tables but never to rails; legends render as a key with a rule above and below, provenance aligned right | Commit rows show the description on a second row because the subject line is truncated by git's convention; authors show as git records them, truncated with the full value in the tooltip. [woods-map#19](https://github.com/lost-in-the/woods-map/issues/19) |
| D-18 | Navigation chrome | Breadcrumbs sit in a band under the bar with a copy-path control; a persistent, collapsible file-tree explorer lives at the left edge, collapsed to a 28px strip below 1280px and to a sheet behind ☰ below 960px; icon rails use Unicode glyphs (↕ ⤵ ≡ ⎘) | The tree is the only persistent navigation besides the bar; tabs show one count each. The primary action on a unit page is *Code at L18* (open the code view at the definition), not an editor deep link. [woods-map#20](https://github.com/lost-in-the/woods-map/issues/20) |
| D-19 | Responsiveness | Four tiers, driven by container queries on `.wm` so the map works in split windows as well as phones: ≥1280 full; 1279 to 960 tree strip and shorter bar; 959 to 640 rail hidden behind ☰, facts in two columns; ≤639 one column, tree in a sheet, smaller type; `pointer: coarse` grows every target to 44px | Decided before components were built, not after. Every C board shows all four widths; no tier hides data, only navigation. [woods-map#21](https://github.com/lost-in-the/woods-map/issues/21) |
| D-20 | Glyphs over assets | Unicode glyphs for every status and control mark (ⓘ ⎘ ↕ ⤵ ≡ ☰ ✓ ⚠ ●) with a fixed vocabulary table in the guidelines; no icon font, no SVG sprite | One fewer vendored asset; glyphs inherit colour and size from text. A glyph is replaced by inline SVG only if it renders inconsistently across the three supported platforms. [woods-map#22](https://github.com/lost-in-the/woods-map/issues/22) |

## Diagram renderer (18 October 2026)

Settled from the verification recorded in [woods-map#25](https://github.com/lost-in-the/woods-map/issues/25)
(Pele 1.6.0, every diagram type the boards use, themed from `tokens.css`),
under the engine's constraint that no request may need Node.

| # | Question | Decision | Consequence |
|---|---|---|---|
| D-21 | Diagram renderer | Pele, vendored and run in the browser; supersedes D-5 (Mermaid 12) | One ESM file under `vendor/javascript/` renders the Mermaid text the page already carries into SVG on the client. The text stays in the page as the fallback without JavaScript and as the *copy Mermaid* source, so the engine needs no Node at request time and no diagram is lost when scripts are off. Themes come from the eight `--pele-*` custom properties set in `tokens.css` (dark, light, colour-vision), so the Mermaid overrides at the end of the sheet go away and `classDef` colours leave the diagram text. Server-side and extraction-time rendering are not adopted: Pele renders in Node only. The ES2024 requirement of Mermaid 12 falls away; the node budget per diagram (R-4) stays the control. Lands with M3 ([woods-map#5](https://github.com/lost-in-the/woods-map/issues/5)); until then the diagram panels show the Mermaid text. [woods-map#25](https://github.com/lost-in-the/woods-map/issues/25) |

## Accessibility amendments (23 October 2026)

Settled by the maintainer on the `needs-decision` issues below. The engine
had shipped each answer while it was open; these rows make them the design.
D-22 and D-23 amend D-11, and D-24 amends B8-Code. No new hue was needed:
the palette is already the pigeon colours, and each fix either adds a
non-colour cue or lifts an existing role within its own hue.

| # | Question | Decision | Consequence |
|---|---|---|---|
| D-22 | Inline links need a cue besides colour (amends D-11) | A link sitting among other text carries a faint underline in its own hue: `--link` at 55% for the underline, the full hue on hover, 3px offset. Standalone links stay bare: the bar, tabs, tree rows and table cells (except the prose of boundary rows). | Fixes WCAG 1.4.1 (axe `link-in-text-block`). A different link colour cannot fix it. Cobalt+ is about 1.1:1 against `--mut` and 1.9:1 against `--text` in dark mode. No colour reaches 3:1 against the surrounding text while also holding 4.5:1 against `--bg`, so a colour-only cue is out. The rule lives in `map.css` under the selectors for running-text containers. The colour-vision theme keeps every link underlined. [woods-map#26](https://github.com/lost-in-the/woods-map/issues/26) |
| D-23 | Token contrast at 11–12px (amends D-11) | Four corrected values: dark `--dim` `#86919E` (from `#6E7987`); dark `--risk` `#EE665F` (from `#E64D47`); light `--dim` `#646E7B` (from `#6E7987`); light `--hot` `#A74D1A` (from `#B9561D`). The `M` and blocking chips take their text from `var(--bg)` instead of a hard-coded colour. | Every role reaches 4.5:1 on `--bg`, `--panel` and `--ground2` in both themes. The lowest is light `--dim` on `--ground2` at 4.53:1. Each value stays in its pigeon hue, so D-11's severity order and its colour-vision separation of sun, orange and beak are unchanged. Both `tokens.css` copies carry the values. Board renders made before this use the old values; regenerate them from the engine's copy. The `--hover` tint is a separate gap, tracked in [woods-map#49](https://github.com/lost-in-the/woods-map/issues/49). [woods-map#27](https://github.com/lost-in-the/woods-map/issues/27) |
| D-24 | Code view scrolling (amends B8-Code) | The code view scrolls as one region (`.cvwrap`, focusable only while it overflows). The source column grows to its longest line, and the heat strip, line numbers and marginalia stay in place with `position:sticky`. Long lines are never soft-wrapped by default at any width. | D-17's "scroll past a visible cliff" now covers code as well as tables. B8-Code's per-line `overflow-x:auto` is retired, because a keyboard could not reach it (WCAG 2.1.1, axe `scrollable-region-focusable`). Wrapping was rejected as the default: continuation lines lose their indentation, which misreads in Ruby. A `wrap` setting may exist only as an opt-in per browser (B-15), off by default. [woods-map#29](https://github.com/lost-in-the/woods-map/issues/29) |

## Sharing (24 October 2026)

Settled by the maintainer on [woods-map#57](https://github.com/lost-in-the/woods-map/issues/57).

| # | Question | Decision | Consequence |
|---|---|---|---|
| D-25 | What the Share menu offers | The Share menu offers the focus URL and the Mermaid text of the page's diagrams. It offers no Markdown or JSON report, even text handed through unchanged from Woods. Its audience is agents pulling charts into automated code review on pull requests, and people sharing architecture feedback. | Impact reports in Markdown and JSON stay with Woods (D-1): `woods:impact`, its CI comment and the `change_impact` MCP tool. The boards' *Markdown for PR* button is dropped. The `CLAUDE.md` rule "never render Markdown or JSON reports here" stands as written. Because agents are a primary audience, two things must hold: a focus URL is stable and carries no token, and every diagram's Mermaid text can be fetched without scraping HTML. **Amended by [woods-map#76](https://github.com/lost-in-the/woods-map/issues/76): the share output is paste-ready for a pull-request comment.** Each diagram's *copy for PR comment*, and its `.md` URL beside the `.mmd`, give the text in a ```` ```mermaid ```` fence plus one line linking the token-free focus URL (at `config.public_url` when set), the generation and the `.mmd` URL. That is a diagram, not a report: nothing is derived. Every text must parse with the Mermaid GitHub renders (11.16.1, checked by a spec), and a comment longer than GitHub's 65,536 characters is refused with the reason, never cut. |

## Staging hardening (24 October 2026)

Settled by the maintainer on [woods-map#59](https://github.com/lost-in-the/woods-map/issues/59); the engine shipped each option with M8 ([woods-map#10](https://github.com/lost-in-the/woods-map/issues/10)).

| # | Question | Decision | Consequence |
|---|---|---|---|
| D-26 | What a rate-limited request sees | The 403 panel's plain page: no frame and no index facts. It has an HTTP 429 eyebrow, the budget, the wait and the configuration snippet, with `Retry-After`. JSON clients get a JSON body, and the palette shows its message in the status line. | The limit runs inside the gate, before the repository opens a generation, so the page needs nothing from the index. It is not an empty state in the frame, which would have shown "no index". |
| D-27 | Token-less loopback mode | Besides a loopback peer, it requires a loopback `Host` header: `localhost`, `127.0.0.1` or `::1`. The check uses `Woods::MCP::OriginPolicy`, the same policy `woods-mcp-http` enforces. `config.allowed_origins` adds names such as `http://myapp.test`. | This blocks DNS rebinding, where a page reaches the map through the developer's browser under its own host name. It does not rely on Rails' `config.hosts`, which is empty in production and staging. A refused request gets a 403 panel that names the reason. |
| D-28 | Inline styles | Views and helpers write no `style` attribute, and `style-src` never allows `'unsafe-inline'`. Varying geometry uses bounded classes in `map.css`, column widths use the `width` hint, swatches are SVG fills, and Pele's and Cytoscape's styles are applied through the CSSOM. | A spec fails if a view or helper writes a `style` attribute. New views follow the same rule. |

## Editor links (24 October 2026)

Settled with the reading settings ([notes/settings.md](notes/settings.md)), which built it in M1.

| # | Question | Decision | Consequence |
|---|---|---|---|
| D-29 | Editor deep links | The editor scheme (a preset or a custom template with `{path}`, `{file}` and `{line}`) and the checkout path are per-browser settings, kept in browser storage; the map never guesses either from the index or the host. | *In editor at L…* appears only in a browser that names an editor whose template can be filled, and never without JavaScript; the index and the server hold no editor or checkout path. |

## Graph layout (24 October 2026)

Settled by the maintainer on [woods-map#63](https://github.com/lost-in-the/woods-map/issues/63) after the contact sheets of every candidate on the testbed's depth-1 and depth-2 neighbourhoods and the 300-unit fixture.

| # | Question | Decision | Consequence |
|---|---|---|---|
| D-30 | The layout of the Graph tab and `/woods/graph` | One layout, the butterfly the map computes: this unit alone in the middle, dependents left and dependencies right in columns by signed traversal level. No layout library is vendored. dagre was rejected at 8.8 s for 300 units and has no notion of the focus's direction; fcose at 2.0 s, and it ships only as UMD, so using it breaks the unmodified-vendor rule. Radial (Cytoscape's concentric) and the clusters layout are removed from the layout control: most of their drawings were illegible at real sizes. | The rail keeps only *reset positions*, and the position cache is keyed by generation and query alone. Domain clusters stay on Landscape Domains and Components. The butterfly is drawn for legibility: one label per pair of units, edges bundled at each hub's trunk outside its column, wrapped columns staggered so edges pass between units, and the focus centred and filled. Overview mode (no names, arrows or edge labels) starts whenever the fitted zoom is below 0.5, where Cytoscape stops drawing names, and above 120 units or 150 edges. The 300-unit first frame stays under the 500 ms budget. |

## Guide streaming (24 October 2026)

Settled by the maintainer on [woods-map#101](https://github.com/lost-in-the/woods-map/issues/101) for now; to be re-evaluated later.

| # | Question | Decision | Consequence |
|---|---|---|---|
| D-31 | A fallback for when the guide's event stream cannot open | None for now. The guide keeps one `ActionController::Live` stream per answer with a heartbeat comment (`guide_heartbeat_seconds`) and the proxy settings in [DEPLOYMENT.md §8](../DEPLOYMENT.md#8-streaming-the-m7-guide-behind-proxies). When the stream cannot open, the panel says so and names §8. | The design study's "fall back to polling Turbo Frames" is superseded. Turbo stays unvendored, and the engine starts no background work in the host. The answer runs inside the stream request, so any later fallback must first move the run out of it, either to a thread the engine starts or to the host's Active Job, and then poll the stored turn. Re-evaluate this when a deployment's proxy cannot be configured for streaming, or at the next guide milestone. |

## Open

- Boundary-row labels in flow tables (`⇒ async hop, new process: …`) are placeholders; the real label comes from the job or mailer unit named by the flow.
- The ☰ sheet and tree strip have token and layout rules but no interaction prototype yet; verify with keyboard and screen reader on the testbed before M1 closes.
- Light-mode diagram renders on the B6 boards still use the dark Mermaid theme. The engine draws with Pele from the `--pele-*` tokens in every theme (D-21, [woods-map#5](https://github.com/lost-in-the/woods-map/issues/5)); only the boards' static renders remain.
