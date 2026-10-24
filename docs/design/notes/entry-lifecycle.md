# Lifecycle on controllers, jobs and mailers

Scope: FR-6, "a lifecycle flowchart for any entry point (controller action,
job, mailer, model callback)". Option 1 of
[woods-map#91](https://github.com/lost-in-the/woods-map/issues/91). B6-Lifecycle
designs only the model view, so this note is the contract for the others. It
reuses the model tab's frame, panel and views, and the Trail's builder
([trail.md](trail.md)).

## What the tab shows

On a controller, a job or a mailer, the Lifecycle tab draws the flow of one
entry point:

| Unit | Entry points | Default |
|---|---|---|
| controller | its published `actions`, as an action picker | the first action |
| mailer | its published `actions`, as an action picker | the first action |
| job | `perform` | `perform` |

The picker is `?action_name=` (Passage uses the same name). An unknown action
reads as the default. A unit that publishes no action shows an empty state.

The steps are `LifecycleBuilder`'s, the same steps the Trail shows for that
entry:

- **The flow.** The generation's precomputed flow document when it has one (controller actions, W-14). Otherwise Woods' `FlowAssembler` on demand, cached per generation. The panel and the rail name which.
- **Async hops.** A `perform_later`, and a `_later` mail delivery, start another process. The steps table marks the boundary with a dashed rule naming the call and its line. The hop budget is the Trail's default (2). Steps past it are counted in the rail, and the Trail goes further.
- **The model event a save implies.** A controller action whose flow calls `save`, `create`, `update` or `destroy` runs the model event the Passage ladder reads from the action: the permitted model, else the first referenced one, and the action's name. Example: `PostsController#create` → `Post@create`. It runs in the same process. The step says "save implies" and names the action it was read from. This inference is the ladder's, already on the Passage tab; the tab only follows it into the chain.
- **A mailer action's templates**, from the Passage tab's resolution.

## Views

The views are the model chain's `sequence`, `flowchart` and `lanes` (`?view=`;
the keys `s`, `f`, `l`):

- **sequence**: one participant per unit in order of appearance. Each step is a message from the unit whose operation reached it, and an async hop is an open arrow. `autonumber` matches the steps table.
- **flowchart**: `flowchart TD`, each step from the step that reached it. An async hop is dashed and labelled; an inferred model event is labelled "save implies".
- **lanes**: the Trail's lanes (`flowchart LR`, one subgraph per unit type).

C4-dynamic stays model-only (B-23).

Budgets (R-4) are the model chain's: the sequence budget counts participants plus messages, and the flowchart budget counts nodes. Above a budget the panel keeps the text and the table lists every step.

## Steps

Below the panel:

- **The lanes table**, the Trail's partial: one column per unit type, with dashed async rules.
- **An operations table**: each step with its lane and process, every operation the flow records with its `L<line>` link (conditionals and their branches flattened), and the step's flags (`TrailFlags`: no retry, conditional callbacks, if without else, dynamic dispatch, unassigned template ivars).
  - Callbacks the model does not define are counted, not listed.
  - Operations without a line show `—`.

"Open in the Trail" and a closing link take the entry to `/woods/trail` with
the unit pinned, for the cross-process view.

## Mermaid text (D-25)

`/woods/units/:type/:identifier/lifecycle.mmd` takes `action_name` and `view`
for these types, with the answers of [mermaid-text-urls.md](mermaid-text-urls.md).
A unit with no action answers 404.

## Limits

- Woods' flows are static. Receiverless calls, procs and dynamic dispatch stay as labelled, and nothing proves a path ran.
- The model event a save implies is the Passage ladder's reading of the action, not a resolved receiver.
- A precomputed document keeps the depth it was written with.
