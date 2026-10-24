# frozen_string_literal: true

module WoodsMap
  # The Landscape's arrows between containers, from published edges: each
  # edge from a process's unit (web, jobs) to a unit in another container,
  # tallied by mechanism. A model's own edges (an enqueue in a callback)
  # start in whichever process saves it, which the index does not say, so
  # edges leaving a store are not drawn.
  class ContainerRelationships
    # Mechanisms that hand work to the job runner.
    ASYNC_VIAS = %w[job_enqueue mailer_call deliver deliver_later scheduled].freeze

    # @param node [Hash, nil] a graph node
    # @return [String, nil] the Landscape container id: web, jobs or db_<database>
    def self.container_id(node)
      return nil unless node && node['container']

      case node['container']
      when 'database' then "db_#{node['database'] || 'primary'}"
      when 'web', 'jobs' then node['container']
      end
    end

    # @param repository [Repository]
    def initialize(repository)
      @repository = repository
      @graph = repository.graph
    end

    # @return [Array<Landscape::Relationship>] the processes' arrows first
    def to_a
      grouped = tally.group_by { |(from, to, _), _| [from, to] }
      rows = grouped.map { |(from, to), counts| relationship(from, to, counts) }
      rows.sort_by { |r| [rank(r.from), rank(r.to)] }
    end

    private

    def tally
      counts = Hash.new(0)
      Hash(@graph['edges']).each do |source, edges|
        from = self.class.container_id(@graph.dig('nodes', source))
        next unless %w[web jobs].include?(from)

        Array(edges).each do |edge|
          to = self.class.container_id(@repository.graph_node(edge['target'], type: edge['type']))
          counts[[from, to, edge['via'].to_s]] += 1 if to && to != from
        end
      end
      counts
    end

    def relationship(from, to, counts)
      vias = counts.map { |(_, _, via), _| via }
      edges = counts.sort_by { |(_, _, via), count| [-count, via] }.map { |(_, _, via), count| "#{count} #{via}" }
      label, mechanism = describe(to, vias)
      Landscape::Relationship.new(from: from, to: to, label: label, mechanism: mechanism, edges: edges.join(', '),
                                  source: 'typed edges')
    end

    # An enqueue into the job runner, Active Record into a database, otherwise the mechanisms.
    def describe(to, vias)
      return %w[enqueues perform_later] if to == 'jobs' && (vias & ASYNC_VIAS).any?
      return ['reads, writes', 'Active Record'] if to.start_with?('db_')

      ['references', vias.sort.first(3).join(', ')]
    end

    def rank(id)
      %w[web jobs].index(id) || (id.start_with?('db_') ? 2 : 3)
    end
  end
end
