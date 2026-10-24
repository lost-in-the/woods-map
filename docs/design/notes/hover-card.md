# Hover card on a reference

Scope: B-3; relates to #34. The disambiguation popover (FR-4, B-1) remains separate.

A reference link in the code view (`.cv .src a`) opens a card. The card shows
the target's typed identifier and type, its path, its PageRank place and
score, its last author with the long relative date, and its churn: commits
and change frequency, with the hot chip when Woods classifies the unit as hot.

**Data.** Type, path and churn come from the typed graph node, and PageRank
from the graph's identifier-level `pagerank` scores. The place counts ties as
one place. The last author and the commit count come from the target unit's
`metadata.git`. A value the index lacks reads `not recorded`, `not scored` or
`no file in the index`; nothing is derived.

**Prefetch.** B-3 asks for a prefetched per-page payload. The Code tab
already reads every linked target to admit its link, so the server renders
each card once with the page. Each card is an inert `<template>` keyed by the
link's URL. Hovering therefore makes no request, and the card opens 100 ms
after hover intent. The templates are server-rendered HTML rather than JSON,
so ERB escapes the values in one place.

**Interaction.** The card is the one tooltip (D-16, C5). The `card`
controller copies each template to its links as `data-tip-html` with
`data-tip-delay="100"`, the tooltip's only new option. The tooltip then opens
the card:

- on hover after 100 ms;
- at once on keyboard focus, with `aria-describedby` on the link;
- and it closes on Escape (focus stays on the link), on leaving the link, or on Tab away.

The card holds no links, abbreviations or ⓘ buttons, so no tooltip opens
inside it. `p` still opens the peek drawer.

**Without JavaScript** the templates stay inert and each reference is a plain
link to the unit page. That page's facts tiles carry the same last-author and
churn facts.

## Validation

- **Specs:** `bin/rake spec` with `WOODS_MAP_BROWSER` and `WOODS_MAP_RENDER_SPEC=1` passes: 398 examples, 0 failures, 6 pending. RuboCop: no offenses.
- **Chromium regression** (`spec/woods_map_hover_card_spec.rb`), at 1440, 960, 640 and 390:
  - focus opens the card at once and describes the link;
  - the card fits the viewport;
  - Escape closes it and keeps focus on the link;
  - hover waits for intent, then opens within 150 ms;
  - mouseout closes it.
- **Testbed:** an isolated `woods-testbed` `rails-8.0` copy with a git snapshot so `metadata.git` is present, after a fresh `woods:extract`. The User and UsersController Code tabs with a card open, by hover or focus, had 0 axe-core 4.14 violations at 1440, 960, 640 and 390, and in light at 1440.
