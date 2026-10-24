# frozen_string_literal: true

module WoodsMap
  # Reads Woods' authoritative retained-generation report without deriving impact.
  # Historical identities deliberately have no links into the current generation.
  class ImpactRange
    MESSAGES = {
      unavailable: 'Range reports are unavailable in this Woods version. Install a version providing Woods::Impact::Report.',
      invalid: 'The range could not be resolved. Use gen:N, now, or a retained commit SHA (7–40 characters).',
      error: 'The retained range report could not be read. Its evidence is unavailable; this is not an empty result.',
      missing: 'No saved impact report has this ID in this index. Saved reports live with the index that computed them.'
    }.freeze

    # Shown after Woods' own resolution message when a selector names no retained payload.
    RETENTION = 'A generation the index no longer retains cannot be compared; pinning a review base ' \
                '(W-11, woods#761) is not available in this Woods.'

    # A saved report (E-6): the exact bytes `woods:impact` stored under the
    # index, read through Woods' store and independent of payload retention.
    #
    # @param index_dir [Pathname, String] configured published-index root
    # @param id [String] the report's SHA-256 ID
    # @return [ImpactRange]
    def self.saved(index_dir, id)
      allocate.tap { |range| range.send(:load_saved, index_dir, id.to_s) }
    end

    # @return [Class, nil] Woods' saved-report store, loaded only when a saved report is requested
    def self.store
      require 'woods/impact/store' unless defined?(Woods::Impact::Store)
      Woods::Impact::Store if Woods::Impact::Store.method_defined?(:read)
    rescue LoadError => e
      raise unless e.path == 'woods/impact/store'

      nil
    end

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
      @state = :invalid
      return unless from.is_a?(String) && to.is_a?(String)

      backend = self.class.backend
      @state = :unavailable
      return unless backend

      @data = backend.compare(index_dir, from: from, to: to).to_h
      @state = valid_envelope? ? :available : :error
    rescue ArgumentError => e
      @state = :invalid
      @detail = e.message if e.class.name.to_s.end_with?('ResolutionError')
    rescue LoadError, StandardError
      @state = :error
    end

    # @return [String, nil] safe explanation: Woods' resolution message names
    #   retained generations only, never a path
    def message
      return "#{@detail.chomp('.')}. #{RETENTION}" if @detail&.include?('retained')

      MESSAGES[state]
    end

    private

    def load_saved(index_dir, id)
      @state = :missing
      return unless id.match?(/\A[0-9a-f]{64}\z/)

      store = self.class.store
      @state = :unavailable
      return unless store

      @data = JSON.parse(store.new(index_dir).read(id))
      @state = valid_envelope? ? :available : :error
    rescue IOError
      @state = :missing
    rescue LoadError, StandardError
      @state = :error
    end

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
