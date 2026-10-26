# Changelog entries

Each change adds one file here. Do not edit `CHANGELOG.md` directly: parallel
pull requests all edited its `## [Unreleased]` block and conflicted on every
merge.

## Naming

`<type>_<slug>.md`, directly inside this directory (no subdirectories).

- Types: `added`, `build`, `changed`, `dependencies`, `documentation`, `fixed`,
  `performance`, `security`, `testing`, `upgrade-notes`.
- Slugs start with a lowercase letter or digit and use lowercase letters,
  digits, hyphens or underscores.
- One unique file per change.

## Contents

Nonempty UTF-8 Markdown, starting with a `- ` list item, with indented
continuation or nested lines. No headings of any kind: the fold adds the
`### <Type>` heading. For example, `fixed_trail-restore.md`:

```markdown
- The reading trail restores a page's full address.
  - Nested detail is indented two spaces.
```

## Releasing

```bash
bin/rake "changelog:fold[1.2.3]"
```

This moves every entry under a new `## [1.2.3] - <date>` heading, grouped by
type in the order above (files sorted by name within a type), deletes the
files, and leaves `## [Unreleased]` pointing here. It validates every file
before writing anything, and refuses a malformed name, an unknown type, a
heading inside an entry, a version that already has a heading, or entries
written directly under Unreleased. With no entries it changes nothing.
