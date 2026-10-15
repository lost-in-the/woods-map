# frozen_string_literal: true

WoodsMap::Engine.routes.draw do
  root to: 'status#show'

  resource :session, only: %i[new create destroy]

  # Engine-served JavaScript: /assets/<digest>/<logical path>. The digest is
  # the file's content hash, so responses are cached as immutable.
  get 'assets/:digest/*path', to: 'assets#show', as: :asset, format: false
end
