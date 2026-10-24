# Keyboard help

Scope: NFR-3; relates to #34. Other milestone work remains separate.

The primary bar's `?` button and the `?` key open a named native modal.
Close receives focus; Tab and Shift+Tab stay there. Escape, Close and a
backdrop click dismiss it and restore the opener. The dialog lists shipped
shortcuts with their component context, including the controls that must
be present. It does not advertise source-line j/k navigation, which is not
implemented. Page shortcuts ignore editing, composition and modifier chords;
help also ignores repeats, consumed events and other open modals. Native
modal inertness keeps background controls out of the tab order.

At narrow widths the dialog scrolls vertically, uses existing design tokens
and keeps its named Close control at the start. No new shortcut changes
graph traversal or rendering.

## Validation

The combined implementation passed 375 examples (zero failures, six existing
macOS-only skips) and RuboCop on Ruby 4.0.6 / Rails 8.0.5.1 with Woods main
`d7e7a846aab1`. The isolated keyboard-help branch passed 341 examples with zero failures
and six macOS-only skips; RuboCop inspected 99 files without offenses.

Mounted acceptance used woods-testbed rails-8.0-large at `70c26124533e`,
Ruby 3.3.1 / Rails 8.0.5.1 and a fresh extraction. The status page and six
unit types at 1440, 960, 640 and 390 pixels, with help closed and open,
produced 56 axe-core 4.10.3 scans with zero reported WCAG A/AA violations
and no document overflow. Live help focus return passed. Hidden popup
references, icon-only chrome and clipped tabs require manual judgment;
the dialog target was verified in the DOM and mobile help inspected visually.
The open dialog had no incomplete axe checks.

The first concurrent browser run failed one existing palette focus check;
the complete isolated rerun passed all 341 examples.

## The y copy key

`y` copies what the page's status bar names, and nothing else:

- **Schema and Lifecycle:** the diagram's Mermaid.
- **Passage:** the passage as Mermaid.
- **Impact page, every lens:** the focus URL, as the B8 Impact boards show (`y copy URL`).

Each such page marks that one tool with `data-key="y"`. Before this, `y` activated the first copy tool in the document, which on unit pages was the breadcrumb's path tool. Two specs guard it: `spec/requests/copy_key_spec.rb` checks that each promise names its marked tool, and `spec/woods_map_copy_key_spec.rb` presses `y` in Chromium at 1440 and 390.
