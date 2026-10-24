# frozen_string_literal: true

module WoodsMap
  # The Lifecycle tab of a controller, a job or a mailer (FR-6, woods-map#91,
  # notes/entry-lifecycle.md): the flow of one entry point (an action, or a
  # job's `perform`) drawn as a sequence, a flowchart and lanes, the same
  # views a model's callback chain gets. The steps are {LifecycleBuilder}'s,
  # so they cross async hops as the Trail's do.
  class EntryLifecycle
    TYPES = %w[controller job mailer].freeze
    VIEWS = %w[sequence flowchart lanes].freeze

    # Sequence budget (R-4), participants plus messages, as the model chain's.
    SEQUENCE_BUDGET = Lifecycle::SEQUENCE_BUDGET
    # Flowchart and lanes budget (R-4), nodes.
    NODE_BUDGET = LifecycleBuilder::NODE_BUDGET

    # @param type [String] a unit type
    # @return [Boolean] whether the type's Lifecycle tab is an entry flow
    def self.applies?(type)
      TYPES.include?(type.to_s)
    end

    # @param repository [WoodsMap::Repository]
    # @param unit [Hash] a controller, job or mailer unit
    # @param action [String, nil] the requested action; the first when absent or unknown
    # @param hops [Integer] the async hop budget
    def initialize(repository, unit, action: nil, hops: TrailBoard::DEFAULT_HOPS)
      @repository = repository
      @unit = unit
      @actions = unit['type'] == 'job' ? ['perform'] : Array(unit.dig('metadata', 'actions')).map(&:to_s)
      @action = @actions.include?(action.to_s) ? action.to_s : @actions.first
      @hops = hops
    end

    # @return [Array<String>] the entry points the unit offers: actions, or `perform`
    attr_reader :actions
    # @return [String, nil] the selected one
    attr_reader :action

    # @return [String, nil] `Unit#action`
    def entry
      @action && "#{@unit['identifier']}##{@action}"
    end

    # @return [LifecycleBuilder, nil]
    def builder
      return nil unless entry

      @builder ||= LifecycleBuilder.new(@repository, entry, hops: @hops)
    end

    # @return [Array<LifecycleBuilder::Step>]
    def steps
      builder&.steps || []
    end

    # @return [String] precomputed (W-14) or assembled
    def source
      builder&.sources&.fetch(entry, nil) || 'assembled'
    end

    # @param view [String] one of {VIEWS}
    # @return [String]
    def diagram(view)
      case view
      when 'flowchart' then flowchart
      when 'lanes' then TrailLanes.new(builder.lanes, steps).mermaid
      else sequence
      end
    end

    # @param view [String]
    # @return [Integer] what the view's budget counts
    def size(view)
      view == 'sequence' ? participants.size + steps.size : steps.size
    end

    # @param view [String]
    # @return [String, nil] why the view is not drawn (R-4)
    def refusal(view)
      sequence = view == 'sequence'
      budget = sequence ? SEQUENCE_BUDGET : NODE_BUDGET
      return nil if size(view) <= budget

      "#{size(view)} #{sequence ? 'participants and messages' : 'nodes'} is over the " \
        "#{sequence ? 'sequence' : 'flowchart'} budget of #{budget}"
    end

    # Mermaid sequence: the caller of the entry, then one message per step
    # from the unit whose operation reached it; async hops are `-)`. The
    # numbers match the steps table (`autonumber`).
    #
    # @return [String]
    def sequence
      lines = ['sequenceDiagram', '  autonumber', "  participant In as #{caller_name}"]
      participants.each_with_index { |unit, i| lines << "  participant P#{i} as #{unit}" }
      steps.each do |step|
        from = step.caller ? alias_for(caller_step(step)&.unit) : 'In'
        to = alias_for(step.unit)
        arrow = step.hop || step.via == :graph ? '-)' : '->>'
        lines << "  #{from}#{arrow}#{to}: #{message(step)}"
      end
      lines.join("\n")
    end

    # Mermaid flowchart: each step from the step that reached it, dashed
    # where another process starts, labelled with how.
    #
    # @return [String]
    def flowchart
      nodes = ["  in([#{quoted(caller_name)}])"]
      edges = []
      steps.each do |step|
        nodes << "  s#{step.n}[#{quoted("#{step.n} · #{step.title}")}]"
        from = caller_step(step)
        label = TrailLanes.reach_label(step)
        arrow = step.hop || step.via == :graph ? '-.->' : '-->'
        edges << "  #{from ? "s#{from.n}" : 'in'} #{arrow}#{"|#{quoted(label)}|" if label} s#{step.n}"
      end
      (['flowchart TD'] + nodes + edges).join("\n")
    end

    private

    def caller_name
      { 'controller' => 'Browser', 'job' => 'Queue', 'mailer' => 'App' }.fetch(@unit['type'], 'App')
    end

    # Units in the order they first appear.
    def participants
      @participants ||= steps.map(&:unit).uniq
    end

    def alias_for(unit)
      index = participants.index(unit)
      index ? "P#{index}" : 'In'
    end

    def caller_step(step)
      step.caller && steps.find { |s| s.label == step.caller }
    end

    def message(step)
      text = step.hop ? "#{step.hop.mechanism} → #{step.title}" : step.title
      text = "save implies #{step.title}" if step.via == :inferred
      text.tr(';#', ',·')
    end

    def quoted(text)
      "\"#{text.to_s.tr('"', "'")}\""
    end
  end
end
