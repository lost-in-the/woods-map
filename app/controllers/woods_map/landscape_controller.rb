# frozen_string_literal: true

module WoodsMap
  # The Landscape (B8-Landscape, B6-Overview; B-21): the system at C4 level 2
  # from container attribution (W-9), its hotspots from graph_analysis.json and
  # its domain clusters (woods#799), all from one pinned generation. The
  # container diagram is also served as Mermaid, Structurizr DSL and LikeC4
  # text, for agents and architecture tools (D-25).
  class LandscapeController < ApplicationController
    TABS = %w[containers components hotspots domains].freeze

    prepend_before_action :text_response, only: %i[export diagram]

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

    # Plain Mermaid text of the Components flowchart (by `group`), the
    # hotspots quadrant or the forward-flow sankey (D-25): 200 with the text,
    # 422 when the generation lacks what that diagram is drawn from.
    def diagram
      with_repository do |repository|
        response.headers['X-Woods-Generation'] = repository.generation_number.to_s
        name = params[:diagram].to_s
        text, missing = diagram_text(repository, name)
        next render_text(:unprocessable_entity, missing) unless text

        response.headers['Content-Disposition'] = %(inline; filename="#{diagram_filename(name)}")
        render plain: "#{text}\n", content_type: 'text/plain'
      end
    end

    private

    def diagram_text(repository, name)
      case name
      when 'components'
        components = WoodsMap::Components.new(repository, group: params[:group])
        components.limit ? [nil, limit_message(components.limit)] : [components.mermaid]
      when 'quadrant'
        [WoodsMap::Hotspots.new(repository).quadrant_mermaid,
         'This generation carries no commit counts to weigh churn.']
      else
        [WoodsMap::Hotspots.new(repository).sankey_mermaid, 'No edge runs forward between the layers.']
      end
    end

    def diagram_filename(name)
      group = params[:group].to_s if name == 'components' && WoodsMap::Components::GROUPS.key?(params[:group].to_s)
      "#{['landscape', name, group].compact.join('-')}.mmd"
    end

    def limit_message(limit)
      if limit == :no_packages
        'This generation publishes no Packwerk packages; group by namespace or cluster.'
      else
        'This generation publishes no domain clusters (woods#799).'
      end
    end

    def load_frame(repository)
      @freshness = repository.freshness
      @tree = WoodsMap::FileTree.for(repository)
      @nav = primary_nav(:landscape)
      @landscape = landscape_for(repository)
      @export = WoodsMap::LandscapeExport.new(@landscape, generation: repository.generation_number)
      @hotspots = WoodsMap::Hotspots.new(repository)
      @clusters = Array(repository.graph_analysis['domain_clusters'])
      @components = WoodsMap::Components.new(repository, group: params[:group])
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
      return super unless %w[export diagram].include?(action_name)

      render_text(:service_unavailable, 'No published Woods index.')
    end

    def refuse(reason)
      return super unless %w[export diagram].include?(action_name)

      render_text(:forbidden, "Woods Map refused the request (#{reason}).")
    end
  end
end
