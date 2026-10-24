# Code navigation: ambiguity, method targets and callers

Scope: FR-4, B-1, B-8, B-13. These close #34's last reading item (the
disambiguation popover) and the B8-Code "called from" margin. They build on Woods
W-1 reference spans ([woods#751](https://github.com/lost-in-the/woods/issues/751)),
W-2 method tables ([woods#752](https://github.com/lost-in-the/woods/issues/752))
and W-6 method targets ([woods#756](https://github.com/lost-in-the/woods/issues/756)).
No board draws the popover or the callers section; this note is their contract.

## Reference spans in the code view

- **Verified** spans (`constant`, `association`, `callback_method`, `scope`)
  link as before.
- **Static** spans (the literal spelling names one indexed unit, but the runtime
  did not verify it) also link. They carry a dashed rule and say so in their
  accessible name. Colour is never the only cue.
- A span that names a **method** links to that method's line, taken from the
  target's method table: the target's own page `#L<file line>`, or the concern
  that owns the definition, at the concern's line. A constant receiver prefers a
  class-level method. Without a table entry the link stops at the class.
- A reference to the unit itself is linked only when it reaches a method line
  (a callback to its method). A `scope` span has no method line and stays plain.

## Disambiguation popover

An **ambiguous** span names several indexed units the index cannot choose
between. It is a `<button>` with a dotted rule, not a link, and the map never
picks a candidate.

- **Opening** (Enter, Space or a click): the popover appears under the
  reference. It is a `role="dialog"` named "Candidates for X" and lists every
  candidate the index published, with its type and path, each linked to its
  unit page. Focus moves to the first candidate.
- **Keys**: ↑/↓ move between candidates and wrap. Escape closes and returns
  focus to the reference.
- **Closing**: a click outside, scrolling or focus leaving the popover also
  closes it. Pressing the reference again closes it.
- **Without JavaScript**: the lists follow the code view as plain blocks.

## Callers

`WoodsMap::Callers` indexes every `verified` and `static` constant span in the
pinned generation by typed target, cached per generation. It leaves out
ambiguous spans, which name no single callee, and a unit's references to itself.

- The Code tab's **Callers** section lists each call into the unit: the method
  it names (or "the class itself" for a bare read), the caller linked at its
  line, and the evidence.
- A definition line's margin says "called from N" when no other note is there.
- The outline counts callers per method.
- An empty list says no published reference names the unit. Dynamic dispatch
  and receiverless calls publish no span, so it does not prove the code unused.

## Outline from the method table

With `metadata.methods` the outline groups methods by owner: the unit first,
then each inlined concern. Each method is linked to its line and shows its
visibility, `self.` for class methods, and its caller count. Older indexes keep
the name lists.

## Validation

- Specs:
  - request specs on a synthetic generation with every span kind and confidence;
  - unit specs for the span kinds and method lines;
  - a Chromium keyboard spec for the popover's focus, arrows, Escape and outside
    click.
- Testbed: rails-8.0 extracted with the Woods W-1/W-2 branch, plus a namespaced
  and a top-level `Notifier` so that a singleton-scope read is ambiguous and
  another is static. axe reported 0 violations at 1440, 960, 640 and 390, light
  and colour-vision included, with the popover open.
