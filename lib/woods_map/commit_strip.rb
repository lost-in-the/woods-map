# frozen_string_literal: true

require 'date'
require 'time'

module WoodsMap
  # The commit strip of the History tab (B6-History): commits per week across
  # the window (per day for a window of eight weeks or less), the last four
  # weeks marked hot, and a dashed mark where a retained generation was
  # extracted. Pure geometry over dates the commit table publishes; the view
  # draws it as an SVG in viewBox units.
  class CommitStrip
    # One bar.
    Bucket = Struct.new(:first, :last, :count, :recent, :x, :height, keyword_init: true) do
      # @return [String] the bar's accessible name: "3 commits, week of 2026-10-12"
      def label(step)
        unit = step == 1 ? 'day' : 'week of'
        "#{count} #{count == 1 ? 'commit' : 'commits'}, #{unit} #{first.iso8601}"
      end
    end

    # A generation mark.
    Mark = Struct.new(:number, :x, keyword_init: true)

    HEIGHT = 48
    BAR = 10
    GAP = 4
    RECENT_DAYS = 28
    # Bars an axis label keeps clear of the window's end labels.
    TICK_CLEARANCE = 4

    # @param dates [Array<String, Time>] commit dates (ISO 8601 or Time)
    # @param days [Integer] the window, ending today
    # @param now [Time]
    # @param generations [Array<Array(Integer, String)>] generation number and its extracted_at
    def initialize(dates, days:, now: Time.now.utc, generations: [])
      @days = days
      @today = now.utc.to_date
      @step = days <= 56 ? 1 : 7
      @start = @today - (bucket_count * @step) + 1
      @recent_from = @today - RECENT_DAYS + 1
      @counts = Hash.new(0)
      dates.each { |value| (index = bucket_index(day(value))) && (@counts[index] += 1) }
      @generations = generations
    end

    # @return [Integer] days per bar: 1 or 7
    attr_reader :step

    # @return [Integer]
    def bucket_count
      (@days / @step.to_f).ceil
    end

    # @return [Integer] viewBox width
    def width
      (bucket_count * (BAR + GAP)) - GAP
    end

    # @return [Integer] the tallest bar's count
    def peak
      @counts.values.max || 0
    end

    # @return [Integer] commits inside the window
    def total
      @counts.values.sum
    end

    # @return [Integer] commits in the last four weeks
    def recent_total
      buckets.select(&:recent).sum(&:count)
    end

    # @param value [String, Time] a commit date
    # @return [Integer, nil] the bar holding it; nil outside the window
    def index_of(value)
      bucket_index(day(value))
    end

    # @return [Array<Bucket>] oldest first
    def buckets
      @buckets ||= Array.new(bucket_count) do |index|
        first = @start + (index * @step)
        last = first + @step - 1
        count = @counts[index]
        height = peak.zero? || count.zero? ? 0 : [(count * HEIGHT.to_f / peak).round, 3].max
        Bucket.new(first: first, last: last, count: count, recent: last >= @recent_from, x: index * (BAR + GAP),
                   height: height)
      end
    end

    # @return [Array<Mark>] generations extracted inside the window
    def marks
      @generations.filter_map do |number, extracted_at|
        index = bucket_index(day(extracted_at))
        Mark.new(number: number, x: (index * (BAR + GAP)) + (BAR / 2)) if index
      end
    end

    # Axis labels: the first bar of each quarter month (Jan, Apr, Jul, Oct)
    # and the window's ends, at their bar index.
    #
    # @return [Array<Array(Integer, String)>]
    def ticks
      ends = [[0, @start.strftime('%b %Y')], [bucket_count - 1, @today.strftime('%b %Y')]]
      inner = quarter_ticks.reject { |index, _| index < TICK_CLEARANCE || index > bucket_count - 1 - TICK_CLEARANCE }
      (ends + inner).uniq(&:first).sort_by(&:first)
    end

    # @param first [Date] a bar's first day
    # @return [Bucket, nil]
    def bucket_starting(first)
      buckets.find { |bucket| bucket.first == first }
    end

    private

    # Weekly bars that open a quarter month, labelled by month (and year in January).
    def quarter_ticks
      return [] unless @step == 7

      buckets.each_with_index.filter_map do |bucket, index|
        first = bucket.first
        next unless first.day <= @step && ((first.month - 1) % 3).zero?

        [index, first.strftime(first.month == 1 ? '%b %Y' : '%b')]
      end
    end

    def day(value)
      time = value.is_a?(Time) ? value : Time.iso8601(value.to_s)
      time.utc.to_date
    rescue ArgumentError
      nil
    end

    def bucket_index(date)
      return nil unless date && date >= @start && date <= @today

      ((date - @start).to_i / @step)
    end
  end
end
