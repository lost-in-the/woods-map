# frozen_string_literal: true

module WoodsMap
  # Search over the pinned generation (B8-Search): the results page in name,
  # code or path mode, and the palette's grouped hits as JSON.
  class SearchController < ApplicationController
    def show
      with_repository do |repository|
        @repository = repository
        @tree = WoodsMap::FileTree.for(repository)
        @freshness = repository.freshness
        @results = WoodsMap::SearchResults.new(repository, params[:q], mode: params[:in].to_s,
                                                                       types: Array(params[:types]).presence)
        @nav = [['Units', woods_map.search_path, true]]
        render :show
      end
    end

    def palette
      hits = with_repository { |repository| WoodsMap::Palette.new(repository, params[:q]).to_h }
      render json: hits
    rescue WoodsMap::Repository::Unavailable
      render json: { 'query' => params[:q].to_s, 'groups' => [], 'complete' => false, 'error' => 'no index' },
             status: :service_unavailable
    end
  end
end
