# frozen_string_literal: true

require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/module/delegation'
require 'woods/published_index'
require 'woods/mcp/index_reader'
require 'woods/source_inputs/status'
require_relative 'repository_history'
require_relative 'repository_flows'
require_relative 'repository_assembled_flows'
require_relative 'retention'

module WoodsMap
  # One pinned generation per request.
  #
  # Wraps {Woods::PublishedIndex} so controllers never touch payload paths. The
  # block form holds the shared manifest lock for the duration of the request's
  # reads and releases it on the way out, which is what keeps retention from
  # deleting a payload mid-render. Every read below goes through the index
  # reader of that one generation; nothing is resolved from a path.
  class Repository
    include RepositoryHistory
    include RepositoryFlows
    include RepositoryAssembledFlows

    # Raised when no published generation can be opened at the configured root.
    class Unavailable < StandardError; end

    # Open the configured index for one block.
    #
    # @param index_dir [Pathname, String] defaults to the configured root
    # @yieldparam repository [WoodsMap::Repository]
    # @return [Object] the block's value
    # @raise [Unavailable] when the index is missing or unreadable
    def self.open(index_dir = WoodsMap.configuration.index_path)
      Woods::PublishedIndex.open(index_dir) { |index| yield new(index) }
    rescue ArgumentError, Woods::PublishedIndex::CorruptPointerError, Errno::ENOENT => e
      raise Unavailable, "No published Woods index at #{index_dir}: #{e.message}"
    end

    # @param index [Woods::PublishedIndex]
    def initialize(index)
      @index = index
      # The queries the published-index API does not expose (search, the raw
      # graph, freshness) come from a reader pinned to the same payload.
      @reader = Woods::MCP::IndexReader.new(index.payload_dir.to_s, auto_refresh: false)
      @units = {}
    end

    # @!method generation_number
    #   @return [Integer] the pinned generation number (0 for a flat index)
    # @!method manifest
    #   @return [Hash] the pinned manifest
    delegate :generation_number, :manifest, to: :@index

    # Facts the manifest records at the top level on current writers and under
    # `provenance` on some older ones.
    PROVENANCE_KEYS = %w[git_branch git_sha rails_version ruby_version woods_version].freeze

    # Published generation numbers under the index root, ascending. A flat
    # (pre-2.0) index reports `[0]`.
    #
    # @return [Array<Integer>]
    def generations
      numbers = Woods::PublishedIndex.available_generations(@index.index_dir)
      numbers.empty? ? [generation_number] : numbers
    end

    # @return [Array] cache identity of this index and its pinned generation
    def generation_key
      [@index.index_dir.expand_path.to_s, @index.payload_dir.expand_path.to_s, generation_number,
       manifest['extracted_at'], manifest['total_units']]
    end

    # What the bar shows on every page: the generation and the HEAD it was
    # extracted at.
    #
    # @return [Hash{String => Object}]
    def generation_facts
      { 'generation' => generation_number, 'extracted_at' => manifest['extracted_at'] }.merge(provenance_facts)
    end

    # Status facts for the home page and the status bar.
    #
    # @return [Hash{String => Object}]
    def status
      generation_facts.merge(manifest_facts).merge('generations' => generations)
    end

    # @param type [String, nil]
    # @return [Array<Hash>] unit index entries
    def units(type: nil)
      @index.units(type: type)
    end

    # One unit, read once per request.
    #
    # @param identifier [String]
    # @param type [String, nil]
    # @return [Hash, nil]
    def unit(identifier, type: nil)
      @units.fetch([identifier, type]) { @units[[identifier, type]] = @index.unit(identifier, type: type) }
    end

    # Resolve a constant or identifier to the unit types that own it, from
    # the primary node and any coexisting types in the graph's variants.
    #
    # @param identifier [String]
    # @return [Array<String>] unit types; empty when unknown
    def identifier_types(identifier)
      Array(nodes_by_identifier[identifier]).filter_map { |node| node['type']&.to_s }.uniq
    end

    # Every identifier of this generation with the type of its primary node:
    # the set the guide may link (design study, section 11).
    #
    # @return [Hash{String => String}]
    def identifier_index
      @identifier_index ||= nodes_by_identifier.each_with_object({}) do |(identifier, nodes), index|
        type = nodes.first && nodes.first['type']
        index[identifier] = type.to_s if type
      end
    end

    # @param identifier [String]
    # @param type [String, nil] the unit type; nil selects the primary node
    # @return [Hash, nil] the matching graph node, or nil when that typed unit is absent
    def graph_node(identifier, type: nil)
      nodes = Array(nodes_by_identifier[identifier])
      type ? nodes.find { |node| node['type'].to_s == type.to_s } : nodes.first
    end

    # @return [Pathname] the index root this repository was opened at
    delegate :index_dir, to: :@index

    # @return [Hash{String => String}] model identifier => the table its graph node names
    def model_tables
      @model_tables ||= Hash(graph['nodes']).each_with_object({}) do |(identifier, node), tables|
        tables[identifier] = node['table'] if node['type'] == 'model' && node['table']
      end
    end

    # The index reader pinned to this generation, for Woods' own builders
    # (`Woods::Diagrams`) that read the same generation the page does.
    #
    # @return [Woods::MCP::IndexReader]
    def index_reader
      @reader
    end

    # @return [Hash] the raw dependency graph (nodes, edges, reverse, reverse_via, pagerank, file_map)
    def graph
      @graph ||= @reader.raw_graph_data
    end

    # @return [Hash] graph_analysis.json, or an empty hash when absent
    def graph_analysis
      @graph_analysis ||= @reader.graph_analysis || {}
    rescue StandardError
      @graph_analysis = {}
    end

    # The request flows a best-effort extraction could not assemble (W-14,
    # woods#764): +entry_point+, +controller+, +action+, +reason+, +error+.
    # Empty when none failed, or with a Woods that does not publish them.
    #
    # @return [Array<Hash>]
    def flow_failures
      @flow_failures ||= @reader.respond_to?(:flow_failures) ? Array(@reader.flow_failures).grep(Hash) : []
    end

    # Drift of the working tree against this generation, within a quarter
    # second budget; compares file identities, never runs git. The answer is
    # reused for {FreshnessCache::TTL} seconds per index and generation.
    #
    # @return [Hash] with 'state' (current, drifted, unknown, unavailable)
    def freshness
      key = [@index.index_dir.to_s, @index.payload_dir.to_s, generation_number]
      @freshness ||= FreshnessCache.fetch(key) do
        Woods::SourceInputs::Status.new(output_dir: @index.index_dir, payload_dir: @index.payload_dir,
                                        generation: generation_number, mode: 'quick').call
      end
    rescue StandardError => e
      @freshness = { 'state' => 'unknown', 'reasons' => [e.class.name] }
    end

    # Search the pinned generation. The reader answers with symbol keys and
    # rows of identifier, type and match_field; the map reads string keys
    # everywhere and wants the file path beside each row.
    #
    # @see Woods::MCP::IndexReader#search
    # @return [Hash] 'results' rows with 'identifier', 'type', 'match_field' and 'file_path';
    #   'completeness', 'partial', 'note' and 'hint' as the reader reports them
    def search(query, **options)
      response = @reader.search(query, **options).deep_stringify_keys
      response['results'] = Array(response['results']).map do |row|
        row.merge('file_path' => graph_node(row['identifier'], type: row['type'])&.dig('file_path'))
      end
      response
    end

    # Whether this Woods takes a per-call deep-field scan budget
    # (+max_scan:+). Older readers cap code search at
    # WOODS_SEARCH_MAX_SCAN only.
    #
    # @return [Boolean]
    def search_scan_budget?
      @reader.method(:search).parameters.any? { |_kind, name| name == :max_scan }
    end

    # The dependency-graph file map restricted to permitted relative keys.
    # No path is normalized or decoded here.
    #
    # @return [Hash{String => Array<String>}] exact path => identifiers
    def file_map
      @file_map ||= (graph['file_map'] || {}).select { |path, _| permitted_file_path?(path) }
    end

    # @param path [String] already Rails-decoded relative application path
    # @return [Boolean] whether the key is safe for exact payload lookup
    def permitted_file_path?(path)
      path.is_a?(String) && path.present? && path.valid_encoding? &&
        !path.match?(%r{\A(?:/|[a-z]:)|[\\\p{Cc}]}i) &&
        path.split('/', -1).none? { |part| part.empty? || %w[. ..].include?(part) }
    end

    # All typed owners whose published primary or contributor path matches
    # an admitted file-map key. Never infer ownership from an identifier alone.
    #
    # @param path [String] exact permitted file-map key
    # @return [Array<Hash>] deterministic, distinct typed node facts
    def file_owners(path)
      file_map.key?(path) ? file_owners_by_path.fetch(path, []) : []
    end

    # @param path [String] exact permitted file-map key
    # @return [Array<String>] membership without a matching typed owner
    def unresolved_file_identifiers(path)
      (Array(file_map[path]).uniq - file_owners(path).pluck('identifier')).sort
    end

    # Legacy first-owner lookup for existing source-line links. File
    # navigation uses {#file_owners} and never selects one owner's page.
    #
    # @param path [String] exact permitted file-map key
    # @return [Hash, nil] the first resolved typed owner
    def file_owner(path)
      file_owners(path).first
    end

    private

    # Index published ownership once per request, rather than scanning every
    # node for each file in the tree. Only admitted exact keys enter it.
    def file_owners_by_path
      @file_owners_by_path ||= begin
        owners = {}
        nodes_by_identifier.each do |identifier, nodes|
          nodes.each { |node| add_file_owner(owners, identifier, node) if node['type'].present? }
        end
        owners.transform_values { |members| members.sort.map(&:last) }
      end
    end

    def add_file_owner(owners, identifier, node)
      owner = node.merge('identifier' => identifier)
      ([node['file_path']] + Array(node['source_paths'])).uniq.each do |path|
        next unless file_map.key?(path)

        (owners[path] ||= {})[[identifier, node['type']]] ||= owner
      end
    end

    # Woods publishes coexisting types as a flat variants array; older
    # generations omit it. Build the lookup once for this pinned generation.
    def nodes_by_identifier
      @nodes_by_identifier ||= begin
        nodes = (graph['nodes'] || {}).transform_values { |node| [node] }
        Array(graph['variants']).grep(Hash).each do |record|
          next unless record['identifier']

          (nodes[record['identifier']] ||= []) << record
        end
        nodes
      end
    end

    def manifest_facts
      {
        'total_units' => manifest.fetch('total_units') { manifest['total'] },
        'counts' => manifest.fetch('counts', {})
      }
    end

    def provenance_facts
      provenance = manifest['provenance'] || {}
      PROVENANCE_KEYS.index_with { |key| manifest.fetch(key) { provenance[key] } }
    end
  end
end
