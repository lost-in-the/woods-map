# frozen_string_literal: true

WoodsMap::Engine.routes.draw do
  root to: 'status#show'

  resource :session, only: %i[new create destroy]

  # Engine-served files: /assets/<digest>/<logical path>. The digest is the
  # file's content hash, so responses are cached as immutable. Named
  # engine_asset so it never shadows Action View's asset_path in views.
  get 'assets/:digest/*path', to: 'assets#show', as: :engine_asset, format: false
end
