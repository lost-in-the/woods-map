# The guide panel: what is built

Scope: M7 ([woods-map#9](https://github.com/lost-in-the/woods-map/issues/9)), FR-8 and section 11 of the design study, built to [B8-Guide](../boards/B8-Guide.html). The panel's unavailable state follows the *guide unavailable below Ruby 3.2* panel of [B8-States](../boards/B8-States.html).

## Availability

- **Off by default.** Without `config.guide_enabled`, nothing appears: no button, no panel, no notice. Every guide route answers 404.
- **Enabled, but RubyLLM cannot load.** This covers Ruby below 3.2, or `ruby_llm` missing from the host bundle. The bar shows a disabled *Guide ▸* button with the reason in its title, plus one `banner mod` with the same reason, and nothing else.
  - RubyLLM is not a gemspec dependency. `WoodsMap::Guide.backend` requires it only when the guide is enabled, as `ImpactRange` loads `Woods::Impact::Report`.
  - Verified on Ruby 3.1.6: the notice reads "RubyLLM 2.1 needs Ruby 3.2 and this host runs 3.1.6; everything else works."
- **The gate.** The guide sits behind the engine's own gate and adds its own check: it never answers a non-loopback request without the token (M8). Asking is rate limited like search and impact.

## The panel

- **Layout.** The panel docks right of the page under the bar and opens from *Guide ▸* or `g`.
  - While it is open, the frame is one screen tall and the page scrolls beside it. The page becomes the `wm` container, so its tiles and tables adapt to the narrower column.
  - Below 960 px the panel covers the page.
  - The open state is remembered per browser.
- **Context.** The header shows the model "via host config", *new* and *history*. The context chips show the unit and type, the selected lines when the reader selects code rows, the units selected on a graph, the generation and "read-only tools".
- **Actions.** Each page offers the actions that fit it:

  | Page | Actions |
  |---|---|
  | Code | explain this unit, explain this method (needs selected lines), why might this fail?, plan a feature here, summarise blast radius |
  | Lifecycle | adds explain lifecycle |
  | Passage | adds explain this passage |
  | Graph tab, full-screen graph | explain this unit, summarise blast radius, explain the selected units (needs a selection) |
  | Impact | summarise blast radius, review this change |
  | Range | review this change |
  | Under each answer | draft an issue |

  The issue names eight actions; all eight are built, plus *explain the selected units* and *draft an issue*. Prompts are Markdown templates in `lib/woods_map/guide/prompts/`. A host overrides one with `config/woods_map/prompts/<key>.md`.
- **Answers.**
  - Each answer shows "guide, n tool calls, s seconds", then a card per tool call as it starts (◌) and ends (✓, or ✕ when it fails), with its arguments and duration.
  - The text streams with the cursor. When the answer ends, the server-rendered answer replaces it: raw HTML stripped, Markdown link targets dropped, and links only to identifiers of the pinned generation.
  - *⎘ copy* copies the Markdown.
- **Limits.** The budget line shows "n of 12 tool calls" and the tokens spent this session. When a limit stops an answer, the text so far stays and a *Limit reached.* finding names the limit. A spent session budget disables the question box and the actions.

## Transport

- The browser POSTs the question. The server records a pending turn and answers with its stream URL.
- An `EventSource` reads `tool`, `delta`, then one of `done`, `limited`, `cancelled` or `failed`, each carrying the turn and its rendered HTML.
- Turbo is not vendored. Turbo Streams would add a library to keep the same order of events that one SSE stream already guarantees. A small Stimulus controller sets streamed text as text, and sets only the server's rendered HTML as HTML.
- `connect-src 'self'` covers the stream. A turn streams once: EventSource's automatic reconnect gets the finished turn again instead of a second model run.
- *Stop* marks the turn and closes the stream, and the server cancels the chat. Proxy settings are in the deployment guide.

## Budgets and persistence

- **Per answer:** tool calls (12), model turns (10) and seconds (120).
- **Per browser session:** tokens (60,000).
- **Storage.** Conversations are JSON files, one per browser session, under `<index_dir>/explorer/chats/`, outside every payload (F-4).
  - The file's id comes from a signed, HttpOnly, SameSite=Strict cookie.
  - *new* starts another conversation and keeps the session's spend.
  - Each answer replays the earlier turns as plain messages, so no chat object outlives a request.

## Index MCP servers kept across answers

stdio to `woods-mcp` (D-7) costs about 2 s to start, so `WoodsMap::Guide::ServerPool` keeps the processes alive and lends one to each answer.

- **Bounded.** At most `guide_mcp_servers` (2) per Ruby process. An answer that finds them all busy waits `guide_mcp_wait_seconds` (10), then fails with "All 2 guide index servers are busy; ask again in a moment." `0` restores one process per answer.
- **One generation.** A server serves one key: the transport (command or URL) and `Repository#generation_key` of the generation the answer pins. A new generation stops the old generation's idle servers at once and its busy ones when their answers end.
- **Only clean answers hand a server back.** After `done` or `limited` the server returns to the pool; the limits are checked between steps and before a call runs, so nothing is in flight. After `failed` or `cancelled` it is stopped, since a request may still be outstanding on it.
- **Idle and exit.** A server idle for `guide_mcp_idle_seconds` (600) is stopped the next time the pool is used. Every server is stopped at exit. A forked Puma worker starts with an empty pool and never stops its parent's processes.
- On the testbed the second answer of a generation starts no process; the real-stack spec checks that the same `woods-mcp` process answers both and that a new generation key stops it.

## History list (no board)

B8-Guide draws a *history* button in the panel header and no list. The list is designed here.

- **What it holds.** The browser session's conversations: the current one first, marked *current*, then the earlier ones newest first, each with its first question (or action and question), the number of questions, the page context it started on, and when it last changed (D-15 shorthand). The newest 20 are kept with the session's spend in the same file under `<index_dir>/explorer/chats/` (F-4); *new* moves the current conversation into the list.
- **Per browser session**, like the token budget: the signed cookie that names the file is a session cookie, so a new browser session starts with an empty list and a fresh budget.
- **Layout.** *history* (`aria-expanded`, `aria-controls`) replaces the thread with the list, under a *Conversations* heading and a *back* tool. Rows are buttons; focus moves to the first. Escape inside the list closes it and returns focus to *history*; a second Escape closes the panel.
- **Opening one** makes it current again and the conversation it leaves joins the list. Its answers are linked against the page's generation, like the thread on any page. While an answer streams the server refuses the switch (409, "Stop it first").
- `GET /woods/guide/conversations` returns the list's HTML; `POST /woods/guide/conversations/:id` opens one and returns its thread. Both sit behind the guide's gate; ids are 16 hex characters the server issued.

## Units selected on a graph

- On the Graph tab and on `/woods/graph`, while the guide is ready, **Space** on the canvas or **Shift+click** (Ctrl or Cmd+click) on a unit adds it to the guide's context, or takes it out. A plain click still opens the unit. The canvas draws a double `--select` border on picked units, and the status line says "added to the guide's context, 2 units selected".
- The graph controller sends the set in a `woods-map:graph-pick` event. The panel shows a chip ("Micropost, User selected" with *clear*) and hidden `context[nodes][]` fields of `type:identifier`. The server keeps at most 20 and only the typed units the pinned generation has; the prompt gets "units selected on the graph: Micropost (model), User (model)".
- Graph pages offer *explain this unit*, *summarise blast radius* and *explain the selected units*, which waits for a selection.
- With the guide off, nothing changes on the graph: Space does nothing and a Shift+click opens the unit.

## Draft an issue

- Every finished answer offers *⎘ copy* and *draft an issue*. The draft is an action on that answer (`draft_issue`, prompt in `prompts/draft_issue.md`): the model rewrites it as title, Summary, Evidence, Proposed change, Tests and Open questions, citing identifiers. It streams like any answer, marked *issue draft*, under the same budgets.
- A draft offers only *⎘ copy issue*, with "Paste it into your tracker; the map posts nothing." The map holds no GitHub credentials and makes no request beyond the provider and the Index MCP server.
- **D-25 and the impact rule.** D-25 keeps Markdown and JSON impact reports with Woods, and `CLAUDE.md` says never to render Markdown or JSON reports here. A draft is the guide's own answer text. It renders through the same `Answer` subset as every answer, and it is copied raw. It is not a Woods report, and nothing from `Woods::Impact::Report` is rendered or relayed, so the rule stands as written and no decision was needed. The design study already says *plan a feature here* writes "Markdown ready for an issue".

## Not built here

- **Pin** and **open as investigation**: they hand units to Trail, and M6 Trail ([woods-map#8](https://github.com/lost-in-the/woods-map/issues/8)) is not on `main`. The answer row leaves them out rather than drawing controls that do nothing; they join it when Trail's board can take units.
- `acts_as_chat` persistence.
- Personalised PageRank ordering.
- A real provider run: no key is available here, so #9's exit criterion stays open.

## Validation

- **Specs with a scripted fake chat** (no provider): the event order, tool cards, every limit, stop and disconnect, provider failures, the replay of earlier turns, session isolation, the gate, the rate limit, the budget-exhausted state, links only to known identifiers, the history list and reopening, draft an issue, and graph units as context.
- **Pool specs** with fake servers: reuse, the bound and the wait, a new generation, failed answers, idle expiry, shutdown and a fork.
- **Chromium**: the graph controller's Space, Shift+click and clear (`woods_map_graph_browser_spec`), and the panel's selection chip and fields, answer tools, and history list with Escape at 1440, 960, 640 and 390 (`woods_map_guide_browser_spec`).
- **Real-stack spec.** RubyLLM 2.1.1 runs against an in-process OpenAI-shaped endpoint and the real `woods-mcp` over stdio on the fixture index. The model sees exactly the twelve read-only tools, a `lookup` call returns the index's answer, and tokens are counted.
- **Testbed (rails-8.0).** The same stack ran in a copy of the testbed, with a slow fake endpoint mounted in that copy only: closed, open, streaming, answered, budget-exhausted and unavailable states at 1440, 960, 640 and 390, plus light, with no axe violations and no policy violations.
- **Not run:** a real provider. No key is available here, so the exit criterion stays open.
