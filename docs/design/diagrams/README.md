# Diagram sources

The Mermaid text behind every diagram on the design boards, one file per
diagram, with the `---config---` front matter the boards used. They are the
fixtures for M3: a renderer that draws these the way the boards show them
passes.

| File | Where it is drawn |
|---|---|
| `seq-impact.mmd`, `seq-create.mmd`, `seq-post-create.mmd`, `seq-publishjob.mmd`, `seq-init.mmd` | Lifecycle and Impact Flows, sequence with `autonumber` (the step tables use the same numbers) |
| `swim-post-create.mmd`, `swim-tb.mmd` | Lifecycle, lanes |
| `flow-nbhd.mmd` | Graph tab neighbourhood; node classes are unit types plus `focus`, `changed`, `risk` |
| `impact-lr.mmd` | Impact Graph export, `flowchart LR` |
| `er-post.mmd`, `er-through.mmd`, `er-chunk.mmd`, `er-schema.mmd` | Schema tab and `/woods/erd`, keys only, crow's feet, `:::join` for join tables |
| `class-post.mmd`, `class-nbhd.mmd`, `class-nbhd2.mmd` | Schema tab, class view |
| `state-post.mmd`, `state-post2.mmd` | Lifecycle, state machine |
| `sankey-coupling.mmd`, `treemap-pkg.mmd` | Landscape Hotspots, forward flow and where the code is |
| `timeline-gen.mmd` | History, generations |

`pele-render.mjs` renders any of them with [Pele](https://pele.run) in Node
(`npm install pele`, then `node pele-render.mjs seq-impact er-post`) and
reports type, size and time; it is the verification behind woods-map#25.
Colours inside the sources (`classDef`, `box rgba(...)`) are placeholders from
the Mermaid era: under `tokens.css` the classes are styled by CSS and the
colours in the text are dropped.
