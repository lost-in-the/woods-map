# frozen_string_literal: true

WoodsMap::Engine.routes.draw do
  root to: 'status#show'

  resource :session, only: %i[new create destroy]

  # The component boards rendered from the engine's own partials (woods-map#23).
  get 'guidelines', to: 'guidelines#show', as: :guidelines

  # Search (M1): the results page and the palette's hits.
  get 'search', to: 'search#show', as: :search
  get 'search/palette', to: 'search#palette', as: :palette, defaults: { format: :json }

  # The impact page (M4b): a focus set with no range is the blast radius; a range needs woods:impact (W-12).
  get 'impact', to: 'impact#show', as: :impact

  # Unit pages (M1): one route per tab, taking a unit type and an identifier
  # from the pinned generation; never a file path.
  scope 'units/:type', constraints: { type: /[a-z0-9_]+/ }, format: false do
    get '*identifier/schema', to: 'units#schema', as: :unit_schema
    get '*identifier/passage', to: 'units#passage', as: :unit_passage
    get '*identifier/lifecycle', to: 'units#lifecycle', as: :unit_lifecycle
    get '*identifier/graph', to: 'units#graph', as: :unit_graph
    get '*identifier/history', to: 'units#history', as: :unit_history
    get '*identifier/peek', to: 'units#peek', as: :unit_peek
    get '*identifier', to: 'units#show', as: :unit
  end

  # Engine-served files: /assets/<digest>/<logical path>. The digest is the
  # file's content hash, so responses are cached as immutable. Named
  # engine_asset so it never shadows Action View's asset_path in views.
  get 'assets/:digest/*path', to: 'assets#show', as: :engine_asset, format: false
end
