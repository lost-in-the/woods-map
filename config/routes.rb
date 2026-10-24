# frozen_string_literal: true

WoodsMap::Engine.routes.draw do
  root to: 'status#show'

  resource :session, only: %i[new create destroy]

  # The component boards rendered from the engine's own partials (woods-map#23).
  get 'guidelines', to: 'guidelines#show', as: :guidelines

  # Search (M1): the results page and the palette's hits.
  get 'search', to: 'search#show', as: :search
  get 'search/palette', to: 'search#palette', as: :palette, defaults: { format: :json }
  # The Landscape (B8-Landscape, B6-Overview): C4 containers, components, hotspots and domains
  # of one generation; every diagram is also plain text for agents and other tools (D-25).
  get 'landscape.mmd', to: 'landscape#export', as: :landscape_mmd, defaults: { export: 'mermaid' }, format: false
  get 'landscape.dsl', to: 'landscape#export', as: :landscape_dsl, defaults: { export: 'structurizr' }, format: false
  get 'landscape.c4', to: 'landscape#export', as: :landscape_c4, defaults: { export: 'likec4' }, format: false
  get 'landscape/:diagram.mmd', to: 'landscape#diagram', as: :landscape_diagram_mmd,
                                constraints: { diagram: /context|components|quadrant|sankey|treemap|mindmap/ },
                                format: false
  get 'landscape(/:tab)', to: 'landscape#show', as: :landscape,
                          constraints: { tab: /context|containers|components|hotspots|domains|status/ }, format: false

  # The full-screen graph (M5): a centre by identifier and type, never a path.
  get 'graph', to: 'graphs#show', as: :graph
  get 'graph/neighbourhood', to: 'neighbourhoods#show', as: :neighbourhood, defaults: { format: :json }

  # The guide (M7): ask, stream an answer as server-sent events, stop it, start over, reopen an earlier one.
  post 'guide/questions', to: 'guide#create', as: :guide_questions, defaults: { format: :json }
  get 'guide/questions/:id/stream', to: 'guide_streams#show', as: :guide_stream, constraints: { id: /[0-9a-f]{16}/ }
  post 'guide/questions/:id/cancel', to: 'guide#cancel', as: :guide_cancel, constraints: { id: /[0-9a-f]{16}/ },
                                     defaults: { format: :json }
  delete 'guide/conversation', to: 'guide#destroy', as: :guide_conversation, defaults: { format: :json }
  # The session's conversations (history) and opening an earlier one.
  get 'guide/conversations', to: 'guide#history', as: :guide_history, defaults: { format: :json }
  post 'guide/conversations/:id', to: 'guide#resume', as: :guide_resume, constraints: { id: /[0-9a-f]{16}/ },
                                  defaults: { format: :json }

  # The impact page (M4b): a focus set with no range is the blast radius; a range delegates to Woods' report (W-12).
  # The Mermaid text of a page's diagram as text/plain (D-25); see docs/design/notes/mermaid-text-urls.md.
  get 'impact.mmd', to: 'impact#show', as: :impact_mmd, defaults: { mmd: '1' }, format: false
  get 'impact', to: 'impact#show', as: :impact
  # A saved report (E-6): the SHA-256 ID woods:impact printed, read through Woods' store.
  get 'impacts/:id', to: 'impact#saved', as: :saved_impact, constraints: { id: /[0-9a-f]{64}/ }, format: false

  # The whole database by chunk (M3, B6-ERD): a chunk number, never a table name or path.
  get 'erd.mmd', to: 'erd#show', as: :erd_mmd, defaults: { mmd: '1' }, format: false
  get 'erd(/:chunk)', to: 'erd#show', as: :erd, constraints: { chunk: /[1-9][0-9]{0,5}/ }, format: false

  # The cross-unit timeline (M4): typed identifiers in the query, never a path.
  get 'history.mmd', to: 'history#show', as: :history_mmd, defaults: { mmd: '1' }, format: false
  get 'history', to: 'history#show', as: :history

  # The Trail (M6, notes/trail.md): the board is its query; `.mmd` is its Mermaid (D-25).
  get 'trail.mmd', to: 'trails#show', as: :trail_mmd, defaults: { mmd: '1' }, format: false
  get 'trail/graph', to: 'trails#graph', as: :trail_graph, defaults: { format: :json }
  get 'trail', to: 'trails#show', as: :trail, format: false

  get 'units', to: 'units#index', as: :units
  # File paths are exact admitted file_map keys, never host filesystem paths.
  get 'files', to: 'files#show', format: false
  get 'files/*path', to: 'files#show', as: :file, format: false

  # Unit pages (M1): one route per tab, taking a unit type and an identifier
  # from the pinned generation; never a file path.
  scope 'units/:type', constraints: { type: /[a-z0-9_]+/ }, format: false do
    # The tabs' Mermaid text (D-25), ahead of the glob routes that would take `.mmd` as part of an identifier.
    %w[schema passage lifecycle graph history].each do |tab|
      get "*identifier/#{tab}.mmd", to: "units##{tab}", as: :"unit_#{tab}_mmd", defaults: { mmd: '1' }
    end
    get '*identifier/schema', to: 'units#schema', as: :unit_schema
    get '*identifier/routes', to: 'units#routes', as: :unit_routes
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
