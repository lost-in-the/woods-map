# frozen_string_literal: true

require 'digest'

module WoodsMap
  # The Landscape's Components tab (C4 level 3, B8-Landscape): the
  # application's own units grouped by Packwerk package (`package` on graph
  # nodes, Woods #280), by top-level namespace, or by published domain
  # cluster (woods#799), with the published edges between groups. Every group
  # is a published fact; the map never infers a package or a cluster.
  class Components
    # The board's `group` control, in its order.
    GROUPS = { 'package' => 'package', 'namespace' => 'namespace', 'cluster' => 'domain cluster' }.freeze

    # Units that are not application code, or are bookkeeping about it.
    EXCLUDED = %w[route route_file migration config_file configuration doc i18n test_mapping database_table
                  database_view js_module package engine middleware rails_source rake_task factory test_support
                  scheduled_job].freeze

    # Edges that are tests, documentation or schema bookkeeping, not coupling.
    NOT_COUPLING = Hotspots::NOT_COUPLING + %w[package_dependency]

    # Components a flowchart draws before it names the budget instead (R-4).
    BUDGET = 40

    # Name of the group of units no package, namespace or cluster claims.
    UNGROUPED = { 'package' => '(no package)', 'namespace' => '(top level)', 'cluster' => '(no cluster)' }.freeze

    # One component: its name, members as [identifier, type], and the hub.
    Component = Struct.new(:name, :members, :types, :hub, :declared, keyword_init: true) do
      # @return [String] a Mermaid-safe node id
      def id
        "c_#{Digest::SHA256.hexdigest(name)[0, 10]}"
      end
    end

    # Edges from one component to another.
    Relationship = Struct.new(:from, :to, :edges, :vias, :undeclared, keyword_init: true)

    # @param repository [Repository]
    # @param group [String] one of {GROUPS}; anything else is `package` when the
    #   generation has packages and `namespace` otherwise
    def initialize(repository, group: nil)
      @repository = repository
      @graph = repository.graph
      @analysis = repository.graph_analysis
      @group = GROUPS.key?(group.to_s) ? group.to_s : default_group
    end

    attr_reader :group

    # @return [Boolean] whether any application unit belongs to a Packwerk package
    def packages?
      members.any? { |identifier, _| package_of(identifier) }
    end

    # @return [Boolean] whether the generation publishes domain clusters at all
    def clusters?
      @analysis.key?('domain_clusters')
    end

    # @return [Symbol, nil] why the selected grouping has nothing to show:
    #   :no_packages, :no_clusters, or nil
    def limit
      return :no_packages if @group == 'package' && !packages?
      return :no_clusters if @group == 'cluster' && !clusters?

      nil
    end

    # @return [Array<Component>] largest first, the ungrouped last
    def components
      @components ||= limit ? [] : build_components
    end

    # @return [Array<Relationship>] most edges first
    def relationships
      @relationships ||= limit ? [] : build_relationships
    end

    # @return [Integer] application units considered
    def unit_count
      members.size
    end

    # @return [String, nil] why the flowchart is not drawn, nil within the budget
    def refusal
      return nil if components.size <= BUDGET

      "#{components.size} components is over the diagram budget of #{BUDGET}; the tables below list every one"
    end

    # Mermaid flowchart of the components and the edges between them.
    #
    # @return [String]
    def mermaid
      nodes = components.map do |c|
        %(  #{c.id}["#{text("#{c.name} · #{c.members.size} #{'unit'.pluralize(c.members.size)}")}"])
      end
      arrows = relationships.map do |r|
        %(  #{component(r.from).id} -->|"#{text(relationship_label(r))}"| #{component(r.to).id})
      end
      (['flowchart LR'] + nodes + arrows).join("\n")
    end

    private

    def relationship_label(relationship)
      edges = relationship.edges
      "#{edges} #{'edge'.pluralize(edges)}#{', undeclared' if relationship.undeclared}"
    end

    def default_group
      members.any? { |identifier, _| package_of(identifier) } ? 'package' : 'namespace'
    end

    # Application units as [identifier, type]: a relative source file and a
    # type that is code rather than bookkeeping.
    def members
      @members ||= Hash(@graph['nodes']).filter_map do |identifier, node|
        path = node['file_path'].to_s
        next if path.empty? || path.start_with?('/') || EXCLUDED.include?(node['type'].to_s)

        [identifier, node['type'].to_s]
      end
    end

    def package_of(identifier)
      @graph.dig('nodes', identifier, 'package')
    end

    def group_of(identifier)
      case @group
      when 'package' then package_of(identifier)
      when 'cluster' then cluster_index[identifier]
      else @graph.dig('nodes', identifier, 'namespace').to_s.split('::').first.presence
      end
    end

    def cluster_index
      @cluster_index ||= Array(@analysis['domain_clusters']).each_with_object({}) do |cluster, index|
        Array(cluster['typed_members']).each { |member| index[member['identifier']] ||= cluster['name'] }
      end
    end

    def assignment
      @assignment ||= members.to_h do |identifier, type|
        [[identifier, type], group_of(identifier) || UNGROUPED[@group]]
      end
    end

    def build_components
      groups = assignment.group_by { |_, name| name }.transform_values { |pairs| pairs.map(&:first) }
      list = groups.map { |name, units| component_for(name, units) }
      list.sort_by { |c| [c.name == UNGROUPED[@group] ? 1 : 0, -c.members.size, c.name] }
    end

    def component_for(name, units)
      ranks = Hash(@graph['pagerank'])
      hub = units.max_by { |identifier, _| [ranks[identifier].to_f, identifier] }
      types = units.map(&:last).tally.sort_by { |type, n| [-n, type] }.to_h
      Component.new(name: name, members: units.sort, types: types, hub: hub, declared: declared_dependencies(name))
    end

    # Packages a package declares in its package.yml, as package_dependency edges.
    def declared_dependencies(name)
      return nil unless @group == 'package'

      Array(@graph.dig('edges', name)).select { |e| e['via'] == 'package_dependency' }.pluck('target').sort
    end

    def build_relationships
      list = edge_tally.map do |(from, to), vias|
        Relationship.new(from: from, to: to, edges: vias.values.sum, vias: vias.sort_by { |v, n| [-n, v] }.to_h,
                         undeclared: undeclared?(from, to))
      end
      list.sort_by { |r| [-r.edges, r.from, r.to] }
    end

    # @return [Hash{Array(String, String) => Hash{String => Integer}}] [from, to] => via => edges
    def edge_tally
      tally = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      members.each do |identifier, type|
        from = assignment[[identifier, type]]
        Array(@graph.dig('edges', identifier)).each do |edge|
          next if NOT_COUPLING.include?(edge['via'].to_s)

          to = target_group(edge)
          tally[[from, to]][edge['via'].to_s] += 1 if to && to != from
        end
      end
      tally
    end

    def target_group(edge)
      target = edge['target'].to_s
      type = (edge['type'] || @graph.dig('nodes', target, 'type')).to_s
      assignment[[target, type]]
    end

    def undeclared?(from, to)
      return false unless @group == 'package'

      Array(@analysis['undeclared_package_edges']).any? { |e| e['from_package'] == from && e['to_package'] == to }
    end

    def component(name)
      components.find { |c| c.name == name }
    end

    def text(value)
      value.to_s.gsub('"', '#quot;').gsub('<', '#lt;').gsub('>', '#gt;')
    end
  end
end
