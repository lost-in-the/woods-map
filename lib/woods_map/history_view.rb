# frozen_string_literal: true

module WoodsMap
  # The History tab (B6-History) from the git facts the extractor publishes
  # per unit: the last commits, the people, the churn. The commit table across
  # units (co-change, hunks, facets moved) waits on W-3.
  class HistoryView
    Commit = Struct.new(:sha, :message, :date, :author, keyword_init: true)
    Person = Struct.new(:name, :commits, keyword_init: true)

    # @param unit [Hash]
    def initialize(unit)
      @git = unit.dig('metadata', 'git') || {}
    end

    # @return [Boolean] whether the index carries git facts for this unit
    delegate :any?, to: :@git

    # @return [Array<Commit>] newest first
    def commits
      Array(@git['recent_commits']).map do |c|
        Commit.new(sha: c['sha'], message: c['message'], date: c['date'], author: c['author'])
      end
    end

    # @return [Array<Person>] by commit count
    def people
      people = Array(@git['contributors']).map { |c| Person.new(name: c['name'], commits: c['commits']) }
      people.sort_by { |p| -p.commits.to_i }
    end

    # @return [Integer]
    def commit_count
      @git['commit_count'].to_i
    end

    # @return [String] new, hot, active, stable or dormant
    def frequency
      @git['change_frequency'].to_s
    end

    # @return [String, nil]
    def last_modified
      @git['last_modified']
    end

    # @return [Array<String>] what this view cannot show yet, and why
    def limits
      [
        "#{commits.size} of #{commit_count} commits per unit until the commit table (W-3)",
        'co-change, hunks and facets moved need W-3 and W-10',
        'unmerged branches absent'
      ]
    end
  end
end
