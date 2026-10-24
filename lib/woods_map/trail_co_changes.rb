# frozen_string_literal: true

module WoodsMap
  # Commits that touched two or more pinned units (C-5, notes/trail.md),
  # from the pinned generation's commit table (W-3). A pin's files are the
  # ones its History tab covers ({UnitPaths}).
  class TrailCoChanges
    # One commit and the pins it touched.
    Pair = Struct.new(:commit, :pins, keyword_init: true)

    SHOWN = 50

    # @param repository [WoodsMap::Repository]
    # @param identities [Array<Array(String, String)>] pinned identities the generation has
    def initialize(repository, identities)
      @repository = repository
      @identities = identities
    end

    # @return [Symbol] the commit table's state (:available, :absent, :unreadable, :unsupported)
    def state
      @repository.commit_table_state
    end

    # @return [Array<Pair>] newest first, at most {SHOWN}
    def pairs
      @pairs ||= begin
        table = @repository.git_commits
        table && @identities.size >= 2 ? collect(table) : []
      end
    end

    private

    def collect(table)
      touched = Hash.new { |hash, sha| hash[sha] = [] }
      @identities.each do |identity|
        table.commits_for(*paths(identity)).each { |row| touched[row['sha']] << identity }
      end
      table.commits.filter_map do |row|
        pins = touched.fetch(row['sha'], []).uniq
        Pair.new(commit: row, pins: pins) if pins.size >= 2
      end.first(SHOWN)
    end

    def paths(identity)
      unit = @repository.unit(identity.first, type: identity.last)
      unit ? UnitPaths.for(@repository, unit) : []
    end
  end
end
