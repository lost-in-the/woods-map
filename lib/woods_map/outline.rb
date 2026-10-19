# frozen_string_literal: true

module WoodsMap
  # The rail of the Code tab (B8-Code): the lifecycle per event in chain
  # order, associations, methods by owner, scopes; for a controller the
  # actions and filters. Everything comes from the unit's metadata.
  class Outline
    Group = Struct.new(:label, :count, :items, keyword_init: true)
    Item = Struct.new(:key, :text, :own, :line, keyword_init: true)

    # @param unit [Hash]
    # @param lifecycle [WoodsMap::Lifecycle, nil]
    # @param concern_methods [Hash{String => Array<String>}]
    def initialize(unit, lifecycle: nil, concern_methods: {})
      @unit = unit
      @metadata = unit['metadata'] || {}
      @lifecycle = lifecycle
      @concern_methods = concern_methods
    end

    # @return [Array<Group>]
    def groups
      case @unit['type'].to_s
      when 'model' then model_groups
      when 'controller', 'mailer' then controller_groups
      when 'job' then job_groups
      when 'view_template', 'view_component', 'component' then template_groups
      else method_groups
      end
    end

    private

    def model_groups
      lifecycle_groups + [associations_group, *method_groups, scopes_group].compact
    end

    def lifecycle_groups
      return [] unless @lifecycle

      @lifecycle.chains.map do |event, steps|
        items = steps.map do |step|
          own = step.owner == @unit['identifier'] ? nil : "← #{step.owner}"
          Item.new(key: step.n, text: "#{step.type} #{step.filter}", own: own)
        end
        Group.new(label: "lifecycle, #{event}", count: steps.size, items: items)
      end
    end

    def associations_group
      assocs = Array(@metadata['associations'])
      return nil if assocs.empty?

      items = assocs.map do |a|
        detail = [a['type'], (a['through'] ? "through #{a['through']}" : a['target'])].join(' ')
        Item.new(key: '·', text: a['name'].to_s, own: detail)
      end
      Group.new(label: 'associations', count: assocs.size, items: items)
    end

    def method_groups
      own = Array(@metadata['instance_methods'] || @metadata['public_methods']).map(&:to_s)
      concern_defined = @concern_methods.values.flatten
      groups = []
      mine = own - concern_defined
      if mine.any?
        groups << Group.new(label: "methods, #{@unit['identifier']}", count: mine.size, items: mine.map { |m|
          Item.new(key: '·', text: m)
        })
      end
      @concern_methods.each do |concern, methods|
        groups << Group.new(label: "methods, #{concern}", count: methods.size, items: methods.map { |m|
          Item.new(key: '·', text: m)
        })
      end
      groups
    end

    def scopes_group
      scopes = Array(@metadata['scopes'])
      return nil if scopes.empty?

      Group.new(label: 'scopes', count: scopes.size, items: scopes.map do |s|
        Item.new(key: '·', text: (s.is_a?(Hash) ? s['name'] : s).to_s)
      end)
    end

    def controller_groups
      [actions_group, filters_group].compact
    end

    def actions_group
      actions = Array(@metadata['actions']).map(&:to_s)
      return nil if actions.empty?

      Group.new(label: 'actions', count: actions.size,
                items: actions.map { |a| Item.new(key: '·', text: a, own: route_label(a)) })
    end

    def filters_group
      filters = Array(@metadata['filters']).reject { |f| f['filter'].to_s.match?(Lifecycle::INTERNAL) }
      return nil if filters.empty?

      items = filters.map { |f| Item.new(key: '·', text: "#{f['kind']} #{f['filter']}", own: filter_scope(f)) }
      Group.new(label: 'filters', count: filters.size, items: items)
    end

    def route_label(action)
      routes = Array(@metadata.dig('routes', action))
      routes.map { |r| "#{r['verb']} #{r['path']}" }.first(2).join(', ')
    end

    def filter_scope(filter)
      only = Array(filter['only']).presence
      except = Array(filter['except']).presence
      if only
        "only #{only.join(', ')}"
      else
        (except ? "except #{except.join(', ')}" : nil)
      end
    end

    def job_groups
      params = Array(@metadata['perform_params']).join(', ')
      queue = @metadata['queue'] && "queue #{@metadata['queue']}"
      [Group.new(label: 'perform', count: 1, items: [Item.new(key: '·', text: "perform(#{params})", own: queue)])]
    end

    def template_groups
      [group_of('instance variables', Array(@metadata['instance_variables'])),
       group_of('partials rendered', Array(@metadata['partials_rendered'])),
       group_of('helpers called', Array(@metadata['helpers_called']))].compact
    end

    def group_of(label, names)
      return nil if names.empty?

      Group.new(label: label, count: names.size, items: names.map { |name| Item.new(key: '·', text: name.to_s) })
    end
  end
end
