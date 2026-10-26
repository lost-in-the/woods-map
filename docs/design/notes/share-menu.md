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
| `⎘ <diagram name>` and `⤓ .mmd` under *Mermaid*, one per distinct diagram export | each `components/mermaid_tools` copy tool (`data-mermaid-name`, `data-mermaid-href`): the Mermaid text the page already carries, unchanged, and the diagram's absolute, token-free `.mmd` URL (D-25) | absent; each panel shows its Mermaid text and its own `.mmd` link instead |
| `⎘ for PR comment` after each diagram's `.mmd` | the panel's `⎘ copy for PR comment` (`data-pr-comment`): the text in a ```` ```mermaid ```` fence and one line linking this view, its generation and its `.mmd` URL (woods-map#76, [pr-comment-share.md](pr-comment-share.md)). A comment over GitHub's 65,536 characters is listed by name with the reason (`data-pr-comment-refusal`), never offered | absent; the panel's `.mmd` URL with `.md` for `.mmd` is the same text |

**What the panel says.** Under the URL it states what the link carries (this page and its query: the entry and pins) and what it does not (notes, a conclusion or questions). It says a generation or hop count in the address is applied again on opening, not a frozen copy. A reasoned handoff is the Trail's *Copy handoff summary* ([trail.md](trail.md)), copied to the clipboard and never put in a URL.

**What the menu does not do:**

- It never renders, parses, derives or hands through a Markdown or JSON report (D-25), and the boards' *Markdown for PR* button is dropped. The PR comment is a diagram, not a report: the Mermaid in a fence and one line of links, nothing derived (D-25 as amended).
- Its absolute URLs start at `config.public_url` when one is set.
- It does not render Mermaid itself: it lists the exports the diagram tools already offer. The `.mmd` routes are paced like the JSON endpoints (M8) and answer a 429 as plain text.
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
