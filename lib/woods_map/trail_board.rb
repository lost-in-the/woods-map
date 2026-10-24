# frozen_string_literal: true

require 'digest'

module WoodsMap
  # The Trail's board state (C-3, notes/trail.md): an entry, typed pins, the
  # generation the board was made against and the async hop budget. Every
  # value is an identifier or a number, so the board's URL can be pasted into
  # an issue without carrying a token, a path or free text.
  class TrailBoard
    # One pinned typed unit.
    Pin = Struct.new(:type, :identifier, keyword_init: true) do
      # @return [String] `type:identifier`, the URL form
      def to_param
        "#{type}:#{identifier}"
      end

      # @return [Array(String, String)] identifier and type, the graph's identity order
      def identity
        [identifier, type]
      end
    end

    MAX_PINS = 24
    HOPS = (1..3)
    DEFAULT_HOPS = 2

    # `type:identifier`: a unit type, then an identifier with no control
    # characters. Identifiers may contain colons (`Admin::User`), so the type
    # is everything up to the first one.
    PIN = /\A(?<type>[a-z][a-z0-9_]*):(?<identifier>[^\p{Cc}]{1,300})\z/

    # A flow entry: a constant path, optionally `#method` or the W-5 event
    # grammar (`@create`, `@after_commit(create)`).
    ENTRY = /\A(?<unit>[A-Z]\w*(?:::[A-Z]\w*)*)(?<rest>#[a-z_]\w*[?!]?|@[a-z_]+(?:\((?:create|update|destroy)\))?)?\z/

    # @param params [ActionController::Parameters, Hash]
    # @return [TrailBoard]
    def self.from_params(params)
      new(entry: params[:entry], pins: params[:pin], gen: params[:gen], hops: params[:hops])
    end

    # @param entry [String, nil]
    # @param pins [Array<String>, String, nil] `type:identifier` values
    # @param gen [String, Integer, nil]
    # @param hops [String, Integer, nil]
    def initialize(entry: nil, pins: nil, gen: nil, hops: nil)
      @entry = entry.to_s.strip.presence
      @entry = nil unless @entry&.match?(ENTRY)
      @rejected_entry = entry.to_s.strip.presence if entry.to_s.strip.present? && @entry.nil?
      parse_pins(pins)
      @gen = gen.to_s.match?(/\A[1-9][0-9]{0,8}\z/) ? gen.to_i : nil
      @hops = hops.to_s.match?(/\A[0-9]\z/) && HOPS.cover?(hops.to_i) ? hops.to_i : DEFAULT_HOPS
    end

    # @return [String, nil] the entry as given, nil when absent or malformed
    attr_reader :entry
    # @return [String, nil] a malformed entry, named on the chooser
    attr_reader :rejected_entry
    # @return [Array<Pin>] at most {MAX_PINS}, in URL order, without repeats
    attr_reader :pins
    # @return [Array<String>] pin values that are not `type:identifier`, or past the limit
    attr_reader :rejected_pins
    # @return [Integer, nil] the generation the board names
    attr_reader :gen
    # @return [Integer] the async hop budget
    attr_reader :hops

    # @return [String, nil] the unit part of the entry (`Post` of `Post@create`)
    def entry_unit
      @entry && ENTRY.match(@entry)[:unit]
    end

    # @param pin [Pin]
    # @return [Boolean]
    def pinned?(pin)
      @pins.any? { |p| p.type == pin.type && p.identifier == pin.identifier }
    end

    # The query of this board with other values: `pins:` replaces the pins.
    #
    # @return [Hash] string keys, nil values left out
    def to_query(entry: @entry, pins: @pins, gen: @gen, hops: @hops)
      { 'entry' => entry, 'pin' => pins.map(&:to_param).presence, 'gen' => gen,
        'hops' => (hops == DEFAULT_HOPS ? nil : hops) }.compact
    end

    # @param pin [Pin]
    # @return [Hash] the query with +pin+ added (no change past the limit)
    def with_pin(pin)
      return to_query if pinned?(pin) || @pins.size >= MAX_PINS

      to_query(pins: @pins + [pin])
    end

    # @param pin [Pin]
    # @return [Hash] the query without +pin+
    def without_pin(pin)
      to_query(pins: @pins.reject { |p| p.type == pin.type && p.identifier == pin.identifier })
    end

    # @return [String] what the notes of this board are stored under in the browser
    def key
      Digest::SHA256.hexdigest([@entry, @pins.map(&:to_param).sort, @gen].to_json)[0, 16]
    end

    private

    def parse_pins(pins)
      @pins = []
      @rejected_pins = []
      Array(pins).map(&:to_s).each do |value|
        match = PIN.match(value)
        next @rejected_pins << value unless match

        pin = Pin.new(type: match[:type], identifier: match[:identifier])
        next if pinned?(pin)

        @pins.size < MAX_PINS ? @pins << pin : @rejected_pins << value
      end
    end
  end
end
