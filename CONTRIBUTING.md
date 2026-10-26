# Contributing to Woods Map

## Work tracking

GitHub issues own active work, acceptance criteria and resolution evidence.
The Woods Development project organizes them. The milestone plan in
`docs/design/plan.md` maps every piece of planned work to an issue and is
updated in the same pull request that changes an issue's scope or state.
Decisions are made in issues labelled `needs-decision` and recorded in
`docs/design/decisions.md`.

## Development setup

Prerequisites are Git, Ruby 3.0 or later and a compatible Bundler. The gem
depends on an unreleased Woods; the Gemfile takes it from a sibling checkout
at `../woods` when present, otherwise from the Woods `main` branch.

```bash
git clone https://github.com/lost-in-the/woods-map.git
cd woods-map
bin/setup
bin/rake spec
bin/rubocop
```

Create a branch from `main`. Keep each pull request to one logical change.
New features follow TDD: a failing spec first. Bug fixes add a regression
spec. Validate anything that touches rendering against a `woods-testbed`
variant with the engine mounted.

## Changelog

Add a file `changelog/<type>_<slug>.md` for every user-visible change. Never
edit `CHANGELOG.md` directly: parallel pull requests would all edit its
Unreleased block and conflict. [changelog/README.md](changelog/README.md)
gives the types and format, and `bin/rake "changelog:fold[<version>]"` folds
the files into `CHANGELOG.md` at release.

## Pull requests

Describe the requirement identifiers the change covers, link the milestone
issue, and include the spec and testbed evidence. Do not include model
identifiers or session links in commits.
