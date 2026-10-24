# frozen_string_literal: true

require 'woods_map/version'
require 'woods_map/rate_limiter'
require 'woods_map/configuration'
require 'woods_map/content_security_policy'
require 'woods_map/assets'
require 'woods_map/glyphs'
require 'woods_map/importmap'
require 'woods_map/repository'
require 'woods_map/highlighter'
require 'woods_map/composite_source'
require 'woods_map/lifecycle_chart'
require 'woods_map/lifecycle'
require 'woods_map/state_machine_view'
require 'woods_map/marginalia'
require 'woods_map/references'
require 'woods_map/code_view'
require 'woods_map/hover_card'
require 'woods_map/unit_facts'
require 'woods_map/unit_page'
require 'woods_map/outline'
require 'woods_map/mermaid_export'
require 'woods_map/schema_view'
require 'woods_map/erd'
require 'woods_map/erd_chunks'
require 'woods_map/erd_diagram'
require 'woods_map/erd_findings'
require 'woods_map/neighbourhood'
require 'woods_map/neighbourhood_query'
require 'woods_map/graph_elements'
require 'woods_map/neighbourhood_response'
require 'woods_map/history_view'
require 'woods_map/action_facts'
require 'woods_map/passage_templates'
require 'woods_map/passage'
require 'woods_map/permitted_attributes'
require 'woods_map/routes_view'
require 'woods_map/blast_radius'
require 'woods_map/landscape'
require 'woods_map/container_relationships'
require 'woods_map/landscape_export'
require 'woods_map/hotspots'
require 'woods_map/impact_review'
require 'woods_map/impact_range'
require 'woods_map/unassigned_ivar_rule'
require 'woods_map/file_tree'
require 'woods_map/search_results'
require 'woods_map/palette'
require 'woods_map/guide'
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
