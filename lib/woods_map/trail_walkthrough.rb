# frozen_string_literal: true

module WoodsMap
  # A bounded reading order over the Trail's existing typed pins. This is
  # published evidence, not a generated explanation or an execution trace.
  class TrailWalkthrough
    MAX_LINES = 20
    MAX_CHARACTERS = 4000

    # @return [Array<Hash>] ordered cards, including pins missing from the generation
    attr_reader :cards

    # @param repository [Repository] already pinned to the board's generation
    # @param pins [Array<TrailBoard::Pin>] the reader's ordered selection
    def initialize(repository, pins)
      @cards = pins.first(TrailBoard::MAX_PINS).map do |pin|
        unit = repository.unit(pin.identifier, type: pin.type)
        source = unit && unit['source_code'].to_s
        excerpt = source && source.each_line.first(MAX_LINES).join[0, MAX_CHARACTERS]
        { pin: pin, present: !unit.nil?, excerpt: excerpt,
          truncated: source && excerpt.length < source.length }
      end
    end
  end
end
