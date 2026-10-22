# frozen_string_literal: true

Rails.application.routes.draw do
  mount WoodsMap::Engine => '/woods'
  mount WoodsMap::Engine => '/catalog/map', as: :catalog_map
end
