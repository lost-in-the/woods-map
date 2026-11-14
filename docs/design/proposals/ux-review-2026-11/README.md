# UX review proposal, November 2026

**Status: proposal.** Nothing here is a decision yet, and nothing here is
built. The boards in [`docs/design/boards/`](../../boards/README.md) and the
[decision log](../../decisions.md) remain the binding design until rows are
added for the items under [What this would change](#what-this-would-change).

This folder keeps the output of a review of Woods Map as used against a large
real application. The review found that the pages hold up on a small sample
application and become inventories at real scale. The proposal answers that
with a stated audience, four journeys, a diagram-first page pattern and an
extended colour system.

All names, commits, pull request numbers and handles on the boards are invented
sample data.

## Files

| File | What it is |
|---|---|
| [`../../notes/users-and-journeys.md`](../../notes/users-and-journeys.md) | Purpose, audience, the four journeys and the page rules |
| [`boards/start.html`](boards/start.html), `.png` | The landing page: search, the product by area, what moved this week |
| [`boards/passage.html`](boards/passage.html), `.png` | Understand: how one controller action works |
| [`boards/blast-radius.html`](boards/blast-radius.html), `.png` | Plan: what a unit affects, at class level |
| [`boards/review.html`](boards/review.html), `.png` | Review: a pull request before merge |
| [`boards/diagnose.html`](boards/diagnose.html), `.png` | Diagnose: from a symptom to the likely spot |
| [`boards/colour-suite.html`](boards/colour-suite.html), `.png` | The palette, its two values per hue and its roles |
| [`review.css`](review.css) | Proposal styles. Loads after `foundations/tokens.css` |

The boards link `foundations/tokens.css` and `review.css` by relative path, so
they open from a lodging. They load Inter and Fira Code from Google Fonts.

## The page pattern

Every page has the same four parts, top to bottom.

1. **A context line and a plain title.** The title is the unit or the change, in white.
2. **One line of facts**, in Rails vocabulary. No sentences of explanation.
3. **A diagram that is the answer.** A flowchart, or lanes by part of the product.
4. **Source for the selected node, beside a facts table.**

The header carries the hand-off: a copy action for a brief, review note or
incident note, then *Copy Mermaid* and *Copy link*.

## Colour

### Two values per hue

| Value | Use | Text on it |
|---|---|---|
| **Base** | A fill. The brand colour, unchanged | The colour that passes: white or near-black |
| **Lifted** | Text and bars on the dark ground | n/a |

`tokens.css` already holds both sets as its light and dark themes. The proposal
makes the pairing explicit and uses the base value for fills in the dark theme.

### Hues

Contrast is the lowest ratio against the three dark surfaces
(`#222126`, `#1B1A1F`, `#28272D`) for the lifted value, and against the stated
text colour for the base value.

| Hue | Origin | Base | Text on base | Lifted | Lifted on dark | Role |
|---|---|---|---|---|---|---|
| purple | brand | `#7E4384` | white, 6.8 | `#B580BC` | 4.8 | selection, the subject, the primary button |
| green | brand | `#436961` | white, 6.0 | `#7DAA9E` | 5.7 | status: added, covered |
| yellow | brand | `#F1B73A` | black, 8.8 | `#F1B73A` | 8.2 | status: modified |
| orange | brand | `#E66747` | black, 4.9 | `#EF8A3C` | 5.9 | status: check |
| red | brand | `#E64D47` | black, 4.2 (large text only) | `#EE665F` | 4.7 | status: gap, risk |
| blue | brand | `#4D597A` | white, 6.8 | `#7EB1D4` | 6.4 | kind: view |
| gray | brand | `#6E7987` | white, 4.3 (large text only) | `#9BA5B0` | 5.9 | kind: route, task, external, halt |
| teal | new | `#2F6F7A` | white, 5.6 | `#6FC3CC` | 7.3 | kind: model |
| indigo | new | `#565A9C` | white, 6.1 | `#A3A9F0` | 6.7 | kind: controller |
| plum | new | `#8E4468` | white, 6.4 | `#E29BBB` | 6.8 | kind: callback, filter |
| olive | new | `#5E6B34` | white, 5.6 | `#B3C47A` | 7.8 | kind: service, PORO |
| umber | new | `#7A5A3A` | white, 6.1 | `#D3B58A` | 7.6 | kind: job, mailer |

Two cautions from the table: red and gray pass only for large text as fills. A
small solid chip uses the lifted red with near-black text (4.7). Gray is used
for bars and text, never as a fill.

### Two channels

Colour carries two different things, and they never share a shape.

| Channel | Says | Drawn as | Tokens |
|---|---|---|---|
| **Kind** | What a unit is | The bar on the left of a box, and its small label | `--kind-*` |
| **Status** | What happened to it | A chip with a glyph: `M`, `A`, `✓`, `⚠`, `✕`, `?` | `--st-*` |

The mapping from channel to hue lives in one block of `review.css`. Changing
"models are teal" or "a gap is red" is a one-line edit there.

### Emphasis

| Meaning | Treatment |
|---|---|
| The subject of the page | Brand purple fill, white text |
| Selected | Purple outline with a faint purple tint |
| Changed (in this pull request, or recently) | Faint yellow tint; chips on it get a dark backing |
| Primary button | Brand purple fill, white text |

No white borders.

## What this would change

Each row needs a `needs-decision` issue before any of it is built.

| Item | Current rule | Proposed |
|---|---|---|
| Audience | Not stated | An engineering team building a SaaS product on Rails |
| Landing page | `/woods` is the Status page (coverage.md) | A start page; Status becomes a link |
| Navigation | Units, Landscape, Graph, ERD, Impact, History, Trail | How it works, What it affects, What changed, Browse |
| Colour roles | D-11: one palette, assigned by severity | Two channels, kind and status, on an extended palette |
| Selection | D-11: purple | Unchanged, and purple also fills the subject |
| Default typeface | The `.wm` root is Fira Code; `.ui` opts into Inter | Inter by default; Fira Code for identifiers, paths and counts |
| Type scale | D-14: 11, 12, 13, 15, 18, 24 | 12, 14, 16, 20, 32 |
| Explanations | D-14, D-15: tooltips only | One line of facts above the diagram; the rest stays in tooltips |
| Route names | `impact`, `erd` | Unchanged. Only labels change |

## What depends on Woods

Measured on the testbed large variant (8,894 units): an incremental extract of
a pull request head took 11 s and the comparison under 3 s. The Review page is
drawn only on what that run and the Woods maintainer confirmed.

| The design shows | State |
|---|---|
| Changed methods in a pull request | Data exists; the join from changed lines to method ranges is not built |
| Callers of one method | Not available. Call sites record the class, not the method. The boards say "class-level link" |
| Units grouped by part of the product | Feasible from namespace and directory |
| Who knows an area | Recent authors exist in the commit table; no ownership source is read |
| Whether a spec names a method | Spec mapping is per file today |
| A symptom matched to entry points | Search over names and code exists; ranking by kind is not built |
| A link that stays on its snapshots | Links reapply the current generation today |

## Not done

- Light theme and the colour-vision theme for the new hues.
- The widths below 1440 (D-19).
- Mermaid sources. The diagrams are hand-placed boxes. They map to a flowchart with subgraphs and a sequence diagram.
- axe checks.
