# frozen_string_literal: true

require 'set'

module WoodsMap
  # The blast radius of a focus set (E-9, pre-change mode): the units the
  # graph's reverse edges reach within a depth, each with the path that
  # explains it, its PageRank weight and the analysis notes. The same
  # propagation the impact report describes (E-3), over one generation and
  # no range.
  class BlastRadius
    # One affected unit: how far, by which mechanism, from which unit, along which path.
    Affected = Struct.new(:identifier, :type, :distance, :via, :from, :path, keyword_init: true)

    MAX_DEPTH = 3
    # Affected rows one page of the impact list shows; the pager reaches the rest.
    LIST_PER_PAGE = 300
    # The "show" control: which unit types a view hides.
    HIDDEN = { 'no_tests' => %w[test_mapping test_support],
               'no_views' => %w[view_template view_component component] }.freeze

    # @param repository [WoodsMap::Repository]
    # @param focus [Array<String>, String, nil] identifiers, comma-separated or repeated
    # @param depth [Integer, String] 1 to 3
    # @param filters [Hash] :types and :via (lists to keep among the affected), :show (all, no_tests, no_views)
    def initialize(repository, focus:, depth: 2, filters: {})
      @graph = repository.graph
      @analysis = repository.graph_analysis
      @focus, @unknown = list(focus).partition { |id| @graph.fetch('nodes', {}).key?(id) }
      @depth = depth.to_i.clamp(1, MAX_DEPTH)
      @types = list(filters[:types]).presence
      @via = list(filters[:via]).presence
      @show = HIDDEN.key?(filters[:show].to_s) ? filters[:show].to_s : 'all'
    end

    attr_reader :focus, :unknown, :depth, :show

    # @!method empty?
    #   @return [Boolean] no focus unit exists in the generation
    delegate :empty?, to: :focus

    # @param identifier [String]
    # @return [String] the unit type the graph records
    def type_of(identifier)
      @graph.dig('nodes', identifier, 'type').to_s
    end

    # @param identifier [String]
    # @return [Float] the PageRank weight
    def weight(identifier)
      @graph.dig('pagerank', identifier).to_f
    end

    # @param identifier [String]
    # @return [Integer] how many units depend on it
    def dependent_count(identifier)
      Array(@graph.dig('reverse_via', identifier)).pluck('source').uniq.size
    end

    # @return [Array<Affected>] every unit within reach, breadth first, before the filters
    def reached
      @reached ||= collect
    end

    # @return [Array<Affected>] after the type, mechanism and show filters
    def affected
      reached.select { |a| keep?(a) }
    end

    # @return [Array<Affected>] one edge away from the focus
    def direct
      affected.select { |a| a.distance == 1 }
    end

    # @return [Array<Affected>] further away
    def transitive
      affected.select { |a| a.distance > 1 }
    end

    # @return [Array<String>] the focus and the affected identifiers
    def involved
      focus + affected.map(&:identifier)
    end

    # @param identifier [String]
    # @return [Array<String>] notes from the analysis: hub, cycle, bridge
    def notes(identifier)
      notes = []
      notes << "hub, #{hubs[identifier]} dependents" if hubs.key?(identifier)
      notes << 'in a cycle' if cycles.include?(identifier)
      notes << 'bridge' if bridges.include?(identifier)
      notes
    end

    # @return [Hash{String => Integer}] hub identifier => dependent count
    def hubs
      @hubs ||= Array(@analysis['hubs']).to_h { |h| [h['identifier'].to_s, h['dependent_count'].to_i] }
    end

    # @return [Set<String>] every unit on a reported cycle
    def cycles
      @cycles ||= Array(@analysis['cycles']).flatten.to_set(&:to_s)
    end

    # @return [Set<String>] every unit at either end of a bridge
    def bridges
      @bridges ||= Array(@analysis['bridges']).flat_map { |b| b.is_a?(Hash) ? [b['source'], b['target']] : Array(b) }
                                              .to_set(&:to_s)
    end

    # @return [Hash{String => Integer}] unit type => reached units, for the filters
    def type_counts
      reached.map(&:type).tally.sort.to_h
    end

    # @return [Hash{String => Integer}] mechanism => reached units
    def via_counts
      reached.map(&:via).tally.sort.to_h
    end

    # @return [String] a flowchart of the paths, focus to affected, with the mechanism on each edge
    def mermaid
      lines = ['flowchart LR']
      involved.uniq.each { |id| lines << "  #{node_id(id)}[\"#{id}\"]" }
      affected.each { |a| lines << "  #{node_id(a.from)} -- #{a.via} --> #{node_id(a.identifier)}" }
      focus.each { |id| lines << "  class #{node_id(id)} focus" }
      lines.join("\n")
    end

    private

    def list(value)
      Array(value).flat_map { |v| v.to_s.split(',') }.map(&:strip).reject(&:empty?).uniq
    end

    # Breadth first over the reverse edges, one path per unit, the focus never re-entered.
    def collect
      seen = focus.to_set
      queue = focus.map { |id| [id, 0, []] }
      found = []
      until queue.empty?
        id, distance, path = queue.shift
        next if distance >= @depth

        expand(id, path, seen).each do |affected|
          affected.distance = distance + 1
          found << affected
          queue << [affected.identifier, distance + 1, affected.path]
        end
      end
      found
    end

    # The dependents of one unit not seen before, each with its path so far.
    def expand(identifier, path, seen)
      Array(@graph.dig('reverse_via', identifier)).filter_map do |edge|
        source = edge['source'].to_s
        next unless seen.add?(source)

        Affected.new(identifier: source, type: edge['source_type'].to_s, via: edge['via'].to_s, from: identifier,
                     path: path + [[identifier, edge['via'].to_s, source]])
      end
    end

    def keep?(affected)
      return false if @types&.exclude?(affected.type)
      return false if @via&.exclude?(affected.via)

      HIDDEN.fetch(@show, []).exclude?(affected.type)
    end

    def node_id(identifier)
      identifier.gsub(/[^A-Za-z0-9_]/, '_')
    end
  end
end
