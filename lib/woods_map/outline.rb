# frozen_string_literal: true

module WoodsMap
  # The rail of the Code tab (B8-Code): the lifecycle per event in chain
  # order, associations, methods by owner, scopes; for a controller the
  # actions and filters. Everything comes from the unit's metadata.
  class Outline
    Group = Struct.new(:label, :count, :items, keyword_init: true)
    Item = Struct.new(:key, :text, :own, :line, :href, keyword_init: true)

    # @param unit [Hash]
    # @param lifecycle [WoodsMap::Lifecycle, nil]
    # @param concern_methods [Hash{String => Array<String>}]
    # @param callers [Hash{String, nil => Array}] calls into the unit by method name
    # @param links [Hash{Symbol => #call}] resolvers for the links an item can carry; each answers nil for no link:
    #   :method (method table entry => URL of its line), :definition (published file and file line => URL)
    def initialize(unit, lifecycle: nil, concern_methods: {}, callers: {}, links: {})
      @unit = unit
      @metadata = unit['metadata'] || {}
      @lifecycle = lifecycle
      @concern_methods = concern_methods
      @callers = callers
      @links = links
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

    # Grouped by owner from the method table (W-2) when the index has one, in
    # source order with each method's line; else the name lists.
    def method_groups
      table = @metadata['methods']
      table.is_a?(Array) ? table_groups(table) : name_groups
    end

    def name_groups
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

    def table_groups(table)
      entries = table.select { |entry| entry.is_a?(Hash) && entry['name'].is_a?(String) }
      owners = entries.pluck('owner').uniq
      owners = [@unit['identifier']] + (owners - [@unit['identifier']]) if owners.include?(@unit['identifier'])
      owners.map do |owner|
        items = entries.select { |entry| entry['owner'] == owner }.map { |entry| table_item(entry) }
        Group.new(label: "methods, #{owner}", count: items.size, items: items)
      end
    end

    def table_item(entry)
      name = entry['kind'] == 'singleton' ? "self.#{entry['name']}" : entry['name']
      calls = Array(@callers[entry['name']]).size if entry['owner'] == @unit['identifier']
      own = [(entry['visibility'] if entry['visibility'] && entry['visibility'] != 'public'),
             (entry['kind'] if entry['kind'] == 'module_function'),
             ("#{calls} #{calls == 1 ? 'caller' : 'callers'}" if calls&.positive?)].compact.join(', ').presence
      Item.new(key: '·', text: name, own: own, href: link(:method, entry))
    end

    def scopes_group
      scopes = Array(@metadata['scopes'])
      return nil if scopes.empty?

      Group.new(label: 'scopes', count: scopes.size, items: scopes.map do |s|
        Item.new(key: '·', text: (s.is_a?(Hash) ? s['name'] : s).to_s)
      end)
    end

    def link(kind, *arguments)
      @links[kind]&.call(*arguments)
    end

    def controller_groups
      ControllerOutline.new(@metadata, definition_href: @links[:definition]).groups
    end

    def job_groups
      params = Array(@metadata['perform_params']).filter_map { |param| parameter_label(param) }.join(', ')
      queue = @metadata['queue'] && "queue #{@metadata['queue']}"
      [Group.new(label: 'perform', count: 1, items: [Item.new(key: '·', text: "perform(#{params})", own: queue)])]
    end

    def parameter_label(param)
      return param if param.is_a?(String)

      UnitFacts.parameter_label(param) if param.is_a?(Hash) && param['name'].is_a?(String)
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
