# Vendored JavaScript

Third-party modules served by the engine's own assets route and pinned in
`lib/woods_map/importmap.rb`. Each file is an unmodified, self-contained ES
module copied from the package's published build, with the package name,
version, license and source recorded here when added.

| Module | File | Version | License | Source |
|---|---|---|---|---|
| `@hotwired/stimulus` | `stimulus.js` | 3.2.2 (`dist/stimulus.js`) | MIT (`stimulus.LICENSE.md`) | https://www.npmjs.com/package/@hotwired/stimulus |
| `pele` | `pele.js` | 1.6.0 (`dist/pele.js`, npm integrity `sha512-VfAiVItsOGlGhvnBfphdT28VCG7mXMZxQNOwAGsCtxI2ztbUsT39MraEOYjsapLxVETkdUZscm0DdotYDQMLdw==`) | MIT (`pele.LICENSE.md`) | https://www.npmjs.com/package/pele |
| `cytoscape` | `cytoscape.esm.min.mjs` | 3.34.3 (`dist/cytoscape.esm.min.mjs`, npm integrity `sha512-yfYGhRcGAntq6YBD583j4n0Eg3jIxvWmZtz/5uz9UYkeIStSlMxuUja+ec5j3iBD8nv1rwaOAYMW09tBdkSeaQ==`) | MIT (`cytoscape.LICENSE.md`) | https://www.npmjs.com/package/cytoscape |

Cytoscape is loaded on demand by the Graph tab's canvas (M5), as Pele is by
the diagram panels. Its ESM build has no imports of its own. Layout
extensions are not vendored: fcose ships only as UMD bundles, and the dagre
extension's ESM build took seconds on a 300-unit neighbourhood, so the
butterfly layout is computed by the graph controller and the radial one is
Cytoscape's built-in concentric layout (woods-map#7; the layout decision is
[woods-map#63](https://github.com/lost-in-the/woods-map/issues/63)).
