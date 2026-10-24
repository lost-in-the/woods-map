# Share menu

Scope: E-6, E-7; relates to #34. What the menu offers is settled by D-25
([woods-map#57](https://github.com/lost-in-the/woods-map/issues/57)): the focus
URL and the page's Mermaid, for agents pulling charts into pull-request review
and people sharing architecture feedback. No Markdown or JSON report, not even
Woods' output handed through; those stay with Woods (D-1).

**Where.** `Share ▾` is a default button (`.btn`) placed just before the page's
primary action:

- every unit tab;
- the pre-change impact page;
- the impact range page.

This is where the B8 boards draw it.

**Without JavaScript.** It is a native `<details>` disclosure, so it opens with
Enter, Space or a click, and the focus URL is readable and selectable with
scripts off.

**With the share controller.** Escape or a click outside closes it, and Escape
returns focus to the button. The panel aligns to the right of the controls,
and to the left below 960 where the controls wrap, and always fits the
viewport.

## Contents

| Item | Source | Without JavaScript |
| --- | --- | --- |
| Focus URL with `⎘ copy URL` | `focus_url`: the page's absolute address and query, less any `token` (D-4). On opening it gains the `#L…` line the address targets | the URL text; the copy tool is hidden |
| `⎘ <diagram title>` under *Mermaid*, one per diagram panel | the Mermaid text the panel already carries (`[data-diagram-target=source]`, D-21), copied unchanged | absent; each panel shows its Mermaid text instead |

**What the menu does not do:**

- It never renders, parses, derives or hands through a Markdown or JSON report (D-25), and the boards' *Markdown for PR* button is dropped.
- It does not add its own Mermaid export. Diagram-panel export belongs to the diagram panels.
- The `y` key keeps copying the page's own first copy tool, skipping the Share menu's.

## Validation

- **Specs:** `bin/rake spec` with `WOODS_MAP_BROWSER` and `WOODS_MAP_RENDER_SPEC=1`: 396 examples, 0 failures, 6 pending. RuboCop: no offenses.
- **Chromium regression** (`spec/woods_map_share_spec.rb`), at 1440, 960, 640 and 390:
  - the summary opens the menu;
  - the focus URL carries `#L3`;
  - there is one Mermaid copy per diagram with the panel's own text, and reopening does not duplicate it;
  - the panel fits the viewport;
  - Escape closes and returns focus;
  - an outside click closes;
  - `y` skips the menu.
- **Testbed:** an isolated `woods-testbed` `rails-8.0` copy after a fresh `woods:extract`. 0 axe-core 4.14 violations with the menu open on:
  - User Schema at 1440, 960, 640 and 390, and in light at 1440;
  - the pre-change impact page at the same four widths;
  - the range page at 1440 and 390;
  - the UsersController Code tab at 1440.
