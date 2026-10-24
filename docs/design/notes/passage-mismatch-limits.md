# Passage mismatch flags beyond the unassigned ivar

Scope: B-18 (the permitted-param and partial-local flags); advances #3. The
unassigned-ivar flag and the W-8 filter matrix are separate work.

B8-Passage designs only the unassigned-ivar flag. The other two B-18 flags
need facts the index does not publish yet, so the passage shows what it can
prove and names the rest as a limit. It raises neither flag.

## Permitted param with no matching attribute

`WoodsMap::PermittedAttributes` compares each permitted key with the model the
require key names (`user` → `User`). It checks these published model facts, in
this order:

1. `column_names`
2. association names
3. `<singular>_ids` for `has_many` and `has_and_belongs_to_many`
4. `active_storage_attachments`
5. `action_text_fields`
6. `<key>=` in `instance_methods`

`instance_methods` covers writers defined in the class body only.

- The request stage shows an `attributes` row under each `permits` row, for example `column: name, email · unverified: password, password_confirmation`.
- When the index holds no model for the require key, the keys are not checked and the row says so.
- An unmatched key is **unverified**, not flagged. `has_secure_password`, the attribute API, nested attributes and module writers are not published, so an absent match proves nothing. On the testbed, `password` is one such key.
- A ⓘ note in the responds stage names the unverified keys and links [woods#797](https://github.com/lost-in-the/woods/issues/797). That issue asks Woods to publish every writer a model accepts and the model each params method resolves to. Once it lands, the note becomes a ⚑ flag.

## Partial local never read

- W-7 publishes the locals an action passes to a partial it renders itself. The partial row shows them as `locals: …`, as the board does.
- The index publishes no locals a template passes to its partials, and no locals a partial reads. When partials are shown, a ⓘ note says the check is not made and links [woods#798](https://github.com/lost-in-the/woods/issues/798).

Both items also appear in the rail's *limits* group. Neither flag is added to the impact page's rule registry: B8-Impact-Risks does not list them.
