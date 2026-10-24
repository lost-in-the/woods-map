# frozen_string_literal: true

module WoodsMap
  # The History tab's strip and generation side (B6-History): the strip by
  # time ({CommitStrip}) or *by generation* ({GenerationStrip}), which
  # retained generations carried the unit's commits ({CommitLedger}) and the
  # facets Woods recorded moving at each generation ({GenerationFacets}).
  # Mixed into {HistoryView}, which supplies `table?`, `paths`,
  # `window_commits` and the repository; it also reads the bar, generation
  # and span filters (`read_filters`, `narrow`).
  module HistoryGenerations
    # @return [CommitStrip, GenerationStrip, nil] the strip the `by` filter asks for; nil without a table
    def strip
      return nil unless table?

      @by == 'generation' ? generation_strip : commit_strip
    end

    # @return [CommitStrip, nil] bars over time, whatever `by` says; nil without a table
    def commit_strip
      return nil unless table?

      marks = ledger.generations.map { |generation| [generation.number, generation.extracted_at] }
      @commit_strip ||= CommitStrip.new(window_commits.map(&:date), days: @days, now: @now, generations: marks)
    end

    # @return [CommitLedger]
    def ledger
      @ledger ||= CommitLedger.for(@repository)
    end

    # @return [Array<CommitLedger::Generation>] retained generations that carried this unit's commits, newest first
    def generations
      return [] unless table?

      ledger.touching(@table.commits_for(*paths).pluck('sha'))
    end

    # @return [GenerationFacets] what moved in the unit at each retained generation
    def facets
      @facets ||= GenerationFacets.new(@repository, @unit, ledger.generations.map(&:number))
    end

    # @param commit [Commit]
    # @return [String, nil] the facets moved at the generation that first carried
    #   the commit; nil for a commit only known to be at or before a generation
    def facets_moved(commit)
      generation = commit.generation
      return nil if generation.nil? || generation.baseline

      facets.label(generation.number)
    end

    # @return [Array<Integer>] the generations a diff can compare
    def generation_numbers
      @repository.generations.select(&:positive?)
    end

    # @return [GenerationStrip] one bar per retained generation with a table
    def generation_strip
      @generation_strip ||= GenerationStrip.new(window_commits, ledger, current: @repository.generation_number)
    end

    private

    def read_filters(filters)
      @week = parse_date(filters[:week])
      @by = HistoryView::BY.include?(filters[:by].to_s) ? filters[:by].to_s : HistoryView::BY.first
      @gen = parse_generation(filters[:gen])
      @span = DateSpan.parse(filters[:span])
    end

    # The window's commits narrowed to the selected bar, generation or span.
    def narrow(list)
      list = list.select { |c| in_week?(c) } if @week
      list = list.select { |c| c.generation&.number == @gen } if @gen
      list = list.select { |c| DateSpan.cover?(@span, c.date) } if @span
      list
    end

    def in_week?(commit)
      date = time(commit.date)&.to_date
      date && date >= @week && date < @week + (commit_strip&.step || 7)
    end
  end
end
