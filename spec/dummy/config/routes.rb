# frozen_string_literal: true

Rails.application.routes.draw do
  mount WoodsMap::Engine => '/woods'
  mount WoodsMap::Engine => '/catalog/map', as: :catalog_map
  # A host page outside the mount: the engine's policy must not reach it.
  get '/host/page', to: ->(_env) { [200, { 'content-type' => 'text/html' }, ['host page']] }
end
