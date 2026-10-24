# frozen_string_literal: true

require 'date'
require 'time'

module WoodsMap
  # The History tab (B6-History) from the generation's commit table (Woods
  # W-3, `PublishedIndex#git_commits`): the commit strip, the commits that
  # touched the unit's files with their description and files, the people,
  # what moves with it (co-change) and the retained generations that carried
  # its commits. Without a table (an older index, or an extraction without
  # readable git history) it falls back to the five commits per unit in
  # `metadata.git` and says so. Nothing here runs git.
  class HistoryView
    include HistoryGenerations

    Commit = CommitRows::Commit
    FileChange = CommitRows::FileChange
    # One author over the window.
    Person = Struct.new(:name, :commits, :last, keyword_init: true)
    CoChange = UnitCoChanges::CoChange

    RANGES = { '30d' => 30, '365d' => 365 }.freeze
    BY = %w[commit generation].freeze
    # Why there is no table, as the limits rail says it.
    TABLE_STATES = { absent: 'this generation has no commit table (no readable git history at extraction)',
                     unreadable: 'the commit table could not be read',
                     unsupported: 'this Woods has no commit table reader' }.freeze
    SHOWN = 10
    ALL_LIMIT = 500
    CO_CHANGES_SHOWN = 8

    # @param repository [WoodsMap::Repository]
    # @param unit [Hash]
    # @param now [Time]
    # @param filters [Hash] `range:` one of {RANGES} (365d by default); `week:`
    #   an ISO date, only the bar starting that day; `by:` commit (bars per
    #   week or day) or generation (bars per retained generation); `gen:` only
    #   the commits a generation first carried; `span:` only the days a drag
    #   picked ({DateSpan}); `all:` every commit in the window rather than
    #   the latest {SHOWN}; `author:` only the commits whose author, as git
    #   recorded it, is exactly this name (woods-map#92)
    def initialize(repository, unit, now: Time.now.utc, **filters)
      @repository = repository
      @unit = unit
      @now = now
      @git = unit.dig('metadata', 'git') || {}
      @table = repository.git_commits
      @days = RANGES.fetch(filters[:range].to_s) { RANGES.fetch('365d') }
      @all = filters[:all] ? true : false
      read_filters(filters)
      @author = filters[:author].to_s.presence
    end

    # @return [Range<Date>, nil] the days a drag picked on the strip
    attr_reader :span
    # @return [String, nil] the author the commits are narrowed to
    attr_reader :author

    # @return [String] commit or generation: what one bar of the strip is
    attr_reader :by
    # @return [Integer, nil] the generation the list is narrowed to
    attr_reader :gen

    # @return [Integer] the window in days
    attr_reader :days
    # @return [Date, nil] the selected bar's first day
    attr_reader :week

    # @return [Symbol] :available, :absent, :unreadable or :unsupported
    def state
      @repository.commit_table_state
    end

    # @return [Boolean] whether the commit table drives this view
    def table?
      !@table.nil?
    end

    # @return [String] the selected range's key
    def range
      RANGES.key(@days)
    end

    # @return [Boolean] whether there is anything to list
    def any?
      table? ? window_commits.any? : @git.any?
    end

    # @return [Boolean] whether every commit in the window is listed
    def all?
      @all
    end

    # @return [Array<String>] the files the history covers
    def paths
      @paths ||= UnitPaths.for(@repository, @unit)
    end

    # @return [String] "post.rb and its 2 concerns"
    def paths_label
      own = File.basename(paths.first.to_s)
      extra = paths.size - 1
      extra.positive? ? "#{own} and #{extra} more #{'file'.pluralize(extra)}" : own
    end

    # Commits inside the window, newest first, by {#author} when one is set.
    #
    # @return [Array<Commit>]
    def window_commits
      @window_commits ||= @author ? all_window_commits.select { |c| c.author == @author } : all_window_commits
    end

    # The rows the table shows: the selected bar's commits, or the latest
    # {SHOWN} (every one with `all`).
    #
    # @return [Array<Commit>]
    def commits
      list = table? ? narrow(window_commits) : window_commits
      @all || @week || @gen || @span ? list.first(ALL_LIMIT) : list.first(SHOWN)
    end

    # @return [Integer] commits in the window, or the unit's commit count without a table
    def total
      table? ? window_commits.size : @git['commit_count'].to_i
    end

    # @return [Array<Person>] most commits first
    def people
      return fallback_people unless table?

      people = all_window_commits.group_by(&:author).map do |name, list|
        Person.new(name: name, commits: list.size, last: list.first.date)
      end
      people.sort_by { |person| [-person.commits, person.name.to_s] }
    end

    # Units whose files changed in the same commits as this unit's files,
    # from `CommitTable#co_changes`, most shared commits first.
    #
    # @return [Array<CoChange>]
    def co_changes
      return [] unless table?

      @co_changes ||= UnitCoChanges.new(@repository, @table, paths, own: own_key).top(CO_CHANGES_SHOWN)
    end

    # @return [String, nil] the last change's date
    def last_modified
      table? ? window_commits.first&.date || @git['last_modified'] : @git['last_modified']
    end

    # @return [Array<String>] what this view cannot show, and why
    def limits
      list = []
      list << table_limit unless table?
      if table?
        list << 'line counts and hunks are not in this commit table (woods#804)' unless @table.try(:line_stats?)
        if ledger.generations.size >= 2 && !facets.available?
          list << 'facets moved need Woods::Impact::UnitDiff (woods#802)'
        end
        list << 'heat is per file, not per line'
        list << "the table keeps the latest #{@table.max_commits} commits" if @table.truncated?
      end
      list << 'unmerged branches absent'
    end

    # @param view [String] timeline or xychart
    # @return [String, nil] the export's Mermaid text; nil when there is nothing to draw
    def mermaid(view)
      return nil unless any?

      title = "#{@unit['identifier']} history, #{@days}d"
      chart = view == 'xychart' && commit_strip
      chart ? HistoryMermaid.xychart(title, commit_strip) : HistoryMermaid.timeline(title, window_commits)
    end

    private

    # Commits inside the window by every author, newest first.
    def all_window_commits
      @all_window_commits ||= table? ? table_window_commits : CommitRows.fallback(@git)
    end

    def table_window_commits
      cutoff = @now - (@days * 86_400)
      rows = CommitRows.new(@repository, @table, ledger)
      @table.commits_for(*paths).select { |row| (time(row['date']) || cutoff) >= cutoff }.map { |row| rows.build(row) }
    end

    def own_key
      [@unit['identifier'], @unit['type']]
    end

    def fallback_people
      Array(@git['contributors']).map { |c| Person.new(name: c['name'], commits: c['commits'].to_i, last: nil) }
                                 .sort_by { |person| -person.commits }
    end

    def table_limit
      shown = CommitRows.fallback(@git).size
      reason = TABLE_STATES.fetch(state, TABLE_STATES[:absent])
      "#{shown} of #{@git['commit_count'].to_i} commits per unit: #{reason}"
    end

    def time(value)
      Time.iso8601(value.to_s).utc
    rescue ArgumentError
      nil
    end

    def parse_generation(value)
      value.to_i if value.to_s.match?(/\A[1-9][0-9]{0,8}\z/)
    end

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue ArgumentError
      nil
    end
  end
end
