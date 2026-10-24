# History

Scope: FR-7 (history part), B-6, B-14, C-5, A-6. M4, [woods-map#6](https://github.com/lost-in-the/woods-map/issues/6).
Data: the generation's commit table, `git_commits.json`, from Woods W-3
([woods#753](https://github.com/lost-in-the/woods/issues/753)). It is read only
through `Woods::PublishedIndex#git_commits`, and the map runs no git.

[B6-History](../boards/B6-History.html) designs the History tab. Three pieces have
no board, and this note sets them:

- the cross-unit page `/woods/history`;
- the generation picker;
- the unit diff.

## History tab

`GET /woods/units/:type/:identifier/history?range=&week=&all=1&from=&to=`

- **Files covered.**
  - The unit's own file.
  - Its `source_paths` from the graph.
  - The files of the concerns it inlines, so "post.rb and its concerns" reads as the board says.
- **Commit strip.**
  - Commits per week over the window. For the 30-day range, commits per day.
  - The last four weeks are drawn in `--hot`.
  - A dashed mark in `--mod` shows where a retained generation was extracted.
  - Each bar with commits links to `?week=` and lists its commits.
  - The strip is an SVG in viewBox units. Its axis labels are SVG text at percentage positions, so the page needs no `style` attribute (CSP, M8).
- **Commits table** (D-17).
  - Columns: *when, sha, author, message* (the champion), *files, units* and *gen*.
  - The latest 10 are shown; *all N* lists the window.
  - Each detail block holds the description, the files with their status (`new`, `deleted`, `type changed`; unindexed files muted), *co-changed with* (the units of this generation that own the other files), and the parents of a merge.
- **Gen column.** The retained generation whose commit table first lists the commit (`WoodsMap::CommitLedger`). It compares the sha lists of retained tables and nothing else. A commit already in the oldest retained table reads `≤ N`.
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
- source lines before and after.

If the report lists no change, the section says so. An unavailable report shows its
reason. *Full range report* opens `/woods/impact?from=gen:N&to=gen:M`. The map does
not diff payloads. Changed line ranges wait on
[woods#802](https://github.com/lost-in-the/woods/issues/802). The comparison counts
against the impact rate limit.

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

- **No line counts or hunks.** The board's `+6 −1` and *hunks* need per-file line counts and hunks in the commit table ([woods#804](https://github.com/lost-in-the/woods/issues/804)). Until then the detail block says so.
- **No facets-moved column.** It would need a report per generation pair. The unit diff shows the facets for one chosen pair.
- **No *by generation / commit* toggle.** It is not built; the strip groups by time.
- **No *git graph* export.** Branch topology is not published; only `parents` is.
- **Unmerged branches absent.** The table is HEAD-reachable.
