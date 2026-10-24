# frozen_string_literal: true

module WoodsMap
  # Helpers for the component partials: glyphs, chips, counts, people and the
  # ⓘ explanation.
  module ComponentsHelper
    # Table minimum widths, in px, that map.css has a class for. The policy
    # (M8) refuses style attributes, so a table's minimum is a class, not a
    # custom property set inline.
    TABLE_MIN_WIDTHS = [480, 560, 640, 720, 760, 820, 860, 900, 980].freeze

    # @param value [String, nil] a minimum width such as `"900px"`
    # @return [String, nil] the class that sets it
    # @raise [ArgumentError] for a width map.css has no class for
    def table_min_width_class(value)
      return nil if value.nil?

      px = value.to_s[/\A(\d+)px\z/, 1].to_i
      raise ArgumentError, "no table minimum class for #{value.inspect}" unless TABLE_MIN_WIDTHS.include?(px)

      "min-#{px}"
    end

    # A column width as the `width` attribute's presentational hint, which the
    # policy does not govern: `"150px"` becomes `150`, a percentage stays.
    #
    # @param value [String] `"<n>px"` or `"<n>%"`
    # @return [String]
    # @raise [ArgumentError] for any other unit
    def table_column_width(value)
      case value.to_s
      when /\A(\d+)px\z/ then Regexp.last_match(1)
      when /\A\d+%\z/ then value.to_s
      else raise ArgumentError, "column widths are px or %, not #{value.inspect}"
      end
    end

    # A glyph from the vocabulary (D-20), hidden from screen readers unless it
    # is the whole label.
    #
    # @param name [Symbol] a key of {WoodsMap::Glyphs::VOCABULARY}
    # @param label [String, nil] accessible name when the glyph stands alone
    # @return [ActiveSupport::SafeBuffer]
    def glyph(name, label: nil)
      mark = WoodsMap::Glyphs[name]
      label ? tag.span(mark, role: 'img', 'aria-label': label) : tag.span(mark, 'aria-hidden': 'true')
    end

    # The ⓘ control on a heading (D-14): the explanation opens in the tooltip.
    #
    # @param text [String] the explanation
    # @param html [String, nil] server-rendered markup with links instead
    # @return [ActiveSupport::SafeBuffer]
    def info_tip(text, html: nil)
      attributes = { class: 'info', type: 'button', 'aria-label': 'Explain' }
      html ? attributes['data-tip-html'] = html : attributes[:title] = text
      tag.button(WoodsMap::Glyphs[:info], **attributes)
    end

    # A count on a heading, tab or rail group.
    #
    # @param value [Integer, String]
    # @return [ActiveSupport::SafeBuffer]
    def count_tag(value)
      tag.span(value, class: 'n')
    end

    # A layer chip: provenance, never meaning.
    #
    # @param text [String]
    # @return [ActiveSupport::SafeBuffer]
    def layer_chip(text)
      tag.span(text, class: 'lyr')
    end

    # The git author as recorded, truncated with the full value in the tooltip.
    #
    # @param name [String, nil]
    # @param email [String, nil]
    # @return [ActiveSupport::SafeBuffer]
    def who(name, email: nil)
      return tag.span('—', class: 'dim') if name.to_s.empty?

      tag.span(name, class: 'who', title: [name, email].compact.join(', '))
    end

    # Chip kind => CSS class (D-11).
    CHIP_CLASSES = { modified: 'M', hot: 'hot', risk: 'flag', blocking: 'fl', note: 'fl note', fresh: 'fresh' }.freeze

    # The chips of D-11: modified, hot, risk, blocking, note, fresh.
    #
    # @param kind [Symbol] a key of {CHIP_CLASSES}
    # @param text [String, nil] the word, or the tooltip for the glyph chips
    # @return [ActiveSupport::SafeBuffer]
    def chip(kind, text = nil)
      css = CHIP_CLASSES.fetch(kind) { raise ArgumentError, "unknown chip #{kind}" }
      label = chip_label(kind, text)
      title = text if %i[modified risk].include?(kind)
      tag.span(label, class: css, title: title)
    end

    # @return [String] what the chip reads
    def chip_label(kind, text)
      case kind
      when :modified then 'M'
      when :risk then WoodsMap::Glyphs[:flag]
      when :fresh then "#{WoodsMap::Glyphs[:current]} #{text || 'current'}"
      else text || kind.to_s
      end
    end

    # An empty value (C2 rule 8): `—` for not applicable, `none` for known-empty.
    #
    # @param applicable [Boolean]
    # @return [ActiveSupport::SafeBuffer]
    def empty_value(applicable: true)
      tag.span(applicable ? 'none' : WoodsMap::Glyphs[:none], class: 'dim')
    end
  end
end
