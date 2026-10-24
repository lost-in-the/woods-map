# M3 exit check: diagrams against the flow document and the model facts

Scope: the M3 exit criterion of [woods-map#5](https://github.com/lost-in-the/woods-map/issues/5),
"flowchart, sequence and ERD output match the flow document and model facts on the
testbed". Chunking on the 300-model fixture is verified separately (`/woods/erd`).

## How it is checked

`spec/support/m3_exit_check.rb` compares what the map draws with what Woods publishes
for one generation. `spec/woods_map/m3_exit_check_spec.rb` runs it on the fixture in
every CI run. Point it at any published index with `WOODS_MAP_EXIT_INDEX=<index dir>`
to run it on a testbed.

| Check | The map's side | Woods' side | A match means |
|---|---|---|---|
| Entry flows: every controller action, job `perform` and mailer action | `EntryLifecycle` steps and its sequence, flowchart and lanes texts | `Woods::FlowAssembler#assemble` at the depth the map read (the precomputed document's `max_depth`, otherwise 6). This is what `woods:flow` prints. | Every Woods step is a map step, in Woods' order. Each view draws one message or node per step, and the sequence names each step. |
| Model events: `create`, `update`, `destroy` of every application model | `Lifecycle#steps(event)` and its sequence | The callbacks of the `Model@event` flow that Woods expands, so not marked `unexpanded` | The same callbacks in the same order, each named in the sequence |
| Schema: every application model | `SchemaView` columns and ER text | The model's `metadata.columns`, `metadata.associations`, and the target model's table on its graph node | The same columns in order, and every direct association drawn to the table its target reads |

Map steps that are not in the entry's own document are allowed. They are listed with
how they were reached:
- `inferred`: the model event a save implies, as on the Passage ladder;
- `async` and `delivery`: hops into a job or a mailer;
- `graph`: a published `job_enqueue` edge;
- `template`: a mailer's templates.

Each is drawn with its own label, so it never reads as part of the action's flow.

## Testbed run

The testbed was an isolated woods-testbed `rails-8.0` copy with the blog scenario:
Post with the Taggable concern, `notify_subscribers`, NotifySubscribersJob and
MailingListMailer. It was extracted with `precompute_flows` on. `woods:flow` was run by
hand for `PostsController#create`, `Post@create` and `NotifySubscribersJob#perform`, and
printed the same steps the check reads.

| Check | Rows | Woods steps | Map steps | Mismatches before | After |
|---|---|---|---|---|---|
| Entry flows | 37 (32 precomputed, 5 assembled) | 49 | 77 (28 added: 12 template, 6 inferred, 6 call in an inferred model flow, 2 delivery, 1 async, 1 graph) | 0 | 0 |
| Model events | 4 (User and Post, create and update) | 9 callbacks | 9 callbacks | 2: `Post@create` and `Post@update` | 0 |
| Schema | 8 models, 22 associations | | | 1: `Micropost` | 0 |

### Mismatches found and fixed

1. **A concern's callback was a framework callback to Woods** (Woods). `Taggable` defines
   `before_save :normalize_tags`. The model's `source_code` carries the concern only as a
   comment block, so `FlowAssembler` marked the callback `unexpanded: "not defined in the
   unit"`. The map's Lifecycle tab, which reads the concern's methods, drew it as the
   application's.
   - Woods now looks for the method in the inlined concerns as well. It names the concern
     in `defined_in` and expands the callback there (`Taggable#normalize_tags`).
   - The fix is in the Woods PR for this close-out. Before it, the entry Lifecycle of
     `PostsController#create` counted `normalize_tags` as "callbacks the model does not
     define".
2. **The ER's far table was guessed from the class name** (map).
   `Micropost has_one :image_attachment` (`ActiveStorage::Attachment`) was drawn to
   `active_storage/attachments`. The model reads `active_storage_attachments`.
   - `SchemaView` now takes the target model's table from its graph node
     (`Repository#model_tables`), the table Rails reads.
   - Without a node, it falls back to `tableize` with `/` as `_`.

### Deliberate differences

- **Framework callbacks are counted differently.** Woods marks 7 to 10 callbacks per
  event `unexpanded`: autosave, `_ensure_no_duplicate_errors`, association procs and
  `normalize_changed_in_place_attributes`.
  - The Lifecycle tab leaves Rails' internal ones out entirely (names starting with `_`
    or `autosave_associated_records_for_`, and procs).
  - It counts the rest as "callbacks the model does not define": 2 per event on the
    testbed.
  - Both say the same thing about the application's own callbacks.
- **Precomputed documents are shallower than an assembled flow.** `FlowPrecomputer`
  writes depth 3, so `PostsController#create` has one step in its own document. The map
  draws the model event its save implies, and that event's own flow, as `inferred` steps.
  `woods:flow` at depth 6 reaches the same units.
