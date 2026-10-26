# frozen_string_literal: true

module WoodsMap
  # The actions and filters groups of a controller's or mailer's outline: each
  # action and filter links to the definition line the generation publishes
  # for it (`action_sources`, a filter's `file` and `line`), and stays plain
  # text when it publishes none.
  class ControllerOutline
    # @param metadata [Hash] the unit's metadata
    # @param definition_href [#call, nil] published file and file line => URL of that line, or nil
    def initialize(metadata, definition_href: nil)
      @metadata = metadata
      @definition_href = definition_href
    end

    # @return [Array<Outline::Group>]
    def groups
      [actions_group, filters_group].compact
    end

    private

    def actions_group
      actions = Array(@metadata['actions']).map(&:to_s)
      return nil if actions.empty?

      items = actions.map do |a|
        Outline::Item.new(key: '·', text: a, own: route_label(a), href: action_href(a))
      end
      Outline::Group.new(label: 'actions', count: actions.size, items: items)
    end

    def filters_group
      filters = Array(@metadata['filters']).reject { |f| f['filter'].to_s.match?(Lifecycle::INTERNAL) }
      return nil if filters.empty?

      items = filters.map do |f|
        Outline::Item.new(key: '·', text: "#{f['kind']} #{f['filter']}", own: filter_scope(f), href: definition_href(f))
      end
      Outline::Group.new(label: 'filters', count: filters.size, items: items)
    end

    def action_href(action)
      source = @metadata.dig('action_sources', action)
      definition_href(source) if source.is_a?(Hash)
    end

    def definition_href(record)
      @definition_href&.call(record['file'], record['line'])
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
  end
end
