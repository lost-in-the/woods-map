# frozen_string_literal: true

module WoodsMap
  # The Routes tab of a controller (FR-3): the routes that dispatch to it, the
  # named-route helpers they define, where each action is defined and the
  # units that reach the controller through a route helper. Everything comes
  # from one pinned generation: the controller's `routes` and `action_sources`
  # metadata, the route units dispatching to it (`route_dispatch` reverse
  # edges), graph analysis's `unresolvable_routes`, and the navigation edges
  # (`link_to`, `redirect_to`, `form_action`) Woods resolves from `_path` and
  # `_url` helpers. Nothing is parsed from host source.
  class RoutesView
    # Navigation mechanisms, in the order the tab lists them.
    NAVIGATION = %w[link_to redirect_to form_action].freeze

    # One route to the controller: as the controller's metadata declares it,
    # joined to the route unit of the same verb and path when the index has one.
    Route = Struct.new(:verb, :path, :action, :name, :constraints, :key, :unit, :line, :finding,
                       keyword_init: true) do
      # @return [Array<String>] the named-route helpers Rails defines for the name
      def helpers
        name ? ["#{name}_path", "#{name}_url"] : []
      end

      # @return [String] the route unit's identifier: its own when known, else "VERB path"
      def identifier
        key || "#{verb} #{path}"
      end
    end

    # One action of the controller with its definition and its routes.
    Action = Struct.new(:name, :owner, :defined_in, :file, :line, :routes, :gem, keyword_init: true) do
      # @return [Boolean] whether the action is defined above the controller itself
      def inherited?
        defined_in.present? && owner.present? && defined_in != owner
      end
    end

    # One unit reaching the controller through a route helper. +uses+ are the
    # helpers it calls for this controller by this mechanism, from its
    # `route_helper_references` (woods#795); nil when its generation predates them.
    Reference = Struct.new(:source, :source_type, :via, :uses, keyword_init: true)

    # One route helper a unit calls: the helper as written and the action it reaches.
    Use = Struct.new(:helper, :action, :verb, :path, keyword_init: true)

    # How many routes the tab lists, without building them: the routes the
    # controller's metadata declares plus the route units dispatching to it
    # that the metadata omits. The unit page's tab count uses it, so the tab,
    # the section header and the table agree.
    #
    # @param repository [WoodsMap::Repository]
    # @param unit [Hash] the controller unit
    # @return [Integer]
    def self.count_for(repository, unit)
      declared = Array(unit.dig('metadata', 'routes')).flat_map do |_action, list|
        Array(list).map { |route| "#{route['verb']} #{route['path']}" }
      end
      extra = dispatch_sources(repository, unit['identifier'].to_s) - declared
      declared.size + extra.count { |id| repository.graph_node(id, type: 'route') }
    end

    # @return [Array<String>] route units with a `route_dispatch` edge to the controller
    def self.dispatch_sources(repository, identifier)
      Array(repository.graph.dig('reverse_via', identifier)).filter_map do |edge|
        edge['source'].to_s if edge['via'].to_s == 'route_dispatch' && edge['source_type'].to_s == 'route'
      end.uniq
    end

    # @param repository [WoodsMap::Repository]
    # @param unit [Hash] the controller unit
    def initialize(repository, unit)
      @repository = repository
      @unit = unit
      @metadata = unit['metadata'] || {}
      @identifier = unit['identifier'].to_s
      @reverse = Array(repository.graph.dig('reverse_via', @identifier))
      @analysis = repository.graph_analysis
      @routes = build_routes
    end

    attr_reader :routes

    # @return [Array<Action>] every action, with routes, in the metadata's order
    def actions
      @actions ||= begin
        names = (Array(@metadata['actions']) + gem_actions.keys + @routes.map(&:action)).compact.map(&:to_s).uniq
        names.map { |name| build_action(name) }
      end
    end

    # @return [Array<Action>] actions no route reaches
    def unrouted_actions
      actions.select { |action| action.routes.empty? }
    end

    # @return [Array<Route>] routes graph analysis reports as unresolvable
    def unresolvable
      @routes.select(&:finding)
    end

    # @return [Array<Route>] routes that define a named-route helper
    def named
      @routes.select(&:name)
    end

    # @return [Array<Reference>] units that reach the controller by a route helper
    def references
      @references ||= begin
        edges = @reverse.select { |edge| NAVIGATION.include?(edge['via'].to_s) }
        refs = edges.map do |edge|
          Reference.new(source: edge['source'], source_type: edge['source_type'], via: edge['via'].to_s)
        end
        refs.uniq { |ref| [ref.source, ref.source_type, ref.via] }
            .sort_by { |ref| [NAVIGATION.index(ref.via), ref.source.to_s] }
            .each { |ref| ref.uses = uses_for(ref) }
      end
    end

    # @return [Integer] the tab's count
    def count
      @routes.size
    end

    # @return [Array<String>] what this tab cannot show from the index
    def limits
      limits = []
      if references.any? { |ref| ref.uses.nil? }
        limits << 'helper references name the controller, not the helper or action (woods#795)'
      end
      missing = @routes.count { |route| route.unit.nil? }
      limits << "#{missing} #{'route'.pluralize(missing)} without a route unit in this generation" if missing.positive?
      limits
    end

    private

    # The helpers a referencing unit publishes for this controller and mechanism.
    def uses_for(ref)
      published = @repository.unit(ref.source, type: ref.source_type.to_s)&.dig('metadata', 'route_helper_references')
      return nil unless published.is_a?(Array)

      mine = published.select { |entry| entry['controller'] == @identifier && entry['via'].to_s == ref.via }
      uses = mine.map do |entry|
        Use.new(helper: entry['helper'], action: entry['action'], verb: entry['verb'], path: entry['path'])
      end
      uses.sort_by { |use| [use.helper.to_s, use.action.to_s] }
    end

    def build_routes
      declared = Array(@metadata['routes']).flat_map do |action, list|
        Array(list).map { |route| declared_route(action.to_s, route) }
      end
      dispatched = dispatching_routes(declared.map(&:identifier))
      (declared + dispatched).each { |route| attach_unit(route) }
                             .sort_by { |route| [route.path.to_s, route.verb.to_s] }
    end

    def declared_route(action, route)
      Route.new(verb: route['verb'].to_s, path: route['path'].to_s, action: action, name: route['name'].presence,
                constraints: route['constraints'].presence)
    end

    # Route units dispatching to this controller that its metadata does not list.
    def dispatching_routes(declared)
      sources = @reverse.select { |edge| edge['via'].to_s == 'route_dispatch' && edge['source_type'].to_s == 'route' }
                        .map { |edge| edge['source'].to_s }
      (sources.uniq - declared).filter_map { |identifier| unit_route(identifier) }
    end

    def unit_route(identifier)
      meta = @repository.unit(identifier, type: 'route')&.dig('metadata')
      return nil unless meta

      Route.new(verb: meta['http_method'].to_s, path: meta['path'].to_s, action: meta['action'].to_s.presence,
                name: meta['route_name'].presence, constraints: meta['constraints'].presence, key: identifier)
    end

    def attach_unit(route)
      unit = @repository.unit(route.identifier, type: 'route')
      route.unit = unit && route.identifier
      route.line = unit&.dig('metadata', 'line_number')
      route.finding = findings[route.identifier]
      route
    end

    # route identifier => reason, for this controller's unresolvable routes
    def findings
      @findings ||= Array(@analysis['unresolvable_routes']).each_with_object({}) do |entry, out|
        next unless entry.is_a?(Hash) && entry['controller'].to_s == @identifier

        out[entry['route'].to_s] = entry['reason'].to_s
      end
    end

    def build_action(name)
      source = (@metadata['action_sources'] || {})[name] || gem_actions[name] || {}
      Action.new(name: name, owner: source['owner'], defined_in: source['defined_in'], file: source['file'],
                 line: source['line'], routes: @routes.select { |route| route.action == name },
                 gem: gem_actions.key?(name))
    end

    def gem_actions
      @gem_actions ||= (@metadata['inherited_gem_actions'].is_a?(Hash) ? @metadata['inherited_gem_actions'] : {})
                       .transform_keys(&:to_s).transform_values { |v| v.is_a?(Hash) ? v : {} }
    end
  end
end
