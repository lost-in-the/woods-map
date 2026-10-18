# Boards

The design boards, one self-contained HTML file and one PNG at 1440px each, so
anyone working in this repository, a person or an agent, can see the design
without the canvas. The HTML is the source of truth here: open it in a
browser, or run `python3 render.py` (Playwright + Chromium) to regenerate the
PNGs. Each file inlines `foundations/tokens.css` and loads Inter and Fira Code
from Google Fonts; nothing else is fetched. The canvas on claude.ai holds the
same boards with the review comments.

Read [../coverage.md](../coverage.md) for which page each board designs and
what is not designed yet. Three groups:

## Pages (v7 and v8 on tokens)

| Board | Page | Shows |
|---|---|---|
| [B8-Code](B8-Code.html) ([png](B8-Code.png)) | unit page, Code tab | effective-class lens, outline rail, heat gutter, marginalia, peek drawer, included-concern folds, confidence marks |
| [B6-Schema](B6-Schema.html) ([png](B6-Schema.png)) | unit page, Schema tab | ER one hop (rendered), associations, columns, database facts |
| [B6-Lifecycle](B6-Lifecycle.html) ([png](B6-Lifecycle.png)) | unit page, Lifecycle tab | sequence with autonumber, 12 numbered steps with detail rows, state machine and transitions |
| [B6-Graph](B6-Graph.html) ([png](B6-Graph.png)) | unit page, Graph tab | neighbourhood flowchart, filters, edge table |
| [B6-History](B6-History.html) ([png](B6-History.png)) | unit page, History tab | commit strip, commits with description rows, people, co-change |
| [B8-Passage](B8-Passage.html) ([png](B8-Passage.png)) | controller action, Passage tab | stages, filter matrix, callback ladder, mismatch flag, export |
| [B8-Search](B8-Search.html) ([png](B8-Search.png)) | search | code-search results, the palette |
| [B8-Guide](B8-Guide.html) ([png](B8-Guide.png)) | guide panel | context chips, actions, tool-call cards, streamed answer, budget |
| [B8-Landscape](B8-Landscape.html) ([png](B8-Landscape.png)) | Landscape, Containers | C4 L2 boxes, zoom ladder, relationships, structural risk |
| [B6-Overview](B6-Overview.html) ([png](B6-Overview.png)) | Landscape, Hotspots | quadrant, coupling matrix, sankey, treemap, structural risk |
| [B6-ERD](B6-ERD.html) ([png](B6-ERD.png)) | /woods/erd | whole database by chunk, findings |
| [B8-Impact-Changed](B8-Impact-Changed.html) ([png](B8-Impact-Changed.png)) | Impact, Changed | changed units as subdivided rows, edge facts, finding, diff |
| [B8-Impact-Risks](B8-Impact-Risks.html) ([png](B8-Impact-Risks.png)) | Impact, Risks | findings with evidence, rule registry |
| [B6-Impact-Flows](B6-Impact-Flows.html) ([png](B6-Impact-Flows.png)) | Impact, Flows | entry points through changed units, numbered steps, async boundaries, sequence per flow |
| [B8-Impact-Tests](B8-Impact-Tests.html) ([png](B8-Impact-Tests.png)) | Impact, Tests | run first, gaps |
| [B8-Impact-Unknown](B8-Impact-Unknown.html) ([png](B8-Impact-Unknown.png)) | Impact, Unknown | unknowns, what each layer proves |
| [B8-States](B8-States.html) ([png](B8-States.png)) | states | first run, drifted, stale, degraded, empty, guide unavailable, refused, status page |
| [B8-Widths](B8-Widths.html) ([png](B8-Widths.png)) | responsiveness | the Changed page at 960, 640 and 390 from the same markup |

## Foundations and components

| Board | Shows |
|---|---|
| [B7-Guidelines](B7-Guidelines.html) ([png](B7-Guidelines.png)) | priority scoring, component inventory, token audit with contrast, typography, colour-vision and light mode, the twelve rules, decision ledger |
| [C1-Tokens](C1-Tokens.html) ([png](C1-Tokens.png)) | palette in three themes, type, spacing, borders, glyphs, dates |
| [C2-Table](C2-Table.html) ([png](C2-Table.png)) | table anatomy, detail blocks, steps, expandable row states, four widths, light and CVD |
| [C3-Navigation](C3-Navigation.html) ([png](C3-Navigation.png)) | rail, file tree (open, filtered, strip), the ☰ sheet at 960, 640 and 390 |
| [C4-Diagrams](C4-Diagrams.html) ([png](C4-Diagrams.png)) | sequence, neighbourhood, ER and state panels with legends; phone full-screen |
| [C5-Chrome](C5-Chrome.html) ([png](C5-Chrome.png)) | top bar, breadcrumb band, title block, tabs, facts tiles, status bar, buttons, chips, tooltip |
| [B9-Pele](B9-Pele.html) ([png](B9-Pele.png)) | the Pele renderer test for woods-map#25: four diagrams, dark and light from one SVG |

The B6 boards carry their own board-level styles ahead of the inlined tokens
(they were retrofitted); the B8 and C boards are generated straight from the
tokens and are the better reference for markup.
