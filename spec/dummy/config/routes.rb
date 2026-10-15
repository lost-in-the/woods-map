# frozen_string_literal: true

Rails.application.routes.draw do
  mount WoodsMap::Engine => '/woods'
end
