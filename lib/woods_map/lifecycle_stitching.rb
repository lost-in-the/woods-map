# frozen_string_literal: true

module WoodsMap
  # What the Trail adds where a flow stops (C-1, notes/trail.md): the model
  # event a controller action's save implies, the jobs a published
  # `job_enqueue` edge names, and a mailer action's templates. Each is marked
  # by how it was reached. Mixed into {LifecycleBuilder}.
  module LifecycleStitching
    # Persistence calls whose model event the Passage ladder can name.
    PERSIST = %w[save save! create create! update update! destroy destroy!].freeze

    private

    # A controller action whose flow calls `save` (or create, update,
    # destroy) on something the flow cannot resolve runs the model event the
    # Passage ladder reads from the action: the permitted model, else the
    # first referenced one, and the action's name. It runs in the same
    # process, and the step says it is inferred.
    def infer_model_events
      @steps.select { |step| step.type == 'controller' && step.method_name }.each do |step|
        next unless persists?(step)

        model, event = ladder(step)
        next unless model && event

        entry = "#{model}@#{event}"
        next if seen?(entry)

        @limits['model events inferred from a controller action (the Passage ladder)'] += 1
        add_flow(entry, process: step.process, via: :inferred, hop: nil, caller: step.label)
      end
    end

    def persists?(step)
      found = false
      each_operation(step.operations) { |op| found ||= op[:type].to_s == 'call' && PERSIST.include?(op[:method].to_s) }
      found
    end

    def ladder(step)
      unit = @repository.unit(step.unit, type: 'controller')
      passage = unit && Passage.new(@repository, unit, action: step.method_name)
      [passage&.ladder_model&.dig('identifier'), passage&.ladder_event]
    end

    # Published `job_enqueue` edges from a step to a job the flow did not
    # reach start a process of their own while the budget lasts. No flow
    # operation shows the call site, and the hop says so.
    def follow_graph_enqueues
      index = 0
      while index < @steps.size
        step = @steps[index]
        index += 1
        next if step.process >= @hops

        graph_jobs(step.unit).each do |job|
          next if @steps.any? { |s| s.unit == job }

          entry = "#{job}#perform"
          hop = LifecycleBuilder::Hop.new(n: step.process + 1, label: entry, from: step.label,
                                          mechanism: 'job_enqueue edge')
          @limits['hops from a graph edge, with no call site in the flow'] += 1
          add_flow(entry, process: step.process + 1, via: :graph, hop: hop, caller: step.label)
        end
      end
    end

    def graph_jobs(unit)
      Array(@repository.graph.dig('edges', unit)).filter_map do |edge|
        target = edge['target'].to_s
        target if edge['via'] == 'job_enqueue' && @repository.graph_node(target, type: 'job')
      end.uniq
    end

    def add_templates(mailer, action, process, caller)
      unit = @repository.unit(mailer, type: 'mailer')
      return unless unit

      Passage.new(@repository, unit, action: action).templates.each do |template|
        next if seen?(template.identifier)

        @steps << LifecycleBuilder::Step.new(
          label: template.identifier, unit: template.identifier, type: 'view_template', lane: 'view',
          process: process, file_path: @repository.graph_node(template.identifier)&.dig('file_path'),
          operations: [], via: :template, caller: caller
        )
      end
    end
  end
end
