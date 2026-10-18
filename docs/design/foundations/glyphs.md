# Glyph vocabulary

Every icon in the map is a Unicode character in the text, coloured by the
token it sits in (D-20): no icon font, no sprite, no image requests. Fira Code
covers the arrows and box drawing; what it lacks falls through to the system
font, which is acceptable for a glyph and never for text. Each glyph has an
`aria-label` or sits next to its word, and every glyph that acts is a real
control: the `+` / `−` row toggle is a `<button>`, a checkbox is an `<input>`.
One glyph, one meaning, everywhere; a new need adds a row here first.

| glyph | meaning | where |
|---|---|---|
| + − | closed, open (row toggle) | subdivided rows |
| ▸ ▾ | closed, open | accordions, tree folders |
| → ⇒ ⇢ | call, async hop, return | steps, legends, sequence |
| ⚑ | risk (red), warning (orange) | chips, rail, diagrams, tree |
| M hot | modified, churn | cells, tree, facts |
| ● ○ | current, stale index; one, many on ER | top bar, legends |
| ⌕ ☰ ✕ ⓘ | search, menu, close, explain | top bar, panels, section headers |
| ⎘ ↗ ‹ › | copy, open outside, collapse, expand | tools, tree strip, breadcrumb |
| ↕ ⤵ ≡ | sequence, flowchart, lanes | the diagram icon rail (with tooltips) |
| ▲ ▼ ⇅ | up, down, sortable | trend cells, table heads |
| — … | not applicable, more | empty cells, truncated paths |

Row toggles are `+` closed and `−` open (D-17), bare, no box. Confidence marks
on code references: unmarked = runtime-verified, `○` static, `?` ambiguous
(B-11). Freshness in the top bar: `●` green current, orange drifted, yellow
stale, `○` no index.
