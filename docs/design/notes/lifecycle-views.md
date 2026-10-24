# Lifecycle views and state diagrams

Scope: FR-6, B-19, B-23 (in part) and R-4; M3, [woods-map#5](https://github.com/lost-in-the/woods-map/issues/5).
[B6-Lifecycle](../boards/B6-Lifecycle.html) designs the view control, the
sequence and the state machine section. It does not draw the flowchart or the
lanes, so this note records what they show.

## View control

`view` sits beside `entry` in the title block and offers sequence, flowchart
and lanes (`?view=flowchart`, `?view=lanes`). The sequence is the default and
needs no parameter. An unknown value falls back to the sequence. Event links
keep the view, and view links keep the event. The keys are `s`, `f` and `l`,
beside `c`, `u` and `d`. All three views use the same numbered steps as the
steps table and the same panel tools.

- **Flowchart** (`flowchart TD`): the branching view. Each step with a
  condition is a decision. Its "yes" edge reaches the step. Its dotted "no"
  edge skips to the next node. The commit is a node of its own, before the
  first commit callback. Each job or mailer a step hands work to is a node,
  reached by a dotted `enqueues` or `mails` edge.
- **Lanes** (`swimlane-beta TB`): one lane for each place a step runs:
  validation, in the transaction, after commit, and another process. Empty
  lanes are left out. Validation also runs inside the save's transaction. It
  has its own lane because it can stop the chain before any write.
- **Budgets (R-4).** The flowchart and the lanes count nodes against
  `Lifecycle::FLOWCHART_BUDGET` (150, the neighbourhood's budget). The
  sequence keeps `SEQUENCE_BUDGET`.

**C4-dynamic (B-23)** is not offered. It needs container attribution from
W-9 ([woods#759](https://github.com/lost-in-the/woods/issues/759)), and no
board designs it. The rail names it as a limit.

## State diagrams

A model's state machines are the `state_machine` units with a reverse
`state_machine` edge to it in the pinned generation. Each one gets its own
"State machine transitions" section under the steps. The section has a
`stateDiagram-v2` panel and a transitions table (event, from → to, guard).
The rail gets a `transitions` group, as on the board.

- Every state is declared under an alias. The initial state is entered from
  `[*]`. Each transition is labelled with its event and, when there is one,
  its guard in brackets.
- Gems without events (Statesman) draw unlabelled transitions.
- `StateMachineView::STATE_BUDGET` (150 states plus transitions) is the
  budget.

The board's callbacks, side-effects and finding columns are not drawn per
transition. Woods publishes each transition callback only as a raw DSL line,
not tied to a transition, and the map does not parse DSL. These lines are
listed under "Transition callbacks".
[woods#796](https://github.com/lost-in-the/woods/issues/796) asks for
structured entries.

## Verification

The `swimlane-beta` checks from `mermaid-diagram-types.md` passed on the
vendored Pele 1.6.0, the renderer of D-21, not Mermaid:

- lanes as top-level `subgraph id ["Label"]`
- three and four lanes
- a back-edge
- a dotted edge with a label (the async hop)
- wrapping of long labels

The headless render spec draws every flowchart, lanes and state text that the
fixture generates. The Chromium spec draws a lanes panel and a state panel.
