# frozen_string_literal: true

module WoodsMap
  # Bounded JSON projection of Neighbourhood, without another graph traversal.
  # Filters and limits affect the output only, and no retained edge can dangle.
  class NeighbourhoodResponse
    # @param repository [Repository] held open for the whole response
    # @param query [NeighbourhoodQuery]
    def initialize(repository, query)
      @repository = repository
      @query = query.to_h
      @focus = @query.values_at('centre', 'type')
      @elements = GraphElements.new(repository, @focus)
      @neighbourhood = Neighbourhood.new(
        repository, @focus.first, type: @focus.last, depth: @query['depth'], direction: @query['direction'],
                                  filters: { types: @query['types'], via: @query['via'] }
      )
    end

    # @return [Hash] versioned string-keyed response with provenance and truncation
    def to_h
      select_elements
      { 'schema_version' => 1, 'query' => @query, 'provenance' => provenance,
        'elements' => { 'nodes' => @nodes.keys.map { |identity| @elements.node(identity) },
                        'edges' => @edges.map { |edge| @elements.edge(edge) } },
        'truncation' => truncation }
    end

    private

    def provenance
      @repository.generation_facts.merge(
        'sources' => %w[dependency_graph.json graph_analysis.json],
        'analysis_scope' => 'identifier', 'identifier_level_attributes' => %w[pagerank hub cycle],
        'limits_scope' => 'response; existing traversal is unchanged'
      )
    end

    def select_elements
      @nodes = { @focus => true }
      @edges = []
      @omitted = []
      @matched = @neighbourhood.edges.select { |edge| keep_package?(edge) }
      @matched.each do |edge|
        identities = endpoints(edge)
        added = identities.reject { |identity| @nodes.key?(identity) }
        if @nodes.size + added.size <= @query['node_limit'] && @edges.size < @query['edge_limit']
          added.each { |identity| @nodes[identity] = true }
          @edges << edge
        else
          @omitted << edge
        end
      end
    end

    def endpoints(edge)
      [[edge.from, edge.from_type], [edge.to, edge.to_type]].uniq
    end

    def keep_package?(edge)
      return true unless @query['package']

      endpoints(edge).all? { |identity| identity == @focus || @elements.package(identity) == @query['package'] }
    end

    def truncation
      total_nodes = ([@focus] + @matched.flat_map { |edge| endpoints(edge) }).uniq.size
      { 'truncated' => @omitted.any?, 'node_limit' => @query['node_limit'], 'edge_limit' => @query['edge_limit'],
        'total_nodes' => total_nodes, 'total_edges' => @matched.size,
        'omitted_nodes' => total_nodes - @nodes.size, 'omitted_edges' => @omitted.size,
        'boundaries' => boundaries }
    end

    def boundaries
      counts = {}
      @omitted.each do |edge|
        identities = endpoints(edge)
        identities.select { |identity| @nodes.key?(identity) }.each do |identity|
          count = (counts[identity] ||= { edges: 0, nodes: {} })
          count[:edges] += 1
          identities.reject { |key| @nodes.key?(key) }.each { |key| count[:nodes][key] = true }
        end
      end
      counts.map do |identity, count|
        { 'node_id' => @elements.node_id(identity), 'hidden_edges' => count[:edges],
          'hidden_nodes' => count[:nodes].size }
      end
    end
  end
end
