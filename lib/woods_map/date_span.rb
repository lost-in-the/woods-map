# frozen_string_literal: true

require 'date'

module WoodsMap
  # `?span=2026-09-01..2026-10-18`: the days a drag (or Shift+arrows) picked
  # on a commit strip or timeline, first and last day inclusive.
  module DateSpan
    FORMAT = /\A(\d{4}-\d{2}-\d{2})\.\.(\d{4}-\d{2}-\d{2})\z/

    module_function

    # @param value [String, nil]
    # @return [Range<Date>, nil] the days in order; nil when absent or malformed
    def parse(value)
      match = FORMAT.match(value.to_s)
      return nil unless match

      first, last = [Date.iso8601(match[1]), Date.iso8601(match[2])].sort
      first..last
    rescue ArgumentError
      nil
    end

    # @param range [Range<Date>]
    # @return [String] the parameter value
    def format(range)
      "#{range.first.iso8601}..#{range.last.iso8601}"
    end

    # @param range [Range<Date>, nil]
    # @param value [String, Time, nil] an ISO 8601 time
    # @return [Boolean] whether the time's UTC day is inside the range
    def cover?(range, value)
      return false unless range

      day = Time.iso8601(value.to_s).utc.to_date
      range.cover?(day)
    rescue ArgumentError
      false
    end
  end
end
