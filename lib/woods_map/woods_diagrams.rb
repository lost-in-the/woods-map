# frozen_string_literal: true

module WoodsMap
  # Woods' own diagram builders (`Woods::Diagrams`, woods#826), which the
  # Index MCP server's `diagram` tool and `woods:diagram` answer from. The
  # Graph neighbourhood, the Schema ER and the Lifecycle sequence draw their
  # Mermaid from them, so the map, its `.mmd` and `.md` URLs and a review
  # agent's tool call give the same bytes. A Woods without the builders
  # (older than #826) keeps the map's own builders: every caller falls back
  # to its local text when this answers nil. Map-only presentation (the
  # lanes and flowchart views, `?since=` marks, C4 views, the ERD, History,
  # the Trail) stays in the map.
  module WoodsDiagrams
    module_function

    # @return [Boolean] whether the loaded Woods has the diagram builders
    def available?
      return @available unless @available.nil?

      @available = begin
        require 'woods/diagrams'
        Woods::Diagrams.respond_to?(:build)
      rescue LoadError
        false
      end
    end

    # @param repository [WoodsMap::Repository, nil]
    # @param unit [Hash] a model or database_table unit
    # @return [String, nil] Woods' ER text at depth 1, the Schema tab's
    def schema(repository, unit)
      repository && text(repository, kind: 'schema', identifier: unit['identifier'], type: unit['type'], depth: 1)
    end

    # @param repository [WoodsMap::Repository, nil]
    # @param identifier [String] a model's identifier
    # @param event [String]
    # @return [String, nil] Woods' sequence at depth 0, the Lifecycle tab's
    def lifecycle(repository, identifier, event)
      repository && text(repository, kind: 'lifecycle', identifier: identifier, type: 'model', depth: 0, event: event)
    end

    # @param repository [WoodsMap::Repository] the request's pinned generation
    # @param kind [String] neighbourhood, schema or lifecycle
    # @param identifier [String]
    # @param options [Hash] type, depth and the kind's own options
    # @return [String, nil] Woods' text; nil without the builders, or when Woods
    #   refuses or cannot answer, so the caller draws its own
    def text(repository, kind:, identifier:, **options)
      reader = repository.respond_to?(:index_reader) ? repository.index_reader : nil
      # Only a real reader: a repository whose graph is supplied some other way keeps the map's builders.
      return nil unless available? && reader.is_a?(Woods::MCP::IndexReader)

      Woods::Diagrams.build(reader, kind: kind, identifier: identifier, **options.compact).text
    rescue Woods::Diagrams::InvalidRequest, Woods::Diagrams::UnitNotFound
      nil
    end

    # Forget what {available?} found (specs).
    #
    # @return [void]
    def reset!
      @available = nil
    end
  end
end
