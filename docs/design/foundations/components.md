# Component inventory

Every component the boards use, scored when the system was planned so the
specimens were built in order of risk. S size, C colour, K contrast, D
division, each 0–3 (the scale is on board B7 · Guidelines); P1 ≥ 9 got a
specimen with states at four widths before anything else was built. *built*
means a specimen exists on the named C or B8 board; *settled* means a rule with
no specimen needed.

| # | component | group | specimen | S | C | K | D | score | tier | state | note |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Code view (gutter heat, lines, marginalia, peek drawer, confidence marks) | text | B8-Code, Guide | 3 | 2 | 2 | 3 | 10 | P1 | built | B8: effective-class lens, folds, included-from blocks, unmarked, ○ and ? confidence marks; margin hides below 640 |
| 2 | Diagram styling (Mermaid overrides) | diagram | all diagram boards | 3 | 3 | 2 | 2 | 10 | P1 | built | C4: type tints, changed / risk classDef, labels on page background, crow's feet, Fira Code, native size; light-mode re-render open |
| 3 | File tree explorer (persistent, collapsible) | nav | C3, all | 3 | 1 | 2 | 3 | 9 | P1 | built | C3: open, strip, sheet, filtered, current, unindexed; D-18 |
| 4 | Rail (eyebrow heading, groups, numbered items, filters) | nav | C3, all | 3 | 1 | 3 | 2 | 9 | P1 | built | no striping in rails, group rules instead; active heading purple+; counts right-aligned |
| 5 | Responsive shell (breakpoints, collapsing regions, phone layout) | layout | C1–C5, all | 3 | 0 | 3 | 3 | 9 | P1 | built | container queries on .wm at 1279 / 959 / 639, pointer: coarse; D-19 |
| 6 | Table, bordered and striped | table | all | 3 | 1 | 2 | 3 | 9 | P1 | built | C2: fixed layout, cliff instead of word breaks, champion column bold, group-parity striping, no bullet separators; D-17 |
| 7 | Expandable row (checkbox over a bare + / −, tint on toggle cell only) | table | C2, Flows | 2 | 2 | 2 | 3 | 9 | P1 | built | hover and checked tint the toggle cell, never the content; detail on panel bg with no left bar; D-17 |
| 8 | Banner and empty state (first run, drifted, stale, degraded, refused) | layout | B8-States, all | 3 | 2 | 1 | 2 | 8 | P2 | built | 3px severity bar, one bold sentence, tools right; empty states keep the frame; the 403 has none |
| 9 | Buttons: primary, default, text tool, segmented, tabs | control | C5, all | 3 | 2 | 2 | 1 | 8 | P2 | built | one purple+ primary per page (Code at L18); default and tool buttons neutral; tabs one count each |
| 10 | Diagram panel (header band, body, legend) | diagram | C4, all diagram boards | 3 | 1 | 1 | 3 | 8 | P2 | built | band on panel, body on page background, legend as key below |
| 11 | Search palette and code-search results | control | B8-Search, all | 3 | 1 | 2 | 2 | 8 | P2 | built | four groups with counts and completeness; matches in purple+ never colour alone; results as expandable rows with snippets |
| 12 | Table header row | table | all | 3 | 0 | 3 | 2 | 8 | P2 | settled | 11px uppercase in --mut (5.9:1 on panel); abbreviations in heads get dotted underline + tooltip |
| 13 | Legend (key with rule above and below, provenance right) | diagram | C4, all diagram boards | 2 | 3 | 2 | 1 | 8 | P2 | built | glyph + words, never colour alone; tight rows; comma phrasing; D-17 |
| 14 | Passage stages, filter matrix, callback ladder | table | B8-Passage | 2 | 1 | 2 | 3 | 8 | P2 | built | stage column with a dot rail; matrix with vertical action heads, current column tinted; ladder is a steps table |
| 15 | Semantic chips: M modified, ⚑ risk, note / blocking badges, hot | chip | all | 2 | 3 | 3 | 0 | 8 | P2 | built | M sun (modified), hot orange′ (warning), ⚑ beak (risk): warm hues by severity; D-11 |
| 16 | Steps table (number gutter, process rule, call-depth indent) | table | C2, Flows, Lifecycle | 2 | 1 | 2 | 3 | 8 | P2 | built | numbers match the diagram's autonumber; boundary rows mark async hops (label wording open) |
| 17 | Links: inline, nav, goto | text | all | 3 | 2 | 2 | 0 | 7 | P2 | built | cobalt+ text, underline on hover; nav links --mut → --bright current; D-11 |
| 18 | Section header (h2, count, goto, rule) | layout | all | 3 | 0 | 1 | 3 | 7 | P2 | built | h2 18px with count; explanation moves to a ⓘ on the heading; D-14 |
| 19 | C4 container box and zoom ladder | diagram | B8-Landscape | 2 | 1 | 1 | 3 | 7 | P2 | built | «stereotype», name, technology, mechanism lines; db = double border, external = dashed |
| 20 | Detail block (dl.det) with divider and toggle column | table | C2, History, Lifecycle, ERD | 2 | 0 | 2 | 3 | 7 | P2 | built | panel background, hairline rows, no left bar, no border; + / − only on rows that have details; closed by default + expand all |
| 21 | Facts strip / tiles (eyebrow, big number, lines, layer) | layout | C5, all | 2 | 1 | 2 | 2 | 7 | P2 | built | one form: eyebrow, then dl rows (facts) or headline + rows (tiles); no big isolated number |
| 22 | Guide panel (context chips, actions, tool-call cards, streamed answer, budget) | layout | B8-Guide | 2 | 1 | 2 | 2 | 7 | P2 | built | 460px aside; links only to known identifiers; hidden below 960 |
| 23 | Matrix (coupling, amber outline) | chart | Overview | 1 | 2 | 2 | 2 | 7 | P2 | settled | colour scale c1–c4 needs AA check against text |
| 24 | Quadrant scatter | chart | Overview | 1 | 2 | 2 | 2 | 7 | P2 | settled | hot dot colour-only: add shape or label |
| 25 | Count (.n) on headings, tabs, rail | text | all | 3 | 0 | 3 | 0 | 6 | P2 | settled | Fira Code 12px --mut; one count per tab or heading |
| 26 | Layer chip (.lyr) | chip | all | 3 | 0 | 3 | 0 | 6 | P2 | settled | 11px --mut; provenance, never meaning; no leading dot |
| 27 | Page title block (crumbs band, h1, data subtitle) | layout | C5, all | 3 | 0 | 1 | 2 | 6 | P2 | built | breadcrumbs in a band under the bar with ⎘ copy path; subtitle is data only, comma separated |
| 28 | Status bar with kbd keys | layout | all | 3 | 0 | 2 | 1 | 6 | P2 | settled | spans separated by gap |
| 29 | Top bar (logo, search, nav, freshness, Guide, ☰ below 960) | layout | C5, all | 3 | 1 | 1 | 1 | 6 | P2 | built | no bottom rule; search in Fira Code; ☰ fixed top-left below 960 |
| 30 | Commit row (subject, description row, author as recorded, truncated) | table | C2, History | 2 | 0 | 2 | 2 | 6 | P2 | built | description on a second row; author shown as git records it, truncated with the full value on hover; D-17 |
| 31 | Meta and caption lines | text | all | 3 | 0 | 2 | 0 | 5 | P3 | built | hint text removed from boards; what remained became tooltips or ⓘ |
| 32 | Empty values (—, none, nil) | text | all tables | 2 | 0 | 3 | 0 | 5 | P3 | settled | — for not applicable, none for known-empty, both --dim |
| 33 | Commit strip (bars, generation markers) | chart | History | 1 | 2 | 1 | 1 | 5 | P3 | settled |  |
| 34 | Treemap bars | chart | Overview | 1 | 1 | 1 | 2 | 5 | P3 | settled |  |
| 35 | Relative dates (abbr with absolute on hover) | text | all | 3 | 0 | 1 | 0 | 4 | P3 | built | git convention 3d 5w 7mo 1y, no space;  tooltip '3 days ago, 2026-10-13'; D-15 |
| 36 | Author name (.who) | text | History, facts | 2 | 0 | 2 | 0 | 4 | P3 | built | max-width with ellipsis, full name in the tooltip; names or usernames as recorded |
| 37 | Tooltip (caret, may hold links) | text | C5, all | 2 | 0 | 2 | 0 | 4 | P3 | built | one component, panel bg, rule2 border, caret; used by ⓘ, abbr, authors, rail; D-16 |
| 38 | Checkbox and filters | control | C2, Flows, Graph | 1 | 2 | 1 | 0 | 4 | P3 | built | accent-color purple+; label is the hit area; 22px on coarse pointers |
| 39 | Icon rail (diagram type) with tooltip | control | C4, Flows | 1 | 1 | 2 | 0 | 4 | P3 | built | Unicode glyphs ↕ ⤵ ≡ ⎘, pressed state purple+ border; D-20 |
| 40 | Inline code and kbd | text | all | 2 | 0 | 1 | 0 | 3 | P3 | settled | Fira Code, no chip background inside the map |
