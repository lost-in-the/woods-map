# Changelog

## [Unreleased]

- Design system (woods-map#23): Inter and Fira Code vendored and served beside `fonts.css`; one content digest for the whole asset set; Stimulus vendored with six controllers (scroll cliff, tooltip, subdivided rows, file tree, ☰ sheet, copy); partials for the bar, breadcrumb band, title block, tabs, status bar, banners, empty states, tables with detail blocks and steps, rail, tree, legend, diagram panel and facts tiles; the glyph vocabulary as `WoodsMap::Glyphs`; `/woods/guidelines` renders the C1 to C5 boards from the same partials. Token corrections for AA contrast (woods-map#27) and a faint underline on inline links (woods-map#26).
- Design study, decision log and milestone plan under `docs/design/`.
- Engine scaffold: configuration, authentication (bearer token, `?token=` and form exchange for a signed cookie, host `authorize` hook, loopback default with a boot warning), the 403 panel and first-run empty state from the States board, status page over one pinned generation, the token sheet served with a content hash, engine-served assets with a literal import map.
