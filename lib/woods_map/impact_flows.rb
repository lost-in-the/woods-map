# frozen_string_literal: true

module WoodsMap
  # The impact page's Flows tab (B6-Impact-Flows, E-4): entry points whose
  # precomputed flow documents pass through a changed unit, with their steps.
  #
  # Membership is Woods' inverted flow index (W-13) and nothing else: in
  # pre-change mode the map asks `flow_entry_points` for each focus unit; in
  # range mode the entry points are the report's own `flows` records, which
  # Woods computed from the same inverse. Steps come from `flow_document` of
  # the pinned generation only. A record of another generation keeps its
  # route and changed steps but shows no steps (historical identities have no
  # current-source links, D-1). Membership is bounded flow evidence: a step
  # expanded within the document's assembly depth, not proof a path ran.
  class ImpactFlows
    # Entry points shown at most; the rest are counted.
    LIMIT = 100
    # Steps and operations drawn per flow; the rest are counted.
    STEP_LIMIT = 40
    OPERATION_LIMIT = 12

    # One entry point through the changes.
    Row = Struct.new(:entry_point, :route, :generation, :endpoint, :changed, :steps, :steps_state,
                     keyword_init: true) do
      # @return [Integer] steps that are changed units
      def changed_steps
        Array(steps).count { |step| step.distance&.zero? }
      end
    end

    # One step of a flow document: a typed unit and its operations.
    Step = Struct.new(:identifier, :type, :label, :distance, :lines, :cycle, :linkable, keyword_init: true)

    # One operation line under a step, already bounded.
    Line = Struct.new(:depth, :kind, :text, :mech, keyword_init: true)

    # Line kinds by flow operation type; anything else is :other.
    KINDS = { 'call' => :call, 'conditional' => :branch, 'response' => :response }.freeze

    # @param repository [WoodsMap::Repository]
    # @param roots [Array<Array(String, String)>] the focus units' typed identities
    # @param marks [Hash{Array(String, String) => Integer}] distance per typed unit (0 changed)
    # @return [ImpactFlows]
    def self.for_focus(repository, roots:, marks: {})
      members = Hash.new { |hash, key| hash[key] = [] }
      roots.each do |identifier, type|
        Array(repository.flow_entry_points(identifier, type: type)).each do |entry|
          members[entry] << { 'identifier' => identifier, 'type' => type }
        end
      end
      records = members.sort.map do |entry, identities|
        { 'entry_point' => entry, 'changed_steps' => identities.uniq, 'generation' => repository.generation_number,
          'endpoint' => 'to' }
      end
      new(repository, records, marks: roots.index_with(0).merge(marks), routes: true)
    end

    # @param repository [WoodsMap::Repository]
    # @param report [WoodsMap::RangeReport]
    # @return [ImpactFlows]
    def self.for_report(repository, report)
      marks = report.emphasis.to_h { |e| [[e.identifier.to_s, e.type.to_s], e.distance] }
      new(repository, report.flows, marks: marks)
    end

    # @param repository [WoodsMap::Repository]
    # @param records [Array<Hash>] entry point, route, changed_steps, generation, endpoint
    # @param marks [Hash{Array(String, String) => Integer}]
    # @param routes [Boolean] whether the route comes from the document (pre-change)
    def initialize(repository, records, marks: {}, routes: false)
      @repository = repository
      @records = records
      @marks = marks
      @routes = routes
    end

    # The rows, each reading its flow document once; built on first use so a
    # tab count costs no document reads.
    #
    # @return [Array<Row>]
    def rows
      @rows ||= @records.first(LIMIT).map { |record| row(record, @routes) }
    end

    # @return [Integer] entry points, before {LIMIT}
    def total
      @records.size
    end

    # @return [Boolean]
    def truncated?
      total > rows.size
    end

    # @return [Symbol] the repository's flow state after the reads (see
    #   {RepositoryFlows#flows_state})
    def state
      @repository.flows_state
    end

    private

    def row(record, routes)
      changed = Array(record['changed_steps']).grep(Hash).map { |s| s.values_at('identifier', 'type').map(&:to_s) }
      document, steps_state = document_for(record)
      route = routes && document ? document['route'] : record['route']
      Row.new(entry_point: record['entry_point'].to_s, route: route.is_a?(Hash) ? route : nil,
              generation: record['generation'], endpoint: record['endpoint'], changed: changed,
              steps: document && steps(document, changed), steps_state: steps_state)
    end

    def document_for(record)
      return [nil, :historical] unless record['generation'] == @repository.generation_number

      document = @repository.flow_document(record['entry_point'].to_s)
      return [nil, :missing] unless document

      [document, Array(document['steps']).size > STEP_LIMIT ? :truncated : :shown]
    end

    def steps(document, changed)
      Array(document['steps']).first(STEP_LIMIT).grep(Hash).map { |step| step_for(step, changed) }
    end

    def step_for(step, changed)
      return Step.new(cycle: true, label: step['unit'].to_s, lines: []) if step['type'] == 'cycle'

      identity = [step['unit'].to_s.split('#', 2).first, step['type'].to_s]
      Step.new(identifier: identity.first, type: identity.last, label: step['unit'].to_s,
               distance: changed.include?(identity) ? 0 : @marks[identity], lines: lines(step['operations']),
               cycle: false, linkable: !@repository.graph_node(identity.first, type: identity.last).nil?)
    end

    def lines(operations)
      all = []
      framework = flatten(Array(operations), 0, all)
      shown = all.first(OPERATION_LIMIT)
      hidden = all.size - shown.size
      shown << Line.new(depth: 0, kind: :more, text: "#{hidden} more operations") if hidden.positive?
      if framework.positive?
        shown << Line.new(depth: 0, kind: :framework, text: "#{framework} untargeted calls",
                          mech: 'framework or dynamic, not shown')
      end
      shown
    end

    # @return [Integer] calls without a constant target (framework filters,
    #   procs, dynamic sends), counted rather than drawn
    def flatten(operations, depth, out)
      operations.sum { |op| op.is_a?(Hash) ? flatten_one(op, depth, out) : 0 }
    end

    def flatten_one(operation, depth, out)
      return 1 if operation['type'] == 'call' && operation['target'].to_s.empty?

      out << Line.new(depth: depth, kind: KINDS.fetch(operation['type'], :other), text: operation_text(operation),
                      mech: line_of(operation))
      return 0 unless operation['type'] == 'conditional'

      flatten(Array(operation['then_ops']), depth + 1, out) + flatten(Array(operation['else_ops']), depth + 1, out)
    end

    def operation_text(operation)
      case operation['type']
      when 'call' then "#{operation['target']}.#{operation['method']}"
      when 'conditional' then "#{operation['kind'] || 'if'} #{operation['condition']}".strip
      when 'response' then [operation['status_code'], operation['render_method']].compact.join(' ')
      else operation['type'].to_s
      end
    end

    def line_of(operation)
      operation['line'] ? "line #{operation['line']}" : nil
    end
  end
end
