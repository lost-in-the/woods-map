# frozen_string_literal: true

module WoodsMap
  # One published state machine of a model (B6-Lifecycle, "State machine
  # transitions"): its states, the transitions each event makes and the
  # transition callbacks as Woods recorded them. Everything comes from the
  # `state_machine` unit the StateMachineExtractor published; nothing is
  # read from the model's source here.
  class StateMachineView
    # One transition: the event that makes it (nil when the gem declares
    # transitions without events, as Statesman does), its ends and its guard.
    Transition = Struct.new(:event, :from, :to, :guard, keyword_init: true)

    # One structured transition callback (woods#796): its kind, its literal
    # scope (empty is any; a field named in +unresolved+ was not literal),
    # the method or a block, and the side effects Woods analysed.
    Callback = Struct.new(:kind, :on, :from, :to, :method_name, :block, :side_effects, :unanalysed, :unresolved,
                          keyword_init: true) do
      # @return [String] before, around, after or after_failure
      def phase
        kind.to_s.delete_suffix('_transition')
      end

      # @param transition [Transition]
      # @return [Boolean] whether its literal scope admits the transition
      def applies_to?(transition)
        unresolved.empty? && admits?(on, transition.event) && admits?(from, transition.from) &&
          admits?(to, transition.to)
      end

      # @return [String] the method, or "block"
      def label
        method_name || 'block'
      end

      # @return [Array<String>] "enqueues X", "writes y" phrases (Lifecycle's verbs)
      def effects
        Lifecycle::EFFECT_VERBS.filter_map do |key, verb|
          values = Array((side_effects || {})[key])
          "#{verb} #{values.join(', ')}" if values.any?
        end
      end

      private

      def admits?(scope, value)
        scope.empty? || (value && scope.include?(value))
      end
    end

    # Callback columns of the transitions table, in the order they run.
    PHASES = %w[before around after after_failure].freeze

    # State budget (R-4), states plus transitions, the same as a flowchart.
    STATE_BUDGET = 150

    # The state machines published for a model, found through the reverse
    # `state_machine` edges of the pinned generation's graph.
    #
    # @param repository [WoodsMap::Repository]
    # @param identifier [String] the model's identifier
    # @return [Array<StateMachineView>]
    def self.for_model(repository, identifier)
      Array(repository.graph.dig('reverse_via', identifier))
        .select { |edge| edge['via'].to_s == 'state_machine' && edge['source_type'].to_s == 'state_machine' }
        .filter_map { |edge| repository.unit(edge['source'].to_s, type: 'state_machine') }
        .uniq { |unit| unit['identifier'] }
        .map { |unit| new(unit) }
    end

    # @param unit [Hash] a state_machine unit
    def initialize(unit)
      @unit = unit
      @metadata = unit['metadata'] || {}
    end

    # @return [String] the unit's identifier, such as `Post::state_machine_state`
    def identifier
      @unit['identifier'].to_s
    end

    # @return [String, nil] aasm, statesman or state_machines
    def gem
      @metadata['gem_detected']
    end

    # @return [String, nil]
    def initial_state
      @metadata['initial_state'].presence
    end

    # Declared states first, then any a transition names that the
    # declarations missed, so no transition points at an undrawn state.
    #
    # @return [Array<String>]
    def states
      (Array(@metadata['states']) + [initial_state] + transitions.flat_map { |t| [t.from, t.to] })
        .compact.map(&:to_s).reject(&:empty?).uniq
    end

    # @return [Array<String>] events in declaration order
    def events
      Array(@metadata['events']).filter_map { |event| event['name'].presence&.to_s }
    end

    # Per-event transitions when the gem has events; the flat list otherwise.
    #
    # @return [Array<Transition>]
    def transitions
      @transitions ||= begin
        per_event = Array(@metadata['events']).flat_map do |event|
          Array(event['transitions']).map { |t| transition(t, event['name']) }
        end
        per_event.presence || Array(@metadata['transitions']).map { |t| transition(t, nil) }
      end
    end

    # @return [Array<String>] transition callbacks as the extractor recorded
    #   them (a line of the DSL each), the fallback for a generation without
    #   {#transition_callbacks}
    def callbacks
      Array(@metadata['callbacks']).map(&:to_s)
    end

    # @return [Boolean] whether the unit publishes structured transition callbacks (woods#796)
    def structured?
      @metadata['transition_callbacks'].is_a?(Array)
    end

    # @return [Array<Callback>] in declaration order
    def transition_callbacks
      @transition_callbacks ||= Array(@metadata['transition_callbacks']).grep(Hash).map do |record|
        Callback.new(kind: record['kind'].to_s, on: list(record['on']), from: list(record['from']),
                     to: list(record['to']), method_name: record['method'].presence&.to_s,
                     block: record['block'] == true,
                     side_effects: record['side_effects'], unanalysed: record['unanalysed'],
                     unresolved: list(record['unresolved']))
      end
    end

    # @param transition [Transition]
    # @return [Hash{String => Array<Callback>}] phase => the callbacks its literal scope admits
    def callbacks_for(transition)
      transition_callbacks.select { |callback| callback.applies_to?(transition) }.group_by(&:phase)
    end

    # @return [Array<Callback>] callbacks no transition can carry: a scope
    #   that is not literal, or one no published transition matches
    def unplaced_callbacks
      transition_callbacks.reject { |callback| transitions.any? { |t| callback.applies_to?(t) } }
    end

    # Mermaid state diagram text: every state declared under an alias (so a
    # state named like a keyword stays valid), the initial state entered from
    # `[*]`, and one edge per transition labelled with its event and guard.
    #
    # @return [String]
    def mermaid
      ids = states.each_with_index.to_h { |state, i| [state, "s#{i}"] }
      lines = ['stateDiagram-v2']
      ids.each { |state, id| lines << "  state \"#{state.tr('"', "'")}\" as #{id}" }
      lines << "  [*] --> #{ids[initial_state]}" if initial_state
      transitions.each { |t| lines << "  #{ids[t.from]} --> #{ids[t.to]}#{edge_label(t)}" }
      lines.join("\n")
    end

    # @return [Integer] states plus transitions
    def size
      states.size + transitions.size
    end

    # @return [Boolean] whether the diagram would exceed {STATE_BUDGET}
    def over_budget?
      size > STATE_BUDGET
    end

    # @return [String, nil] why the diagram is not drawn, nil within the budget
    def refusal
      "#{size} states and transitions is over the state budget of #{STATE_BUDGET}" if over_budget?
    end

    private

    # The event, then its guard in brackets, then the callbacks it carries
    # by phase; a colon would end the label early.
    def edge_label(transition)
      text = [transition.event, (transition.guard ? "[#{transition.guard}]" : nil)].compact.join(' ')
      carried = callbacks_for(transition).sort_by { |phase, _| PHASES.index(phase) || PHASES.size }
                                         .map { |phase, list| "#{phase.tr('_', ' ')} #{list.map(&:label).join(', ')}" }
      text = [text.presence, carried.join(', ').presence].compact.join(' / ')
      text.empty? ? '' : " : #{text.tr(':;#', '   ')}"
    end

    def list(value)
      Array(value).map(&:to_s).reject(&:empty?)
    end

    def transition(record, event)
      Transition.new(event: event.presence&.to_s, from: record['from'].to_s, to: record['to'].to_s,
                     guard: record['guard'].presence&.to_s)
    end
  end
end
