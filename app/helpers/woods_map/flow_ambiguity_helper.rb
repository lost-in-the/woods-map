# frozen_string_literal: true

module WoodsMap
  # Published flow candidates are identifiers, never an inferred target.
  module FlowAmbiguityHelper
    # Link only a single typed identity in the request's pinned generation.
    # @param candidates [Array<String>] published identifiers
    # @return [ActiveSupport::SafeBuffer]
    def flow_candidates(candidates)
      links = Array(candidates).map do |identifier|
        types = current_repository.identifier_types(identifier)
        types.one? ? unit_link(identifier, types.first) : ERB::Util.html_escape(identifier)
      end
      tag.span(safe_join(links, ', '), class: 'flow-candidates')
    end
  end
end
