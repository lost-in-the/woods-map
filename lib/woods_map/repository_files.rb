# frozen_string_literal: true

module WoodsMap
  # The file reads of {Repository}: the graph's file map restricted to
  # permitted keys and the typed owners of each file, indexed once per
  # generation. Mixed into Repository, which supplies `graph`, `snapshot` and
  # `nodes_by_identifier`.
  module RepositoryFiles
    # The dependency-graph file map restricted to permitted relative keys.
    # No path is normalized or decoded here.
    #
    # @return [Hash{String => Array<String>}] exact path => identifiers
    def file_map
      snapshot.fetch(:file_map) { (graph['file_map'] || {}).select { |path, _| permitted_file_path?(path) } }
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

    # Index published ownership once per generation, rather than scanning every
    # node for each file in the tree. Only admitted exact keys enter it.
    def file_owners_by_path
      snapshot.fetch(:file_owners_by_path) do
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
  end
end
