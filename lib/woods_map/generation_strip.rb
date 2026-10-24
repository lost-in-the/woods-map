# frozen_string_literal: true

module WoodsMap
  # The commit strip *by generation* (B6-History's "by generation | commit"):
  # one bar per retained generation with the unit's commits that generation's
  # table first carried ({CommitLedger}). Same shape as {CommitStrip}, so the
  # strip partial draws either; a bar's key is the generation number.
  class GenerationStrip
    # One bar: `first` is the generation number.
    Bucket = Struct.new(:first, :count, :baseline, :recent, :x, :height, keyword_init: true) do
      # @return [String] "2 commits first carried by gen 41"
      def label(_step = nil)
        carried = baseline ? "already in gen #{first}, the oldest retained table" : "first carried by gen #{first}"
        "#{count} #{count == 1 ? 'commit' : 'commits'} #{carried}"
      end
    end

    HEIGHT = CommitStrip::HEIGHT
    BAR = CommitStrip::BAR * 3
    # The year strip's width, so a few generation bars stay bars, spread
    # edge to edge under the axis labels rather than stretched.
    WIDTH = (53 * (CommitStrip::BAR + CommitStrip::GAP)) - CommitStrip::GAP

    # @param commits [Array<#generation>] the window's commit rows
    # @param ledger [CommitLedger]
    # @param current [Integer] the pinned generation, drawn hot
    def initialize(commits, ledger, current:)
      @generations = ledger.generations.select(&:table?)
      @counts = commits.filter_map { |commit| commit.generation&.number }.tally
      @current = current
    end

    # @return [nil] bars are generations, not days
    def step
      nil
    end

    # @return [Integer]
    def bucket_count
      @generations.size
    end

    # @return [Integer] viewBox width
    def width
      WIDTH
    end

    # @return [Integer]
    def peak
      @counts.values.max || 0
    end

    # @return [Integer]
    def total
      @counts.values.sum
    end

    # @return [Integer] commits the pinned generation introduced
    def recent_total
      @counts.fetch(@current, 0)
    end

    # @return [Array<Bucket>] oldest generation first
    def buckets
      @buckets ||= @generations.each_with_index.map do |generation, index|
        count = @counts.fetch(generation.number, 0)
        height = peak.zero? || count.zero? ? 0 : [(count * HEIGHT.to_f / peak).round, 3].max
        Bucket.new(first: generation.number, count: count, baseline: generation.baseline,
                   recent: generation.number == @current, x: x_for(index), height: height)
      end
    end

    # @param index [Integer]
    # @return [Integer] the bar's left edge: first at 0, last flush right, like the axis labels
    def x_for(index)
      bucket_count < 2 ? 0 : (index * (WIDTH - BAR) / (bucket_count - 1).to_f).round
    end

    # @return [Array] no extraction marks: each bar is one
    def marks
      []
    end

    # @return [Array<Array(Integer, String)>] every bar labelled by its generation
    def ticks
      buckets.each_with_index.map { |bucket, index| [index, "gen #{bucket.first}"] }
    end
  end
end
