# frozen_string_literal: true

module WoodsMap
  # The whole database by chunk (B6-ERD): one chunk drawn at a time, under
  # the ER table budget (R-4), with the database's findings. The route takes
  # a chunk number; `by` and `columns` are closed choices.
  class ErdController < ApplicationController
    def show
      with_repository do |repository|
        next render_chunk_mermaid(repository) if mermaid_request?

        @freshness = repository.freshness
        @tree = WoodsMap::FileTree.for(repository)
        @nav = primary_nav('ERD')
        choose_views
        @erd = WoodsMap::Erd.for(repository)
        @chunk = @erd.chunk(@by, params.fetch(:chunk, 1).to_i)
        next render(:show) if @chunk || @erd.tables.empty?

        render :missing, status: :not_found
      end
    end

    private

    # One chunk's erDiagram text (D-25): `/woods/erd.mmd?chunk=N`, with the same closed choices.
    def render_chunk_mermaid(repository)
      choose_views
      erd = WoodsMap::Erd.for(repository)
      number = params.fetch(:chunk, 1).to_s
      chunk = erd.chunk(@by, number.match?(/\A[1-9][0-9]{0,5}\z/) ? number.to_i : 0)
      return render_text(:not_found, "No chunk #{number} by #{@by}; there are #{erd.chunks(@by).size}.") unless chunk

      render_mermaid(erd.mermaid(chunk, columns: @columns), name: "erd #{chunk.number} #{chunk.label}")
    end

    # The closed choices: an unknown value is the default, never an error.
    def choose_views
      @by = WoodsMap::Erd::GROUPINGS.include?(params[:by]) ? params[:by] : WoodsMap::Erd::GROUPINGS.first
      @columns = WoodsMap::Erd::COLUMN_MODES.include?(params[:columns]) ? params[:columns] : 'keys'
    end
  end
end
