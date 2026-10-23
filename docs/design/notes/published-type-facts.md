# Published type facts

Scope: B-4; relates to #34. Other milestone work remains separate.

A first tile precedes the existing dependency/history tiles for jobs,
mailers, view templates, concerns, serializers and database tables. It reads
only the selected typed unit's `metadata` from the pinned generation:

| Type | Fields |
| --- | --- |
| Job | kind, queue, structured perform parameters, scheduled, retry/discard handlers, enqueued jobs |
| Mailer | actions, delivery method, layout, template count, helpers, callback count |
| Template | engine, partial flag, lexical ivar mentions, helpers, rendered partials |
| Concern | kind, scope, ActiveSupport flag, instance/class methods, callback/scope counts |
| Serializer | kind, wrapped model, attributes, association count, views, custom methods |
| Table | name, database, primary key, column/index/foreign-key counts, models |

Missing or unrecognized values say `not recorded`; empty lists say
`none recorded`, empty counted collections say `0`, and a published false
says `no`. Composite primary-key arrays retain every published column.
Job parameter defaults are labelled optional without inventing
the default value. Ivars are mentions, not runtime values. Every tile labels
its source as published unit metadata, and Rails escapes all values. No new
extractor, source parsing, database access or runtime reflection is involved.

## Validation

The combined implementation passed 375 examples (zero failures, six existing
macOS-only skips) and RuboCop on Ruby 4.0.6 / Rails 8.0.5.1 with Woods main
`d7e7a846aab1`. The isolated unit-facts branch passed 347 examples with zero failures
and six macOS-only skips; RuboCop inspected 99 files without offenses.

Mounted acceptance used woods-testbed rails-8.0-large at `70c26124533e`,
Ruby 3.3.1 / Rails 8.0.5.1 and a fresh extraction. The status page and six
unit types at 1440, 960, 640 and 390 pixels, with help closed and open,
produced 56 axe-core 4.10.3 scans with zero reported WCAG A/AA violations
and no document overflow. Live help focus return passed. Hidden popup
references, icon-only chrome and clipped tabs require manual judgment;
the dialog target was verified in the DOM and mobile help inspected visually.
The open dialog had no incomplete axe checks.
