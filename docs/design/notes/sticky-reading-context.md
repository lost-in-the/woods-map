# Sticky reading context

Scope: reading long pages without losing the unit, the generation pair or the
column meanings. Relates to [woods-map#135](https://github.com/lost-in-the/woods-map/issues/135).

**Unit pages: a context bar.** One line under the tabs names the unit, its
file, the generation (and the lens on the Code tab) and links back to the top.
It is in the flow and sticks to the top of the scroll, so it never narrows the
source column. Its height is one custom property, `--ctx-h`, built from tokens;
`:target` scrolls clear of it with `scroll-margin-top`. The source-line
permalink is centred by the `reveal` controller and does not need the margin.

- The id, path and generation sit in an `aria-hidden` span: the title block
  already says them. The back-to-top link is outside that span, so nothing
  focusable is hidden.
- The code view keeps its one scroll region (D-24). The bar sits outside
  `.cvwrap`, and `.src` gains no `overflow-x`.
- The page's `overflow-x:hidden` became `clip`. The body is a size container,
  so its overflow does not reach the viewport and it became its own scroll
  container, which nothing could stick to. `clip` makes no scroll container.

**Tables and diffs: the header sticks in its own region.** A scroll wrapper
that never scrolls vertically has nothing to stick to, so `.tblwrap` and
`.difft` are bounded in height. The `thead` sticks inside them, over the
first-column stickiness (which keeps its horizontal `left:0`, and its corner
cell sits above the body cells). On an impact range page the `thead` carries a
first row with the pair "gen A → gen B" (`compare:` on `components/_table`,
read from the page's range report). A unit diff names the pair in each hunk
header. A region that overflows only vertically keeps its tab stop (`cliff`).

Below 640 only the context bar sticks: wrappers are not bounded and headers
scroll with the page, because a phone has no room for two sticky layers.

**Truncated identities.** An identity cell (`td.id`) of the impact lists
carries the full name, type and mechanism as a title (`identity_tip`). The one
tooltip adopts it, on hover and on focus, and opens only while the text is cut
off. A cell that holds a link keeps the link as its tab stop; a plain text cell
becomes focusable.

## Validation

Browser specs (`WOODS_MAP_BROWSER`): `woods_map_sticky_context_spec.rb` (bar
visible after a deep scroll, source and grid widths unchanged, a target clear
of the bar, at four widths), `woods_map_sticky_table_spec.rb` (header and pair
stay at 1440, 960 and 640, not at 390; the first column keeps its place; the
tab stop stays), `woods_map_sticky_diff_spec.rb` and
`woods_map_identity_tip_spec.rb` (focus shows the identity; no extra tab stop
on a link). No mounted run: Docker and the testbed were not available.
