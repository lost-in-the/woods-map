# frozen_string_literal: true

require 'digest'

module WoodsMap
  # Cytoscape data shaped from published typed nodes and edges. Absent attributes
  # stay nil, and identifier-level analysis is not presented as typed analysis.
  class GraphElements
    # @param repository [Repository] the request's pinned generation
    # @param focus [Array(String, String)] identifier and type
    def initialize(repository, focus)
      @repository = repository
      @graph = repository.graph
      @analysis = repository.graph_analysis
      @focus = focus
      @hubs = Array(@analysis['hubs']).to_h { |hub| [hub['identifier'], true] }
      @cycles = Array(@analysis['cycles']).flatten.index_with(true)
    end

    # Stable, unambiguous typed identity; the full digest avoids truncating collisions.
    # @param identity [Array(String, String)] identifier and type
    # @return [String]
    def node_id(identity)
      "n_#{Digest::SHA256.hexdigest(identity.to_json)}"
    end

    # @param identity [Array(String, String)] identifier and type
    # @return [String, nil] an explicitly published package
    def package(identity)
      record(identity)&.dig('package')
    end

    # @param identity [Array(String, String)] identifier and type
    # @return [Hash] Cytoscape node, without interpreting a missing attribute
    def node(identity)
      identifier, type = identity
      raw = record(identity) || {}
      { 'data' => {
        'id' => node_id(identity), 'identifier' => identifier, 'label' => identifier, 'type' => type,
        'focus' => identity == @focus, 'file_path' => raw['file_path'],
        'pagerank' => @graph.dig('pagerank', identifier), 'change_frequency' => raw['change_frequency'],
        'hub' => (@hubs.key?(identifier) if @analysis.key?('hubs')),
        'cycle' => (@cycles.key?(identifier) if @analysis.key?('cycles')), 'package' => raw['package']
      } }
    end

    # @param edge [Neighbourhood::Edge]
    # @return [Hash] Cytoscape edge, retaining published relationship attributes
    def edge(edge)
      from = [edge.from, edge.from_type]
      to = [edge.to, edge.to_type]
      id = Digest::SHA256.hexdigest([from, edge.via, to].to_json)
      raw = raw_edge(edge)
      { 'data' => { 'id' => "e_#{id}", 'source' => node_id(from), 'target' => node_id(to),
                    'via' => edge.via, 'depth' => edge.depth,
                    'through' => raw['through'], 'cross_database' => raw['cross_database'] } }
    end

    private

    def record(identity)
      @repository.graph_node(identity.first, type: identity.last)
    end

    def raw_edge(edge)
      Array(outgoing(edge)).find do |candidate|
        type = candidate['type'] || @repository.graph_node(candidate['target'])&.dig('type')
        candidate['target'] == edge.to && type == edge.to_type && candidate['via'].to_s == edge.via
      end || {}
    end

    def outgoing(edge)
      primary = @repository.graph_node(edge.from)&.dig('type') == edge.from_type
      primary ? @graph.dig('edges', edge.from) : record([edge.from, edge.from_type])&.dig('edges')
    end
  end
end
