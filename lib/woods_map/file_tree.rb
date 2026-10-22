# frozen_string_literal: true

module WoodsMap
  # The file-tree explorer's rows (C3, D-18) from the graph's file map: the
  # application's files as they are on disk, directories with the count of
  # indexed units beneath them, each file linking to the unit it defines.
  # Built once per generation and kept in a small process cache.
  class FileTree
    Row = Struct.new(:kind, :name, :level, :path, :count, :identifier, :type, :units, keyword_init: true)

    CACHE_SIZE = 4
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
            owners = repository.file_map.keys.index_with { |path| repository.file_owner(path) }
            @cache[key] = new(repository.file_map, {}, owners: owners)
          end
        end
      end

      # @return [void]
      def reset!
        @mutex.synchronize { @cache.clear }
      end
    end

    # @param file_map [Hash{String => Array<String>}] relative path => identifiers
    # @param nodes [Hash{String => Hash}] identifier => node facts (type)
    # @param owners [Hash{String => Hash}, nil] pre-resolved typed owners by file path
    def initialize(file_map, nodes, owners: nil)
      @file_map = file_map
      @nodes = nodes
      @owners = owners
    end

    # @return [Integer] indexed units across the tree
    def unit_count
      @unit_count ||= @file_map.values.flatten.uniq.size
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
      Row.new(kind: :dir, name: name, level: level, path: "#{prefix}#{name}", count: count_units(children))
    end

    def count_units(node)
      node.values.sum { |v| v.is_a?(Hash) ? count_units(v) : Array(@file_map[v]).size }
    end

    def file_row(name, level, path)
      identifiers = Array(@file_map[path])
      first = identifiers.first
      owner = @owners ? @owners[path] : { 'identifier' => first, 'type' => first && @nodes.dig(first, 'type') }
      Row.new(kind: :file, name: name, level: level, path: path, identifier: owner&.dig('identifier'),
              type: owner&.dig('type'), units: identifiers.size)
    end
  end
end
