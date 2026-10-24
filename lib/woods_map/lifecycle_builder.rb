# frozen_string_literal: true

require 'set'

module WoodsMap
  # The Trail's lifecycle across async hops (C-1, notes/trail.md): the entry's
  # flow from Woods' `FlowAssembler`, cut into processes at each async hop,
  # extended along published `job_enqueue` edges where the flow stops, with
  # each mailer action's templates, and grouped into lanes by unit type.
  # Nothing here reads host source: steps, operations and lines are the flow
  # document's, templates are the Passage tab's.
  class LifecycleBuilder
    include LifecycleReach
    include LifecycleStitching

    # How deep one flow is assembled. Async hops are budgeted separately.
    FLOW_DEPTH = 6

    # Lanes in reading order, each with the unit types it holds; any other
    # application type runs in the service lane.
    LANES = {
      'request' => %w[route controller],
      'model' => %w[model model_event concern state_machine],
      'service' => [],
      'job' => %w[job],
      'mailer' => %w[mailer],
      'view' => %w[view_template component view_component]
    }.freeze

    # The flowchart budget of the lanes diagram (R-4), as the neighbourhood's.
    NODE_BUDGET = 150

    # One step of the lifecycle. +via+ says how it was reached: :entry, :call,
    # :async (an enqueue), :delivery (a mail delivery), :graph (a published
    # `job_enqueue` edge with no flow operation), :template, or :inferred (the
    # model event a controller action's save implies, as the Passage ladder
    # reads it). +caller+ is the label of the step whose operation reached it.
    Step = Struct.new(:n, :label, :unit, :method_name, :type, :lane, :process, :file_path, :operations, :via,
                      :hop, :caller, keyword_init: true) do
      # @return [Array(String, String)] identifier and type
      def identity
        [unit, type == 'model_event' ? 'model' : type]
      end

      # @return [String] `Unit#method` (a job reached by an enqueue reads as
      #   its `#perform`), `Unit@event`, or the template
      def title
        return label if type == 'model_event' || method_name.nil? || label.include?('#')

        "#{unit}##{method_name}"
      end
    end

    # A process boundary: where process +n+ was started from.
    Hop = Struct.new(:n, :label, :from, :mechanism, :file, :line, keyword_init: true)

    # @param repository [WoodsMap::Repository]
    # @param entry [String] a flow entry
    # @param hops [Integer] the async hop budget
    def initialize(repository, entry, hops: TrailBoard::DEFAULT_HOPS)
      @repository = repository
      @entry = self.class.normalize(repository, entry)
      @hops = hops
      @steps = []
      @beyond = []
      @limits = Hash.new(0)
      @sources = {}
      build
    end

    # A bare job is its `#perform`; a bare mailer with one action is that
    # action. Everything else is the entry as given.
    #
    # @param repository [WoodsMap::Repository]
    # @param entry [String]
    # @return [String]
    def self.normalize(repository, entry)
      return entry if entry.include?('#') || entry.include?('@')

      case repository.graph_node(entry)&.dig('type').to_s
      when 'job' then "#{entry}#perform"
      when 'mailer'
        actions = Array(repository.unit(entry, type: 'mailer')&.dig('metadata', 'actions'))
        actions.one? ? "#{entry}##{actions.first}" : entry
      else entry
      end
    end

    # @return [String] the entry the flow started from
    attr_reader :entry
    # @return [Array<Step>] in flow order, numbered from 1
    attr_reader :steps

    # @return [Array<Hop>] each process an async hop started within the budget
    def processes
      @steps.filter_map(&:hop)
    end
    # @return [Array<Array(String, Integer)>] steps cut by the hop budget: label and process
    attr_reader :beyond
    # @return [Integer] the async hop budget
    attr_reader :hops
    # @return [Hash{String => String}] each assembled entry => precomputed or assembled
    attr_reader :sources

    # @return [Hash{String => Integer}] limit => how often it applies
    def limits
      @limits.reject { |_, count| count.zero? }
    end

    # @return [Array<String>] the lanes that hold a step, in {LANES} order
    def lanes
      present = @steps.map(&:lane).uniq
      LANES.keys.select { |lane| present.include?(lane) }
    end

    # @return [Array<Array(String, String)>] the typed units of the lifecycle, once each
    def identities
      @steps.map(&:identity).uniq
    end

    # Mermaid flowchart text of the lanes (C-4 under D-25), see {TrailLanes}.
    #
    # @return [String]
    def mermaid
      TrailLanes.new(lanes, @steps).mermaid
    end

    # @return [Integer] nodes the lanes diagram draws
    delegate :size, to: :@steps

    # @return [String, nil] why the lanes diagram is not drawn (R-4)
    def refusal
      "#{size} steps is over the flowchart budget of #{NODE_BUDGET}" if size > NODE_BUDGET
    end

    private

    def build
      capabilities = RepositoryAssembledFlows.capabilities
      unless capabilities[:mail_deliveries]
        @limits['this Woods does not follow mail deliveries into the mailer (woods#755)'] += 1
      end
      if @entry.include?('@') && !capabilities[:model_events]
        @limits['model event entries need Woods W-5 (woods#755)'] += 1
        return
      end

      add_flow(@entry, process: 0, via: :entry, hop: nil)
      infer_model_events if capabilities[:model_events]
      follow_graph_enqueues
      @steps.each_with_index { |step, index| step.n = index + 1 }
    end

    # Steps of one flow document, each in the process its caller's operation
    # puts it in.
    def add_flow(entry, process:, via:, hop:, caller: nil)
      doc = @repository.flow(entry, max_depth: FLOW_DEPTH)
      @sources[entry] = doc[:source] || 'assembled'
      reach = { entry => [process, via, hop, caller] }
      Array(doc[:steps]).each do |raw|
        next @limits['revisits of a unit already on the path'] += 1 if raw[:type].to_s == 'cycle'

        label = raw[:unit].to_s
        place = place_for(reach, label, process)
        operations = Array(raw[:operations])
        map_operations(operations, label, place.first, reach)
        next @beyond << [label, place.first] if place.first > @hops
        next if seen?(label)

        add_step(raw, label, place, operations)
      end
    end

    # Where a step runs: what an earlier operation recorded for it, else its caller's process.
    def place_for(reach, label, process)
      reach.delete(label) || reach[label.split('#', 2).first] || [process, :call, nil, nil]
    end

    def add_step(raw, label, place, operations)
      process, via, hop, caller = place
      unit, method_name = label.split(/[#@]/, 2)
      type = raw[:type].to_s
      method_name ||= 'perform' if type == 'job' && %i[async graph].include?(via)
      count_unexpanded(operations) if type == 'model_event'
      @steps << Step.new(label: label, unit: unit, method_name: method_name, type: type, lane: lane_for(type),
                         process: process, file_path: raw[:file_path], operations: operations, via: via, hop: hop,
                         caller: caller)
      add_templates(unit, method_name, process, label) if type == 'mailer' && method_name
    end

    def seen?(label)
      @steps.any? { |step| step.label == label }
    end

    def count_unexpanded(operations)
      @limits['callbacks the model does not define (framework or proc)'] += operations.count { |op| op[:unexpanded] }
    end

    def lane_for(type)
      LANES.find { |_, types| types.include?(type) }&.first || 'service'
    end
  end
end
