# frozen_string_literal: true

module WoodsMap
  # The external services around the system (woods#814): the services whose
  # client gem the Gemfile unit declares (`metadata.external_services`) and
  # the targets of the `service_call` edges Woods records where code calls a
  # client constant. Each becomes an external box on Context and Containers;
  # the web and job processes whose units call one get a relationship to it.
  # Uncatalogued gems and generic HTTP clients are not published, so they are
  # not drawn.
  class LandscapeServices
    # @param graph [Hash] the published dependency graph
    # @param gemfile [Hash] the Gemfile configuration unit, or an empty hash
    # @param nodes [Hash] graph nodes by identifier
    def initialize(graph, gemfile, nodes)
      @graph = graph
      @declared = Array(gemfile.dig('metadata', 'external_services')).index_by { |service| service['name'].to_s }
      @published = Hash(gemfile['metadata']).key?('external_services')
      @nodes = nodes
    end

    # @return [Boolean] whether this generation says which services the code calls
    def published?
      @published || callers.any?
    end

    # @return [Array<Landscape::Container>] declared and called services, by name
    def boxes
      @boxes ||= (@declared.keys | callers.keys).sort.map { |name| box(name) }
    end

    # @return [Hash{String => Array<String>}] service name => calling unit identifiers
    def callers
      @callers ||= Hash(@graph['edges']).each_with_object({}) do |(source, edges), out|
        Array(edges).each do |edge|
          (out[edge['target'].to_s] ||= []) << source if edge['via'] == 'service_call'
        end
      end.transform_values(&:uniq)
    end

    # @return [Array<Landscape::Relationship>] web and jobs to each service they call
    def relationships
      boxes.flat_map do |box|
        by_process = callers.fetch(box.name, []).group_by { |id| @nodes.dig(id, 'container') }
        by_process.slice('web', 'jobs').map do |from, ids|
          Landscape::Relationship.new(from: from, to: box.id, label: 'calls', mechanism: 'client code',
                                      edges: ids.size, source: 'service_call')
        end
      end
    end

    private

    def box(name)
      Landscape::Container.new(id: "svc_#{name.parameterize(separator: '_')}", name: name, kind: 'external',
                               technology: technology(@declared[name]), description: description(name), counts: {})
    end

    def technology(declared)
      return 'no client gem in the Gemfile' unless declared

      "#{declared['category']}, gem #{Array(declared['gems']).join(', ')}"
    end

    def description(name)
      calling = callers.fetch(name, [])
      return 'client gem declared, no call found' if calling.empty?

      "called by #{calling.size} #{'unit'.pluralize(calling.size)}"
    end
  end
end
