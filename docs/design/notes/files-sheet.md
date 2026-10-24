# Files sheet and narrow-width navigation

Scope: C3-Navigation, C5-Chrome, D-18; NFR-3. No board draws these states.

## The tree is its own response

No page carries the file tree. The sheet (☰ in the bar, *files* in the crumbs)
fetches `/woods/tree?gen=<n>[&since=<selector>]` the first time it opens. The
fragment depends only on the pinned generation and the selector:

- the server renders it once per pair and keeps it in a small process cache;
- the browser keeps it for an hour when the URL names the current generation,
  and revalidates it by ETag otherwise.

The page names its own file in `data-current`; the browser marks it and opens its
folders. A failed fetch says so in the sheet, and the next open tries again.

On a generated index of 4,500 units (2,000 of them framework and gem source), the
status page went from 1.75 MB to 11.5 KB and a unit page from 1.76 MB to 21 KB. The
tree response is about 1 MB, fetched once per generation.

## What the tree holds

The tree is the application. A file whose every owner is framework or gem source
(Woods' `rails_source` and `gem_source` units, installed-gem paths) is left out.
Those units keep their own pages.

Top-level folders start open and the rest folded. A folded folder hides
everything under it, so ▸ never sits above visible rows. Filtering opens the
folders of the matches. Clearing the filter puts the folds back as they were.
The status line under the filter says how many files match, or that none do,
and is a polite live region.

## The sheet

- ☰ opens the sheet at every width, with a 32px hit area.
- The header stays put while the rest scrolls, and the tree's filter stays at the
  top of that scroll. Opening scrolls to the top and focuses Close.
- Below 960, where the bar hides the primary nav, the sheet starts with it.

## The bar and the status bar below 640

- The search keeps a text field that takes the bar's free width. A tap anywhere
  on the box, or `/`, puts focus in it.
- The status bar wraps its items instead of clipping them.

## Validation

- Chromium regressions (`spec/woods_map_navigation_ui_spec.rb`,
  `spec/woods_map_peek_browser_spec.rb`) run the engine's pages with the shipped
  CSS, the vendored Stimulus and the engine's controllers at 1280, 900 and 390. They
  fail on the previous main.
- axe-core 4.14 on woods-testbed rails-8.0 found no violations: status, Code with
  the sheet open, Passage, Impact, search, Hotspots, Landscape Status and the
  timeline, at 1440, 960, 640 and 390, and in the light theme.
