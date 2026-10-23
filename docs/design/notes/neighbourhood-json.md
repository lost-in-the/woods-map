# JSON endpoint

Scope: FR-5, A-1 to A-6 endpoint slice; relates to #7. Other milestone work remains separate.

`GET /woods/graph/neighbourhood?centre=User&type=model` is mount-relative and
JSON-only, behind the same host, bearer/cookie and loopback gates as the
existing graph page. It opens one published generation. Invalid queries
return 400, a missing typed centre 404, unavailable index 503, host refusal
403 and missing credentials 401. Successful responses are not cached.

Parameters:

| Parameter | Contract |
| --- | --- |
| `centre`, `type` | required nonempty strings, each at most 2048 bytes |
| `depth` | integer 1 or 2; default 1 |
| `direction` | `both` (default), `dependencies`, `dependents` |
| `types[]`, `via[]` | optional arrays, at most 64 nonempty strings of at most 200 bytes |
| `package` | optional exact published package; unknown packages do not match |
| `node_limit` | integer 1–300; default 300, including the centre |
| `edge_limit` | integer 1–1000; default 1000 |

Schema version 1 contains normalized `query`, `provenance`, Cytoscape-shaped
`elements.nodes` / `elements.edges`, and `truncation`. Stable full SHA-256 IDs
encode typed identities and typed edge endpoints plus mechanism; two types
with the same identifier stay distinct. Nodes carry published type, path,
PageRank, change frequency, hub/cycle membership and package. Edges carry
mechanism, traversal depth, and published `through` / `cross_database`
attributes. Missing attributes remain null. Analysis is explicitly labelled
identifier-scoped rather than typed. Provenance names the generation and
published artifacts; it carries the generation's extraction, Git and version
facts when available.

Selection consumes the existing `Neighbourhood#edges` order and semantics,
including its first-reached type filter and typed deduplication. A package
filter applies after traversal and requires both endpoints to match except
for the centre, which is always retained. Edges are admitted atomically with
their endpoints until either response limit would be exceeded. Later edges
that fit may still be retained, including self-loops. No edge dangles.

Truncation counts are exact **after filters, before limits**: total and omitted
nodes/edges, limits, a truncated flag, and retained boundary node IDs with
hidden edge and distinct hidden neighbor counts. Boundary counts are local,
not additive totals. These limits bound response elements, not the existing
traversal's memory or execution cost. No renderer or traversal has changed;
Cytoscape layouts, full-screen graph and performance targets remain in #7.

## Validation

The combined implementation passed 375 examples (zero failures, six existing
macOS-only skips) and RuboCop on Ruby 4.0.6 / Rails 8.0.5.1 with Woods main
`d7e7a846aab1`. The isolated neighbourhood branch passed 362 examples with zero failures
and six macOS-only skips; RuboCop inspected 103 files without offenses.

Mounted acceptance used a fresh woods-testbed rails-8.0-large extraction
at `70c26124533e` on Ruby 3.3.1 / Rails 8.0.5.1. Article at depth 2 had
149 nodes / 303 edges. Limits of 5 nodes / 4 edges returned exactly those
limits, reported 144 omitted nodes / 299 omitted edges, and no dangling
edges. This is projection evidence, not a graph rendering performance result.
