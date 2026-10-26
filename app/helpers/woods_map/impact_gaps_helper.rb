# frozen_string_literal: true

module WoodsMap
  # The Tests tab's gap sentences.
  module ImpactGapsHelper
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
