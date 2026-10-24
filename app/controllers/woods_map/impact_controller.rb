# frozen_string_literal: true

module WoodsMap
  # The impact page (M4b). With a focus set and no range it is the pre-change
  # mode (E-9): the blast radius from the graph of one generation, with the
  # tabs of the report boards over what that generation proves. With a range
  # it delegates retained-generation evidence to Woods::Impact::Report (W-12).
  class ImpactController < ApplicationController
    woods_map_rate_limit :impact
    LENSES = %w[changed risks flows tests unknown].freeze

    def show
      with_repository do |repository|
        next render_impact_mermaid(repository) if mermaid_request?

        load_frame(repository)
        next render_range if range_request?

        @radius = radius_from_params(repository)
        @review = WoodsMap::ImpactReview.new(repository, @radius)
        render(@radius.empty? ? :pick : :show)
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
      selectors = [params.fetch(:from, ''), params.fetch(:to, 'now')]
      selectors[1] = 'now' if selectors.last == ''
      @range = selectors.map { |selector| selector.is_a?(String) ? selector : '' }
      if selectors.first.present? || selectors.any? { |selector| !selector.is_a?(String) }
        @report = WoodsMap::ImpactRange.new(woods_map_config.index_path, from: selectors.first, to: selectors.last)
      end
      render :range
    end
  end
end
