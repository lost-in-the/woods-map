# frozen_string_literal: true

module WoodsMap
  # The History tile of a unit page's facts: the last commit, the churn and
  # the people, each over the window Woods' per-file git facts cover, and
  # labelled with it. `commit_count` counts the past year; `contributors`
  # lists only the top few authors, so the people count comes from the
  # commit table when the generation has one (W-3).
  class HistoryTile
    # Days Woods' per-file git facts cover (EXTRACTOR_REFERENCE, git metadata).
    WINDOW_DAYS = 365

    # @param repository [WoodsMap::Repository]
    # @param unit [Hash]
    # @param now [Time]
    def initialize(repository, unit, now: Time.now.utc)
      @repository = repository
      @unit = unit
      @git = unit.dig('metadata', 'git')
      @now = now
    end

    # @return [Hash, nil] eyebrow and rows, nil without git facts
    def tile
      return nil unless @git

      count = @git['commit_count'].to_i
      { eyebrow: 'History', rows: [
        ['last', { who: @git['last_author'], date: @git['last_modified'] }],
        ['churn', { text: "#{@git['commit_count']} #{'commit'.pluralize(count)} in #{WINDOW_DAYS}d",
                    hot: @git['change_frequency'].to_s == 'hot' }],
        ['people', people],
        ['frequency', @git['change_frequency'].to_s]
      ] }
    end

    # @return [String] "11 authors in 365d", or "top 5 contributors" without a commit table
    def people
      authors = table_authors
      return "#{authors} #{'author'.pluralize(authors)} in #{WINDOW_DAYS}d" if authors

      listed = Array(@git['contributors']).size
      listed.zero? ? 'none recorded' : "top #{listed} #{'contributor'.pluralize(listed)}"
    end

    private

    def table_authors
      return nil unless @repository.respond_to?(:commit_table_state) && @repository.commit_table_state == :available

      table = @repository.git_commits
      return nil unless table.respond_to?(:commits_for)

      cutoff = @now - (WINDOW_DAYS * 86_400)
      rows = table.commits_for(*UnitPaths.for(@repository, @unit))
      rows.select { |row| recent?(row['date'], cutoff) }.filter_map { |row| row['author'].presence }.uniq.size
    end

    def recent?(date, cutoff)
      Time.iso8601(date.to_s) >= cutoff
    rescue ArgumentError
      false
    end
  end
end
