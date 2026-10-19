# Woods Map

Rails Engine that mounts a code-comprehension web explorer over a published
[Woods](https://github.com/lost-in-the/woods) index. Developers read a unit's
code as Rails runs it, follow references, data passages and lifecycles, see
relationship graphs, schema and history, and get change-impact reports with
sharable focus URLs. It reads the published index only: no live database, no
runtime reflection, no git subprocess at request time.

Status: scaffold landed, design done. The design study, decision log, boards
and milestone plan live in `docs/design/` and are the source of truth for
scope; `docs/design/foundations/tokens.css` is the stylesheet the engine ships
verbatim (a spec keeps the two copies identical).

## Commands

```bash
bin/setup                    # bundle install (woods comes from a sibling checkout or git)
bin/rake spec                # unit and request specs against spec/dummy
bin/rubocop -a               # lint + autofix
```

Integration validation happens in a host application from
[`lost-in-the/woods-testbed`](https://github.com/lost-in-the/woods-testbed):
mount the engine in a variant, run `woods:extract`, open `/woods`.

## Non-negotiables

- **Floors match Woods**: railties >= 6.0, Ruby >= 3.0. Only the RubyLLM guide needs Ruby 3.2 and it degrades to a notice below that.
- **No build step, no asset-pipeline dependency**: every JavaScript library is vendored under `vendor/javascript/`, served by the engine's own assets route under one content digest for the whole set (so relative URLs between files work), and pinned by a literal `<script type="importmap">` in the layout. No importmap-rails, no turbo-rails, no Node.
- **One token sheet**: `tokens.css` is the design's file and ships verbatim (a spec compares the two copies); engine-only rules go in `map.css`; views never hard-code a colour or a size and compose from the partials under `app/views/woods_map/shared/` and `components/`. Every page must pass axe (colour contrast, names) at 1440, 960, 640 and 390.
- **Engine only**: there is no standalone launcher. The map belongs inside a Rails application, like Woods.
- **Index only**: every read goes through `Woods::PublishedIndex` or `Woods::MCP::IndexReader` pinned to one generation per request. Never resolve a payload path yourself; never read `manifest.json` from the index root.
- **Read-only and gated**: loopback without a token boots with a warning; anything else refuses without `WOODS_MAP_TOKEN`; `config.authorize` lets the host add its own gate. Routes take identifiers and generation numbers, never file paths from the client.
- **Mounting is explicit**: `mount WoodsMap::Engine => "/woods"`; the Railtie injects nothing.

## Architecture (see docs/design/plan.md for what is still planned)

```
lib/woods_map.rb                 # module, Configuration (boot_warning)
lib/woods_map/engine.rb          # Rails::Engine, isolate_namespace WoodsMap, after_initialize warning
lib/woods_map/repository.rb      # one pinned generation per request, per-generation caches (planned)
lib/woods_map/assets.rb          # engine-served files: roots, content digests, content types
lib/woods_map/importmap.rb       # pins for vendored modules, the literal import map
app/controllers/concerns/woods_map/authentication.rb  # token, cookie and loopback gate (D-4)
lib/woods_map/glyphs.rb          # the glyph vocabulary (D-20)
app/controllers/woods_map/       # application (gate order, 403 panel), status, sessions, assets, guidelines; units, search, ...
app/helpers/woods_map/           # asset URLs, date shorthand (D-15), short SHA; components (glyphs, chips, ⓘ, people)
app/assets/stylesheets/woods_map/ # tokens.css (verbatim from docs/design/foundations), fonts.css, map.css (engine-only rules)
app/javascript/woods_map/        # Stimulus application and controllers: cliff, tooltip, rows, tree, sheet, copy
app/views/woods_map/shared/      # the frame: bar, crumbs, ident, tabs, status, sheet
app/views/woods_map/components/  # table, steps, detail, rail, tree, facts, legend, diagram, banner, empty state
app/views/woods_map/guidelines/  # the C1 to C5 boards rendered from the partials above
vendor/javascript/               # stimulus (vendored); turbo, cytoscape, vis-timeline, highlight.js as milestones land them
vendor/fonts/                    # Inter (latin subsets) and the complete Fira Code, WOFF2 (D-12)
docs/design/                     # design study, decisions, boards, foundations, plan
```

## Conventions

- `frozen_string_literal: true` on every file; YARD on every public method and class.
- RuboCop with the same posture as Woods (`NewCops: enable`, target Ruby 3.0).
- Always `rescue StandardError`, never bare `rescue`.
- JSON output uses string keys, snake_case.
- Specs: unit specs with mocks plus request specs against `spec/dummy`; anything that needs a real index uses the fixture under `spec/fixtures/index/` (a minimal published generation) or a testbed variant.

## Work tracking

GitHub issues own active work and acceptance criteria. Every milestone and
requirement in `docs/design/plan.md` maps to an issue on the
[Woods Development project](https://github.com/orgs/lost-in-the/projects/1/views/1).
Rules:

1. Before opening a milestone issue, run the audit checklist in `plan.md` and name the requirement identifiers (FR, NFR, A, B, C, E, W) the issue covers.
2. When an issue is created, closed or re-scoped, update the matching row and the issue-links section of `plan.md` in the same pull request.
3. Record decisions in issues labelled `needs-decision`, then copy the settled decision into `docs/design/decisions.md` with the issue link.
4. Do not create a local task queue or copy issue status into a file; `plan.md` is a map, not a status board.
5. Data the map needs from extraction is a Woods issue (W-item), not a workaround in this gem.
