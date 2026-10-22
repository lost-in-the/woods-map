# frozen_string_literal: true

module WoodsMap
  # Reads Woods' authoritative retained-generation report without deriving impact.
  # Historical identities deliberately have no links into the current generation.
  class ImpactRange
    MESSAGES = {
      unavailable: 'Range reports are unavailable in this Woods version. Install a version providing Woods::Impact::Report.',
      invalid: 'The range could not be resolved. Use gen:N, now, or a retained commit SHA (7–40 characters).',
      error: 'The retained range report could not be read. Its evidence is unavailable; this is not an empty result.'
    }.freeze

    # @return [Class, nil] optional backend, loaded only when a range is requested
    def self.backend
      require 'woods/impact/report' unless defined?(Woods::Impact::Report)
      Woods::Impact::Report if Woods::Impact::Report.respond_to?(:compare)
    rescue LoadError => e
      raise unless e.path == 'woods/impact/report'

      nil
    end

    # @return [Symbol] available, unavailable, invalid or error
    attr_reader :state
    # @return [Hash, nil] the backend's unchanged string-keyed report
    attr_reader :data

    # @param index_dir [Pathname, String] configured published-index root
    # @param from [String] retained endpoint selector
    # @param to [String] retained endpoint selector; now resolves once in Woods
    def initialize(index_dir, from:, to: 'now')
      backend = self.class.backend
      @state = :unavailable
      return unless backend

      @data = backend.compare(index_dir, from: from, to: to).to_h
      @state = valid_envelope? ? :available : :error
    rescue ArgumentError
      @state = :invalid
    rescue LoadError, StandardError
      @state = :error
    end

    # @return [String, nil] safe, static explanation; backend paths are not exposed
    def message
      MESSAGES[state]
    end

    private

    def valid_envelope?
      return false unless data.is_a?(Hash) && data['schema_version'] == 1
      return false unless %w[parameters coverage range].all? { |key| data[key].is_a?(Hash) }
      return false unless %w[changed affected flows unknowns].all? { |key| data[key].is_a?(Array) }

      %w[from to].all? do |side|
        endpoint = data['range'][side]
        endpoint.is_a?(Hash) && endpoint['generation'].is_a?(Integer) && endpoint['generation'].positive?
      end
    end
  end
end
