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

    # Logged once, after every host initializer has run, so a token set in
    # config/initializers/woods_map.rb is seen: a loopback-only mount boots
    # with a warning rather than silently (D-4, M8).
    config.after_initialize do
      message = WoodsMap.configuration.boot_warning
      Rails.logger&.warn("[woods-map] #{message}") if message
    end
  end
end
