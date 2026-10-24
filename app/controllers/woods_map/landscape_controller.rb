# frozen_string_literal: true

module WoodsMap
  # The Landscape (B8-Landscape, B6-Overview; B-21): the system at C4 level 2
  # from container attribution (W-9), its hotspots from graph_analysis.json and
  # its domain clusters (woods#799), all from one pinned generation. The
  # container diagram is also served as Mermaid, Structurizr DSL and LikeC4
  # text, for agents and architecture tools (D-25).
  class LandscapeController < ApplicationController
    TABS = %w[containers hotspots domains].freeze

    prepend_before_action :text_response, only: :export

    def show
      with_repository do |repository|
        load_frame(repository)
        @tab = TABS.include?(params[:tab]) ? params[:tab] : 'containers'
        render @tab
      end
    end

    # Plain text of the container diagram: 200 with the text, 422 when the
    # generation has no container attribution to draw from.
    def export
      format = params[:export].to_s
      with_repository do |repository|
        landscape = landscape_for(repository)
        response.headers['X-Woods-Generation'] = repository.generation_number.to_s
        next render_text(:unprocessable_entity, needs_attribution) unless landscape.attributed?

        exporter = WoodsMap::LandscapeExport.new(landscape, generation: repository.generation_number)
        response.headers['Content-Disposition'] = %(inline; filename="#{exporter.filename(format)}")
        render plain: "#{exporter.text_for(format)}\n", content_type: 'text/plain'
      end
    end

    private

    def load_frame(repository)
      @freshness = repository.freshness
      @tree = WoodsMap::FileTree.for(repository)
      @nav = primary_nav(:landscape)
      @landscape = landscape_for(repository)
      @export = WoodsMap::LandscapeExport.new(@landscape, generation: repository.generation_number)
      @hotspots = WoodsMap::Hotspots.new(repository)
      @clusters = Array(repository.graph_analysis['domain_clusters'])
    end

    def landscape_for(repository)
      WoodsMap::Landscape.new(repository, system_name: woods_map_config.system_name)
    end

    def needs_attribution
      'This generation has no container attribution (Woods W-9, metadata.container); ' \
        'extract again with a Woods that publishes it.'
    end

    def text_response
      request.format = :text
      response.headers['Cache-Control'] = 'no-store'
    end

    def render_text(status, message)
      render plain: "#{message}\n", status: status, content_type: 'text/plain'
    end

    def render_unavailable(error)
      return super unless action_name == 'export'

      render_text(:service_unavailable, 'No published Woods index.')
    end

    def refuse(reason)
      return super unless action_name == 'export'

      render_text(:forbidden, "Woods Map refused the request (#{reason}).")
    end
  end
end
