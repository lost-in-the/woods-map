# frozen_string_literal: true

module WoodsMap
  # Helpers for the unit pages: links to units, the facts tile values, the
  # freshness words, the tab table.
  module UnitsHelper
    TAB_LABELS = { 'code' => 'Code', 'routes' => 'Routes', 'schema' => 'Schema', 'passage' => 'Passage',
                   'lifecycle' => 'Lifecycle', 'graph' => 'Graph', 'history' => 'History' }.freeze

    # @param identifier [String]
    # @param type [String, nil]
    # @param label [String, nil]
    # @return [ActiveSupport::SafeBuffer] a link to the unit, or its name when the type is unknown
    def unit_link(identifier, type = nil, label: nil)
      type ||= Array(current_repository&.identifier_types(identifier)).first
      return ERB::Util.html_escape(label || identifier) unless type

      link_to(label || identifier, woods_map.unit_path(type: type, identifier: identifier))
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
      return woods_map.unit_path(type: page.type, identifier: page.identifier) if tab == 'code'

      woods_map.public_send("unit_#{tab}_path", type: page.type, identifier: page.identifier)
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
      return value.to_s unless value.is_a?(Hash)
      return unit_link(value[:link][0], value[:link][1], label: value[:link][2]) if value[:link]
      return tile_links(value[:links]) if value[:links]
      return layer_chip(value[:layer]) if value[:layer]

      tile_text(value)
    end

    # @param value [Hash] a tile value with :who and :date, or :text and :hot
    # @return [ActiveSupport::SafeBuffer]
    def tile_text(value)
      return safe_join([who(value[:who]), ', ', date_abbr(value[:date])]) if value.key?(:who)

      safe_join([value[:text], (value[:hot] ? chip(:hot) : nil)].compact, ' ')
    end

    # @param links [Array<Array(String, String)>] identifier, type pairs
    # @return [ActiveSupport::SafeBuffer] the first three as links, the rest as a count
    def tile_links(links)
      shown = links.first(3).map { |identifier, type| unit_link(identifier, type) }
      rest = links.size - shown.size
      shown << tag.span("+#{rest} more", class: 'dim') if rest.positive?
      safe_join(shown, ', ')
    end

    # The reasons behind the freshness words, for the bar's tooltip: what the
    # quick check saw, and which of Woods' verifications it could not make.
    #
    # @param freshness [Hash, nil] the repository's freshness report
    # @return [String, nil]
    def freshness_detail(freshness)
      return nil unless freshness.is_a?(Hash)

      counts = freshness['counts'].to_h
      seen = %w[added changed removed].filter_map { |k| "#{counts[k]} #{k}" if counts[k].to_i.positive? }
      files = freshness.dig('metrics', 'visited_files')
      seen << "#{files} files checked, no drift seen" if seen.empty? && files
      reasons = Array(freshness['reasons']).map { |r| r.to_s.tr('_', ' ') }
      [seen.join(', ').presence, reasons.join(', ').presence].compact.join('; ').presence
    end

    # @param state [String] a freshness state
    # @return [Array(String, String)] the glyph class and the words for the bar
    def freshness_words(state)
      case state
      when 'current' then ['fresh', 'index current']
      when 'drifted' then ['hot', 'index drifted']
      when 'stale' then ['mod', 'index stale']
      else ['dim', 'freshness unknown']
      end
    end
  end
end
