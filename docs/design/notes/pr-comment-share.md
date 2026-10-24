# Share output for a pull-request comment

Scope: [woods-map#76](https://github.com/lost-in-the/woods-map/issues/76). It
follows D-25 as amended
([woods-map#57](https://github.com/lost-in-the/woods-map/issues/57)), and
relates to D-21 (#25) and M3 (#5).

People and agents paste the map's diagrams into GitHub pull-request comments.
GitHub must draw what they paste. The map never posts a comment itself.

## GitHub's Mermaid

GitHub draws a ```` ```mermaid ```` block in the browser with its own Mermaid
build. It does not publish the version. Its documentation says to check by
rendering an `info` diagram in a comment.

The latest such check on record is GitHub Community discussion
[#70672](https://github.com/orgs/community/discussions/70672). On 20 August
2026 it read **11.16.1**.

`spec/diagrams/github_mermaid_spec.rb` holds the map to that version:

- **Parse check, everywhere.** It parses every text the map generates with that
  exact build (`mermaid@11.16.1`, `dist/mermaid.min.js`). These are the 229
  texts the Pele render spec draws. The check runs in Node at test time, and
  in CI.
- **Render check, with a browser.** With `WOODS_MAP_BROWSER` set, it also draws
  each text with `mermaid.render` in headless Chromium, under strict security
  as on GitHub.
- **Live checks.** A broken text must fail. Every keyword in
  `MermaidExport::NEWER_THAN_GITHUB` must be rejected as an unknown type.
- **Pinned.** The build is vendored under `spec/vendor/github_mermaid`, where
  the README records its checksums and how to update it.
  `MermaidExport::GITHUB_MERMAID_VERSION` names it.

**What it cannot prove:**

- that GitHub still runs 11.16.1 today;
- what GitHub's own page does beyond the library.

One manual paste of `info` and of a diagram confirms both.

### Per type

| Keyword | Map diagrams | Texts in the spec | Parses with 11.16.1 | Renders with 11.16.1 (Chromium) | GitHub variant |
|---|---|---:|---|---|---|
| `erDiagram` | Schema ER, ERD chunks, the Trail's ERD of pinned | 54 | yes | yes | none needed |
| `classDiagram` | Schema class diagram | 3 | yes | yes | none needed |
| `stateDiagram-v2` | state machines on Lifecycle | 2 | yes | yes | none needed |
| `sequenceDiagram` | Lifecycle sequence (model events and entries), Passage | 19 | yes | yes | none needed |
| `flowchart` | Lifecycle flowchart, entry lanes, Trail lanes, Graph neighbourhood, impact paths, Trail graph of pinned, C4 containers, context, components and dynamic views | 98 | yes | yes | none needed |
| `swimlane-beta` | Lifecycle lanes view of a model event | 3 | yes | yes | none needed: added in Mermaid 11.16.0, so GitHub's 11.16.1 knows it |
| `timeline` | History timeline, the cross-unit timeline | 23 | yes | yes | none needed |
| `xychart-beta` | History XY chart | 22 | yes | yes | none needed |
| `quadrantChart` | Hotspots quadrant | 1 | yes | yes | none needed |
| `sankey-beta` | Hotspots forward flow | 1 | yes | yes | none needed |
| `treemap-beta` | Hotspots treemap | 2 | yes | yes | none needed |
| `mindmap` | Domains mindmap | 1 | yes | yes | none needed |

**No variant is needed.** No generated text needs a GitHub variant, so the map
serves one text per diagram and has no `?for=github` parameter. The lanes view
was the expected exception. It was marked "may not render on GitHub" while the
version was unmeasured, and it is not one.

**Newer types.** Mermaid 12's `usecase-beta` and `agentflow-beta` are the only
types 11.16.1 does not register. The map generates neither.

**When a check fails.** If a later text fails to parse, the spec fails in CI.
The fix is then syntax that both Pele and Mermaid accept, or a GitHub variant
for the copy, `.mmd` and `.md` while the page keeps Pele's text. Update this
table either way.

## ⎘ copy for PR comment

Every diagram panel offers it beside `⎘ copy Mermaid` and `⤓ .mmd`
(`components/mermaid_tools`). The Share menu lists it in each diagram's row as
`⎘ for PR comment`. It copies:

````markdown
```mermaid
<the panel's Mermaid text, unchanged>
```
[Woods Map, <diagram name>, gen <N>](<focus URL>) · [Mermaid text](<.mmd URL>)
````

- **The focus URL** is the page's absolute address and query (E-6), with no
  token (D-4). It starts at `config.public_url` when one is set.
- **The generation** is the one the text was drawn from. The link opens
  whatever generation is current: pages read the published generation, and
  no URL pins one. So the label names the generation the reader is looking at.
- **The `.mmd` URL** is the panel's own. Without one, the line links only the
  view.
- **The fence** is longer than any run of backticks in the text, so the text
  cannot close it (CommonMark).
- **The label** escapes Markdown punctuation. The URLs percent-encode spaces,
  parentheses and angle and square brackets.

**Limits.**

- **Over GitHub's limit.** A GitHub comment holds 65,536 characters. A longer
  comment is not offered. The panel shows "too long for a PR comment (N of
  65,536 characters)" in its place, and the Share menu names the diagram with
  the reason: "Too long for a GitHub comment: N characters, over its limit of
  65,536. Share the .mmd URL instead." The map never cuts a fence.
- **Over a drawing budget (R-4).** No comment is offered, because the `.mmd`
  answers 422.
- **Without JavaScript.** The copy needs a script (`data-needs-js`). The `.md`
  URL below is the same text with no script.

## `.md` beside every `.mmd`

Each `.mmd` route has a `.md` twin that answers with the comment as
`text/markdown`. Agents can fetch it directly:

- `units/:type/:id/{schema,passage,lifecycle,graph,history}.md`
- `impact.md`, `erd.md`, `history.md`, `trail.md`
- `landscape.md` and `landscape/:diagram.md`

**Rules.** The routes share the `.mmd` routes' controller paths and every rule
they follow:

- the token is taken from the bearer header or the session cookie, never from
  the URL;
- the rate limit is the same;
- 401, 403, 404, 429 and 503 answer in plain text.

**What the `.md` adds.**

- Its link line points at the page that draws the diagram. On Landscape that is
  the tab: `quadrant.md` links Hotspots.
- A diagram over its budget is 422 with the `.mmd` reason.
- A comment over GitHub's limit is 422 with "Too long for a GitHub comment: …".
- `X-Woods-Generation` names the generation, and `Content-Disposition` names a
  `.md` file.

## `config.public_url`

Behind a proxy or on a staging host, the request's origin can be an internal
name reviewers cannot open. `config.public_url` (or `WOODS_MAP_PUBLIC_URL`)
replaces it in every absolute link the map hands out:

- focus URLs;
- the Share menu's `.mmd` URLs;
- the comment's links;
- a 422's page link.

**Its value** is an absolute http(s) URL. A path prefix that a proxy strips may
follow the host. Credentials, a query or a fragment are refused at boot.

**It writes links only.** Origin checks keep using `config.allowed_origins`
(D-27). See [DEPLOYMENT.md §5](../../DEPLOYMENT.md#5-reverse-proxy).

## Woods

Review agents usually talk to the Woods Index MCP server, not the map. Woods
offers Mermaid only through `change_impact` (`format: mermaid`), which is wired
when a snapshot store is. Its impact text also parses with 11.16.1.

[woods#826](https://github.com/lost-in-the/woods/issues/826) proposes three
pieces in Woods:

- `Woods::Diagrams`, with neighbourhood, schema, lifecycle and impact;
- a `diagram` MCP tool;
- a `woods:diagram` task.

The map's view objects would then delegate to `Woods::Diagrams` for those
kinds. Woods never depends on the map.

## Validation

- **Specs:** `bin/rake spec` with `WOODS_MAP_BROWSER` and `WOODS_MAP_RENDER_SPEC=1`: 1069 examples, 0 failures, 6 pending (the macOS-only JavaScriptCore specs). RuboCop: no offenses.
  - `spec/diagrams/github_mermaid_spec.rb`:
    - 229 of 229 texts parse;
    - the Chromium render draws all 229;
    - the broken controls fail;
    - `usecase-beta` and `agentflow-beta` are rejected.
  - `spec/requests/pr_comment_spec.rb` covers the panel, `config.public_url` and every `.md` route family: auth, 401 and 429 in text, 422 for a budget or the limit, and the Landscape tabs.
  - `spec/woods_map_share_spec.rb` (Chromium) runs at four widths: one PR comment copy per diagram row, and the reason in place of a copy over the limit.
- **Testbed:** an isolated `woods-testbed` `rails-8.0` copy after a fresh `woods:extract`.
  - **Crawl.** A crawl of 433 pages over 53 units, three per type, found 383 distinct `.mmd` URLs.
  - **Shape.** Every `.md` twin answered 200 in the shape above, with a fenced text equal to its `.mmd`.
  - **GitHub's Mermaid.** All 383 parse with 11.16.1, and all 383 render with it in Chromium: 170 flowcharts, 57 sequences, 55 ER, 53 class, 45 swimlanes, and one mindmap, sankey and treemap.
- **axe-core 4.14:** 0 violations in 28 scans:
  - the lanes view, the Schema tab with the Share menu open, the Graph tab, the ERD, Landscape and the impact page, each at 1440, 960, 640 and 390;
  - light at 960 and 640;
  - the panels clipped at 390;
  - five more scans with a text over the limit (limit lowered in a testbed initializer, `config.public_url` set).
- **Below 640:** the tool band of a panel now wraps its tools, and the reason for a missing comment wraps with them.
