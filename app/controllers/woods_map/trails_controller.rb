# frozen_string_literal: true

module WoodsMap
  # The Trail (M6, notes/trail.md): a lifecycle across async hops from one
  # entry, with derived flags, a pinboard, the pinned units' graph and ERD
  # and their co-changes. The whole board is its URL (C-3): an entry, typed
  # pins, a generation and a hop budget, nothing else.
  class TrailsController < ApplicationController
    woods_map_rate_limit :graph, only: :graph

    CHOOSER_SHOWN = 24

    def show
      @board = WoodsMap::TrailBoard.from_params(params)
      with_board_repository do |repository|
        next render_trail_mermaid(repository) if mermaid_request?

        load_frame(repository)
        next render(:chooser) if @board.entry.nil? && @board.pins.empty?
        next render(:chooser, status: :not_found) if @board.entry && !repository.graph_node(@board.entry_unit)

        build_board(repository)
        render :show
      end
    end

    # "Graph of pinned" in the neighbourhood JSON shape the graph controller draws.
    def graph
      request.format = :json
      response.headers['Cache-Control'] = 'no-store'
      @board = WoodsMap::TrailBoard.from_params(params)
      with_board_repository do |repository|
        render json: WoodsMap::PinnedViews.new(repository, @board.pins).graph_json
      end
    end

    private

    # The board's generation when it is retained, else the published one;
    # {#generation_note} says which (C-3).
    def with_board_repository(&block)
      with_repository do |repository|
        wanted = @board.gen
        next block.call(repository) if wanted.nil? || wanted == repository.generation_number

        @published_generation = repository.generation_number
        next note_unretained(repository, wanted, &block) unless repository.generations.include?(wanted)

        repository.with_generation(wanted) do |pinned|
          @repository = pinned
          @generation = pinned.generation_facts
          block.call(pinned)
        end
      end
    end

    def note_unretained(repository, wanted)
      @unretained_generation = wanted
      yield repository
    end

    def load_frame(repository)
      @freshness = repository.freshness
      @files_sheet = true
      @nav = primary_nav('Trail')
    end

    def build_board(repository)
      @lifecycle = @board.entry && WoodsMap::LifecycleBuilder.new(repository, @board.entry, hops: @board.hops)
      @pinned = WoodsMap::PinnedViews.new(repository, @board.pins)
      @flags = WoodsMap::TrailFlags.new(repository, @lifecycle&.steps || [], pins: @pinned.identities)
      @co_changes = WoodsMap::TrailCoChanges.new(repository, @pinned.identities)
    end

    # `/woods/trail.mmd`: the lanes, or with `view=graph` / `view=erd` the pinned views (D-25).
    def render_trail_mermaid(repository)
      pinned = WoodsMap::PinnedViews.new(repository, @board.pins)
      case params[:view]
      when 'graph' then render_pinned_graph_mermaid(pinned)
      when 'erd' then render_pinned_erd_mermaid(pinned)
      else render_lanes_mermaid(repository)
      end
    end

    def render_pinned_graph_mermaid(pinned)
      return render_text(:not_found, 'The board has no pinned unit in this generation.') if pinned.identities.empty?

      render_mermaid(pinned.graph_mermaid, name: 'trail pinned graph', refusal: pinned.graph_refusal)
    end

    def render_pinned_erd_mermaid(pinned)
      text = pinned.erd_mermaid
      return render_text(:not_found, 'No pinned model or table maps a published table.') unless text

      render_mermaid(text, name: 'trail pinned erd', refusal: pinned.erd_refusal)
    end

    def render_lanes_mermaid(repository)
      unless @board.entry
        return render_text(:bad_request,
                           'Name an entry: /woods/trail.mmd?entry=NotifySubscribersJob%23perform')
      end
      unless repository.graph_node(@board.entry_unit)
        return render_text(:not_found,
                           "No unit #{@board.entry_unit} in this generation.")
      end

      lifecycle = WoodsMap::LifecycleBuilder.new(repository, @board.entry, hops: @board.hops)
      render_mermaid(lifecycle.mermaid, name: "trail #{lifecycle.entry}", refusal: lifecycle.refusal,
                                        page: woods_map.trail_path(@board.to_query))
    end

    # Starting points the chooser offers: jobs, mailer actions and model create events.
    helper_method def chooser_entries
      { 'jobs' => chooser_jobs.map { |id| "#{id}#perform" }, 'mailer actions' => chooser_mailer_actions,
        'model events' => chooser_models.map { |id| "#{id}@create" } }
    end

    def chooser_jobs
      @repository.units(type: 'job').pluck('identifier').reject { |id| id.end_with?('ApplicationJob') }
                 .sort.first(CHOOSER_SHOWN)
    end

    def chooser_mailer_actions
      @repository.units(type: 'mailer').flat_map do |entry|
        actions = Array(@repository.unit(entry['identifier'], type: 'mailer')&.dig('metadata', 'actions'))
        actions.map { |action| "#{entry['identifier']}##{action}" }
      end.sort.first(CHOOSER_SHOWN)
    end

    def chooser_models
      @repository.units(type: 'model').pluck('identifier')
                 .reject { |id| id.include?('::') && id.start_with?('Active', 'Action') }.sort.first(CHOOSER_SHOWN)
    end
  end
end
