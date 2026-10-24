# frozen_string_literal: true

module WoodsMap
  # A unit's pages: the Code tab (two lenses, D-6), Routes, Passage, Schema,
  # Lifecycle, Graph and History, and the peek fragment the code view opens inline. Every
  # action reads one pinned generation and renders inside it, so the payload
  # lock covers the whole response; the identifier and the type come from the
  # URL, never a path.
  class UnitsController < ApplicationController
    LENS_COOKIE = 'woods_map_lens'

    # Every indexed typed identity, including units without a source file.
    def index
      with_repository do |repository|
        @unit_groups = repository.units.uniq { |unit| unit.values_at('identifier', 'type') }
                                 .sort_by { |unit| [unit['type'].to_s, unit['identifier'].to_s] }
                                 .group_by { |unit| unit['type'].to_s }
        @unit_count = @unit_groups.values.sum(&:size)
        @tree = WoodsMap::FileTree.for(repository)
        @freshness = repository.freshness
        @nav = primary_nav(:units)
        render :index
      end
    end

    def show
      return redirect_to_remembered_lens if params[:lens].present?

      with_unit do
        @lifecycle = lifecycle_for(@unit)
        @code = code_view(@unit, lens, @lifecycle)
        @outline = WoodsMap::Outline.new(@unit, lifecycle: @lifecycle, concern_methods: concern_methods(@unit))
        @cards = WoodsMap::HoverCard.for(@repository, @code.linked_targets)
        render :show
      end
    end

    def schema
      with_unit do
        @schema = WoodsMap::SchemaView.new(@unit, table: @page.table, graph_analysis: @repository.graph_analysis)
        render :schema
      end
    end

    # The data passage of one action (B8-Passage): the first action unless
    # ?action_name= picks one; a type without actions goes to its Code tab.
    def passage
      with_unit do
        unless @page.tabs.include?('passage')
          next redirect_to(woods_map.unit_path(type: @page.type, identifier: @page.identifier))
        end

        @passage = WoodsMap::Passage.new(@repository, @unit, action: params[:action_name])
        @ladder_model = @passage.ladder_model
        @ladder = @ladder_model && lifecycle_for(@ladder_model)
        @ladder_event = ladder_event(@ladder)
        render :passage
      end
    end

    # The routes, helpers and action sources of a controller (FR-3); any
    # other type goes to its Code tab.
    def routes
      with_unit do
        unless @page.tabs.include?('routes')
          next redirect_to(woods_map.unit_path(type: @page.type, identifier: @page.identifier))
        end

        @routes = WoodsMap::RoutesView.new(@repository, @unit)
        render :routes
      end
    end

    def lifecycle
      with_unit do
        @lifecycle = lifecycle_for(@unit)
        @event = params[:event] if WoodsMap::Lifecycle::EVENTS.include?(params[:event])
        @event ||= @lifecycle.chains.keys.first || 'create'
        render :lifecycle
      end
    end

    def graph
      with_unit do
        @neighbourhood = WoodsMap::Neighbourhood.new(
          @repository, @unit['identifier'],
          type: @unit['type'],
          direction: params[:direction].to_s, depth: params.fetch(:depth, 1),
          filters: { types: params[:types], via: params[:via] }
        )
        render :graph
      end
    end

    def history
      with_unit do
        @history = WoodsMap::HistoryView.new(@unit)
        render :history
      end
    end

    # The first lines of a unit around its definition, for the peek drawer.
    def peek
      with_unit do
        @code = code_view(@unit, 'written', lifecycle_for(@unit))
        render :peek, layout: false
      end
    end

    private

    # Open the generation, load the unit and the page frame, and run the
    # action's body (which renders) while the payload lock is held.
    def with_unit
      with_repository do |repository|
        @repository = repository
        @tab = action_name
        @unit = repository.unit(params[:identifier].to_s, type: params[:type].to_s)
        next render_missing_unit unless @unit

        @page = WoodsMap::UnitPage.new(repository, @unit)
        @definition = WoodsMap::CompositeSource.new(@unit).definition_line
        @tree = WoodsMap::FileTree.for(repository)
        @freshness = repository.freshness
        yield
      end
    end

    def render_missing_unit
      @identifier = params[:identifier].to_s
      @type = params[:type].to_s
      render 'woods_map/units/missing', status: :not_found
    end

    def lens
      cookies[LENS_COOKIE].presence || 'written'
    end

    def redirect_to_remembered_lens
      cookies[LENS_COOKIE] = { value: params[:lens], expires: 1.year.from_now, same_site: :lax }
      redirect_to woods_map.unit_path(type: params[:type], identifier: params[:identifier])
    end

    def code_view(unit, lens, lifecycle)
      WoodsMap::CodeView.new(unit, lens: lens, references: WoodsMap::References.new(@repository, unit),
                                   marginalia: WoodsMap::Marginalia.new(unit, lifecycle: lifecycle, table: @page.table),
                                   unit_path: lambda { |identifier, type|
                                     woods_map.unit_path(type: type, identifier: identifier)
                                   })
    end

    def lifecycle_for(unit)
      WoodsMap::Lifecycle.new(unit, concern_methods: concern_methods(unit))
    end

    # The ladder's event: ?event= when valid, else the one the action implies, else the first chain.
    def ladder_event(ladder)
      return nil unless ladder

      requested = params[:event] if WoodsMap::Lifecycle::EVENTS.include?(params[:event])
      requested || @passage.ladder_event || ladder.chains.keys.first || 'create'
    end

    # concern name => the instance methods that concern defines, for the
    # concerns the unit inlines.
    def concern_methods(unit)
      Array(unit.dig('metadata', 'inlined_concerns')).to_h do |name|
        concern = @repository.unit(name, type: 'concern')
        [name, Array(concern&.dig('metadata', 'instance_methods')).map(&:to_s)]
      end
    end
  end
end
