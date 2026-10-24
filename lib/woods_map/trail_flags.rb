# frozen_string_literal: true

module WoodsMap
  # Derived flags of the Trail (C-2, notes/trail.md): facts the generation
  # publishes, each flag naming its evidence. A flag whose fact is absent is
  # a limit naming the W-item that adds it, never a guess.
  class TrailFlags
    # One flag on a typed unit; +line+ and +file+ when an operation has them.
    Flag = Struct.new(:identity, :severity, :rule, :text, :evidence, :file, :line, keyword_init: true)

    RULES = {
      retry: 'no retry_on or discard_on',
      rescue: 'no rescue_from',
      conditional_callback: 'conditional callback',
      no_else: 'if without else',
      dynamic: 'dynamic dispatch',
      cross_db: 'cross-database association',
      hub: 'hub',
      ivar: 'template reads an unassigned ivar'
    }.freeze

    # @param repository [WoodsMap::Repository]
    # @param steps [Array<LifecycleBuilder::Step>]
    # @param pins [Array<Array(String, String)>] pinned identities, for the unit-level flags
    def initialize(repository, steps, pins: [])
      @repository = repository
      @steps = steps
      @pins = pins
      @limits = []
      @flags = collect
    end

    # @return [Array<Flag>] every flag, in step order, then the pins'
    attr_reader :flags

    # @return [Array<String>] facts the generation lacks, with the W-item that adds them
    def limits
      @limits.uniq
    end

    # @param identity [Array(String, String)] identifier and type
    # @return [Array<Flag>]
    def for(identity)
      @flags.select { |flag| flag.identity == identity }
    end

    # @param step [LifecycleBuilder::Step]
    # @return [Array<Flag>] the flags raised on that step's unit and operations
    def for_step(step)
      @by_step[step.n] || []
    end

    private

    def collect
      @by_step = {}
      seen = {}
      flags = @steps.flat_map do |step|
        found = step_flags(step)
        found += unit_flags(step.identity) unless seen[step.identity]
        seen[step.identity] = true
        @by_step[step.n] = found
      end
      flags + @pins.reject { |identity| seen[identity] }.flat_map { |identity| unit_flags(identity) }
    end

    def step_flags(step)
      flags = operation_flags(step)
      flags += callback_flags(step) if step.type == 'model_event'
      flags += template_flags(step) if step.type == 'mailer' && step.method_name
      flags
    end

    # Flags of the unit itself, raised once wherever it appears.
    def unit_flags(identity)
      unit = @repository.unit(identity.first, type: identity.last)
      flags = []
      flags.concat(job_flags(identity, unit)) if identity.last == 'job' && unit
      flags.concat(cross_db_flags(identity))
      flags.concat(hub_flags(identity))
      flags
    end

    def job_flags(identity, unit)
      meta = unit['metadata'] || {}
      unless meta.key?('resilience_source')
        @limits << 'job resilience facts (retry_on, discard_on, rescue_from) need Woods W-4: re-extract with it'
        return []
      end

      source = meta['resilience_source']
      flags = []
      if Array(meta['retry_on']).empty? && Array(meta['discard_on']).empty?
        flags << flag(identity, :retry,
                      'An exception in perform is neither retried nor discarded by a declaration',
                      "retry_on [], discard_on [] (#{source}, W-4)")
      end
      if Array(meta['rescue_from']).empty?
        flags << flag(identity, :rescue, 'No rescue_from handler', "rescue_from [] (#{source}, W-4)")
      end
      flags
    end

    def callback_flags(step)
      step.operations.filter_map do |op|
        conditions = (op[:conditions] || {}).transform_keys(&:to_s).slice('if', 'unless')
        next if conditions.empty? || op[:unexpanded]

        text = conditions.map { |key, values| "#{key} #{Array(values).join(', ')}" }.join('; ')
        flag([step.unit, 'model'], :conditional_callback, "#{op[:callback]} #{op[:method]} runs only #{text}",
             'conditions on the published callback')
      end
    end

    def operation_flags(step)
      flags = []
      each_operation(step.operations) do |op|
        case op[:type]&.to_sym
        when :conditional
          if op[:kind].to_s == 'if' && Array(op[:else_ops]).empty?
            flags << flag(step.identity, :no_else, "if #{op[:condition]} has no else operations",
                          'flow conditional', op)
          end
        when :dynamic_dispatch
          flags << flag(step.identity, :dynamic, "#{op[:target]}.#{op[:method]}: the target is not resolved",
                        'flow dynamic_dispatch', op)
        end
      end
      flags
    end

    def template_flags(step)
      unit = @repository.unit(step.unit, type: 'mailer')
      passage = unit && Passage.new(@repository, unit, action: step.method_name)
      flags = passage&.flags
      if flags.nil?
        @limits << 'unassigned template ivars need per-action facts (Woods W-7)'
        return []
      end

      flags.map do |f|
        Flag.new(identity: [f.template, 'view_template'], severity: :note, rule: RULES[:ivar],
                 text: "#{f.template} mentions #{f.ivar}; #{step.label} assigns none", evidence:
                 'template ivars + per-action facts (advisory: helpers and template locals are not resolved)')
      end
    end

    def cross_db_flags(identity)
      edges = identity.last == primary_type(identity.first) ? @repository.graph.dig('edges', identity.first) : nil
      Array(edges).select { |edge| edge['cross_database'] }.map do |edge|
        flag(identity, :cross_db, "#{edge['via']} #{edge['target']} joins two databases",
             'cross_database on the published edge')
      end
    end

    def hub_flags(identity)
      analysis = @repository.graph_analysis
      return [] unless analysis.key?('hubs')

      hub = Array(analysis['hubs']).find { |h| h['identifier'] == identity.first }
      hub ? [flag(identity, :hub, "a hub, #{hub['dependent_count']} dependents", 'graph_analysis hubs')] : []
    end

    def primary_type(identifier)
      @repository.graph_node(identifier)&.dig('type').to_s
    end

    def flag(identity, rule, text, evidence, operation = nil)
      Flag.new(identity: identity, severity: rule == :retry ? :warn : :note, rule: RULES.fetch(rule), text: text,
               evidence: evidence,
               file: operation&.dig(:file), line: operation&.dig(:line))
    end

    def each_operation(operations, &block)
      Array(operations).each do |op|
        yield op
        %i[nested then_ops else_ops].each { |key| each_operation(op[key], &block) }
      end
    end
  end
end
