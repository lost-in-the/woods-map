# Engine screenshots

What the engine renders, taken with Playwright (Chromium) against the
`woods-testbed` `rails-8.0` variant after `woods:extract`, so each page can be
read beside the board that designs it. Every screenshot in this folder was
taken on a page where axe-core (WCAG 2.0 A/AA, 2.1 AA, best practice) reported
no violations. Regenerate with the runner described in each pull request; the
widths are the tiers of D-19.

| Page | Board | Screenshots |
|---|---|---|
| Status page (`/woods`) | [B8-States](../boards/B8-States.html), *stale: the status page* panel | [1440](status-1440.png), [960](status-960.png), [390](status-390.png) |
| First run, no index published | [B8-States](../boards/B8-States.html), *first run* panel | [1440](first-run-1440.png) |
| Refused, non-loopback host without a token | [B8-States](../boards/B8-States.html), *non-loopback host without a token* panel | [1440](refused-1440.png), [640](refused-640.png) |
| Session form (token configured, no cookie yet) | not designed; the 403 panel's structure with a form | [1440](session-form-1440.png) |
| Guidelines, C1 tokens (`/woods/guidelines#tokens`) | [C1-Tokens](../boards/C1-Tokens.html) | [1440](guidelines-c1-tokens-1440.png) |
| Guidelines, C2 table | [C2-Table](../boards/C2-Table.html) | [1440](guidelines-c2-table-1440.png), [a detail block opened](guidelines-rows-open-1440.png) |
| Guidelines, C3 navigation | [C3-Navigation](../boards/C3-Navigation.html) | [1440](guidelines-c3-navigation-1440.png), [the ☰ sheet at 390](guidelines-sheet-390.png) |
| Guidelines, C4 diagrams (a sequence drawn by Pele, at natural width, scrolling) | [C4-Diagrams](../boards/C4-Diagrams.html), [B9-Pele](../boards/B9-Pele.html) | [1440](guidelines-c4-diagrams-1440.png) |
| Guidelines, C5 chrome | [C5-Chrome](../boards/C5-Chrome.html) | [1440](guidelines-c5-chrome-1440.png), [the tooltip open](guidelines-tooltip-1440.png) |
| Unit page, Code tab (`/woods/units/model/User`) | [B8-Code](../boards/B8-Code.html) | [1440](unit-code-1440.png), [effective lens](unit-code-effective-1440.png), [960](unit-code-960.png), [390](unit-code-390.png), [peek open](unit-code-peek-1440.png), [☰ sheet at 390](unit-code-sheet-390.png) |
| Schema tab (`Post`, the ER drawn by Pele) | [B6-Schema](../boards/B6-Schema.html) | [1440](unit-schema-1440.png) |
| Lifecycle tab (`Post` create, the sequence drawn by Pele) | [B6-Lifecycle](../boards/B6-Lifecycle.html) | [1440](unit-lifecycle-1440.png), [the panel at 390](unit-lifecycle-390.png), [light](unit-lifecycle-light-1440.png) |
| Graph tab (`Post`, the neighbourhood flowchart drawn by Pele above the list equivalent; the interactive canvas is M5) | [B6-Graph](../boards/B6-Graph.html), [B9-Pele](../boards/B9-Pele.html) | [1440](unit-graph-1440.png), [light](unit-graph-light-1440.png), [colour-vision](unit-graph-cvd-1440.png), [*Mermaid text* pressed](unit-graph-text-1440.png) |
| History tab | [B6-History](../boards/B6-History.html) | [1440](unit-history-1440.png) |
| Controller unit page | [B8-Code](../boards/B8-Code.html), outline of actions and filters | [1440](controller-1440.png) |
| Table, template and route unit pages (type-specific tiles are an M1 gap in coverage.md) | B6/B8 frame | [table](table-1440.png), [template](template-1440.png), [route](route-1440.png) |
| No such unit (404) | [B8-States](../boards/B8-States.html), *empty results* panel | [1440](missing-1440.png) |
| Search page: name, code, empty | [B8-Search](../boards/B8-Search.html) | [name](search-name-1440.png), [code](search-code-1440.png), [empty](search-empty-1440.png), [390](search-390.png) |
| Search palette | [B8-Search](../boards/B8-Search.html), *the palette* panel | [1440](search-palette-1440.png) |
| Freshness words with Woods' reasons | [C5-Chrome](../boards/C5-Chrome.html), the bar | [tooltip open](freshness-tip-1440.png) |
| Routes tab, controller (`…/UsersController/routes`) | [Routes tab note](../notes/routes-tab.md) (no board) | [1440](routes-1440.png), [390](routes-390.png) |
| Hover card on a reference, Code tab (`…/model/User`, hovered at 1440, focused at 390) | [Hover card note](../notes/hover-card.md) (no board) | [1440](hover-card-1440.png), [390](hover-card-390.png) |
| Reading settings on the Code tab (`…/model/User`) | [Settings note](../notes/settings.md) (no board) | [dialog 1440](settings-1440.png), [dialog 390](settings-390.png), [editor set, 390](settings-editor-390.png), [wrap on, 390](settings-wrap-390.png) |
| Share menu open, unit tab and impact page (`…/User/schema`, `/woods/impact?focus=User`) | [Share menu note](../notes/share-menu.md) (no board) | [1440](share-1440.png), [impact 390](share-impact-390.png) |
| Passage tab, controller action (`…/UsersController/passage?action_name=show`) | [B8-Passage](../boards/B8-Passage.html) | [1440](passage-1440.png), [create, with the callback ladder](passage-create-1440.png), [390](passage-390.png) |
| Passage tab, mailer action | [B8-Passage](../boards/B8-Passage.html) (the mailer passage is undesigned; the controller passage is reused) | [1440](passage-mailer-1440.png) |
| Impact, pre-change mode (`/woods/impact?focus=User&depth=2`): Changed with a path opened | [B8-Impact-Changed](../boards/B8-Impact-Changed.html), the frame with a focus title | [1440](impact-changed-open-1440.png), [390](impact-390.png) |
| Impact, Risks | [B8-Impact-Risks](../boards/B8-Impact-Risks.html) | [1440](impact-risks-1440.png) |
| Impact, Tests | [B8-Impact-Tests](../boards/B8-Impact-Tests.html) | [1440](impact-tests-1440.png) |
| Impact, Unknown | [B8-Impact-Unknown](../boards/B8-Impact-Unknown.html) | [1440](impact-unknown-1440.png) |
| Impact, a range without a report (W-12) | [B8-States](../boards/B8-States.html), *first run* panel's structure | [1440](impact-range-1440.png) |
| Guidelines at 960, 640 and 390 | the four-widths rows of C2, C3 and C5 | inside the C2 and C5 clips above; the whole page is too tall to keep as a PNG, regenerate it with the runner |

Diagram panels are drawn by the vendored Pele in the browser (D-21) on the
blog scenario of the `rails-8.0` testbed; without JavaScript, or when Pele
refuses a text, they show the Mermaid source. The engine ships dark only, so
the light and colour-vision captures set `data-theme` and `data-cvd` on the
page before drawing.

Fonts: the first-run, refused and session-form screenshots predate the vendored
Inter and Fira Code (woods-map#23) and fall back to the system faces; the
status and guidelines screenshots use the vendored faces.
