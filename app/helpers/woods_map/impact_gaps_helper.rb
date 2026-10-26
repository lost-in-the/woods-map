# frozen_string_literal: true

module WoodsMap
  # Links into Impact: the Tests tab's gap sentences and the unit page's action.
  module ImpactGapsHelper
    # @param page [WoodsMap::UnitPage]
    # @return [ActiveSupport::SafeBuffer, nil] a link that opens Impact focused on the unit, nil when the
    #   pinned generation's dependency graph has no node for it
    def impact_action(page)
      return unless current_repository&.graph_node(page.identifier, type: page.type)

      link_to('Impact', woods_map.impact_path(focus: page.identifier), class: 'btn')
    end

    # @param gap [WoodsMap::ImpactReview::Gap]
    # @return [ActiveSupport::SafeBuffer] the gap sentence with its unit linked, or the unit named as text with
    #   the reason when this generation holds no such typed unit
    def gap_text(gap)
      if gap.type.present? && unit_indexed?(gap.identifier, gap.type)
        return safe_join([unit_link(gap.identifier, gap.type), gap.text.delete_prefix(gap.identifier.to_s)])
      end

      safe_join([gap.text, " (not a typed unit in gen #{current_repository&.generation_number})"])
    end
  end
end
