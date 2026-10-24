# frozen_string_literal: true

module WoodsMap
  # The graph's flow overlay (A-4): one precomputed flow document (Woods W-13)
  # laid over the neighbourhood the explorer draws. Each step is matched to a
  # drawn typed unit, and each move from one step's unit to the next to a
  # drawn edge between them, in either direction. Steps whose unit is not
  # drawn, and moves with no graph edge, are listed rather than invented.
  # Membership is bounded flow evidence: it says a step was expanded within
  # the document's assembly depth, not that a request takes that path.
  class GraphFlow
    # Entry points listed in the rail before a count of the rest.
    LISTED = 12

    # One step of the flow: where it is in the document, the unit it names,
    # the typed graph unit it resolves to, and the move that reached it.
    Step = Struct.new(:position, :unit, :identifier, :type, :drawn, :operations, :edge, :move,
                      keyword_init: true)

    # The rail's list of flows for a typed unit.
    #
    # @param repository [Repository]
    # @param identifier [String]
    # @param type [String]
    # @return [Hash] :state (Repository#flows_state, read after the lookup) and :entries (Array<String>)
    def self.entries(repository, identifier, type)
      entries = repository.flow_entry_points(identifier, type: type)
      { state: repository.flows_state, entries: Array(entries) }
    end

    # @param repository [Repository]
    # @param neighbourhood [Neighbourhood] what the explorer draws
    # @param entry_point [String] a flow index key, e.g. `PostsController#create`
    def initialize(repository, neighbourhood, entry_point)
      @repository = repository
      @neighbourhood = neighbourhood
      @entry_point = entry_point.to_s
      @document = repository.flow_document(@entry_point)
    end

    attr_reader :entry_point

    # @return [Boolean] whether the generation lists this entry point
    def found?
      !@document.nil?
    end

    # @return [String, nil] e.g. `POST /posts`
    def route
      route = @document&.dig('route')
      return nil unless route.is_a?(Hash)

      [route['verb'], route['path']].compact.join(' ').presence
    end

    # @return [Integer, nil] the document's assembly depth
    def max_depth
      @document&.dig('max_depth')
    end

    # @return [Array<Step>] in document order
    def steps
      @steps ||= build_steps
    end

    # @return [Array<Step>] steps drawn on the canvas
    def drawn
      steps.select(&:drawn)
    end

    # @return [Array<Step>] steps the canvas cannot show: their unit is not
    #   drawn, or the move that reached them has no drawn edge
    def unmatched
      steps.reject { |step| step.drawn && %i[edge first same].include?(step.move) }
    end

    # What the canvas needs, in document order: typed units and the drawn
    # edges between consecutive steps.
    #
    # @return [Hash]
    def payload
      { 'entry_point' => @entry_point, 'total' => steps.size,
        'steps' => steps.select(&:drawn).map do |step|
          { 'position' => step.position, 'identifier' => step.identifier, 'type' => step.type,
            'from' => step.edge && edge_end(step.edge, :from), 'to' => step.edge && edge_end(step.edge, :to) }
        end }
    end

    private

    def build_steps
      previous = nil
      Array(@document&.dig('steps')).each_with_index.map do |raw, index|
        identifier, type = resolve(raw)
        step = Step.new(position: index + 1, unit: raw['unit'].to_s, identifier: identifier, type: type,
                        drawn: drawn?(identifier, type), operations: Array(raw['operations']).size)
        step.edge = previous && edge_between(previous, step)
        step.move = move_for(previous, step)
        previous = step
      end
    end

    # A controller step names its action (`PostsController#create`); the
    # graph's unit is the controller.
    def resolve(raw)
      unit = raw['unit'].to_s
      type = raw['type'].to_s
      return [unit, type] if @repository.graph_node(unit, type: type) || unit.exclude?('#')

      [unit.split('#', 2).first, type]
    end

    def drawn?(identifier, type)
      identities.include?([identifier, type])
    end

    def identities
      @identities ||= @neighbourhood.edges.flat_map { |e| [[e.from, e.from_type], [e.to, e.to_type]] }
                                    .push(@neighbourhood.focus).to_set
    end

    def edge_between(from, to)
      a = [from.identifier, from.type]
      b = [to.identifier, to.type]
      @neighbourhood.edges.find do |e|
        ends = [[e.from, e.from_type], [e.to, e.to_type]]
        [[a, b], [b, a]].include?(ends)
      end
    end

    def move_for(previous, step)
      return :first unless previous
      return :same if [previous.identifier, previous.type] == [step.identifier, step.type]
      return :edge if step.edge

      :no_edge
    end

    def edge_end(edge, side)
      side == :from ? [edge.from, edge.from_type] : [edge.to, edge.to_type]
    end
  end
end
