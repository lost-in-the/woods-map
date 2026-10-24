# frozen_string_literal: true

require 'digest'

module WoodsMap
  # "Graph of pinned" and "ERD of pinned" (notes/trail.md): the M5 graph
  # elements and the M3 ER text, restricted to the board's pins.
  class PinnedViews
    # @param repository [WoodsMap::Repository]
    # @param pins [Array<TrailBoard::Pin>]
    def initialize(repository, pins)
      @repository = repository
      @identities = pins.map(&:identity).select { |identifier, type| repository.graph_node(identifier, type: type) }
    end

    # @return [Array<Array(String, String)>] the pins the generation has
    attr_reader :identities

    # Published edges with both typed ends pinned, each once.
    #
    # @return [Array<Neighbourhood::Edge>]
    def edges
      @edges ||= begin
        all = @identities.flat_map { |identity| outgoing(identity) }
        inner = all.select do |edge|
          pinned?([edge.to, edge.to_type]) && [edge.from, edge.from_type] != [edge.to, edge.to_type]
        end
        inner.uniq { |edge| [edge.from, edge.from_type, edge.via, edge.to, edge.to_type] }
      end
    end

    # The neighbourhood JSON shape (schema version 1) the M5 graph controller draws.
    #
    # @return [Hash]
    def graph_json
      elements = GraphElements.new(@repository, @identities.first)
      { 'schema_version' => 1,
        'query' => { 'pins' => @identities.map do |i, t|
          "#{t}:#{i}"
        end, 'summary' => 'pinned units and the edges between them' },
        'provenance' => @repository.generation_facts.merge('sources' => %w[dependency_graph.json graph_analysis.json],
                                                           'analysis_scope' => 'identifier'),
        'elements' => { 'nodes' => @identities.map { |identity| elements.node(identity) },
                        'edges' => edges.map { |edge| elements.edge(edge) } },
        'truncation' => { 'truncated' => false, 'total_nodes' => @identities.size, 'total_edges' => edges.size,
                          'boundaries' => [] } }
    end

    # @return [String] Mermaid flowchart of the pinned units and their edges
    def graph_mermaid
      lines = ['flowchart LR']
      @identities.each { |identifier, type| lines << "  #{node(identifier, type)}" }
      edges.each { |e| lines << "  #{node_id(e.from, e.from_type)} -->|#{e.via}| #{node_id(e.to, e.to_type)}" }
      lines.join("\n")
    end

    # @return [String, nil] why the graph is not drawn (R-4)
    def graph_refusal
      return nil if @identities.size <= Neighbourhood::NODE_BUDGET

      "#{@identities.size} units is over the flowchart budget of #{Neighbourhood::NODE_BUDGET}"
    end

    # The tables of the pinned models and pinned `database_table` units.
    #
    # @return [Array<Erd::Table>]
    def tables
      @tables ||= begin
        erd = Erd.for(@repository)
        names = @identities.filter_map do |identifier, type|
          case type
          when 'model' then erd.tables.find { |t| t.model == identifier }&.name
          when 'database_table' then erd.tables.find { |t| t.identifier == identifier }&.name
          end
        end
        names.uniq.filter_map { |name| erd.table_named(name) }
      end
    end

    # @param columns [String] keys or all
    # @return [String, nil] the erDiagram text, nil without tables
    def erd_mermaid(columns: 'keys')
      return nil if tables.empty?

      chunk = Erd::Chunk.new(number: 0, database: tables.first.database, group: 'pinned', part: 1, parts: 1,
                             tables: tables.map(&:name))
      Erd.for(@repository).mermaid(chunk, columns: columns)
    end

    # @return [String, nil] why the ERD is not drawn (R-4)
    def erd_refusal
      return nil if tables.size <= SchemaView::TABLE_BUDGET

      "#{tables.size} tables is over the ER budget of #{SchemaView::TABLE_BUDGET}"
    end

    private

    def pinned?(identity)
      @identities.include?(identity)
    end

    def outgoing(identity)
      identifier, type = identity
      primary = @repository.graph_node(identifier)&.dig('type') == type
      raw = if primary
              @repository.graph.dig('edges',
                                    identifier)
            else
              @repository.graph_node(identifier, type: type)&.dig('edges')
            end
      Array(raw).map do |edge|
        Neighbourhood::Edge.new(from: identifier, from_type: type, via: edge['via'].to_s, to: edge['target'],
                                to_type: edge['type'] || @repository.graph_node(edge['target'])&.dig('type'), depth: 1)
      end
    end

    def node_id(identifier, type)
      "n_#{Digest::SHA256.hexdigest([type, identifier].to_json)[0, 16]}"
    end

    def node(identifier, type)
      "#{node_id(identifier, type)}[#{"#{identifier} (#{type})".to_json}]"
    end
  end
end
