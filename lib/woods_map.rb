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
require 'woods_map/dynamic_view'
require 'woods_map/state_machine_view'
require 'woods_map/marginalia'
require 'woods_map/span_validation'
require 'woods_map/references'
require 'woods_map/method_line'
require 'woods_map/callers'
require 'woods_map/code_view'
require 'woods_map/hover_card'
require 'woods_map/unit_facts'
require 'woods_map/unit_page'
require 'woods_map/outline'
require 'woods_map/mermaid_export'
require 'woods_map/schema_view'
require 'woods_map/schema_class_diagram'
require 'woods_map/erd'
require 'woods_map/erd_chunks'
require 'woods_map/erd_diagram'
require 'woods_map/erd_findings'
require 'woods_map/neighbourhood'
require 'woods_map/neighbourhood_query'
require 'woods_map/graph_elements'
require 'woods_map/neighbourhood_response'
require 'woods_map/graph_flow'
require 'woods_map/graph_timeline'
require 'woods_map/unit_paths'
require 'woods_map/commit_ledger'
require 'woods_map/commit_strip'
require 'woods_map/generation_strip'
require 'woods_map/path_heat'
require 'woods_map/history_mermaid'
require 'woods_map/commit_rows'
require 'woods_map/unit_co_changes'
require 'woods_map/date_span'
require 'woods_map/history_generations'
require 'woods_map/history_view'
require 'woods_map/history_timeline'
require 'woods_map/action_facts'
require 'woods_map/passage_templates'
require 'woods_map/passage_filter'
require 'woods_map/passage'
require 'woods_map/trail_board'
require 'woods_map/lifecycle_reach'
require 'woods_map/lifecycle_stitching'
require 'woods_map/trail_lanes'
require 'woods_map/lifecycle_builder'
require 'woods_map/entry_lifecycle'
require 'woods_map/trail_flags'
require 'woods_map/pinned_views'
require 'woods_map/trail_co_changes'
require 'woods_map/permitted_attributes'
require 'woods_map/partial_locals'
require 'woods_map/routes_view'
require 'woods_map/blast_radius'
require 'woods_map/landscape'
require 'woods_map/landscape_services'
require 'woods_map/landscape_status'
require 'woods_map/landscape_context'
require 'woods_map/container_relationships'
require 'woods_map/landscape_export'
require 'woods_map/code_sizes'
require 'woods_map/hotspots'
require 'woods_map/components'
require 'woods_map/domain_mindmap'
require 'woods_map/impact_review'
require 'woods_map/impact_range'
require 'woods_map/unit_diff'
require 'woods_map/source_diff'
require 'woods_map/generation_facets'
require 'woods_map/range_report'
require 'woods_map/impact_flows'
require 'woods_map/since'
require 'woods_map/unassigned_ivar_rule'
require 'woods_map/list_page'
require 'woods_map/units_index'
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
