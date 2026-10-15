# Woods Map

A Rails Engine that turns a published [Woods](https://github.com/lost-in-the/woods)
index into a code-comprehension explorer mounted inside your application:
read each unit as Rails runs it, follow references and data passages, see
lifecycles, relationship graphs, schema and history, and share change-impact
reports with links that open on the interesting part.

Status: design and scaffold. See [`docs/design/`](docs/design/) for the design
study, decision log and milestone plan.

```ruby
# Gemfile
gem "woods-map", group: :development

# config/routes.rb
mount WoodsMap::Engine => "/woods" if Rails.env.development? || ENV["WOODS_MAP"]
```

Run `bundle exec rake woods:extract`, then open `/woods`.

## Principles

- Reads the published index only; no live database, no runtime reflection.
- Same floors as Woods: Rails 6.0+, Ruby 3.0+.
- No build step: every JavaScript library is vendored and served by the engine.
- Read-only, loopback by default, bearer token plus origin guard elsewhere.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
