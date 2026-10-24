# Mermaid text URLs

Scope: D-25 (woods-map#57, #66), constraint 3 of
[mermaid-diagram-types.md](../mermaid-diagram-types.md), FR-6, E-6. M3,
[woods-map#5](https://github.com/lost-in-the/woods-map/issues/5).

Every diagram the map draws can be fetched as plain Mermaid text from a
stable URL. Agents reviewing a pull request get the chart without scraping
HTML. The text is byte for byte what the panel draws, plus a final newline.

## Grammar

| Diagram | URL | Parameters (closed choices; unknown values fall back to the page's default) |
|---|---|---|
| Schema ER | `/woods/units/:type/:identifier/schema.mmd` | — |
| Lifecycle | `/woods/units/:type/:identifier/lifecycle.mmd` | `event` = create, update or destroy; `view` = flowchart or lanes (the sequence when omitted) |
| State machine | `/woods/units/state_machine/:identifier/lifecycle.mmd` | — (a state machine unit's lifecycle is its state diagram) |
| Graph neighbourhood | `/woods/units/:type/:identifier/graph.mmd` | `depth` = 1 or 2; `direction` = both, dependents or dependencies; `types[]`, `via[]` |
| Passage | `/woods/units/:type/:identifier/passage.mmd` | `action_name` |
| Impact paths | `/woods/impact.mmd` | `focus` (required), `depth`, `types[]`, `via[]`, `show` |
| ERD chunk | `/woods/erd.mmd` | `chunk` = 1…n; `by` = namespace or database; `columns` = keys or all |

- `:identifier` is the unit's identifier as on its page. Dots and slashes are fine (`users/show.html.erb`). A `.mmd` suffix is never read as part of one, because the `.mmd` routes come before the glob routes.
- Only the route sets the format (the `mmd` path default). A query parameter cannot turn a page into text.
- The routes read the generation currently published, as the pages do. The answer names it in an `X-Woods-Generation` header. There is no generation parameter yet (W-11).
- Each panel's ⤓ `.mmd` link (`a[data-mermaid-url]`, `rel="alternate"`, `type="text/plain"`) is the URL for that exact view. The Share menu can reuse it.

## Answers

| Status | When | Body |
|---|---|---|
| 200 `text/plain` | the diagram is within its budget | the Mermaid text, `Content-Disposition: inline` with a `.mmd` file name |
| 422 | the diagram is over its R-4 budget | the reason ("41 tables is over the ER budget of 40") and the page that lists everything; never a truncated diagram |
| 400 | `/woods/impact.mmd` without a focus | how to name one |
| 404 | an unknown unit or chunk, a tab the type does not have, an impact range (Woods' report is the range export, D-1) | what is missing |
| 401 | a token is configured and neither the `Authorization: Bearer` header nor the session cookie is present | `WWW-Authenticate: Bearer`. A `?token=` is never exchanged on these routes, so no token ends up in a URL that gets shared |
| 403 | the host's `authorize` hook or the token gate refuses | one line, with no index facts |
| 503 | no published index | one line |

## Limits

- Structurizr DSL and LikeC4 need container attribution (W-9, [woods#759](https://github.com/lost-in-the/woods/issues/759)) and are not served.
- Diagram types newer than GitHub's Mermaid (only `swimlane-beta` among the generated ones) carry a "may not render on GitHub" mark in the panel. GitHub's actual version is still unmeasured.
