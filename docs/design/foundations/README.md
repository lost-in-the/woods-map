# Foundations

The visual system behind every design board, handed off for the engine
(woods-map#23). Decisions D-10 to D-20 in [decisions.md](../decisions.md) are
the rules; this folder holds what they produce. The boards themselves are in
[../boards](../boards/README.md) (HTML and PNG) and on the Design canvas
([Woods Map pages](https://claude.ai/artifact/Vm2Sp2izRie5wyZ26Q6gWr)) with the review comments;
[coverage.md](../coverage.md) maps every page of the map to its board.

| File | What it is |
|---|---|
| [tokens.css](tokens.css) | The single token sheet (D-10): palette roles for dark, light and colour-vision themes, type, spacing, radii, and the component rules (tables, rails, tree, code view, diagram panel, legend, tooltip, banners, palette, guide, landscape, passage) with the container-query folds for the four widths. The engine serves this file with a content hash; views never hard-code a colour or a size. |
| [glyphs.md](glyphs.md) | The Unicode glyph vocabulary (D-20). A glyph outside this table is a review comment. |
| [components.md](components.md) | The component inventory with the priority score that ordered the work and the board each specimen lives on. |

## Theme switching

`tokens.css` defines everything on the `.wm` root. `data-theme="light"` on
that root swaps the surfaces and the six role colours to the true pigeon
palette; `data-cvd="on"` moves the *modified* role off sun so sun, orange and
beak stay apart for deuteranopia and protanopia. No other selector changes.

## Diagrams

Mermaid sources for every diagram the boards render are in
[../diagrams](../diagrams/), with `pele-render.mjs`, the script used to verify
Pele as a renderer (woods-map#25). D-21 adopts Pele in the browser, vendored
like every other module, with the Mermaid text kept in the page as the
fallback. The eight `--pele-*` variables are set from this sheet on `.wm .dia`,
as on [B9-Pele](../boards/B9-Pele.html), with `--dia-fs` for the diagram text
size; the Mermaid overrides that used to end `tokens.css` are gone.

## In the engine

The engine ships this file verbatim as `app/assets/stylesheets/woods_map/tokens.css`
(a spec keeps the copies identical) with an *engine additions* block at the
end for what the boards wrote inline; `map.css` holds the document reset and
the no-JavaScript rules; `fonts.css` declares the vendored faces. The
components below live in `app/views/woods_map/shared/` and `components/`,
the behaviours in `app/javascript/woods_map/controllers/`, and
`/woods/guidelines` renders C1 to C5 from them. The engine additions also make
the code view one scroll region with sticky gutters (woods-map#29), where the
board scrolled each line on its own.

## What the engine must add

- A Stimulus controller that toggles `more` on `.hscroll` and `.tblwrap` when
  content overflows, so the scroll cliff shows only when there is more.
- The tooltip (`.tip`) positioner: below and left-aligned, above when there is
  no room, caret at the anchor, 300 ms delay, open on focus, Escape closes.
- The tree, rail and sheet behaviour below 960px (`☰` in the bar).
- Vendored WOFF2 for Inter (400, 500, 700) and Fira Code (400, 500, 700); the
  boards load them from Google Fonts, the engine must not.
