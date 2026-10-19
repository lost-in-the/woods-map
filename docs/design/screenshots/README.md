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
| Guidelines, C4 diagrams (panel and legend; the renderer is M3) | [C4-Diagrams](../boards/C4-Diagrams.html) | [1440](guidelines-c4-diagrams-1440.png) |
| Guidelines, C5 chrome | [C5-Chrome](../boards/C5-Chrome.html) | [1440](guidelines-c5-chrome-1440.png), [the tooltip open](guidelines-tooltip-1440.png) |
| Unit page, Code tab (`/woods/units/model/User`) | [B8-Code](../boards/B8-Code.html) | [1440](unit-code-1440.png), [effective lens](unit-code-effective-1440.png), [960](unit-code-960.png), [390](unit-code-390.png), [peek open](unit-code-peek-1440.png), [☰ sheet at 390](unit-code-sheet-390.png) |
| Schema tab | [B6-Schema](../boards/B6-Schema.html) | [1440](unit-schema-1440.png) |
| Lifecycle tab | [B6-Lifecycle](../boards/B6-Lifecycle.html) | [1440](unit-lifecycle-1440.png) |
| Graph tab (the list equivalent; the drawn graph is M5) | [B6-Graph](../boards/B6-Graph.html) | [1440](unit-graph-1440.png) |
| History tab | [B6-History](../boards/B6-History.html) | [1440](unit-history-1440.png) |
| Controller unit page | [B8-Code](../boards/B8-Code.html), outline of actions and filters | [1440](controller-1440.png) |
| Table, template and route unit pages (type-specific tiles are an M1 gap in coverage.md) | B6/B8 frame | [table](table-1440.png), [template](template-1440.png), [route](route-1440.png) |
| No such unit (404) | [B8-States](../boards/B8-States.html), *empty results* panel | [1440](missing-1440.png) |
| Search page: name, code, empty | [B8-Search](../boards/B8-Search.html) | [name](search-name-1440.png), [code](search-code-1440.png), [empty](search-empty-1440.png), [390](search-390.png) |
| Search palette | [B8-Search](../boards/B8-Search.html), *the palette* panel | [1440](search-palette-1440.png) |
| Freshness words with Woods' reasons | [C5-Chrome](../boards/C5-Chrome.html), the bar | [tooltip open](freshness-tip-1440.png) |
| Passage tab, controller action (`…/UsersController/passage?action_name=show`) | [B8-Passage](../boards/B8-Passage.html) | [1440](passage-1440.png), [create, with the callback ladder](passage-create-1440.png), [390](passage-390.png) |
| Passage tab, mailer action | [B8-Passage](../boards/B8-Passage.html) (the mailer passage is undesigned; the controller passage is reused) | [1440](passage-mailer-1440.png) |
| Guidelines at 960, 640 and 390 | the four-widths rows of C2, C3 and C5 | inside the C2 and C5 clips above; the whole page is too tall to keep as a PNG, regenerate it with the runner |

Diagram panels on the Schema and Lifecycle tabs show the Mermaid source until
the renderer lands (M3, woods-map#25); the Graph tab shows the list equivalent.

Fonts: the first-run, refused and session-form screenshots predate the vendored
Inter and Fira Code (woods-map#23) and fall back to the system faces; the
status and guidelines screenshots use the vendored faces.
