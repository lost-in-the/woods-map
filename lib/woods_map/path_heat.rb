# frozen_string_literal: true

require 'time'

module WoodsMap
  # The code view's gutter heat (B8-Code) from the commit table: one level
  # per file, from how recently and how often the table says it changed.
  # The table publishes files per commit, not lines, so heat is per file:
  # the class's own lines share one level and each inlined concern its own.
  #
  # Levels: `h3` (hot) three or more commits in the last four weeks; `h2`
  # (active) a commit in the last 90 days; `h1` (settled) otherwise.
  class PathHeat
    HOT_DAYS = 28
    HOT_COMMITS = 3
    ACTIVE_DAYS = 90
    LEVELS = { 'h3' => 'hot', 'h2' => 'active', 'h1' => 'settled' }.freeze

    # @param table [Woods::PublishedIndex::CommitTable]
    # @param now [Time]
    def initialize(table, now: Time.now.utc)
      @table = table
      @now = now
      @dates = table.commits.to_h { |row| [row['sha'], parse(row['date'])] }
    end

    # @param path [String, nil] an application-relative path
    # @return [String] h1, h2 or h3
    def level(path)
      ages = Array(@table.paths[path.to_s]).filter_map { |sha| @dates[sha] }.map { |time| (@now - time) / 86_400 }
      return 'h3' if ages.count { |age| age <= HOT_DAYS } >= HOT_COMMITS
      return 'h2' if ages.any? { |age| age <= ACTIVE_DAYS }

      'h1'
    end

    # @param path [String, nil]
    # @return [String] the level's word and the file's commit count, for the gutter's tooltip
    def describe(path)
      count = Array(@table.paths[path.to_s]).size
      "#{LEVELS.fetch(level(path))}: #{count} #{count == 1 ? 'commit' : 'commits'} in the commit table, #{path}"
    end

    private

    def parse(value)
      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
