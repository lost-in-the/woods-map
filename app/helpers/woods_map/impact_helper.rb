# frozen_string_literal: true

module WoodsMap
  # Escaped, structured evidence from the range report, retaining nested context.
  module ImpactHelper
    # @param value [Object] string-keyed JSON value supplied by Woods
    # @return [ActiveSupport::SafeBuffer] nested facts, including explicit nulls
    def impact_evidence(value)
      case value
      when Hash
        impact_facts(value)
      when Array
        return tag.span('No records returned', class: 'mut') if value.empty?

        tag.ul(safe_join(value.map { |item| tag.li(impact_evidence(item)) }))
      when NilClass
        tag.span('Unavailable', class: 'mut')
      else
        ERB::Util.html_escape(value.to_s)
      end
    end

    # @param parameters [Hash] authoritative normalized query options
    # @return [ActiveSupport::SafeBuffer] nil filters mean unrestricted, not unknown
    def impact_parameters(parameters)
      filters = parameters.dup
      %w[types via].each { |key| filters[key] = 'Unrestricted' if filters.key?(key) && filters[key].nil? }
      impact_evidence(filters)
    end

    # A report record's typed identity: a link when it names a unit of the
    # pinned generation, otherwise escaped text with its endpoint generation
    # (historical identities have no current-source links).
    #
    # @param record [Hash] identifier, type and optionally generation
    # @param report [WoodsMap::RangeReport]
    # @param generation [Integer, nil] the record's generation, when it carries none
    # @param since [Integer, nil] link with ?since=gen:N to light the unit's changes
    # @return [ActiveSupport::SafeBuffer]
    def impact_identity(record, report, generation: record['generation'], since: nil)
      identifier = record['identifier'].to_s
      type = record['type'].to_s
      if report.current?(record, generation: generation)
        params = since ? { since: "gen:#{since}" } : {}
        return link_to(identifier, woods_map.unit_path(type: type, identifier: identifier, **params))
      end

      safe_join([ERB::Util.html_escape(identifier), (generation ? layer_chip("gen #{generation}") : nil)].compact, ' ')
    end

    # @param record [Hash] a record with endpoint and generation
    # @return [String] where the record comes from: "to, gen 42"
    def impact_context(record)
      [record['endpoint'], record['generation'] && "gen #{record['generation']}"].compact.join(', ').presence ||
        'unavailable'
    end

    # @param value [Object] a weight or nil
    # @return [ActiveSupport::SafeBuffer, String] three places, or "unavailable" (never zero)
    def impact_weight(value)
      value.is_a?(Numeric) ? format('%.3f', value) : tag.span('unavailable', class: 'mut')
    end

    # @param path [Hash] one witness path: root and edges
    # @return [ActiveSupport::SafeBuffer] the edges as "source via ← target", root last
    def impact_path(path)
      edges = Array(path['edges']).map do |edge|
        safe_join([edge.dig('source', 'identifier').to_s, ' ', tag.span(edge['via'].to_s, class: 'mut'), ' ',
                   tag.span('→', class: 'ar'), ' ', edge.dig('target', 'identifier').to_s])
      end
      edges.any? ? safe_join(edges, tag.br) : tag.span('no edges recorded', class: 'mut')
    end

    private

    def impact_facts(value)
      facts = value.map do |key, item|
        safe_join([tag.dt(key.tr('_', ' ')), tag.dd(impact_evidence(item))])
      end
      tag.dl(safe_join(facts), class: 'det impact-evidence')
    end
  end
end
