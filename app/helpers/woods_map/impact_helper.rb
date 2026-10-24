# frozen_string_literal: true

module WoodsMap
  # Escaped, structured evidence from the range report, retaining nested context.
  module ImpactHelper
    # What the impact Share menu cannot offer yet (E-7): the report formats are
    # Woods' (D-1), and handing them through is an open decision.
    #
    # @return [String]
    def impact_share_note
      'Markdown and JSON reports come from Woods\' renderers (D-1); whether this menu may hand them through ' \
        'unchanged is open in woods-map#57.'
    end

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

    private

    def impact_facts(value)
      facts = value.map do |key, item|
        safe_join([tag.dt(key.tr('_', ' ')), tag.dd(impact_evidence(item))])
      end
      tag.dl(safe_join(facts), class: 'det impact-evidence')
    end
  end
end
