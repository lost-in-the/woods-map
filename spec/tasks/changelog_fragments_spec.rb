# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require_relative '../../tasks/changelog_fragments'

RSpec.describe ChangelogFragments do
  let(:root) { Dir.mktmpdir }
  let(:date) { Date.new(2026, 11, 2) }
  let(:pointer) { ChangelogFragments::POINTER }
  let(:history) { "## [0.1.0] - 2026-01-01\n\n### Added\n\n- First release.\n" }
  let(:changelog) { "# Changelog\n\n## [Unreleased]\n\n#{pointer}\n\n#{history}" }

  before do
    FileUtils.mkdir_p(File.join(root, 'changelog'))
    File.write(File.join(root, 'CHANGELOG.md'), changelog)
  end

  after { FileUtils.remove_entry(root) }

  def fragment(name, body)
    File.write(File.join(root, 'changelog', name), body)
  end

  def fold(version = '0.2.0')
    described_class.fold(root: root, version: version, date: date)
  end

  def read_changelog
    File.read(File.join(root, 'CHANGELOG.md'))
  end

  def fragment_names
    Dir.children(File.join(root, 'changelog')).sort
  end

  it 'groups fragments under a dated heading by type in a stable order, keeping Unreleased empty' do
    fragment('fixed_b-bug.md', "- Fixed b.\n")
    fragment('added_z-last.md', "- Added z.\n")
    fragment('added_a-first.md', "- Added a.\n  - nested detail\n")
    fragment('security_hardening.md', "- Hardened.\n")

    fold

    expect(read_changelog).to eq(
      "# Changelog\n\n## [Unreleased]\n\n#{pointer}\n\n## [0.2.0] - 2026-11-02\n\n" \
      "### Added\n\n- Added a.\n  - nested detail\n- Added z.\n\n### Fixed\n\n- Fixed b.\n\n" \
      "### Security\n\n- Hardened.\n\n#{history}"
    )
  end

  it 'removes the folded fragment files but leaves the README' do
    File.write(File.join(root, 'changelog', 'README.md'), "# Changelog fragments\n")
    fragment('added_one.md', "- One.\n")
    fragment('changed_two.md', "- Two.\n")

    fold

    expect(fragment_names).to eq(['README.md'])
  end

  it 'changes nothing when there are no fragments' do
    expect(fold).to eq([])
    expect(read_changelog).to eq(changelog)
  end

  it 'refuses a malformed fragment name and leaves every file in place' do
    fragment('added_ok.md', "- Fine.\n")
    fragment('whatever.md', "- Bad name.\n")

    expect { fold }.to raise_error(ChangelogFragments::InvalidEntry, %r{changelog/whatever\.md})
    expect(read_changelog).to eq(changelog)
    expect(fragment_names).to eq(%w[added_ok.md whatever.md])
  end

  it 'refuses an unknown type' do
    fragment('feature_thing.md', "- Thing.\n")

    expect { fold }.to raise_error(ChangelogFragments::InvalidEntry, /types:/)
  end

  it 'refuses an entry that is not a list item or has a heading' do
    fragment('added_prose.md', "Plain prose.\n")
    expect { fold }.to raise_error(ChangelogFragments::InvalidEntry, /'- ' list item/)

    fragment('added_prose.md', "- Item.\n\n## Heading\n")
    expect { fold }.to raise_error(ChangelogFragments::InvalidEntry, /headings/)
  end

  it 'refuses a version that already has a heading' do
    fragment('added_one.md', "- One.\n")

    expect { fold('0.1.0') }.to raise_error(ChangelogFragments::Error, /already/)
    expect(fragment_names).to eq(['added_one.md'])
  end

  it 'refuses entries written directly under Unreleased' do
    File.write(File.join(root, 'CHANGELOG.md'), "# Changelog\n\n## [Unreleased]\n\n- Direct edit.\n\n#{history}")
    fragment('added_one.md', "- One.\n")

    expect { fold }.to raise_error(ChangelogFragments::Error, /Unreleased/)
    expect(fragment_names).to eq(['added_one.md'])
  end
end
