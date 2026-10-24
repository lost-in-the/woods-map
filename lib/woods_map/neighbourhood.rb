# frozen_string_literal: true

require 'digest'

module WoodsMap
  # The Graph tab's list equivalent (B6-Graph): the typed edges around one
  # unit, filtered by direction, depth, type and mechanism, with the notes
  # the graph analysis adds (hubs, cycles, PageRank).
  class Neighbourhood
    # reached_type records the endpoint reached on this edge's first breadth-first visit.
    Edge = Struct.new(:from, :from_type, :via, :to, :to_type, :depth, :reached_type, keyword_init: true)

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
    # @param type [String, nil] the selected unit type; defaults to the primary graph node
    # @param direction [String] both, dependents or dependencies
    # @param depth [Integer] 1 or 2
    # @param filters [Hash] :types (unit types to keep) and :via (mechanisms to keep); nil keeps all
    # The typed focus is explicit alongside the existing traversal options.
    def initialize(repository, identifier, type: nil, direction: 'both', depth: 1, filters: {}) # rubocop:disable Metrics/ParameterLists
      @repository = repository
      @graph = repository.graph
      @analysis = repository.graph_analysis
      @focus = [identifier, type || type_of(identifier)]
      @direction = %w[dependents dependencies].include?(direction) ? direction : 'both'
      @depth = depth.to_i.clamp(1, 2)
      @types = filters[:types]&.map(&:to_s)
      @via = filters[:via]&.map(&:to_s)
    end

    attr_reader :direction, :depth

    # @return [Array(String, String)] the selected unit as identifier and type
    attr_reader :focus

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
      notes << "hub, #{hub['dependent_count']} dependents by identifier" if hub
      notes << 'in a cycle' if Array(@analysis['cycles']).any? { |cycle| cycle.include?(identifier) }
      rank = @graph.dig('pagerank', identifier)
      notes << "weight #{format('%.3f', rank)}" if rank
      notes
    end

    # @param identifier [String]
    # @return [String, nil] a node's type
    def type_of(identifier)
      @repository.graph_node(identifier)&.dig('type')
    end

    # @param identifier [String]
    # @param type [String]
    # @return [Boolean] whether this typed unit is the selected focus
    def focus?(identifier, type)
      @focus == [identifier, type]
    end

    # @return [Integer] distinct typed units the filtered edges touch, the focus included
    def node_count
      edges.flat_map { |e| [[e.from, e.from_type], [e.to, e.to_type]] }.push(@focus).uniq.size
    end

    # @return [Boolean] whether the flowchart would exceed {NODE_BUDGET}
    def over_budget?
      node_count > NODE_BUDGET
    end

    # @return [String, nil] why the flowchart is not drawn, nil within the budget
    def refusal
      return nil unless over_budget?

      "#{node_count} units is over the flowchart budget of #{NODE_BUDGET}; narrow the types or mechanisms to draw it"
    end

    # Mermaid flowchart text for the filtered edges: Woods' own builder when
    # the loaded Woods has it (woods#826), the same bytes as {#local_mermaid}.
    #
    # @return [String]
    def mermaid
      WoodsDiagrams.text(@repository, kind: 'neighbourhood', identifier: @focus.first, type: @focus.last,
                                      depth: @depth, direction: @direction, types: @types, via: @via) || local_mermaid
    end

    # The map's own flowchart text, for a Woods without the diagram builders.
    #
    # @return [String]
    def local_mermaid
      lines = ['flowchart LR', "  #{mermaid_node(*@focus)}"]
      edges.each do |edge|
        from = mermaid_node(edge.from, edge.from_type)
        to = mermaid_node(edge.to, edge.to_type)
        lines << "  #{from} -->|#{edge.via}| #{to}"
      end
      lines << "  class #{node_id(*@focus)} focus"
      lines.join("\n")
    end

    private

    def node_id(identifier, type)
      "n_#{Digest::SHA256.hexdigest([type, identifier].to_json)[0, 16]}"
    end

    def mermaid_node(identifier, type)
      "#{node_id(identifier, type)}[#{"#{identifier} (#{type})".to_json}]"
    end

    # Breadth-first over the typed edges, one level per depth, each edge once.
    def collect
      seen = {}
      frontier = [@focus]
      (1..@depth).each do |level|
        frontier = frontier.flat_map { |node| expand(node, level, seen) }.uniq
      end
      seen.values
    end

    def expand(node, level, seen)
      around(node).filter_map do |edge|
        key = [edge.from, edge.from_type, edge.via, edge.to, edge.to_type]
        next if seen.key?(key)

        edge.depth = level
        seen[key] = edge
        from = [edge.from, edge.from_type]
        reached = from == node ? [edge.to, edge.to_type] : from
        edge.reached_type = reached.last
        reached
      end
    end

    def around(node)
      out = @direction == 'dependents' ? [] : outgoing(node)
      inn = @direction == 'dependencies' ? [] : incoming(node)
      out + inn
    end

    def outgoing(node)
      identifier, type = node
      record = @repository.graph_node(identifier, type: type)
      primary = type_of(identifier) == type
      raw = primary ? @graph.dig('edges', identifier) : record&.dig('edges')
      Array(raw).map do |edge|
        Edge.new(from: identifier, from_type: type, via: edge['via'].to_s, to: edge['target'],
                 to_type: edge['type'] || type_of(edge['target']))
      end
    end

    def incoming(node)
      identifier, type = node
      Array(@graph.dig('reverse_via', identifier)).filter_map do |edge|
        target_type = edge['type'] || type_of(identifier)
        next unless target_type == type

        Edge.new(from: edge['source'], from_type: edge['source_type'] || type_of(edge['source']),
                 via: edge['via'].to_s, to: identifier, to_type: target_type)
      end
    end

    def keep_type?(edge)
      return true if @types.nil?

      edge.reached_type.nil? || @types.include?(edge.reached_type)
    end

    def keep_via?(edge)
      @via.nil? || @via.include?(edge.via)
    end
  end
end
