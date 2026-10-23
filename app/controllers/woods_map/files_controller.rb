# frozen_string_literal: true

module WoodsMap
  # Indexed file ownership only: the route key never reaches host source IO.
  class FilesController < ApplicationController
    def show
      with_repository do |repository|
        @file_path = params[:path].to_s
        unless exact_route_path? && repository.permitted_file_path?(@file_path) && repository.file_map.key?(@file_path)
          next render(:missing, status: :not_found)
        end

        @owners = repository.file_owners(@file_path)
        @unresolved = repository.unresolved_file_identifiers(@file_path)
        @tree = WoodsMap::FileTree.for(repository)
        @freshness = repository.freshness
        render :show
      end
    end

    private

    # Rails routing collapses literal repeated/trailing slashes. Refuse those
    # spellings from the original request path before accepting decoded params;
    # encoded segments are validated as params, never decoded a second time.
    def exact_route_path?
      path = request.original_fullpath.split('?', 2).first
      path.exclude?('//') && !path.end_with?('/')
    end
  end
end
