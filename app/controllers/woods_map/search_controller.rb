# frozen_string_literal: true

module WoodsMap
  # Search over the pinned generation (B8-Search): the results page in name,
  # code or path mode, and the palette's grouped hits as JSON.
  class SearchController < ApplicationController
    woods_map_rate_limit :search, only: %i[show palette]
    def show
      with_repository do |repository|
        @repository = repository
        @tree = WoodsMap::FileTree.for(repository)
        @freshness = repository.freshness
        @results = WoodsMap::SearchResults.new(repository, params[:q], mode: params[:in].to_s,
                                                                       types: Array(params[:types]).presence)
        @nav = primary_nav
        render :show
      end
    end

    def palette
      with_repository do |repository|
        hits = WoodsMap::Palette.new(repository, params[:q]).to_h
        hits['groups'].each do |group|
          group['items'].each { |item| item['href'] = palette_href(item) }
        end
        render json: hits
      end
    rescue WoodsMap::Repository::Unavailable
      render json: { 'query' => params[:q].to_s, 'groups' => [], 'complete' => false, 'error' => 'no index' },
             status: :service_unavailable
    end

    private

    def palette_href(item)
      return woods_map.file_path(path: item['file_path']) if item['type'] == 'file'
      return unless item['type'].present? && item['identifier'].present?

      woods_map.unit_path(type: item['type'], identifier: item['identifier'])
    end
  end
end
