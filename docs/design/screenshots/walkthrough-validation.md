# Trail walkthrough spike receipt

Captured on an isolated copy of woods-testbed `apps/rails-8.0-large` after a
fresh `woods:extract` (452 units, no injected source). Original testbed data
and index were not changed. The copied app points Map to the new index.

- Map rendered code: `d0e3b58` (the navigation/source-test follow-up to `c4de550`).
- Woods: `e97f3875`, read-only isolated worktree.
- Testbed source: `ed205379c477c3c379cddd6d5e615299fdce2dfd` plus only the local index-path initializer change.
- Runtime: Rails 8.0.5.1, Ruby 3.3.1; existing image and cached bundle. No build or gem installation needed for this run.
- Actual route: `/woods/trail?pin[]=model:Article&pin[]=controller:ArticlesController&gen=1`.
- Published index gen 1, produced inside copied app; git provenance is unavailable because the copy has no `.git`.
- Chromium `/usr/bin/chromium`, Playwright 1.63.0 as external test tooling.
- Four CSS viewports: 1440/960/640/390 by 1000, device scale factor 1.
- Native PNGs captured after fonts ready, no scaling/postprocessing. 1440 and 390 inspected at native size.
- Axe 4.11.1: zero violations at all four widths for WCAG 2.0 A/AA,
  2.1 AA and best-practice; `walkthrough-axe.json` records each result.
- Both source cards present at each width. This is automated accessibility
  and rendering evidence, not human task-success or product adoption evidence.

The engine's CSP remains unchanged. Axe ran through the browser's debugging
evaluator after ordinary script-tag injection was refused by CSP.

Known useful next experiment: opening excerpts can contain generated schema
or route annotations instead of the most relevant method. Compare selected
method excerpts and the existing full Code view before claiming a reading
speed benefit. Historical unit-page navigation remains explicitly labeled as
current-generation navigation.
