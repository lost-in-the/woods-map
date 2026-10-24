# Passage mismatch flags beyond the unassigned ivar

Scope: B-18 (the permitted-param and partial-local flags); advances #3. The
unassigned-ivar flag and the W-8 filter matrix are separate work.

B8-Passage designs only the unassigned-ivar flag. The two other B-18 flags
follow it: a ⚑ note in the responds stage, a row in the Flags tile and an
entry in the rail's *flags* group, each advisory and labelled with the facts
it rests on. Woods publishes those facts from woods#806 on; an index made
before it keeps the named limits below, and the map never derives the facts.

## Permitted param with no matching attribute

`WoodsMap::PermittedAttributes` compares each permitted key with the model the
require key names (`user` → `User`). It checks the published model facts in
this order, and names the first that matches:

1. `column_names`
2. association names
3. `<singular>_ids` for `has_many` and `has_and_belongs_to_many`
4. `active_storage_attachments`
5. `action_text_fields`
6. `<key>=` in `instance_methods` (writers the class body defines)
7. `attribute_writers` (woods#797: every public writer, modules included)

The request stage shows an `attributes` row under each `permits` row, e.g.
`column: name, email · attribute writer: password, password_confirmation`.

- With `attribute_writers` published, a key nothing matches is a flag
  (`no attribute: nickname`). It is raised only on actions whose W-7 params
  read that params method; without facts, on every action. Wording: the key
  is permitted for the model, which publishes no writer by that name, so mass
  assignment would raise `ActiveModel::UnknownAttributeError` unless the
  action removes it first.
- Without `attribute_writers` (an older index), an unmatched key is
  **unverified**, not flagged, and a ⓘ note names it with woods#797.
- When the index holds no model for the require key, the keys are not checked
  and the row says so.

## Partial local never read

`WoodsMap::PartialLocals` reads two published facts (woods#798):

- `partial_renders` on each ERB template: the locals each literal partial
  render passes, with the render edge's `target` and line. The action's own
  partial renders come from W-7 and show as `locals: …` on the partial row.
- `locals_read` on each ERB partial: lexical reads, deliberately wide (a
  helper call reads like a local). The partial row shows `reads …`.

A passed local missing from the partial's reads is a flag: "`size` is passed to
`widgets/_card` from `widgets/show.html.erb:3` and never read there by name".
The implicit local of an `object:`/`collection:` render is never flagged. A
render is named as unchecked, not flagged, when its partial is not in the
index, publishes no reads (Haml, Jbuilder), passes computed locals, or reads
them dynamically (`local_assigns` by a computed key, `binding`). Without any
`partial_renders` in the passage (an older index), a ⓘ note names woods#798.

Neither flag is in the impact page's rule registry: B8-Impact-Risks does not
list them.
