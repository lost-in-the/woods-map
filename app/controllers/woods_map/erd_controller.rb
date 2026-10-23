# frozen_string_literal: true

module WoodsMap
  # The whole database by chunk (B6-ERD): one chunk drawn at a time, under
  # the ER table budget (R-4), with the database's findings. The route takes
  # a chunk number; `by` and `columns` are closed choices.
  class ErdController < ApplicationController
    def show
      with_repository do |repository|
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

    # The closed choices: an unknown value is the default, never an error.
    def choose_views
      @by = WoodsMap::Erd::GROUPINGS.include?(params[:by]) ? params[:by] : WoodsMap::Erd::GROUPINGS.first
      @columns = WoodsMap::Erd::COLUMN_MODES.include?(params[:columns]) ? params[:columns] : 'keys'
    end
  end
end
