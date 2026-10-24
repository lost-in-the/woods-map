# frozen_string_literal: true

module WoodsMap
  # Words for `?since=` (E-8) from Woods' range report.
  module SinceHelper
    MARGIN = 'Notes on a changed line, or reading a metadata key that moved, are marked M.'

    # What the banner says about the unit's changed lines.
    #
    # @param since [WoodsMap::Since]
    # @param page [WoodsMap::UnitPage]
    # @return [String]
    def since_lines_sentence(since, page)
      changes = since.source_changes(page.identifier, page.type)
      marks = since.line_marks(page.identifier, page.type)
      lines = if marks then marked_lines(marks)
              elsif !changes.is_a?(Hash) then 'Its source lines did not move.'
              elsif changes['coverage'] == 'too_large' then 'Its source moved too much for Woods to diff line by line.'
              else other_generation(since)
              end
      "#{lines} #{MARGIN} "
    end

    private

    def marked_lines(marks)
      counts = "#{marks.added.to_i} #{'line'.pluralize(marks.added.to_i)} added, #{marks.removed.to_i} removed"
      cut = marks.coverage == 'truncated' ? '; Woods kept only the first ranges' : ''
      "Lines: #{counts}#{cut}; the gutter rule marks changed lines and an underline where lines were removed."
    end

    def other_generation(since)
      "Its line ranges address gen #{since.to_generation}, not gen #{current_repository&.generation_number}, " \
        'so lines are not marked.'
    end
  end
end
