# frozen_string_literal: true

module WoodsMap
  # The impact page (M4b). With a focus set and no range it is the pre-change
  # mode (E-9): the blast radius from the graph of one generation, with the
  # tabs of the report boards over what that generation proves. With a range
  # it delegates retained-generation evidence to Woods::Impact::Report (W-12)
  # and renders that report's tabs; a saved report (E-6) renders the same tabs
  # from the bytes woods:impact stored.
  class ImpactController < ApplicationController
    woods_map_rate_limit :impact
    LENSES = %w[changed risks flows tests graph unknown].freeze

    def show
      with_repository do |repository|
        next render_impact_mermaid(repository) if mermaid_request?

        load_frame(repository)
        next render_range if range_request?

        @radius = radius_from_params(repository)
        @review = WoodsMap::ImpactReview.new(repository, @radius)
        @graph = pre_change_graph(repository) if @lens == 'graph' && !@radius.empty?
        @flows = pre_change_flows(repository) unless @radius.empty?
        render(@radius.empty? ? :pick : :show)
      end
    end

    # A saved report by its ID (E-6): immutable, addressable, independent of
    # which payloads the index still retains.
    def saved
      with_repository do |repository|
        load_frame(repository)
        @saved_id = params[:id]
        @report = WoodsMap::ImpactRange.saved(woods_map_config.index_path, @saved_id)
        render_report(repository)
      end
    end

    private

    def load_frame(repository)
      @repository = repository
      @freshness = repository.freshness
      @tree = WoodsMap::FileTree.for(repository)
      @nav = primary_nav(:impact)
      @lens = LENSES.include?(params[:lens]) ? params[:lens] : 'changed'
    end

    # The Graph tab in pre-change mode: the first focus unit's neighbourhood,
    # tinted by the blast radius (E-3).
    def pre_change_graph(repository)
      identifier = @radius.focus.find { |id| repository.graph_node(id) }
      return nil unless identifier

      graph_for(repository, { 'identifier' => identifier, 'type' => @radius.type_of(identifier) },
                depth: [@radius.depth, 2].min)
    end

    # The Flows tab in pre-change mode (E-4): entry points through the focus
    # units from Woods' inverted flow membership (W-13); reached units keep
    # their distance on the steps.
    def pre_change_flows(repository)
      roots = @radius.focus.map { |id| [id, @radius.type_of(id)] }
      marks = @radius.reached.to_h { |a| [[a.identifier, a.type], a.distance] }
      WoodsMap::ImpactFlows.for_focus(repository, roots: roots, marks: marks)
    end

    def graph_for(repository, centre, depth: params.fetch(:depth, 1))
      @graph_centre = centre
      filters = { types: params[:types], via: params[:via] }
      WoodsMap::Neighbourhood.new(repository, centre['identifier'], type: centre['type'],
                                                                    direction: params[:direction].to_s,
                                                                    depth: depth, filters: filters)
    end

    # The blast radius's paths as Mermaid text (D-25). A range has no diagram
    # here: Woods' report is the range's export (D-1).
    def render_impact_mermaid(repository)
      return render_text(:not_found, 'A range has no Mermaid text here; Woods publishes its report.') if range_request?

      radius = radius_from_params(repository)
      return render_text(:bad_request, 'Name the focus: /woods/impact.mmd?focus=<identifier>.') if radius.empty?

      render_mermaid(radius.mermaid, name: "impact #{radius.focus.join(' ')}")
    end

    def range_request?
      params[:mode] == 'range' || params[:from].present? || params[:to].present?
    end

    def radius_from_params(repository)
      WoodsMap::BlastRadius.new(repository, focus: params[:focus], depth: params.fetch(:depth, 2),
                                            filters: { types: params[:types], via: params[:via], show: params[:show] })
    end

    def render_range
      selectors = [params.fetch(:from, ''), params.fetch(:to, 'now')].map { |selector| generation_selector(selector) }
      selectors[1] = 'now' if selectors.last == ''
      @range = selectors.map { |selector| selector.is_a?(String) ? selector : '' }
      if selectors.first.present? || selectors.any? { |selector| !selector.is_a?(String) }
        @report = WoodsMap::ImpactRange.new(woods_map_config.index_path, from: selectors.first, to: selectors.last)
      end
      render_report(@repository)
    end

    # A bare generation number (`3`) names `gen:3`: a commit SHA has at least
    # seven characters, so one to six digits can mean nothing else. Anything
    # else goes to Woods as typed.
    #
    # @param selector [Object]
    # @return [Object]
    def generation_selector(selector)
      selector.is_a?(String) && selector.strip.match?(/\A[1-9][0-9]{0,5}\z/) ? "gen:#{selector.strip}" : selector
    end

    # The range tabs (Overview first) over an available report, or the
    # selectors with the reason there is none.
    def render_report(repository)
      @lens = WoodsMap::RangeReport::LENSES.include?(params[:lens]) ? params[:lens] : 'overview'
      if @report&.state == :available
        @range_report = WoodsMap::RangeReport.new(@report.data, repository: repository,
                                                                focus: params[:focus].to_s.split(','))
        centre = @range_report.graph_centre if @lens == 'graph'
        @graph = graph_for(repository, centre) if centre
        @flows = WoodsMap::ImpactFlows.for_report(repository, @range_report) if @lens == 'flows'
      end
      render :range, status: @saved_id && @report&.state == :missing ? :not_found : :ok
    end
  end
end
