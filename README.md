# Woods Map

A Rails Engine that turns a published [Woods](https://github.com/lost-in-the/woods)
index into a code-comprehension explorer mounted inside your application:
read each unit as Rails runs it, follow references and data passages, see
lifecycles, relationship graphs, schema and history, and share change-impact
reports with links that open on the interesting part.

Status: M1 Reading (search, unit pages, the two-lens code view, Schema,
Lifecycle, Graph and History tabs), M2 Passage and the pre-change mode of M4b Impact. See [`docs/design/`](docs/design/) for the
design study, decision log, boards and milestone plan.

```ruby
# Gemfile
gem "woods-map", group: :development

# config/routes.rb
mount WoodsMap::Engine => "/woods" if Rails.env.development? || ENV["WOODS_MAP"]
```

Run `bundle exec rake woods:extract`, then open `/woods`.

## Configuration

Everything is read at request time, so a host initializer can run after the
engine loads:

```ruby
# config/initializers/woods_map.rb
WoodsMap.configure do |config|
  config.index_dir = Rails.root.join("tmp/woods")   # where woods:extract publishes
  config.token = ENV["WOODS_MAP_TOKEN"]             # required beyond loopback
  config.authorize = ->(request) { request.env["warden"]&.user&.admin? }
end
```

- Without a token the map serves loopback requests only and logs one warning
  at boot; any other address gets a 403 page that carries no index data.
- With a token, open `/woods?token=…` once (or paste it into the form at
  `/woods/session/new`): it becomes a signed, `HttpOnly`, `SameSite=Strict`
  cookie holding a digest of the token. API clients send
  `Authorization: Bearer …`.
- `config.authorize` runs before any token check and can refuse on its own.
- `config.require_token = true` refuses loopback too.

## Pages

Press `?` or use the primary bar’s help button for contextual shortcuts.
The dialog contains focus and restores the opener when dismissed. See the
[keyboard help contract](docs/design/notes/keyboard-help.md).

- `/woods`: the status page (generation, HEAD, freshness, extractors, host).
- `/woods/search?q=…&in=name|code|path`: name, full-text and path search over
  the pinned generation, with type filters; `/` on any page opens the palette.
- `/woods/units/:type/*identifier`: a unit's Code tab, the file as written or
  the effective class (schema header and inlined concerns folded in), with
  marginalia, outline, peek (`p`) and references linked with their confidence.
- `…/schema`, `…/lifecycle?event=`, `…/graph`, `…/history`: the tabs a type
  has (models: all four; tables: schema and graph; controllers, mailers and
  jobs: lifecycle, graph and history; everything else: graph and history).
- `…/passage?action_name=`: a controller or mailer action's passage, request
  → filters → action → templates → response, with the filter matrix and the
  callback ladder of the model it saves. Declared facts only: what the index
  does not publish yet (W-7, W-8) is named, never guessed.

- `/woods/impact?focus=User,PostsController&depth=2`: the blast radius of a
  planned change, with the risks, tests and unknowns one generation proves;
  `&lens=risks|flows|tests|unknown` picks the tab, `&show=no_tests|no_views`,
  `&types=` and `&via=` filter. A range (`?from=&to=`) needs the report of
  `woods:impact` (W-12).

Every read goes through one generation pinned for the request; the page says
which (`gen N`) and whether the working tree has drifted from it.

## Guidelines page

`/woods/guidelines` renders the component boards of the design (tokens,
tables, navigation, diagrams, chrome) from the engine's own partials, so the
design and the engine cannot drift. Views compose pages from
`app/views/woods_map/shared/` (the frame) and `app/views/woods_map/components/`
and never hard-code a colour or a size: everything comes from the token sheet.

## Principles

- Reads the published index only; no live database, no runtime reflection.
- Same floors as Woods: Rails 6.0+, Ruby 3.0+.
- No build step: every JavaScript library is vendored and served by the engine.
- Read-only, loopback by default, bearer token plus origin guard elsewhere.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
