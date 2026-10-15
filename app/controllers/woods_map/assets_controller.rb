# frozen_string_literal: true

module WoodsMap
  # Serves the engine's vendored JavaScript under a content-hash prefix.
  #
  # The files are the gem's own, so no authentication applies; nothing here
  # reads the index. A digest that does not match the file on disk is a 404,
  # which is what makes the cache immutable across gem upgrades.
  class AssetsController < ApplicationController
    skip_before_action :authorize_host!, :authenticate!
    skip_forgery_protection

    CONTENT_TYPES = {
      '.js' => 'text/javascript; charset=utf-8',
      '.mjs' => 'text/javascript; charset=utf-8',
      '.css' => 'text/css; charset=utf-8',
      '.map' => 'application/json; charset=utf-8'
    }.freeze

    def show
      logical_path = params[:path].to_s
      file = WoodsMap::Importmap.resolve(logical_path)
      digest = file && WoodsMap::Importmap.digest(logical_path)
      return head :not_found unless file && digest == params[:digest]

      response.headers['Cache-Control'] = 'public, max-age=31536000, immutable'
      send_file file.to_s, type: CONTENT_TYPES.fetch(file.extname, 'application/octet-stream'),
                           disposition: 'inline'
    end
  end
end
