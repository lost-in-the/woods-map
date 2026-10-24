# frozen_string_literal: true

module WoodsMap
  # Woods' persistent retention pins (W-11, `woods:pin[N]`), read through
  # `Woods::PublishedIndex.retention_pins`. Pins are operational state beside
  # the payloads, so they are read from the index root, never from a payload.
  #
  # Woods reports pins as recorded: a pin whose payload was deleted outside
  # retention stays listed until released, which {#missing} names.
  class Retention
    # @param index_dir [Pathname, String] the configured index root
    # @return [Retention]
    def self.read(index_dir)
      return new(:unsupported) unless Woods::PublishedIndex.respond_to?(:retention_pins)

      new(:available, Woods::PublishedIndex.retention_pins(index_dir).map(&:to_i).sort.uniq)
    rescue StandardError
      new(:unreadable)
    end

    # @param state [Symbol] :available, :unsupported (this Woods has no pin
    #   reader) or :unreadable (Woods refused the pin state)
    # @param pins [Array<Integer>]
    def initialize(state, pins = [])
      @state = state
      @pins = pins.freeze
    end

    # @return [Symbol]
    attr_reader :state

    # @return [Array<Integer>] pinned generation numbers, ascending
    attr_reader :pins

    # @return [Boolean] whether Woods answered with its pin set
    def available?
      state == :available
    end

    # @param generation [Integer, nil]
    # @return [Boolean]
    def pinned?(generation)
      pins.include?(generation)
    end

    # @param retained [Array<Integer>] the published generations
    # @return [Array<Integer>] pins whose payload is gone (removed outside retention)
    def missing(retained)
      pins - Array(retained)
    end

    # One sentence for a page that could not compare against a generation
    # the index no longer retains.
    #
    # @return [String]
    def fallback
      case state
      when :available
        return 'No generation is pinned; bin/rails woods:pin[N] keeps a review base past retention.' if pins.empty?

        "Pinned, so kept past retention: #{pins.map { |n| "gen #{n}" }.join(', ')}."
      when :unreadable then 'Woods could not read its retention pins, so which generations are kept is unknown.'
      else 'This Woods version cannot report retention pins.'
      end
    end

    # @param generation [Integer, nil]
    # @return [String] the generation's retention, for a rail or a picker
    def describe(generation)
      return 'pins unknown' unless available?

      pinned?(generation) ? 'pinned' : 'not pinned'
    end
  end
end
