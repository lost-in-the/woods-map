# History

Scope: FR-7 (history part), B-6, B-14, C-5, A-6. M4, [woods-map#6](https://github.com/lost-in-the/woods-map/issues/6).
Data: the generation's commit table, `git_commits.json`, from Woods W-3
([woods#753](https://github.com/lost-in-the/woods/issues/753)), with per-file line
counts and hunks ([woods#804](https://github.com/lost-in-the/woods/issues/804)). It is
read only through `Woods::PublishedIndex#git_commits`, and the map runs no git.
Unified diffs and the facets that moved come from `Woods::Impact::UnitDiff`
([woods#802](https://github.com/lost-in-the/woods/issues/802)); the map diffs nothing.

[B6-History](../boards/B6-History.html) designs the History tab. Three pieces have
no board, and this note sets them:

- the cross-unit page `/woods/history`;
- the generation picker;
- the unit diff.

## History tab

`GET /woods/units/:type/:identifier/history?range=&by=&week=&gen=&all=1&from=&to=`

- **Files covered.**
  - The unit's own file.
  - Its `source_paths` from the graph.
  - The files of the concerns it inlines, so "post.rb and its concerns" reads as the board says.
- **Commit strip.**
  - Commits per week over the window. For the 30-day range, commits per day.
  - The last four weeks are drawn in `--hot`.
  - A dashed mark in `--mod` shows where a retained generation was extracted.
  - Each bar with commits links to `?week=` and lists its commits.
  - **Picking a span** (the board's *drag to pick a range*): drag across the bars, or focus a bar and extend with Shift+← / Shift+→, then Enter; Escape cancels (`brush` controller). The page reloads with `?span=first..last` (inclusive days, `WoodsMap::DateSpan`), lights the bars in the span and lists their commits; *whole window* clears it. The band is an SVG rect placed by attributes (CSP), and an `aria-live` line reads the selection. A click without a drag keeps the bar's own link. `/woods/history` takes the same span on its timeline, from a focused dot.
  - *By generation* (`?by=generation`, the board's *by generation | commit* control): one bar per retained generation with a table, holding the commits that generation first carried (`WoodsMap::GenerationStrip` over `CommitLedger`). The pinned generation is drawn hot; the oldest retained table's bar says its commits are only known to be at or before it. A bar links to `?by=generation&gen=N`, which lists only those commits. *Commit* is the default and keeps the time strip.
  - The strip is an SVG in viewBox units. Its axis labels are SVG text at percentage positions, so the page needs no `style` attribute (CSP, M8).
- **Commits table** (D-17).
  - Columns: *when, sha, author, message* (the champion), *files, units*, *gen* and *facets moved*.
  - The latest 10 are shown; *all N* lists the window.
  - Each detail block holds the description, the files with their `+a −d` counts and status (`new`, `deleted`, `type changed`; unindexed files muted; `binary` for a binary file), *hunks*, *co-changed with* (the units of this generation that own the other files), and the parents of a merge.
  - *Hunks* are each file's new-side ranges (`L3–4`, `after L5` for a pure deletion), in the commit's own coordinates. Only when the commit is the file's latest touch do those lines still address the current file, so only then does a range link to the owning unit's Code view at `#L<start>`. A file past Woods' per-file or table-wide hunk budget adds *and more*. A table without line stats says so in the block and in the limits.
- **Gen column.** The retained generation whose commit table first lists the commit (`WoodsMap::CommitLedger`). It compares the sha lists of retained tables and nothing else. A commit already in the oldest retained table reads `≤ N`.
- **Facets moved column.** Woods' record of this unit between the commit's generation and the retained generation before it (`Woods::Impact::UnitDiff` through `WoodsMap::GenerationFacets`): the report categories that moved (`behaviour, edges`), `added`/`removed` with them, or `unchanged`. A commit between extractions is attributed to the next generation, as the board's ⓘ says. A `≤ N` commit has no value. One unit diff per generation pair is read and cached per index identity. The column is left out when the Woods has no unit diff or fewer than two generations are retained.
- **Rail.**
  - *Generations touching the unit*: the generations that introduced its commits, with their head sha.
  - *People*: commits and last date in the window.
  - *Moves with, co-change*: `CommitTable#co_changes` over the unit's files, folded onto the units that own the co-changed files. Once three or more units share two or more commits, units sharing a single commit are left out, because a sweeping commit (an initial import) touches everything once.
  - *Limits*.
- **Range.** 30d or 365d, a segmented control in the title block.
- **Exports** (D-25) in the strip's legend, each with ⎘ and ⤓ `.mmd`:
  - *XY chart*: `xychart-beta`, commits per bar.
  - *timeline*: `timeline`, commits by month and day, at most 40.
  - URLs:
    - `/woods/units/:type/:identifier/history.mmd?view=xychart&range=`
    - `/woods/units/:type/:identifier/history.mmd?range=`
  - Pele draws both (`spec/diagrams/pele_render_spec.rb`).
- **Without a table.** An index from an extraction with no readable git history, or an older Woods, shows the five commits of `metadata.git` with no strip. The first limit says why.

## Gutter heat (Code tab)

The commit table publishes files per commit, not lines, so heat is per file (`WoodsMap::PathHeat`):

| Level | When |
|---|---|
| `h3`, hot | three or more commits in the last four weeks |
| `h2`, active | a commit in the last 90 days |
| `h1`, settled | otherwise |

The class's own lines take the unit file's level. Each inlined concern's lines take
that concern file's level. The cell's tooltip names the level and the file's commit
count. Without a table the strip keeps the unit's `change_frequency`.

## Generation picker and unit diff (B-14)

When two or more generations are retained:

- The primary action is *Diff gen N−1 → N*.
- A *Generations* section offers *from* and *to* selects over the retained generations.

`?from=&to=` adds a *Unit diff* section, which is this unit's record in Woods' change
impact report (`Woods::Impact::Report.compare` through `WoodsMap::ImpactRange`, W-12):

- status;
- facets;
- categories;
- metadata keys;
- source lines before and after;
- then Woods' unified diff of the unit's annotated source (`Woods::Impact::UnitDiff`, woods#802, through `WoodsMap::SourceDiff`), drawn with the B8-Impact-Changed diff component (`components/_diff`): an eyebrow with the added and removed counts, each hunk's `@@` header, both endpoints' line numbers, `+`/`−` rows tinted and named for screen readers. Line numbers are the annotated source the Code view shows. A diff past Woods' bounds says *truncated* or *too large*; a Woods without the API, an unretained generation and an unreadable payload each say so, never an empty diff.

If the report lists no change, the section says so. An unavailable report shows its
reason. *Full range report* opens `/woods/impact?from=gen:N&to=gen:M`. The map does
not diff payloads. The comparison counts against the impact rate limit.

## `/woods/history`

`GET /woods/history?units[]=type:Identifier&range=` takes typed identifiers. A bare
identifier resolves to its primary type. There are at most 12 lanes, and the page
never takes a path.

- **No selection.** The window's most-changed units appear as checkboxes, the first three ticked.
- **Timeline.**
  - One lane per unit and a dot per commit that touched its files.
  - A commit that touched two or more lanes is drawn in `--select`, joined by a vertical rule. This is the "changed together" pair of design-study scenario 2, step 3.
  - Dots link to the commit's row.
  - The timeline is server-rendered SVG. vis-timeline is not vendored, because no unmodified ESM build fits the no-build rule.
- **Changed together.** Each lane pair with its shared commit count and the latest of them.
- **Commits.** Every commit in the window that touched a lane, with the lanes it touched (commit → node links) and, in the detail, every unit it touched.
- **Export.** The `timeline` at `/woods/history.mmd?units[]=…`.
- History joins the primary bar.

## Limits

- **Hunks link only from a file's latest commit.** Older hunks are in their commit's coordinates, which the current Code view no longer shows.
- **Facets moved are per generation, not per commit.** Commits a generation first carried share its value.
- **No *git graph* export.** Branch topology is not published; only `parents` is.
- **Unmerged branches absent.** The table is HEAD-reachable.
