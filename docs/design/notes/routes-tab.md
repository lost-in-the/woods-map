# Controller Routes tab

Scope: FR-3; relates to #34. Other milestone work remains separate.

A controller's tabs are Code, Routes, Passage, Lifecycle, Graph and History
(coverage.md's consistency rule). The Routes count is the number of routes
in the controller's `metadata.routes`. Any other unit type that requests
`…/routes` is redirected to its Code tab.

The page uses the unit frame: crumbs, ident, tabs and facts tiles. Below it
sit a rail (routes by verb, actions with their route counts, limits) and
three sections built from the existing table and empty-state partials:

| Section | Columns | Source |
| --- | --- | --- |
| Routes | route, action, helpers, routes.rb line, finding | controller `metadata.routes`, joined by `VERB path` to route units; `route_dispatch` route units the metadata omits are added; findings are graph analysis's `unresolvable_routes` for this controller |
| Action sources | action, defined in, source line, route count | `metadata.action_sources`; gem-defined actions from `inherited_gem_actions`, labelled `gem` |
| Reached by a route helper | unit, type, via, helper → action | `link_to`, `redirect_to` and `form_action` reverse edges; each unit's `metadata.route_helper_references` (woods#795) for this controller and mechanism |

- **Route column:** links to the route unit when the generation has one. Otherwise it reads `no route unit` in the line column.
- **Action column:** links to that action's Passage.
- **Helpers:** the published route name with `_path` and `_url` appended, which is the Rails naming rule the Passage tile already uses.
- **routes.rb line:** plain text. The `route_file` node has no published source, so nothing can be linked to a line of `config/routes.rb`.
- **Findings:** shown as notes, not risks. Woods#726 tracks `missing_action` false positives for implicit-render actions.

Limits are named on the page, not derived:

- **Helper references are controller-level on older generations.** Each referencing unit's `route_helper_references` ([woods#795](https://github.com/lost-in-the/woods/issues/795)) names the helpers it calls and the action each reaches; the column links that action's Passage. A unit from a generation extracted before them shows *not in this generation*, and the limit is named in the rail.
- **Some routes have no route unit.** The rail counts declared routes that have none in the generation.

Nothing is parsed from host source and no route is resolved at request time.

## Validation

- **Specs:** `bin/rake spec` 400 examples, 0 failures (11 pending, existing). `bin/rubocop` clean.
- **Mounted acceptance:** an isolated `woods-testbed` `rails-8.0` copy with a fresh `woods:extract` on Woods main. `UsersController`, `PostsController` and `StaticPagesController` Routes tabs gave 0 axe-core 4.14 violations at 1440, 960, 640 and 390, and in light at 960.
