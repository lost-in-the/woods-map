# Vendored fonts

The two faces of D-12, served by the engine's own assets route beside
`woods_map/fonts.css`, which declares them with relative URLs. The engine never
loads a font from the network.

| Family | Files | Version | License | Source |
|---|---|---|---|---|
| Inter | `inter/inter-{latin,latin-ext}-{400,500,700}-normal.woff2` | @fontsource/inter 5.3.0 (Inter 4.1) | OFL-1.1 (`inter/LICENSE`) | https://www.npmjs.com/package/@fontsource/inter |
| Fira Code | `fira-code/FiraCode-{Regular,Medium,Bold}.woff2` | Fira Code 6.2 (release `woff2/`) | OFL-1.1 (`fira-code/LICENSE`) | https://github.com/tonsky/FiraCode/releases/tag/6.2 |

The Inter files are the unmodified Google Fonts subsets Fontsource publishes,
with Fontsource's `unicode-range` in `fonts.css`; interface text needs no
more. Fira Code ships complete because the glyph vocabulary (D-20) leans on
its arrows and box drawing; a glyph it lacks falls through to the system
font, which D-20 accepts for a glyph and never for text.
