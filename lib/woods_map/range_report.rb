# frozen_string_literal: true

module WoodsMap
  # A read-only view over Woods' schema 1 range report (W-12, D-1): the tabs of
  # the impact page in range mode, built only from the string-keyed evidence
  # `Woods::Impact::Report` returned. Nothing here diffs, propagates or
  # derives; counts are the report's records, unknowns stay unknowns.
  #
  # A record belongs to its endpoint's generation. It links into the map only
  # when that generation is the one this request pinned (D-1's "historical
  # identities have no current-source links" for every other generation).
  class RangeReport
    # One emphasised unit for the graph canvas: changed (distance 0) or reached.
    Emphasis = Struct.new(:identifier, :type, :distance, keyword_init: true)

    LENSES = %w[overview changed risks flows tests graph unknown].freeze

    # @param data [Hash] the unchanged report (`WoodsMap::ImpactRange#data`)
    # @param repository [WoodsMap::Repository] the pinned current generation
    # @param focus [Array<String>] identifiers the focus URL selects
    def initialize(data, repository:, focus: [])
      @data = data
      @repository = repository
      @focus = Array(focus).map(&:to_s).reject(&:empty?)
    end

    attr_reader :data, :focus

    # @return [Integer, nil]
    def from_generation
      @data.dig('range', 'from', 'generation')
    end

    # @return [Integer, nil]
    def to_generation
      @data.dig('range', 'to', 'generation')
    end

    # @param side [String] "from" or "to"
    # @return [String, nil] the endpoint's short SHA, when Woods recorded one
    def sha(side)
      value = @data.dig('range', side, 'git_sha').to_s
      value.match?(/\A[0-9a-f]{7,40}\z/i) ? value[0, 7] : nil
    end

    %w[changed affected flows tables templates risks tests unknowns].each do |key|
      define_method(key) { Array(@data[key]) }
    end

    # @return [Hash] coverage facts, without the complete flag
    def coverage
      (@data['coverage'] || {}).except('complete')
    end

    # @return [Boolean] whether Woods declares the report complete
    def complete?
      @data.dig('coverage', 'complete') == true
    end

    # @return [Integer, nil] the propagation depth Woods applied
    def depth
      @data.dig('parameters', 'depth')
    end

    # @param lens [String]
    # @return [Integer, nil] the tab's one count (C5)
    def count(lens)
      case lens
      when 'changed' then changed.size
      when 'risks' then risks.size
      when 'flows' then flows.size
      when 'tests' then tests.size
      when 'graph' then changed.size + affected.size
      when 'unknown' then unknowns.size
      end
    end

    # @param record [Hash] a changed record
    # @return [Integer, nil] the generation the record belongs to
    def generation_of_change(record)
      record['status'] == 'removed' ? from_generation : to_generation
    end

    # @param record [Hash] any record carrying identifier, type and optionally generation
    # @return [Boolean] whether the record names a unit of the pinned generation
    def current?(record, generation: record['generation'])
      generation == @repository.generation_number &&
        !@repository.graph_node(record['identifier'].to_s, type: record['type'].to_s).nil?
    end

    # @param record [Hash]
    # @return [Boolean] whether the focus URL selects this record
    def focused?(record)
      @focus.include?(record['identifier'].to_s)
    end

    # @param root [Hash] a changed record
    # @return [Array<Hash>] affected records whose witness paths start at it
    def reached_from(root)
      identity = root.values_at('identifier', 'type')
      affected.select do |record|
        Array(record['paths']).any? { |path| path['root']&.values_at('identifier', 'type') == identity }
      end
    end

    # @return [Hash, nil] the unit the Graph tab centres on: the first focused
    #   or changed unit the pinned generation has
    def graph_centre
      candidates = changed.select { |c| focused?(c) } + changed
      record = candidates.find { |c| current?(c, generation: generation_of_change(c)) }
      record && { 'identifier' => record['identifier'], 'type' => record['type'] }
    end

    # Changed units at distance 0 and the affected units at theirs, for the
    # graph canvas's emphasis (E-3, E-8); only units of the pinned generation.
    #
    # @return [Array<Emphasis>]
    def emphasis
      changes = changed.select { |c| current?(c, generation: generation_of_change(c)) }
                       .map { |c| Emphasis.new(identifier: c['identifier'], type: c['type'], distance: 0) }
      reached = affected.select { |a| current?(a) }
                        .map { |a| Emphasis.new(identifier: a['identifier'], type: a['type'], distance: a['distance']) }
      (changes + reached).uniq { |e| [e.identifier, e.type] }
    end

    # The emphasis in the shape the graph explorer reads (`blast.affected`).
    GraphBlast = Struct.new(:affected)

    # @return [GraphBlast]
    def graph_blast
      GraphBlast.new(emphasis)
    end
  end
end
