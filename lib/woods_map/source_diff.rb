# frozen_string_literal: true

module WoodsMap
  # One unit's unified source diff between two retained generations, as
  # Woods computes it (`Woods::Impact::UnitDiff`, woods#802). The map renders
  # Woods' hunks and lines; it never compares two payloads itself. An older
  # Woods without the API, a generation no longer retained, and an
  # unreadable payload are explicit states, never an empty diff.
  class SourceDiff
    MESSAGES = {
      unavailable: 'Line diffs need a Woods with Woods::Impact::UnitDiff (woods#802).',
      invalid: 'A generation of this range is no longer retained, so its source cannot be compared.',
      error: 'The retained payloads could not be read; the diff is unavailable, not empty.'
    }.freeze

    # @return [Class, nil] Woods' unit diff, when this Woods has one
    def self.backend
      require 'woods/impact/unit_diff' unless defined?(Woods::Impact::UnitDiff)
      Woods::Impact::UnitDiff if Woods::Impact::UnitDiff.respond_to?(:compare)
    rescue LoadError => e
      raise unless e.path == 'woods/impact/unit_diff'

      nil
    end

    # @return [Symbol] :available, :unavailable, :invalid or :error
    attr_reader :state
    # @return [Hash, nil] Woods' unchanged, string-keyed diff
    attr_reader :data

    # @param index_dir [Pathname, String] the configured published-index root
    # @param identifier [String]
    # @param type [String]
    # @param from [Integer] a retained generation
    # @param to [Integer] a retained generation
    def initialize(index_dir, identifier:, type:, from:, to:)
      backend = self.class.backend
      @state = :unavailable
      return unless backend

      @data = backend.compare(index_dir, unit: { 'identifier' => identifier, 'type' => type },
                                         from: "gen:#{from}", to: "gen:#{to}").to_h
      @state = @data.is_a?(Hash) && @data['schema_version'] == 1 ? :available : :error
    rescue ArgumentError
      @state = :invalid
    rescue LoadError, StandardError
      @state = :error
    end

    # @return [String, nil] why there is no diff
    def message
      MESSAGES[state]
    end

    # @return [Hash] Woods' `source_changes` (`hunks` with `lines`, counts, `coverage`), empty when none
    def changes
      (@data && @data['source_changes']) || {}
    end

    # @return [String, nil] added, removed, modified, unchanged or absent
    def status
      @data && @data['status']
    end

    # @return [Array<String>, nil] the report categories that moved
    #   (behaviour, schema, edges...); nil when this Woods does not name them
    def categories
      @data && @data['categories']
    end

    # @return [Array<String>, nil] the facets that moved (source, metadata, dependencies)
    def facets
      @data && @data['facets']
    end

    # @return [Array<Hash>] unified hunks
    def hunks
      Array(changes['hunks'])
    end
  end
end
