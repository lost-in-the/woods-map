# frozen_string_literal: true

module WoodsMap
  # The full-screen graph (M5, notes/graph-page.md): the Graph tab's explorer
  # with the whole page for the canvas, centred on a typed unit named by
  # identifier and type, with the blast radius of a change to it tinted on
  # request. Without a centre it offers the hubs as starting points.
  class GraphsController < ApplicationController
    HUBS_SHOWN = 24

    def show
      with_repository do |repository|
        load_frame(repository)
        @centre = centre(repository)
        next render(:pick) unless @centre

        @neighbourhood = neighbourhood(repository)
        @blast = blast(repository) if params[:blast] == '1'
        render :show
      end
    end

    private

    def load_frame(repository)
      @freshness = repository.freshness
      @tree = WoodsMap::FileTree.for(repository)
      @nav = primary_nav(:graph)
    end

    # @return [Hash, nil] the centre's graph node with its identifier, when the generation has it
    def centre(repository)
      identifier = params[:centre].to_s
      return nil if identifier.empty?

      type = params[:type].to_s.presence
      node = repository.graph_node(identifier, type: type)
      @missing = identifier unless node
      node && { 'identifier' => identifier, 'type' => type || node['type'] }
    end

    def neighbourhood(repository)
      WoodsMap::Neighbourhood.new(
        repository, @centre['identifier'],
        type: @centre['type'], direction: params[:direction].to_s, depth: params.fetch(:depth, 1),
        filters: { types: params[:types], via: params[:via] }
      )
    end

    # Reverse-edge propagation from the centre over the same generation (E-9),
    # to the explorer's depth, the impact page's own model.
    def blast(repository)
      WoodsMap::BlastRadius.new(repository, focus: @centre['identifier'], depth: @neighbourhood.depth)
    end

    helper_method def hubs
      Array(@repository.graph_analysis['hubs']).first(HUBS_SHOWN).filter_map do |hub|
        identifier = hub['identifier']
        type = @repository.graph_node(identifier)&.dig('type')
        type && { identifier: identifier, type: type, dependents: hub['dependent_count'] }
      end
    end
  end
end
