# frozen_string_literal: true

module WoodsMap
  # What a page names for the guide (M7): its kind and the unit (the
  # full-screen graph's centre included), the action, the impact focus or
  # range, or a Trail board's entry, pins, generation and hop budget. Units
  # selected on a graph are added by the browser. The guide rebuilds the
  # context from these against the pinned generation.
  module GuidePage
    extend ActiveSupport::Concern

    # Page kinds the guide offers actions for, by unit tab.
    GUIDE_TABS = { 'show' => 'code', 'lifecycle' => 'lifecycle', 'passage' => 'passage', 'graph' => 'graph' }.freeze

    included do
      helper_method :guide_page_values
    end

    private

    # @return [Hash{String => String, Array<String>, Integer}]
    def guide_page_values
      if @page then guide_unit_values
      elsif @centre then { 'page' => 'graph', 'type' => @centre['type'], 'identifier' => @centre['identifier'] }
      elsif @board then guide_board_values
      elsif @range then { 'page' => 'range', 'from' => @range.first, 'to' => @range.last }
      elsif @radius.present? then { 'page' => 'impact', 'focus' => @radius.focus.join(',') }
      else {}
      end
    end

    def guide_unit_values
      { 'page' => GUIDE_TABS.fetch(@tab.to_s, 'unit'), 'type' => @page.type, 'identifier' => @page.identifier,
        'action_name' => @passage&.action }.compact
    end

    def guide_board_values
      { 'page' => 'trail', 'entry' => @board.entry, 'pins' => @board.pins.map(&:to_param).presence,
        'gen' => @board.gen || @repository&.generation_number, 'hops' => @board.hops }.compact
    end
  end
end
