# frozen_string_literal: true

require 'time'

module WoodsMap
  # "Zoom to the data" on a commit strip or timeline: the shortest of the offered ranges that
  # still holds every commit shown, when it is shorter than the range on screen.
  module HistoryZoom
    module_function

    # @param ranges [Hash{String => Integer}] range keys and their days, shortest first
    # @param days [Integer] the window shown
    # @param dates [Array<String>] ISO 8601 commit dates
    # @param now [Time]
    # @return [String, nil] a key of +ranges+
    def range(ranges, days, dates, now)
      times = dates.filter_map do |date|
        Time.iso8601(date.to_s).utc
      rescue ArgumentError
        nil
      end
      return nil if times.empty?

      ranges.find { |_, span| span < days && times.all? { |time| time >= now - (span * 86_400) } }&.first
    end
  end
end
