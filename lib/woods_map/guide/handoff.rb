# frozen_string_literal: true

module WoodsMap
  module Guide
    # What a finished answer hands to the Trail (M6, design study section 11:
    # "every answer offers pin and open as investigation"). Both are Trail
    # board queries, so the hand-off is a link and the board stays its URL
    # (C-3): identifiers, types and numbers only.
    #
    # - *open as investigation* starts a board from the answer: the units it
    #   cites as pins (the page's unit when it cites none), an entry when the
    #   question's context names one, and the generation the answer was
    #   linked against.
    # - *pin* is offered on answers asked on a Trail board: the board shown
    #   now (or, off a board, the one asked on) with the cited units added.
    class Handoff
      # The links an answer offers, as paths.
      #
      # @param turn [Hash] the finished turn
      # @param answer [Answer] its rendering, which knows the units it cites
      # @param generation [Integer, nil]
      # @param board [Hash, nil] the Trail board the page shows now, as page values
      # @yieldparam query [Hash] a Trail board query
      # @yieldreturn [String] its path
      # @return [Hash{String => String}] 'pin' and 'investigation', each when it applies
      def self.links(turn, answer:, generation:, board: nil, &path)
        handoff = new(turn, cited: answer.cited, generation: generation, board: board)
        { 'pin' => handoff.pin, 'investigation' => handoff.investigation }.compact.transform_values(&path)
      end

      # @param turn [Hash] the finished turn
      # @param cited [Array<Array(String, String)>] identifier and type, from {Answer#cited}
      # @param generation [Integer, nil] the generation the answer's links point into
      # @param board [Hash, nil] the Trail board the page shows now ('page' => 'trail', entry, pins, gen, hops)
      def initialize(turn, cited:, generation:, board: nil)
        @turn = turn
        @context = turn['context'].is_a?(Hash) ? turn['context'] : {}
        @board = board&.dig('page') == 'trail' ? board : @context
        @cited = cited.map { |identifier, type| TrailBoard::Pin.new(type: type.to_s, identifier: identifier.to_s) }
        @generation = generation
      end

      # @return [Hash, nil] the Trail query of a new board, nil when the answer names no unit
      def investigation
        pins = (@cited.presence || context_unit).first(TrailBoard::MAX_PINS)
        return if pins.empty? && entry.nil?

        TrailBoard.new(entry: entry, pins: pins.map(&:to_param), gen: @generation).to_query
      end

      # @return [Hash, nil] the board the question was asked on with the cited
      #   units added, nil off a Trail board or when the answer adds nothing
      def pin
        return unless @board['page'] == 'trail'

        board = TrailBoard.new(entry: @board['entry'], pins: Array(@board['pins']), gen: @board['gen'],
                               hops: @board['hops'])
        added = @cited.reject { |candidate| board.pinned?(candidate) }
        return if added.empty? || board.pins.size >= TrailBoard::MAX_PINS

        board.to_query(pins: (board.pins + added).first(TrailBoard::MAX_PINS))
      end

      private

      # The flow entry the question's context names: the board's own on a
      # Trail page, a job's `#perform`, or the controller action asked about.
      def entry
        candidate = case @context['type']
                    when 'job' then "#{@context['identifier']}#perform"
                    when 'controller', 'mailer'
                      "#{@context['identifier']}##{@context['action_name']}" if @context['action_name']
                    end
        candidate = @context['entry'] if @context['page'] == 'trail'
        candidate if candidate.to_s.match?(TrailBoard::ENTRY)
      end

      def context_unit
        return [] if @context['identifier'].to_s.empty? || @context['type'].to_s.empty?

        [TrailBoard::Pin.new(type: @context['type'].to_s, identifier: @context['identifier'].to_s)]
      end
    end
  end
end
