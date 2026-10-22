# M1 units index and indexed file ownership

This bounded slice of [#34](https://github.com/lost-in-the/woods-map/issues/34)
addresses FR-3 (the units index) and B-5 (indexed file navigation). It reuses
the shared bar, breadcrumbs, identity header, rail, table and empty-state
components. Other M1 gaps and W-12 range UI remain separate work.

`/woods/units` lists every entry returned by the request's pinned Repository,
deduplicated by `[identifier, type]`, grouped by actual type and sorted by
type then identifier. Each type has a native anchor and count. Fileless units
and unfamiliar types remain visible. An empty index has an explicit empty
state. Units navigation and type breadcrumbs lead to this index.

`/woods/files/*path` is an ownership page, never a source reader. Rails decodes
the route once; the result must be a permitted exact `file_map` key. Reject
empty, absolute, drive-prefixed, backslash, control, NUL, empty-segment and
dot-segment paths without normalization. The key is used only for payload
lookup, never filesystem, git or host-source access. Match all primary and
variant nodes whose `file_path` or published `source_paths` includes it,
deduplicate typed identities and show explicit file-profile and unresolved
membership rows. Even one owner retains its file page. No source stitching,
line anchors, inferred types or historical generation selector is provided.

Tree, path-search and palette file results link to the file page using engine
route helpers; unit results retain typed unit links. Additional contributor
paths remain selected. File and directory counts use distinct typed owners
within each scope, including same-name collisions and multi-file units.
Filtered directory counts union those same typed identities across matching
files. Matching file visibility is independent of resolved-owner counts, so
unresolved-only branches remain visible. Unresolved membership is labelled
separately and never treated as a guessed primary owner. File hits identify themselves as files.

Authentication precedes index access. Each action reads and renders inside
one `with_repository` block and retention lock; shared tree caches keep the
index-scoped `generation_key`. Each later request opens the current generation.

Validation uses synthetic unit/request fixtures, actual Rails routing,
alternate mount-prefix links, invalid/encoded keys, typed collisions,
contributors, file profiles, old graphs, unresolved membership, empty/fileless
indexes, authentication and generation isolation. Focused Ruby tests and lint
run locally; CI owns version matrices. Shared mounted-host and responsive/axe
acceptance are coordinated separately, without starting or repointing a host.

The focused client-filter regression executes the shipped controller's filter
and fold methods using macOS native JavaScriptCore (`osascript`) with a minimal
DOM interface and synthetic rows produced by `FileTree`. It needs no Node or
mounted host. Those native-runtime cases are explicitly skipped on non-macOS
CI hosts; rendered typed-identity metadata is also covered by request specs.
