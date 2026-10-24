# Reading settings

Scope: B-15, D-6; relates to #34. The share menu and the disambiguation popover remain separate.

**Where.** The Code tab's code-view header has a `settings` tool next to
`⎘ path:line`. It is script-only, hidden without JavaScript, and opens a
native modal dialog titled *Reading settings*. The dialog reuses the keyboard
help frame:

- the background is inert;
- Escape, Close or a click on the backdrop dismisses it and returns focus to the tool;
- the first focus lands on the current lens.

Every control saves as it changes; there is no Apply step. The keyboard help's
Escape row names the dialog.

| Setting | Values | Kept in |
| --- | --- | --- |
| Lens | as written, effective class | the existing `woods_map_lens` cookie. Choosing a lens follows the same `?lens=` link as the lens control, so the server remembers it as before (D-6) |
| Wrap long lines | off by default at every width | `localStorage["woods_map.settings"]` |
| Font size | small (`--fs-12`), medium (`--fs-13`, default), large (`--fs-15`) | the same key |
| Editor | none (default), VS Code, Cursor, JetBrains `idea://`, TextMate, Zed, or a custom template with `{path}`, `{file}` and `{line}` | the same key |
| Checkout path | the absolute path of this checkout on this machine | the same key |

**Storage.** Every storage access is wrapped in `try/catch`. Refused or absent
storage leaves the defaults. The settings controller sits on the `.wm` root, so
size and wrap apply on every page load as `data-code-size` and
`data-code-wrap`.

**Wrap.** Wrap is an opt-in that respects D-24 (woods-map#29). The code view
stays one scroll region with sticky gutters. Unwrapped, the default, the
source column grows to the longest line. Wrapped, the source column fits the
region with `pre-wrap`, so the same region simply stops overflowing. Nothing
wraps automatically at narrow widths.

**Editor link.** Following decisions.md, the scheme and checkout path are
per-browser settings and are never guessed from the index.

- **Code tab primary action:** *In editor at L…* exists only when this browser names an editor and its template can be filled. A preset needs the checkout path; a custom template needs `{file}`, or `{path}` with a checkout path.
- **Otherwise:** the primary action stays *Code at L…*.
- **Line:** the definition line, or the `#L…` line in the address when there is one, updated on `hashchange`.
- **Path encoding:** paths are URI-encoded.
- **Refused templates:** `javascript:`, `data:` and `vbscript:` templates, and templates without a scheme, make no link, and the preview says why.
- **Without JavaScript:** the editor button stays hidden.

## Validation

- **Specs:** `bin/rake spec` with `WOODS_MAP_BROWSER` and `WOODS_MAP_RENDER_SPEC=1`: 396 examples, 0 failures, 6 pending. RuboCop: no offenses.
- **Chromium regression** (`spec/woods_map_settings_spec.rb`), at 1440, 960, 640 and 390:
  - refused storage keeps the defaults;
  - unwrapped is the default and the single region scrolls a long line;
  - wrap opt-in stops that region overflowing, and is saved;
  - large size gives 15px;
  - a preset without a checkout path makes no link, and with one gives the VS Code URL;
  - the line follows the hash;
  - the custom template works and unsafe schemes are refused;
  - the dialog fits the viewport and closing restores focus;
  - a new page applies the saved settings.
- **Testbed:** an isolated `woods-testbed` `rails-8.0` copy with a git snapshot, after a fresh `woods:extract`. The User Code tab had 0 axe-core 4.14 violations in every state:
  - dialog open at 1440, 960, 640 and 390, and in light at 1440;
  - editor, wrap and large size saved, at 1440, 960, 640 and 390;
  - defaults at 390.
