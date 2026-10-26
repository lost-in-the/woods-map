# frozen_string_literal: true

require_relative 'changelog_fragments'

namespace :changelog do
  desc 'Fold changelog/ entry files into CHANGELOG.md under a dated version heading'
  task :fold, [:version] do |_task, args| # rubocop:disable Rails/RakeEnvironment
    abort 'usage: bin/rake "changelog:fold[1.2.3]"' unless args[:version]

    folded = ChangelogFragments.fold(root: Dir.pwd, version: args[:version])
    puts folded.empty? ? 'No changelog fragments; CHANGELOG.md unchanged.' : "Folded #{folded.size} fragments."
  rescue ChangelogFragments::Error => e
    abort e.message
  end
end
