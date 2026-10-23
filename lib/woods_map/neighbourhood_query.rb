# frozen_string_literal: true

module WoodsMap
  # Validated public query for the JSON graph projection. Limits bound the
  # response, not the existing traversal's work; depth remains one or two hops.
  class NeighbourhoodQuery
    # A malformed query, rejected before the index opens.
    class Invalid < StandardError; end

    MAX_NODES = 300
    MAX_EDGES = 1000
    DIRECTIONS = %w[both dependencies dependents].freeze

    # @param params [Hash, ActionController::Parameters]
    # @raise [Invalid] for malformed, unsupported or oversized query values
    def initialize(params)
      @params = params
      @values = {
        'centre' => text('centre', required: true), 'type' => text('type', required: true),
        'depth' => number('depth', 1, 2), 'direction' => text('direction') || 'both',
        'types' => list('types'), 'via' => list('via'), 'package' => text('package'),
        'node_limit' => number('node_limit', MAX_NODES, MAX_NODES),
        'edge_limit' => number('edge_limit', MAX_EDGES, MAX_EDGES)
      }
      return if DIRECTIONS.include?(@values['direction'])

      raise Invalid, 'direction must be both, dependencies or dependents'
    end

    # @return [Hash] normalized, string-keyed public query
    def to_h
      @values.dup
    end

    private

    def text(key, required: false)
      value = @params[key]
      return nil if value.nil? && !required
      return value if value.is_a?(String) && value.present? && value.bytesize <= 2048 && value.valid_encoding?

      raise Invalid, "#{key} must be a nonempty string of at most 2048 bytes"
    end

    def number(key, default, maximum)
      value = @params.fetch(key, default).to_s
      return value.to_i if value.match?(/\A[0-9]{1,4}\z/) && value.to_i.between?(1, maximum)

      raise Invalid, "#{key} must be an integer between 1 and #{maximum}"
    end

    def list(key)
      value = @params[key]
      return nil if value.nil?
      if value.is_a?(Array) && value.size <= 64 && value.all? { |v| v.is_a?(String) && v.present? && v.bytesize <= 200 }
        return value.uniq
      end

      raise Invalid, "#{key} must be an array of at most 64 nonempty strings, each at most 200 bytes"
    end
  end
end
