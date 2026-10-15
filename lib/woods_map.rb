# frozen_string_literal: true

require 'woods_map/version'
require 'woods_map/configuration'
require 'woods_map/importmap'
require 'woods_map/repository'
require 'woods_map/engine' if defined?(Rails::Engine)

# Woods Map mounts a code-comprehension explorer over a published Woods index.
#
# The gem is a Rails Engine and nothing else: mount it, point it at the index
# directory `woods:extract` publishes, and open the mount path. Every read goes
# through {Woods::PublishedIndex} pinned to one generation per request.
#
# @example Host configuration
#   WoodsMap.configure do |config|
#     config.index_dir = Rails.root.join('tmp/woods')
#     config.token = ENV['WOODS_MAP_TOKEN']
#     config.authorize = ->(request) { request.env['warden']&.user&.admin? }
#   end
module WoodsMap
  class << self
    # @return [WoodsMap::Configuration] the current configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # Yield the configuration for mutation.
    #
    # @yieldparam config [WoodsMap::Configuration]
    # @return [WoodsMap::Configuration]
    def configure
      yield configuration if block_given?
      configuration
    end

    # Replace the configuration with defaults. Specs use this between examples.
    #
    # @return [WoodsMap::Configuration]
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
