# UX review proposal, November 2026

**Status: proposal.** Nothing here is a decision, and nothing here is built.
The boards in [`docs/design/boards/`](../../boards/README.md) and the
[decision log](../../decisions.md) remain the binding design.

A review of Woods Map at real scale found that the pages work on a small sample
application and turn into inventories on a large one. This proposal answers
with a stated audience, four journeys and one page pattern.

All names, commits, pull request numbers and people on the board are invented
sample data.

## Files

| File | What it is |
|---|---|
| [`../../notes/users-and-journeys.md`](../../notes/users-and-journeys.md) | Purpose, audience, the four journeys and the page rules |
| [`boards/passage.html`](boards/passage.html), `.png` | The page pattern, drawn for one controller action |
| [`review.css`](review.css) | Proposal styles. Loads after `foundations/tokens.css` |

The board links `foundations/tokens.css` and `review.css` by relative path, so
it opens from a clone. It loads Inter and Fira Code from Google Fonts.

## The page pattern

Every page has the same four parts, top to bottom.

1. **A context line and a plain title.** The title is the unit or the change.
2. **One line of facts**, in Rails vocabulary. No sentences of explanation.
3. **A diagram that is the answer.** A flowchart, or lanes by part of the product.
4. **Source for the selected node, beside a facts table.**

The header carries the hand-off: *Copy Mermaid* and *Copy link*.

On the board, `†` marks anything Woods does not publish as a fact today.

## What depends on Woods

| The design shows | State |
|---|---|
| Filters that apply to an action, templates rendered, jobs enqueued | Published today |
| Halting branches, and whether an action writes | Needs Woods work. Marked `†` on the board |
| `rescue_from` on a controller | Not published. Woods publishes rescue facts for jobs and services only, so the board leaves it out |
| Models an action touches | Woods knows references, not reads. The board says "references" |
| Callers of one method | Known for a call written on a constant (`Lodging.available`, `PricingService.call`): the reference records the method called, and the map already counts callers per method. Callers are not known for a call on a variable (`booking.price`): Woods does not know the variable's class, and records no reference for it. Listing such calls as unknown needs Woods work |
| Changed methods in a pull request | The data exists; the join from changed lines to method line ranges is not built |
| Units grouped by part of the product | Feasible from namespace and directory. The grouping is whatever those yield, or a configured mapping |
| Who knows an area | Recent commit authors. Woods stores author names; no ownership source is read |
| Whether a spec names a unit | Spec mapping is static and per file. It says a spec names a unit, never that it covers a change |
| A link that keeps showing what its author saw | A link that carries a generation opens it only while that generation is published. Staying true needs the generation pinned |

Measured on the testbed large variant (8,894 units): an incremental extract of
a pull request head took 11 s and the comparison under 3 s.

## Not in this proposal

These were explored in the same review and are held back. Each needs its own
`needs-decision` issue before it returns. Those issues are drafted and not
yet filed.

- **Colour.** The board uses an extended palette to show unit kind. It is
  illustrative. No colour decision is proposed until the light and
  colour-vision themes exist. It touches D-10, D-11 and D-23.
- **Typefaces and type scale.** D-12 and D-14. The board keeps the token
  sizes and sets Inter as the default text face, which is illustrative.
- **The landing page and the navigation labels.** FR-1 and `coverage.md`.
  The board keeps today's navigation.
- **Boards for Blast radius, Review and Diagnose.** They rest on method-level
  callers and pull request data that Woods does not supply yet.
- **Diagram rendering.** The board is hand-placed boxes. D-21 requires Mermaid
  text drawn by Pele, which cannot colour a chip inside a node.

## Not done

- Light theme, the colour-vision theme, and the widths below 1440 (D-19).
- A Mermaid source for the diagram.
- axe checks.
