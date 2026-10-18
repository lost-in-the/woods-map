# frozen_string_literal: true

module WoodsMap
  # Serves the engine's own files (JavaScript, the token sheet, fonts) under a
  # content-hash prefix.
  #
  # The files are the gem's own, so no authentication applies; nothing here
  # reads the index. A digest that does not match the file on disk is a 404,
  # which is what makes the cache immutable across gem upgrades.
  class AssetsController < ApplicationController
    skip_before_action :authorize_host!, :exchange_query_token!, :authenticate!
    skip_forgery_protection

    def show
      file = WoodsMap::Assets.resolve(params[:path].to_s)
      return head :not_found unless file && params[:digest] == WoodsMap::Assets.digest

      response.headers['Cache-Control'] = 'public, max-age=31536000, immutable'
      send_file file.to_s, type: WoodsMap::Assets.content_type(file), disposition: 'inline'
    end
  end
end
