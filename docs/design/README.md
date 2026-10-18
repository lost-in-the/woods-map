# Design documents

| Document | Purpose |
|---|---|
| [design-study.md](design-study.md) | The design study: storage facts, three directions, the chosen direction iterated toward code comprehension, C4 and Mermaid vocabulary, the change-impact spike, tooling, build plan, RubyLLM guide. |
| [design-study.html](design-study.html) | The same study as a self-contained page with rendered wireframes, SVG figures and Mermaid diagrams. Open it locally; it loads Mermaid from a CDN. |
| [decisions.md](decisions.md) | Every decision taken so far, with consequences. Wins over the study where they disagree. |
| [plan.md](plan.md) | Milestones, dependencies, requirement map, audit checklist and issue links. |
| [coverage.md](coverage.md) | Every page and panel of the map against the board that designs it, with the undesigned items grouped by milestone. |
| [foundations/](foundations/README.md) | The token sheet (`tokens.css`), the glyph vocabulary and the component inventory handed off for the engine. |
| [diagrams/](diagrams/README.md) | Mermaid sources for every diagram on the boards, the M3 fixtures, and the Pele verification script. |
| [connection-types.md](connection-types.md) | Renderer-agnostic inventory of every connection the index records (60 edge labels, containment, sequences, states, time, measures, sets, paths, data passage) with the drawing each fits, a renderer-fit matrix and the PlantUML assessment. Read before the Mermaid list. |
| [mermaid-diagram-types.md](mermaid-diagram-types.md) | Every Mermaid diagram type with a verdict (core, secondary, export, verify, no), the Woods data it is built from, where the map renders it, renderer constraints and the verifications M3 must run. |

The full design is produced from these three documents, milestone by
milestone, each as an issue on the Woods Development project.
