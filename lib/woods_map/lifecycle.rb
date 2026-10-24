# frozen_string_literal: true

module WoodsMap
  # Model callbacks in the order Rails runs them for one event (create,
  # update, destroy), from the resolved chain the extractor published. Each
  # step keeps its side effects, conditions and the concern it came from.
  class Lifecycle
    EVENTS = %w[create update destroy].freeze

    # Sequence budget (R-4), participants plus messages: above it the panel
    # names the budget and keeps the text.
    SEQUENCE_BUDGET = 150

    # The renderings of one chain, in the order the view control offers them
    # (B6-Lifecycle): the sequence first, then the branching flowchart, the
    # lanes, and the C4 dynamic view (B-23), which needs container
    # attribution (W-9) and is offered only when the generation has it.
    VIEWS = %w[sequence flowchart lanes dynamic].freeze

    # Views drawn as a flowchart, held to {FLOWCHART_BUDGET} in nodes.
    NODE_VIEWS = %w[flowchart lanes dynamic].freeze

    # Flowchart and lanes budget (R-4), nodes: the same as the neighbourhood.
    FLOWCHART_BUDGET = 150

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
    Step = Struct.new(:n, :type, :filter, :conditions, :side_effects, :owner, :changed, keyword_init: true) do
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

      # @return [String] the lane the step runs in: validation, transaction or commit
      def phase
        return 'validation' if type.to_s.include?('validation')

        commit? ? 'commit' : 'transaction'
      end

      # @return [Array<String>] every job and mailer the step hands work to, jobs first
      def async_targets
        Array((side_effects || {})['jobs_enqueued']) + Array((side_effects || {})['mailers_triggered'])
      end

      # @return [String] the condition column, "—" when unconditional
      def condition
        return '—' if conditions.blank?

        conditions.map { |key, value| "#{key}: #{Array(value).join(', ')}" }.join(', ')
      end
    end

    # @param unit [Hash] a model unit
    # @param concern_methods [Hash{String => Array<String>}] concern name => method names it defines
    # @param dynamic [DynamicView, nil] the C4 dynamic renderer; without one, or without
    #   container attribution, the view is not offered
    # @param changed [Since::Changed, nil] with `?since=`, what moved in the
    #   unit's source: a step is marked when its method or declaration did
    def initialize(unit, concern_methods: {}, dynamic: nil, changed: nil)
      @unit = unit
      @changed = changed
      @dynamic = dynamic
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

    # The branching flowchart of one event (see {LifecycleChart#flowchart}).
    #
    # @param event [String] create, update or destroy
    # @return [String]
    def flowchart(event)
      chart(event).flowchart
    end

    # The lanes of one event (see {LifecycleChart#lanes}).
    #
    # @param event [String] create, update or destroy
    # @return [String]
    def lanes(event)
      chart(event).lanes
    end

    # @return [Array<String>] the views this chain offers: {VIEWS}, the dynamic one only with containers
    def views
      @dynamic&.attributed? ? VIEWS : VIEWS - %w[dynamic]
    end

    # The C4 dynamic view of one event (see {DynamicView#lifecycle}).
    #
    # @param event [String] create, update or destroy
    # @return [String]
    def dynamic(event)
      @dynamic.lifecycle(@unit, steps(event), event)
    end

    # The text for one view of one event.
    #
    # @param view [String] one of {VIEWS}
    # @param event [String] create, update or destroy
    # @return [String]
    def diagram(view, event)
      case view
      when 'flowchart' then flowchart(event)
      when 'lanes' then lanes(event)
      when 'dynamic' then dynamic(event)
      else mermaid(event)
      end
    end

    # @param view [String] one of {VIEWS}
    # @param event [String]
    # @return [Integer] what the view's budget counts: participants plus
    #   messages for the sequence, nodes for the flowchart and the lanes
    def size(view, event)
      case view
      when 'flowchart' then chart(event).flowchart_size
      when 'lanes' then chart(event).lanes_size
      when 'dynamic' then DynamicView.size(dynamic(event))
      else sequence_size(event)
      end
    end

    # @param view [String] one of {VIEWS}
    # @return [Integer] the budget (R-4) that view is held to
    def budget(view)
      NODE_VIEWS.include?(view) ? FLOWCHART_BUDGET : SEQUENCE_BUDGET
    end

    # @param event [String] create, update or destroy
    # @return [Integer] participants plus messages in the event's sequence
    def sequence_size(event)
      list = steps(event)
      2 + list.filter_map(&:async_target).uniq.size + list.size
    end

    # @param event [String] create, update or destroy
    # @param view [String] one of {VIEWS}; the sequence by default
    # @return [Boolean] whether the event's view would exceed its budget
    def over_budget?(event, view: 'sequence')
      size(view, event) > budget(view)
    end

    # @param event [String] create, update or destroy
    # @param view [String] one of {VIEWS}; the sequence by default
    # @return [String, nil] why the view is not drawn, nil within its budget
    def refusal(event, view: 'sequence')
      return nil unless over_budget?(event, view: view)

      sequence = NODE_VIEWS.exclude?(view)
      "#{size(view, event)} #{sequence ? 'participants and messages' : 'nodes'} is over the " \
        "#{sequence ? 'sequence' : 'flowchart'} budget of #{budget(view)}"
    end

    private

    def chart(event)
      LifecycleChart.new(steps(event), "#{@owner} #{event}")
    end

    def fires?(callback, type, event)
      return false unless callback['type'].to_s == type

      on = Array(callback.dig('conditions', 'on')).map(&:to_s)
      on.empty? || on.include?(event)
    end

    def step(callback, number)
      owner = owner_of(callback['filter'].to_s)
      Step.new(n: number, type: callback['type'].to_s, filter: callback['filter'].to_s,
               conditions: (callback['conditions'] || {}).except('on'), side_effects: callback['side_effects'],
               owner: owner, changed: @changed&.callback(callback, owner))
    end

    def owner_of(method_name)
      @concern_methods.find { |_, methods| methods.include?(method_name) }&.first || @owner
    end
  end
end
