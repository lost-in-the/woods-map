# frozen_string_literal: true

require 'woods/flow_assembler'

module WoodsMap
  # The M3 exit criterion (woods-map#5, docs/design/notes/m3-exit-check.md):
  # the Lifecycle and Schema texts the map draws match Woods' flow documents
  # (`FlowAssembler`, as `woods:flow` builds them) and the model metadata of
  # one generation. Each check returns rows with their problems; an empty
  # problem list is a match.
  module M3ExitCheck
    module_function

    # @param index_dir [String] a published Woods index
    # @return [Hash{Symbol => Array<Hash>}] :entries, :models, :schema
    def run(index_dir)
      Repository.open(index_dir) do |repository|
        assembler = Woods::FlowAssembler.new(graph: Woods::DependencyGraph.from_h(repository.graph),
                                             extracted_dir: Woods::PublishedIndex.new(index_dir).payload_dir.to_s)
        { entries: entries(repository, assembler), models: models(repository, assembler),
          schema: M3SchemaCheck.run(repository) }
      end
    end

    # Every controller action, job and mailer action: Woods' steps appear on
    # the map in Woods' order, and the sequence, flowchart and lanes texts
    # each draw every step.
    def entries(repository, assembler)
      %w[controller job mailer].flat_map do |type|
        repository.units(type: type).flat_map do |entry|
          unit = repository.unit(entry['identifier'], type: type)
          EntryLifecycle.new(repository, unit).actions.filter_map do |action|
            entry_row(repository, assembler, EntryLifecycle.new(repository, unit, action: action))
          end
        end
      end
    end

    def entry_row(repository, assembler, lifecycle)
      steps = lifecycle.steps
      return nil if steps.empty?

      depth = depth_of(repository, lifecycle)
      woods = woods_steps(assembler, lifecycle.entry, depth)
      { entry: lifecycle.entry, source: lifecycle.source, depth: depth, woods: woods.size, map: steps.size,
        added: steps.reject { |s| woods.include?(s.label) }.map { |s| "#{s.label} (#{s.via})" },
        problems: order_problems(woods, steps.map(&:label)) + text_problems(lifecycle, steps) }
    end

    # @return [Array<String>] the flow's step labels, cycles left out, first visits only
    def woods_steps(assembler, entry, depth)
      Array(assembler.assemble(entry, max_depth: depth).to_h[:steps])
        .reject { |s| s[:type].to_s == 'cycle' }.map { |s| s[:unit].to_s }.uniq
    end

    def order_problems(woods, labels)
      problems = []
      problems << "Woods steps missing: #{woods - labels}" unless (woods - labels).empty?
      problems << "order: Woods #{woods}, map #{labels}" unless labels & woods == woods & labels
      problems
    end

    def depth_of(repository, lifecycle)
      return LifecycleBuilder::FLOW_DEPTH unless lifecycle.source == 'precomputed'

      repository.flow_document(lifecycle.entry)&.dig('max_depth') || LifecycleBuilder::FLOW_DEPTH
    end

    def text_problems(lifecycle, steps)
      sequence = lifecycle.diagram('sequence')
      problems = text_counts(lifecycle, sequence).filter_map do |what, n|
        "#{what} #{n} for #{steps.size} steps" unless n == steps.size
      end
      missing = steps.reject { |s| sequence.include?(s.title.tr(';#', ',·')) }.map(&:title)
      problems << "not in the sequence: #{missing}" if missing.any?
      problems
    end

    def text_counts(lifecycle, sequence)
      node = /^\s+s\d+\[/
      { 'sequence messages' => sequence.lines.count { |l| l.match?(/^\s+\S+-(>>|\))\S+: /) },
        'flowchart nodes' => lifecycle.diagram('flowchart').lines.count { |l| l.match?(node) },
        'lanes nodes' => lifecycle.diagram('lanes').lines.count { |l| l.match?(node) } }
    end

    # Every application model and event: the map's callback chain is Woods'
    # model event flow's application callbacks, in Woods' order, and the
    # sequence names each.
    def models(repository, assembler)
      repository.units(type: 'model').flat_map do |entry|
        unit = repository.unit(entry['identifier'], type: 'model')
        next [] unless unit['file_path'].to_s.start_with?('app/')

        lifecycle = Lifecycle.new(unit, concern_methods: concern_methods(repository, unit))
        Lifecycle::EVENTS.filter_map { |event| model_row(assembler, unit, lifecycle, event) }
      end
    end

    def model_row(assembler, unit, lifecycle, event)
      map = lifecycle.steps(event).map(&:filter)
      operations = callback_operations(assembler, "#{unit['identifier']}@#{event}")
      woods = operations.reject { |op| op[:unexpanded] }.map { |op| op[:method].to_s }
      return nil if map.empty? && woods.empty?

      { entry: "#{unit['identifier']}@#{event}", callbacks: map, woods_unexpanded: operations.size - woods.size,
        map_framework: lifecycle.framework.size, problems: callback_problems(map, woods, lifecycle.mermaid(event)) }
    end

    def callback_operations(assembler, entry)
      Array(assembler.assemble(entry, max_depth: 1).to_h[:steps]).flat_map { |s| Array(s[:operations]) }
                                                                 .select { |op| op[:type].to_s == 'callback' }
    end

    def callback_problems(map, woods, sequence)
      problems = []
      problems << "callbacks: map #{map}, Woods #{woods}" unless map == woods
      problems << 'a callback is missing from the sequence' unless map.all? { |name| sequence.include?(name) }
      problems
    end

    def concern_methods(repository, unit)
      Array(unit.dig('metadata', 'inlined_concerns')).index_with do |name|
        Array(repository.unit(name, type: 'concern')&.dig('metadata', 'instance_methods')).map(&:to_s)
      end
    end
  end

  # The Schema half of {M3ExitCheck}.
  module M3SchemaCheck
    module_function

    # Every application model: the Schema tab's columns are the model's, and
    # its ER text draws each direct association to the table its target reads.
    def run(repository)
      tables = repository.model_tables
                         .transform_values { |n| n['table'] }
      repository.units(type: 'model').filter_map do |entry|
        unit = repository.unit(entry['identifier'], type: 'model')
        next unless unit['file_path'].to_s.start_with?('app/')

        schema_row(unit, SchemaView.new(unit, tables: tables), tables)
      end
    end

    def schema_row(unit, view, tables)
      columns = Array(unit.dig('metadata', 'columns')).pluck('name')
      problems = view.columns.map(&:name) == columns ? [] : ["columns: #{view.columns.map(&:name)}"]
      { entry: unit['identifier'], table: view.table_name, columns: columns.size,
        associations: view.associations.size, problems: problems + er_problems(unit, view.mermaid, tables) }
    end

    def er_problems(unit, text, tables)
      Array(unit.dig('metadata', 'associations')).reject { |a| a['through'] }.filter_map do |a|
        table = tables[a['target']]
        "#{a['name']} does not draw #{table}" unless table.nil? || text.include?(%("#{table}"))
      end
    end
  end
end
