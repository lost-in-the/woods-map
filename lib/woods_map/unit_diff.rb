# frozen_string_literal: true

module WoodsMap
  # One unit across two retained generations (B-14), as Woods' change impact
  # report records it (`Woods::Impact::Report.compare`, W-12, through
  # {ImpactRange}). The map never diffs payloads itself: it finds this unit's
  # record in the report's `changed` list and shows its status, the facets and
  # categories that moved, the metadata keys and the source sizes. Changed
  # line ranges are not in the schema 1 report (woods#802).
  class UnitDiff
    # @return [Integer] the older generation
    attr_reader :from
    # @return [Integer] the newer generation
    attr_reader :to

    # Parse `from`/`to` against the retained generations; nil unless both
    # name distinct published generations.
    #
    # @param repository [WoodsMap::Repository]
    # @param unit [Hash]
    # @param from [String, nil]
    # @param to [String, nil]
    # @return [UnitDiff, nil]
    def self.for(repository, unit, from:, to:)
      numbers = [from, to].map { |value| value.to_s.match?(/\A[1-9][0-9]{0,8}\z/) ? value.to_i : nil }
      return nil if numbers.any?(&:nil?) || numbers.uniq.size == 1

      available = repository.generations
      return nil unless numbers.all? { |number| available.include?(number) }

      new(repository, unit, *numbers.sort)
    end

    # @param repository [WoodsMap::Repository]
    # @param unit [Hash]
    # @param from [Integer]
    # @param to [Integer]
    def initialize(repository, unit, from, to)
      @unit = unit
      @from = from
      @to = to
      @range = ImpactRange.new(repository.index_dir, from: "gen:#{from}", to: "gen:#{to}")
    end

    # @return [Symbol] :changed, :unchanged, or the report's own unavailable, invalid or error
    def state
      return @range.state unless @range.state == :available

      record ? :changed : :unchanged
    end

    # @return [String, nil] why the report is unavailable
    delegate :message, to: :@range

    # @return [Hash, nil] Woods' unchanged record for this unit
    def record
      return nil unless @range.state == :available

      @record ||= Array(@range.data['changed']).find do |change|
        change['identifier'] == @unit['identifier'] && change['type'] == @unit['type']
      end
    end

    # @return [Array<Array(String, Object)>] label and value rows for the detail block
    def rows
      return [] unless record

      stats = record['diff_stats'] || {}
      [['status', record['status']], ['facets', Array(record['facets']).join(', ')],
       ['categories', Array(record['categories']).join(', ')],
       ['metadata keys', Array(record['metadata_keys']).join(', ')],
       ['source', source_sizes(stats['source_before'], stats['source_after'])]].filter_map do |label, value|
        [label, value] if value.present?
      end
    end

    # @return [Hash] the report's coverage, as published
    def coverage
      @range.data.is_a?(Hash) ? @range.data['coverage'] || {} : {}
    end

    private

    def source_sizes(before, after)
      sizes = [before, after].map { |size| size.is_a?(Hash) ? "#{size['lines']} lines" : 'absent' }
      sizes.uniq.size == 1 && before.nil? ? nil : sizes.join(' → ')
    end
  end
end
