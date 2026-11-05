# WDS-148 mobile nested spacing

Mounted extracted testbed verification of Map code `ff8090ec5e6ed236574b30740bf4be381050cbfc`
against baseline `7b46eaa2b6e87a16d368290ba1c8f538465b4433`.
Woods `237ca7c547555437cd5d596b9a5c1d1d963cfa71`; testbed probe
`c6dc2c2e14fc857f0c9b12883434a5a548dd0af2` over base
`e6c2fdd218b15537d4e962597c2e01628f3b325e`; extracted generation 3;
Rails 8.0.0 / Ruby 3.3.1. Isolated copied app and read-only Map snapshot,
container `woods-map-wds148`, localhost port 3198. No index content injected
for this change; this is the supplied extracted testbed probe, including its
existing documentation unit. Wrapped Code sets the browser reading setting
`data-code-wrap=on`; it does not change index data.

Shared preview measured baseline pages, but two screenshot calls failed with
`Preview automation snapshot timed out after 15000ms.` Native headless Google
Chrome via Playwright was used as the harness-permitted fallback. Captures
wait for network idle and `document.fonts.ready`, device scale 1, native CSS
viewport widths 1440/960/640/390 and height 1000. PNG dimensions were checked
in the capture script; mobile text inspected at 100% with no scaling or repair.

`evidence.json` records after geometry, horizontal scroll/focus checks and axe
results; `before.json` records baseline geometry. All 16 after states have zero
axe violations (WCAG 2 A/AA, 2.1 AA and best practice). Existing table/code
regions scroll horizontally when overflowing and accept focus; wrapped Code
fits its region and correctly loses its redundant scroll tab stop. No global
tokens, controls, notes lane or source semantics changed.

| Page / board | 1440 | 960 | 640 | 390 |
| --- | --- | --- | --- | --- |
| ERD / B6-ERD | [PNG](erd-1440.png) | [PNG](erd-960.png) | [PNG](erd-640.png) | [PNG](erd-390.png) |
| Impact / B8-Impact-Changed, range note | [PNG](impact-1440.png) | [PNG](impact-960.png) | [PNG](impact-640.png) | [PNG](impact-390.png) |
| Code / B8-Code, D-24 | [PNG](code-1440.png) | [PNG](code-960.png) | [PNG](code-640.png) | [PNG](code-390.png) |
| Code wrap / B8-Code, B-15 | [PNG](code-wrap-1440.png) | [PNG](code-wrap-960.png) | [PNG](code-wrap-640.png) | [PNG](code-wrap-390.png) |

| Geometry | 390 before → after | 640 before → after |
| --- | --- | --- |
| Outer body width | 348 → 374 | 598 → 624 |
| Nested section width (all three pages) | 304 → 356 | 554 → 606 |
| Code scroll-region width | 346 → 372 | 596 → 622 |
| Outer and nested horizontal margins | 21 → 8 each | 21 → 8 each |

960 and 1440 retain their baseline dimensions. Vertical margins retain their
baseline values. The 640px Code notes lane remains 240px; inline/collapsible
notes would be a separate interaction change. Passage header budgeting and
Code gutter truthfulness are outside this ticket.

Chrome 157.0.8103.38; axe-core 4.10.3. `touch.json` separately confirms
coarse-pointer Impact row toggles remain 44 × 44px at every required width.
Tab labels retain their existing height; this change makes no control-size claim
beyond preserving existing sizing rules.
