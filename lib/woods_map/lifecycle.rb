# frozen_string_literal: true

module WoodsMap
  # Model callbacks in the order Rails runs them for one event (create,
  # update, destroy), from the resolved chain the extractor published. Each
  # step keeps its side effects, conditions and the concern it came from.
  class Lifecycle
    EVENTS = %w[create update destroy].freeze

    # Chain order per event: the callback types that fire, in sequence.
    ORDER = {
      'create' => %w[before_validation after_validation before_save before_create after_create after_save
                     after_commit after_create_commit after_save_commit],
      'update' => %w[before_validation after_validation before_save before_update after_update after_save
                     after_commit after_update_commit after_save_commit],
      'destroy' => %w[before_destroy after_destroy after_commit after_destroy_commit]
    }.freeze

    # Framework callbacks the chain carries but a reader never wrote.
    INTERNAL = /\A(_|autosave_associated_records_for_|#<)/

    DEFINITION = /^\s*def\s+(?:self\.)?([a-z_]\w*[?!=]?)/

    # Side-effect key => the verb the step reads with.
    EFFECT_VERBS = { 'columns_written' => 'writes', 'jobs_enqueued' => 'enqueues', 'mailers_triggered' => 'mails',
                     'services_called' => 'calls', 'database_reads' => 'reads' }.freeze

    # One step of a chain.
    Step = Struct.new(:n, :type, :filter, :conditions, :side_effects, :owner, keyword_init: true) do
      # @return [Array<String>] "writes x", "enqueues Y" phrases
      def effects
        EFFECT_VERBS.filter_map do |key, verb|
          values = Array((side_effects || {})[key])
          "#{verb} #{values.join(', ')}" if values.any?
        end
      end

      # @return [Boolean] whether the step leaves the transaction (a commit callback)
      def commit?
        type.to_s.include?('commit')
      end

      # @return [Boolean] whether it enqueues work that runs in another process
      def async?
        (side_effects || {}).fetch('jobs_enqueued', []).any? || (side_effects || {}).fetch('mailers_triggered', []).any?
      end

      # @return [String, nil] where an async step's work runs: the first job, else the first mailer
      def async_target
        return nil unless async?

        Array(side_effects['jobs_enqueued']).first || Array(side_effects['mailers_triggered']).first || 'Mailer'
      end

      # @return [String] the condition column, "—" when unconditional
      def condition
        return '—' if conditions.blank?

        conditions.map { |key, value| "#{key}: #{Array(value).join(', ')}" }.join(', ')
      end
    end

    # @param unit [Hash] a model unit
    # @param concern_methods [Hash{String => Array<String>}] concern name => method names it defines
    def initialize(unit, concern_methods: {})
      defined = unit['source_code'].to_s.scan(DEFINITION).flatten.to_set | concern_methods.values.flatten.to_set
      all = Array(unit.dig('metadata', 'callbacks')).reject { |cb| cb['filter'].to_s.match?(INTERNAL) }
      @callbacks, @framework = all.partition { |cb| defined.include?(cb['filter'].to_s) }
      @concern_methods = concern_methods
      @owner = unit['identifier']
    end

    # @return [Array<Hash>] the application's own callbacks, file order
    attr_reader :callbacks

    # @return [Array<Hash>] callbacks whose method the unit does not define (a
    #   gem's or Rails' own), kept out of the chains and counted in the limits
    attr_reader :framework

    # The chain for one event, numbered from 1.
    #
    # @param event [String] create, update or destroy
    # @return [Array<Step>]
    def steps(event)
      ORDER.fetch(event, []).flat_map { |type| @callbacks.select { |cb| fires?(cb, type, event) } }
           .each_with_index.map { |cb, index| step(cb, index + 1) }
    end

    # @return [Hash{String => Array<Step>}] event => steps, events with none left out
    def chains
      EVENTS.index_with { |event| steps(event) }.reject { |_, steps| steps.empty? }
    end

    # Mermaid sequence text for one event: the app calls each step on the
    # model; an async step hands off to its job or mailer. The numbers match
    # the steps table (`autonumber`). Participants are aliased so namespaced
    # names (`Admin::User`) stay valid Mermaid.
    #
    # @param event [String] create, update or destroy
    # @return [String]
    def mermaid(event)
      list = steps(event)
      targets = list.filter_map(&:async_target).uniq
      lines = ['sequenceDiagram', '  autonumber', '  participant App', "  participant M as #{@owner}"]
      targets.each_with_index { |target, i| lines << "  participant A#{i} as #{target}" }
      list.each do |s|
        lines << (s.async? ? "  M-)A#{targets.index(s.async_target)}: #{s.filter}" : "  App->>M: #{s.type} #{s.filter}")
      end
      lines.join("\n")
    end

    private

    def fires?(callback, type, event)
      return false unless callback['type'].to_s == type

      on = Array(callback.dig('conditions', 'on')).map(&:to_s)
      on.empty? || on.include?(event)
    end

    def step(callback, number)
      Step.new(n: number, type: callback['type'].to_s, filter: callback['filter'].to_s,
               conditions: (callback['conditions'] || {}).except('on'), side_effects: callback['side_effects'],
               owner: owner_of(callback['filter'].to_s))
    end

    def owner_of(method_name)
      @concern_methods.find { |_, methods| methods.include?(method_name) }&.first || @owner
    end
  end
end
