# frozen_string_literal: true

module WoodsMap
  # Helpers for the unit pages: links to units, the facts tile values, the
  # tab table. Freshness words are in {FreshnessHelper}.
  module UnitsHelper
    TAB_LABELS = { 'code' => 'Code', 'routes' => 'Routes', 'schema' => 'Schema', 'passage' => 'Passage',
                   'lifecycle' => 'Lifecycle', 'graph' => 'Graph', 'history' => 'History' }.freeze

    # @param identifier [String]
    # @param type [String, nil]
    # @param label [String, nil]
    # @param since [String, nil] a ?since= selector the link keeps (E-8)
    # @param listed [Boolean] the caller took the unit from the generation's own listing
    # @return [ActiveSupport::SafeBuffer] a link to the unit, or its name when the type is unknown or the
    #   pinned generation holds no such typed unit
    def unit_link(identifier, type = nil, label: nil, since: nil, listed: false)
      type ||= Array(current_repository&.identifier_types(identifier)).first
      return ERB::Util.html_escape(label || identifier) unless type && (listed || unit_indexed?(identifier, type))

      link_to(label || identifier, woods_map.unit_path(type: type, identifier: identifier, **{ since: since }.compact))
    end

    # Whether the request's generation holds the typed unit a link would open.
    # A dependency can name what the index never extracted (a framework
    # class, an engine's controller, a table no migration created) or a type
    # it does not publish as units (`framework`, `view`); those stay text.
    #
    # @param identifier [String]
    # @param type [String]
    # @return [Boolean] true when no generation is in hand to ask
    def unit_indexed?(identifier, type)
      repository = current_repository
      return true unless repository

      !repository.graph_node(identifier, type: type).nil? || !repository.unit(identifier, type: type).nil?
    end

    # The class or concern that declared a filter (W-8), linked when the index
    # holds it; a concern is marked "← " as on B8-Passage.
    #
    # @param owner [String, nil]
    # @return [ActiveSupport::SafeBuffer]
    def filter_owner(owner)
      return ERB::Util.html_escape('') if owner.blank?

      types = Array(current_repository&.identifier_types(owner))
      link = unit_link(owner, (%w[controller mailer concern] & types).first || types.first)
      types.include?('concern') ? safe_join(['← ', link]) : link
    end

    # A link to a line of the unit that owns a file, through the graph's file map.
    #
    # @param file [String] a path relative to the application root
    # @param line [Integer, nil]
    # @param text [String, nil] the link text; "path:line" by default
    # @return [ActiveSupport::SafeBuffer, String]
    def code_line_link(file, line, text: nil)
      text ||= [file, line].compact.join(':')
      owner = current_repository&.file_owner(file)
      return ERB::Util.html_escape(text) unless owner && owner['type']

      url = woods_map.unit_path(type: owner['type'], identifier: owner['identifier'])
      link_to(text, "#{url}#{"#L#{line}" if line}")
    end

    # Highlight query text while preserving indexed names and paths as text.
    #
    # @param text [String]
    # @param query [String]
    # @return [ActiveSupport::SafeBuffer]
    def search_match(text, query)
      return ERB::Util.html_escape(text) if query.to_s.empty?

      parts = text.to_s.split(/(#{Regexp.escape(query)})/i)
      safe_join(parts.map { |part| part.casecmp?(query) ? tag.mark(part) : part })
    end

    # @param page [WoodsMap::UnitPage]
    # @param tab [String] the tab key
    # @return [String] the URL of a tab
    def tab_path(page, tab)
      since = current_since ? { since: current_since.selector } : {}
      return woods_map.unit_path(type: page.type, identifier: page.identifier, **since) if tab == 'code'

      woods_map.public_send("unit_#{tab}_path", type: page.type, identifier: page.identifier, **since)
    end

    # @param page [WoodsMap::UnitPage]
    # @param current [String]
    # @return [Array<Hash>] the tabs partial's locals
    def unit_tabs(page, current)
      page.tabs.map do |tab|
        { label: TAB_LABELS.fetch(tab), count: page.tab_count(tab), href: tab_path(page, tab), current: tab == current }
      end
    end

    # Render one value of a facts tile: a string, a link, links, a layer chip,
    # a person with a date, or a count with a hot chip.
    #
    # @param value [String, Hash]
    # @return [ActiveSupport::SafeBuffer, String]
    def tile_value(value)
      return value.html_safe? ? value : breakable(value) unless value.is_a?(Hash)
      return linked_tile_value(*value[:link]) if value[:link]
      return tile_links(value[:links]) if value[:links]
      return layer_chip(value[:layer]) if value[:layer]

      tile_text(value)
    end

    # @param identifier [String]
    # @param type [String]
    # @param label [String, nil]
    # @return [ActiveSupport::SafeBuffer, String]
    def linked_tile_value(identifier, type, label = nil)
      unit_link(identifier, type, label: breakable(label || identifier))
    end

    # A name with a line-break opportunity after each namespace or path separator, so a tile
    # wraps it there before it wraps inside a word.
    #
    # @param text [#to_s]
    # @return [ActiveSupport::SafeBuffer]
    def breakable(text)
      safe_join(text.to_s.split(%r{(?<=::|/)}), tag.wbr)
    end

    # @param value [Hash] a tile value with :who and :date, or :text and :hot
    # @return [ActiveSupport::SafeBuffer]
    def tile_text(value)
      return safe_join([who(value[:who]), ', ', date_abbr(value[:date])]) if value.key?(:who)

      safe_join([breakable(value[:text]), (value[:hot] ? chip(:hot) : nil)].compact, ' ')
    end

    # @param links [Array<Array(String, String)>] identifier, type pairs
    # @return [ActiveSupport::SafeBuffer] the first three as links, the rest as a count
    def tile_links(links)
      shown = links.first(3).map { |identifier, type| unit_link(identifier, type, label: breakable(identifier)) }
      rest = links.size - shown.size
      shown << tag.span("+#{rest} more", class: 'dim') if rest.positive?
      safe_join(shown, ', ')
    end
  end
end
