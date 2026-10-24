# frozen_string_literal: true

module WoodsMap
  # `/woods/history` (M4, FR-7, A-6): the commits of a selected set of units
  # on one timeline from the generation's commit table, with the commits that
  # touched two of them drawn as pairs. Units come as typed identifiers in
  # `units[]`; with none, the page offers the window's most-changed units.
  class HistoryController < ApplicationController
    include AuthorFilter

    woods_map_rate_limit :history

    def show
      with_repository do |repository|
        @repository = repository
        @timeline = WoodsMap::HistoryTimeline.new(repository, selection, days: days, author: author_param,
                                                                         span: WoodsMap::DateSpan.parse(params[:span]))
        next render_timeline_mermaid if mermaid_request?

        @freshness = repository.freshness
        @files_sheet = true
        @nav = primary_nav(:history)
        render :show
      end
    end

    private

    def selection
      units = params[:units]
      if units.is_a?(Array)
        units.grep(String)
      else
        Array(units.is_a?(String) ? units.split(',') : nil)
      end
    end

    def days
      WoodsMap::HistoryView::RANGES.fetch(params[:range].to_s, WoodsMap::HistoryView::RANGES['365d'])
    end

    def render_timeline_mermaid
      if @timeline.empty?
        return render_text(:bad_request,
                           'Name the units: /woods/history.mmd?units[]=<type>:<identifier>.')
      end
      return render_text(:not_found, 'This generation has no commit table.') unless @timeline.table?

      render_mermaid(@timeline.mermaid, name: "history #{@timeline.lanes.map(&:identifier).join(' ')}")
    end
  end
end
