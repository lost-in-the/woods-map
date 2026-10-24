# Trail

Scope: M6, [woods-map#8](https://github.com/lost-in-the/woods-map/issues/8),
requirements C-1 to C-5 (design study, section 5). No board draws the Trail
([coverage.md](../coverage.md)); this note is its contract. It composes the
existing partials and the B6-Lifecycle and B6-Graph visual language.

The Trail is the page you reach once you know your entry point. It answers
"what happens, in which process, when this runs, and what is wrong with it",
across async hops, from facts the generation already publishes. The exit
criterion is design-study scenario 2 (the failing mailing-list job),
reproducible end to end from one URL.

## Route and URL state (C-3)

`GET /woods/trail` with no parameters is the entry chooser. Every other
state is in the query string, and the query carries identifiers and
generation numbers only. It never carries a token, a file path or free text:

| Parameter | Value | Default |
|---|---|---|
| `entry` | a flow entry: `Job#perform`, `Mailer#action`, `Controller#action`, `Model@create`, `Model@update`, `Model@destroy`, `Model@after_commit(create)` (the W-5 grammar), or a bare job or mailer identifier, read as `#perform` or its only action | none: the chooser |
| `pin[]` (repeated) | `type:identifier`, at most 24 | none |
| `gen` | the generation the board was made against | the published one |
| `hops` | the async hop budget, 1 to 3 | 2 |

- An `entry` whose unit is not in the generation is a 404 with the chooser.
- A malformed pin is dropped and named. A pin whose typed unit is not in the generation stays on the board as missing. A board survives a rename as evidence of what was there.
- `gen` reads that retained generation, through `Repository#with_generation`, so a board pasted into an incident thread shows what it showed when it was made. A banner says when it is not the published one and links the same board on the current generation. A generation that is no longer retained is named and the published one is read.
- The URL is not compressed. Identifiers stay readable in an issue, and a board of 24 pins stays short enough to paste.
- **Notes stay in the browser.** A note is free text and could hold anything. A URL lands in logs, chat previews and referrers. Each pin's note is kept in this browser's local storage under the board's key (entry, pins, generation), and the page says so. Without JavaScript there are no notes.
- **No server-side save.** C-3's optional `<index>/explorer/boards/` save is not built: the engine is read-only over the index (the read-only and gated non-negotiable). A saved board is its URL. The limit is listed on the page.

## Lifecycle builder (C-1)

`WoodsMap::LifecycleBuilder` assembles the entry with Woods' `FlowAssembler`, through `Repository#flow`. That is the same assembler `trace_flow` uses, over the pinned generation's graph and payload, which `Woods::MCP::IndexReader` resolves. The flow is assembled on demand and cached per generation and entry, as the design study's storage section asks.

Woods follows both kinds of async hop. A `perform_later` continues into the job's `perform`. A mail delivery continues into the mailer action, which the operation names as `mailer_action`. The builder then:

1. **Numbers processes.** The entry runs in process 0. A step reached through an `:async` operation, or through a `_later` delivery, starts the next process. A step reached by a call stays in its caller's. The hop budget cuts later processes. A cut step is listed as "beyond the hop budget", never dropped silently.
2. **Follows the graph where the flow stops.** A unit of the flow can carry a published `job_enqueue` edge to a job the flow did not reach, for example an enqueue in a framework callback or behind a receiverless call. That job's `#perform` is assembled as a new process while the budget lasts, and the hop is marked "from the graph" because no flow operation shows the call site.
3. **Adds the mailer's templates.** A mailer step gains its action's templates (`Passage#templates`, the same resolution the Passage tab uses) as view steps in the same process.
4. **Assigns lanes by unit type.** The lanes are request (route, controller), model (model, model event, concern), service (every other application type), job, mailer and view (template, component), in that order. Lanes with no step are left out.

Receiverless calls and dynamic dispatch stay as the flow labels them. A callback the model does not define (a framework callback or a proc) is a counted limit, not a step. The lanes have gaps where the flow has gaps, and the page says how many.

## Flags (C-2)

`WoodsMap::TrailFlags` derives flags from published facts. Each flag names its evidence, and a flag whose fact is absent becomes a limit that names the W-item:

| Flag | Evidence | Absent fact |
|---|---|---|
| no retry_on or discard_on | job `retry_on` and `discard_on` both empty, `resilience_source` runtime or static (W-4) | "job resilience facts need W-4: re-extract" |
| no rescue_from | job `rescue_from` empty, under the same condition | as above |
| conditional callback | a model-event callback with `if`/`unless` conditions | — |
| conditional without else | a flow `:conditional` operation with no `else` branch, with its line | — |
| dynamic dispatch | a flow `:dynamic_dispatch` operation, with its line | — |
| cross-database association | a graph edge with `cross_database: true` from a step or pin | — |
| hub | the unit is a hub in `graph_analysis.json` (identifier scope, as everywhere) | analysis absent |
| template reads an unassigned ivar | `Passage#flags` for the mailer action (W-7, advisory) | "per-action facts need W-7" |

Flags are shown on their step, rolled up per pin and listed in one table.

## Pinboard

Each step has a pin toggle: a link to the same board with the pin added or removed. A field also takes a typed identity, and the entry's units can be pinned in one go. A pin card shows the unit link, its flags and its note. The board's key decides which notes it shows.

## Pinned views

- **Graph of pinned.** This reuses the M5 graph controller and its schema version 1 elements. `GET /woods/trail/graph` answers with the pinned units as nodes and the published edges between them, in the neighbourhood JSON shape. The page carries the same flowchart fallback and list equivalent.
- **ERD of pinned.** This reuses `ErdDiagram`. The tables of the pinned models and of the pinned `database_table` units form one synthetic chunk under the ER table budget (R-4).

## Co-change (C-5)

Co-change reads the pinned generation's commit table (W-3, `git_commits.json`, read through `Repository#git_commits`). It lists the commits that touched the files of two or more pinned units, newest first, with the pins each touched. A pin's files are its graph node's `file_path` and `source_paths`. A generation without a table says which state it is in (`commit_table_state`), as the History tab does.

## Export (C-4 under D-25)

The Share menu offers the board's focus URL and its Mermaid, nothing else:

| Diagram | URL |
|---|---|
| lanes, a `flowchart LR` with one subgraph per lane and dashed async edges | `/woods/trail.mmd?entry=…&pin[]=…&gen=…&hops=…` |
| graph of pinned | `/woods/trail.mmd?view=graph&pin[]=…&gen=…` |
| ERD of pinned | `/woods/trail.mmd?view=erd&pin[]=…&gen=…` |

These follow [mermaid-text-urls.md](mermaid-text-urls.md): the same answers, budgets as 422, and a bearer header or cookie, never a token in the URL. D-25 replaces C-4's Markdown export: there is no Markdown or JSON report. Unit links stay in the focus URL's page, not in the text.

## Limits named on the page

- Notes are per browser, and boards are not saved on the server (above).
- Flows are Woods' static flows. Receiverless calls, procs and dynamic dispatch are not resolved.
- Graph-only hops show no call site.
- Model events are assembled on demand. Woods precomputes flows for controller actions only.
- "Explain this investigation" is a guide action (M7, #9) and is not wired here.
