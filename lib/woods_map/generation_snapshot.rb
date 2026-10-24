# frozen_string_literal: true

require 'monitor'
require 'woods/mcp/index_reader'

module WoodsMap
  # What every request derives from one published generation, computed once
  # per process and shared by the requests that pin that generation.
  #
  # A published payload is immutable, so the dependency graph, the unit
  # listings and the lookups built over them cannot change while the
  # generation's identity ({Repository#generation_key}) stays the same. One
  # snapshot holds the Woods index reader of that payload (whose caches are
  # thread-safe and shared, as `woods-mcp-http` shares one reader across
  # request threads) and the derived values, each frozen so a caller that
  # mutates one fails loudly rather than corrupting the next request.
  #
  # Only reads made under a request's pin reach the payload: a value is
  # computed on first use inside {Repository.open}, whose shared manifest lock
  # keeps retention from deleting the payload while it is read.
  class GenerationSnapshot
    # Snapshots kept per process, least recently used first out. The graph of
    # a large application is the bulk of one; the history pages open older
    # generations beside the current one, which every request touches.
    CACHE_SIZE = 3
    @cache = {}
    @mutex = Mutex.new

    class << self
      # @param key [Array] the generation identity ({Repository#generation_key})
      # @param payload_dir [Pathname, String] the pinned payload directory
      # @return [GenerationSnapshot]
      def for(key, payload_dir)
        @mutex.synchronize do
          snapshot = @cache.delete(key)
          @cache.shift while @cache.size >= CACHE_SIZE
          @cache[key] = snapshot || new(payload_dir)
        end
      end

      # @return [void]
      def reset!
        @mutex.synchronize { @cache.clear }
      end
    end

    # @return [Woods::MCP::IndexReader] the reader pinned to this payload
    attr_reader :reader

    # @param payload_dir [Pathname, String]
    def initialize(payload_dir)
      @reader = Woods::MCP::IndexReader.new(payload_dir.to_s, auto_refresh: false)
      @values = {}
      @monitor = Monitor.new
    end

    # A derived value, computed once. Reentrant, so one value may be built
    # from another; concurrent first uses wait for the one computation.
    #
    # @param name [Object] the value's key
    # @yieldreturn [Object] the value, frozen deeply before it is kept
    # @return [Object]
    def fetch(name)
      @monitor.synchronize do
        @values.fetch(name) { @values[name] = self.class.deep_freeze(yield) }
      end
    end

    # @param value [Object]
    # @return [Object] the value, with every Hash, Array and String in it
    #   frozen; other objects are kept as they are
    def self.deep_freeze(value)
      case value
      when Hash then value.each_value { |item| deep_freeze(item) }.freeze
      when Array then value.each { |item| deep_freeze(item) }.freeze
      when String then value.freeze
      else value
      end
    end
  end
end
