# frozen_string_literal: true

module WoodsMap
  # The Graph tab's list equivalent (B6-Graph): the typed edges around one
  # unit, filtered by direction, depth, type and mechanism, with the notes
  # the graph analysis adds (hubs, cycles, PageRank).
  class Neighbourhood
    Edge = Struct.new(:from, :from_type, :via, :to, :to_type, :depth, keyword_init: true)

    # Mechanism families (A1 to A5 on the board).
    FAMILIES = {
      'data model' => %w[belongs_to has_many has_one has_and_belongs_to_many through polymorphic],
      'structure' => %w[include extend code_reference inherits],
      'request' => %w[render view_render link_to redirect_to form_action route_dispatch],
      'async' => %w[job_enqueue mailer_call deliver],
      'cross-cutting' => %w[test_coverage]
    }.freeze

    # Flowchart node budget (R-4): above it the panel names the budget and
    # keeps the text, rather than drawing a diagram nobody can read.
    NODE_BUDGET = 150

    # @param repository [WoodsMap::Repository]
    # @param identifier [String]
    # @param direction [String] both, dependents or dependencies
    # @param depth [Integer] 1 or 2
    # @param filters [Hash] :types (unit types to keep) and :via (mechanisms to keep); nil keeps all
    def initialize(repository, identifier, direction: 'both', depth: 1, filters: {})
      @graph = repository.graph
      @analysis = repository.graph_analysis
      @identifier = identifier
      @direction = %w[dependents dependencies].include?(direction) ? direction : 'both'
      @depth = depth.to_i.clamp(1, 2)
      @types = filters[:types]&.map(&:to_s)
      @via = filters[:via]&.map(&:to_s)
    end

    attr_reader :direction, :depth

    # @return [Array<Edge>] the edges within reach, before the type and via filters
    def all_edges
      @all_edges ||= collect
    end

    # @return [Array<Edge>] after the filters
    def edges
      all_edges.select { |e| keep_type?(e) && keep_via?(e) }
    end

    # @return [Hash{String => Integer}] unit type => edges touching it (for the filters)
    def type_counts
      all_edges.flat_map { |e| [e.from_type, e.to_type] }.compact.tally.sort_by { |type, _| type }.to_h
    end

    # @return [Hash{String => Hash{String => Integer}}] family => via => count
    def via_counts
      counts = all_edges.map(&:via).tally
      FAMILIES.to_h { |family, vias| [family, counts.slice(*vias)] }.reject { |_, c| c.empty? }
    end

    # @param identifier [String]
    # @return [Array<String>] notes from the analysis: hub, cycle, weight
    def notes(identifier)
      notes = []
      hub = Array(@analysis['hubs']).find { |h| h['identifier'] == identifier }
      notes << "hub, #{hub['dependent_count']} dependents" if hub
      notes << 'in a cycle' if Array(@analysis['cycles']).any? { |cycle| cycle.include?(identifier) }
      rank = @graph.dig('pagerank', identifier)
      notes << "weight #{format('%.3f', rank)}" if rank
      notes
    end

    # @param identifier [String]
    # @return [String, nil] a node's type
    def type_of(identifier)
      @graph.dig('nodes', identifier, 'type')
    end

    # @return [Integer] distinct units the filtered edges touch, the focus included
    def node_count
      edges.flat_map { |e| [e.from, e.to] }.push(@identifier).uniq.size
    end

    # @return [Boolean] whether the flowchart would exceed {NODE_BUDGET}
    def over_budget?
      node_count > NODE_BUDGET
    end

    # Mermaid flowchart text for the filtered edges.
    #
    # @return [String]
    def mermaid
      lines = ['flowchart LR', "  #{node_id(@identifier)}[\"#{@identifier}\"]"]
      edges.each { |e| lines << "  #{node_id(e.from)}[\"#{e.from}\"] -->|#{e.via}| #{node_id(e.to)}[\"#{e.to}\"]" }
      lines << "  class #{node_id(@identifier)} focus"
      lines.join("\n")
    end

    private

    def node_id(identifier)
      identifier.to_s.gsub(/[^A-Za-z0-9_]/, '_')
    end

    # Breadth-first over the typed edges, one level per depth, each edge once.
    def collect
      seen = {}
      frontier = [@identifier]
      (1..@depth).each do |level|
        frontier = frontier.flat_map { |node| expand(node, level, seen) }.uniq
      end
      seen.values
    end

    def expand(node, level, seen)
      around(node).filter_map do |edge|
        key = [edge.from, edge.via, edge.to]
        next if seen.key?(key)

        edge.depth = level
        seen[key] = edge
        edge.from == node ? edge.to : edge.from
      end
    end

    def around(node)
      out = @direction == 'dependents' ? [] : outgoing(node)
      inn = @direction == 'dependencies' ? [] : incoming(node)
      out + inn
    end

    def outgoing(node)
      Array(@graph.dig('edges', node)).map do |e|
        Edge.new(from: node, from_type: type_of(node), via: e['via'].to_s, to: e['target'],
                 to_type: e['type'] || type_of(e['target']))
      end
    end

    def incoming(node)
      Array(@graph.dig('reverse_via', node)).map do |e|
        Edge.new(from: e['source'], from_type: e['source_type'] || type_of(e['source']), via: e['via'].to_s,
                 to: node, to_type: type_of(node))
      end
    end

    def keep_type?(edge)
      return true if @types.nil?

      other = edge.from == @identifier ? edge.to_type : edge.from_type
      other.nil? || @types.include?(other)
    end

    def keep_via?(edge)
      @via.nil? || @via.include?(edge.via)
    end
  end
end
