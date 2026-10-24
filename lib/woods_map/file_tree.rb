# frozen_string_literal: true

module WoodsMap
  # The file-tree explorer's rows (C3, D-18) from the graph's file map: the
  # application's files as they are on disk, directories with the count of
  # distinct typed owners beneath them, each file retaining its exact path.
  # Files whose every owner is framework or gem source (Woods' rails_source
  # and gem_source units, installed-gem paths) are left out: the tree is the
  # application. Built once per generation and kept in a small process cache.
  class FileTree
    Row = Struct.new(:kind, :name, :level, :path, :count, :identifier, :type, :units, :owner_keys, :unresolved,
                     keyword_init: true)

    CACHE_SIZE = 4
    # Unit types that are framework or gem source, not the application's own code.
    FRAMEWORK_TYPES = %w[rails_source gem_source].freeze
    @cache = {}
    @mutex = Mutex.new

    class << self
      # @param repository [WoodsMap::Repository]
      # @return [FileTree]
      def for(repository)
        key = repository.generation_key
        @mutex.synchronize do
          @cache.fetch(key) do
            @cache.shift while @cache.size >= CACHE_SIZE
            owners = repository.file_map.keys.index_with { |path| repository.file_owners(path) }
            files = repository.file_map.reject { |path, _| framework?(owners[path]) }
            @cache[key] = new(files, {}, owners: owners)
          end
        end
      end

      # @param owners [Array<Hash>] a file's typed owners
      # @return [Boolean] whether every owner is framework or gem source
      def framework?(owners)
        owners.present? && owners.all? { |owner| FRAMEWORK_TYPES.include?(owner['type'].to_s) }
      end

      # @return [void]
      def reset!
        @mutex.synchronize { @cache.clear }
      end
    end

    # @param file_map [Hash{String => Array<String>}] relative path => identifiers
    # @param nodes [Hash{String => Hash}] identifier => node facts (type)
    # @param owners [Hash{String => Array<Hash>}, nil] pre-resolved typed owners by file path
    def initialize(file_map, nodes, owners: nil)
      @file_map = file_map
      @nodes = nodes
      @owners = owners
    end

    # @return [Integer] indexed units across the tree
    def unit_count
      @unit_count ||= identities(@file_map.keys).size
    end

    # @return [Integer] distinct unresolved identifiers across the tree
    def unresolved_count
      unresolved_identifiers(@file_map.keys).size
    end

    # @return [Array<Row>] directories and files, depth first, as on disk
    def rows
      @rows ||= build(tree, 0, '')
    end

    private

    def tree
      @file_map.keys.sort.each_with_object({}) do |path, root|
        parts = path.split('/')
        node = parts[0...-1].reduce(root) { |dir, part| dir[part] ||= {} }
        node[parts.last] = path
      end
    end

    def build(node, level, prefix)
      dirs = node.select { |_, v| v.is_a?(Hash) }.sort
      files = node.reject { |_, v| v.is_a?(Hash) }.sort
      dirs.flat_map do |name, children|
        [dir_row(name, level, prefix, children)] + build(children, level + 1, "#{prefix}#{name}/")
      end +
        files.map { |name, path| file_row(name, level, path) }
    end

    def dir_row(name, level, prefix, children)
      paths = leaf_paths(children)
      Row.new(kind: :dir, name: name, level: level, path: "#{prefix}#{name}", count: identities(paths).size,
              unresolved: unresolved_identifiers(paths).size)
    end

    def leaf_paths(node)
      node.values.flat_map { |value| value.is_a?(Hash) ? leaf_paths(value) : [value] }
    end

    def identities(paths)
      paths.flat_map { |path| owners(path).map { |owner| owner.values_at('identifier', 'type') } }.uniq
    end

    def unresolved_identifiers(paths)
      paths.flat_map do |path|
        Array(@file_map[path]).uniq - owners(path).pluck('identifier')
      end.uniq
    end

    def owners(path)
      @owners_by_path ||= {}
      @owners_by_path[path] ||= @owners ? @owners.fetch(path, []) : legacy_owners(path)
    end

    def legacy_owners(path)
      Array(@file_map[path]).filter_map do |identifier|
        node = @nodes[identifier]
        node.merge('identifier' => identifier) if node && node['type'].present?
      end
    end

    def file_row(name, level, path)
      owner = owners(path).first
      keys = identities([path])
      Row.new(kind: :file, name: name, level: level, path: path, identifier: owner&.dig('identifier'),
              type: owner&.dig('type'), units: keys.size, owner_keys: keys,
              unresolved: unresolved_identifiers([path]).size)
    end
  end
end
