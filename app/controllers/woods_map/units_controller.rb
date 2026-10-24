# frozen_string_literal: true

module WoodsMap
  # A unit's pages: the Code tab (two lenses, D-6), Routes, Passage, Schema,
  # Lifecycle, Graph and History, and the peek fragment the code view opens inline. Every
  # action reads one pinned generation and renders inside it, so the payload
  # lock covers the whole response; the identifier and the type come from the
  # URL, never a path.
  class UnitsController < ApplicationController
    include WoodsMap::MethodLinks
    include WoodsMap::UnitMermaid
    include WoodsMap::RoutedIdentifier
    include WoodsMap::UnitHistory
    include WoodsMap::GraphOverlays
    include WoodsMap::UnitLifecycle

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
        @callers = WoodsMap::Callers.for(@repository).by_method(@unit['identifier'], @unit['type'])
        @code = code_view(@unit, lens, @lifecycle, callers: @callers)
        @heat = @repository.git_commits && WoodsMap::PathHeat.new(@repository.git_commits)
        @concern_paths = WoodsMap::UnitPaths.concern_files(@repository, @unit)
        @outline = WoodsMap::Outline.new(@unit, lifecycle: @lifecycle, concern_methods: concern_methods(@unit),
                                                method_href: method_href(@unit), callers: @callers)
        @cards = WoodsMap::HoverCard.for(@repository, @code.linked_targets)
        render :show
      end
    end

    def schema
      with_unit do
        @schema = WoodsMap::SchemaView.for(@repository, @unit, table: @page.table)
        next render_schema_mermaid if mermaid_request?

        render :schema
      end
    end

    # The data passage of one action (B8-Passage): the first action unless
    # ?action_name= picks one; a type without actions goes to its Code tab.
    def passage
      with_unit do
        unless @page.tabs.include?('passage')
          next render_text(:not_found, "A #{@page.type.tr('_', ' ')} has no passage.") if mermaid_request?

          next redirect_to(woods_map.unit_path(type: @page.type, identifier: @page.identifier))
        end

        @passage = WoodsMap::Passage.new(@repository, @unit, action: params[:action_name])
        @ladder_model = @passage.ladder_model
        @ladder = @ladder_model && lifecycle_for(@ladder_model)
        @ladder_event = ladder_event(@ladder)
        next render_passage_mermaid if mermaid_request?

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
      with_unit { WoodsMap::EntryLifecycle.applies?(@page.type) ? entry_lifecycle : model_lifecycle }
    end

    def graph
      with_unit do
        @neighbourhood = WoodsMap::Neighbourhood.new(
          @repository, @unit['identifier'],
          type: @unit['type'],
          direction: params[:direction].to_s, depth: params.fetch(:depth, 1),
          filters: { types: params[:types], via: params[:via] }
        )
        next render_graph_mermaid if mermaid_request?

        load_graph_overlays(@repository, @neighbourhood, @unit['identifier'], @unit['type'])
        render :graph
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
        type = params[:type].to_s
        @unit = routed_identifiers.lazy.map { |id| repository.unit(id, type: type) }.find(&:itself)
        next render_missing_unit unless @unit

        @page = WoodsMap::UnitPage.new(repository, @unit)
        @definition = WoodsMap::CompositeSource.new(@unit).definition_line
        unless mermaid_request?
          @tree = WoodsMap::FileTree.for(repository)
          @freshness = repository.freshness
        end
        yield
      end
    end

    def lens
      cookies[LENS_COOKIE].presence || 'written'
    end

    def redirect_to_remembered_lens
      cookies[LENS_COOKIE] = { value: params[:lens], expires: 1.year.from_now, same_site: :lax }
      redirect_to woods_map.unit_path(type: params[:type], identifier: routed_identifiers.first)
    end

    # A model's (or state machine's) Lifecycle tab: its callback chains.
    def model_lifecycle
      @lifecycle = lifecycle_for(@unit, dynamic: WoodsMap::DynamicView.new(@repository))
      @event = params[:event] if WoodsMap::Lifecycle::EVENTS.include?(params[:event])
      @event ||= @lifecycle.chains.keys.first || 'create'
      @view = @lifecycle.views.find { |view| view == params[:view] } || WoodsMap::Lifecycle::VIEWS.first
      @state_machines = @page.type == 'model' ? WoodsMap::StateMachineView.for_model(@repository, @page.identifier) : []
      return render_lifecycle_mermaid if mermaid_request?

      render :lifecycle
    end

    # A controller's, job's or mailer's Lifecycle tab: the flow of one entry
    # point (FR-6, woods-map#91).
    def entry_lifecycle
      @entry_lifecycle = WoodsMap::EntryLifecycle.new(@repository, @unit, action: params[:action_name])
      @view = WoodsMap::EntryLifecycle::VIEWS.find { |view| view == params[:view] } ||
              WoodsMap::EntryLifecycle::VIEWS.first
      return render_entry_lifecycle_mermaid if mermaid_request?

      @flags = WoodsMap::TrailFlags.new(@repository, @entry_lifecycle.steps)
      render :entry_lifecycle
    end

    # The ladder's event: ?event= when valid, else the one the action implies, else the first chain.
    def ladder_event(ladder)
      return nil unless ladder

      requested = params[:event] if WoodsMap::Lifecycle::EVENTS.include?(params[:event])
      requested || @passage.ladder_event || ladder.chains.keys.first || 'create'
    end
  end
end
