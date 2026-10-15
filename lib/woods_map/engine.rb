# frozen_string_literal: true

require 'rails/engine'

module WoodsMap
  # The engine. Mount it explicitly; it injects nothing into the host:
  #
  #   mount WoodsMap::Engine => "/woods" if Rails.env.development?
  #
  # Views, controllers and the assets route are namespaced under WoodsMap.
  class Engine < ::Rails::Engine
    isolate_namespace WoodsMap

    config.woods_map = ActiveSupport::OrderedOptions.new

    initializer 'woods_map.configuration' do
      # Nothing is read at boot: the host may configure WoodsMap in an
      # initializer that runs after this one. Every setting is resolved at
      # request time through WoodsMap.configuration.
    end
  end
end
