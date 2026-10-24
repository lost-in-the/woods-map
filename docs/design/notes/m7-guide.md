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
- **Context.** The header shows the model "via host config". The context chips show the unit and type, the selected lines when the reader selects code rows, the generation and "read-only tools".
- **Actions.** Each page offers the actions that fit it:

  | Page | Actions |
  |---|---|
  | Code | explain this unit, explain this method (needs selected lines), why might this fail?, plan a feature here, summarise blast radius |
  | Lifecycle | adds explain lifecycle |
  | Passage | adds explain this passage |
  | Impact | summarise blast radius, review this change |
  | Range | review this change |

  The issue names eight actions; all eight are built. Prompts are Markdown templates in `lib/woods_map/guide/prompts/`. A host overrides one with `config/woods_map/prompts/<key>.md`.
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

## Not built here

- The chat history list, and *pin* and *open as investigation*: neither has a board (#9's audit), and Trail (M6) is not built.
- *Draft an issue.*
- `acts_as_chat` persistence.
- Graph-node selection as context.
- Personalised PageRank ordering.
- A connection shared across answers. stdio to `woods-mcp` (D-7) starts one server process per answer, about 2 s on the testbed; `config.guide_mcp_url` points at a deployed `woods-mcp-http` instead.

## Validation

- **Specs with a scripted fake chat** (no provider): the event order, tool cards, every limit, stop and disconnect, provider failures, the replay of earlier turns, session isolation, the gate, the rate limit, the budget-exhausted state, and links only to known identifiers.
- **Real-stack spec.** RubyLLM 2.1.1 runs against an in-process OpenAI-shaped endpoint and the real `woods-mcp` over stdio on the fixture index. The model sees exactly the twelve read-only tools, a `lookup` call returns the index's answer, and tokens are counted.
- **Testbed (rails-8.0).** The same stack ran in a copy of the testbed, with a slow fake endpoint mounted in that copy only: closed, open, streaming, answered, budget-exhausted and unavailable states at 1440, 960, 640 and 390, plus light, with no axe violations and no policy violations.
- **Not run:** a real provider. No key is available here, so the exit criterion stays open.
