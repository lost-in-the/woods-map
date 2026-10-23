# Woods Map coding-agent instructions

Woods Map is a Rails engine that mounts a code-comprehension explorer over a
published Woods index. It reads that index only. It never touches a live
database, reflects at runtime or runs git at request time. The visual design is
specified in the repository and is as binding as the code.

[CLAUDE.md](CLAUDE.md) holds the architecture, the non-negotiables and the
implementation gotchas, and they apply to every agent, not only Claude.
[CONTRIBUTING.md](CONTRIBUTING.md) holds the shared work-tracking and
pull-request policy.

## Read before editing

1. Run `git status --short --branch` and `git diff HEAD`; preserve unrelated changes.
2. Read CLAUDE.md's *Non-negotiables* and *Gotchas*, then the nearest implementation and its specs.
3. Find the board that designs the page you are changing in [docs/design/coverage.md](docs/design/coverage.md), and look at it (below) before writing markup or CSS.
4. Check [docs/design/decisions.md](docs/design/decisions.md) for the rule that governs it. Decisions win over the design study where they disagree.

## Seeing the design without a browser or the Claude canvas

Everything below is a file in the repository. The PNGs are the reliable view
from a sandbox without network access: open them with your image viewer.

| What | Where | Notes |
|---|---|---|
| Design boards, one per page and component group | `docs/design/boards/*.png` (1440px wide), with the matching `*.html` | The HTML is the source; [boards/README.md](docs/design/boards/README.md) lists what each board shows. The HTML loads Inter and Fira Code from Google Fonts, so offline it falls back to system faces. `python3 docs/design/boards/render.py` (Playwright, Chromium) regenerates the PNGs. |
| Component guidelines C1 to C5 (tokens, tables, navigation, diagrams, chrome) | `docs/design/boards/C1-Tokens.png` … `C5-Chrome.png` | The engine also renders them live from its own partials at `/woods/guidelines`, which needs a booted host app. |
| The engine as built | `docs/design/screenshots/*.png` | Taken on the `woods-testbed` `rails-8.0` variant at the widths of D-19, each with no axe violations. [screenshots/README.md](docs/design/screenshots/README.md) pairs every screenshot with its board. |
| Tokens, glyphs, components | `docs/design/foundations/` | `tokens.css` is the only stylesheet of colours and sizes, shipped verbatim as `app/assets/stylesheets/woods_map/tokens.css` (a spec keeps the copies identical). `glyphs.md` is the glyph vocabulary; `components.md` is the inventory. |
| Diagram sources | `docs/design/diagrams/*.mmd` | The Mermaid text behind every board diagram. Colours inside them are Mermaid-era placeholders. |
| Design study | `docs/design/design-study.md` | Read the Markdown. The `.html` copy loads Mermaid from a CDN. |

Two limits: the boards' review comments live only on the Claude design canvas,
and the board diagrams are rendered in the dark theme only. Where a board and
an issue disagree, the issue and `decisions.md` win.

## Commands

```bash
bin/setup        # bundle install; Woods comes from ../woods when present, else Woods main
bin/rake spec    # unit and request specs against spec/dummy and the fixture index
bin/rubocop      # same posture as Woods: NewCops enabled, target Ruby 3.0

# Optional Chromium DOM/CSS regressions (code scroll, navigation, palette);
# skipped unless a headless Chromium is given. As root, Chromium refuses to start
# without --no-sandbox: point the variable at a wrapper that execs it with that flag.
WOODS_MAP_BROWSER=/path/to/chromium bin/rake spec
```

Use Ruby 3.0 or later. The engine supports railties 6.0 and later, so do not
use an API newer than Rails 6.0 without a guard.

## Visual work

- Compose views from the partials in `app/views/woods_map/shared/` and `components/`. Engine-only rules go in `map.css`; never hard-code a colour or a size in a view.
- To change a token, edit `docs/design/foundations/tokens.css` and copy it verbatim to the engine.
- Every page must pass axe-core (WCAG 2.0 A/AA, 2.1 AA, best practice) at 1440, 960, 640 and 390. Validate on a `woods-testbed` variant with the engine mounted after `woods:extract`. Put screenshots of a changed page in `docs/design/screenshots/` with a row in its README beside the board it implements.
- JavaScript libraries are vendored under `vendor/javascript/` and pinned in `lib/woods_map/importmap.rb`. There is no Node, no build step and no asset pipeline.
- Data the map needs that the index lacks is a Woods issue (a W-item), not a workaround in this gem.

## Completion checklist

- [ ] The change is limited to the requested behaviour and matches its board and decisions.
- [ ] A spec failed before the change and passes after it.
- [ ] `bin/rake spec` and `bin/rubocop` pass, or the handoff explains why not.
- [ ] Changed pages pass axe at the four widths on a testbed variant, with screenshots beside their boards.
- [ ] `tokens.css` is identical in `docs/design/foundations/` and the engine.
- [ ] `plan.md`, `coverage.md` and `decisions.md` are updated when an issue's scope or a decision changes.
- [ ] The pull request names the requirement identifiers, links the milestone issue and reports the evidence.
