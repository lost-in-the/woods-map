# frozen_string_literal: true

require 'woods/flow_assembler'

module WoodsMap
  # Flows assembled on demand from the pinned generation (C-1): Woods'
  # `FlowAssembler`, the assembler `trace_flow` uses, over the graph and the
  # payload that `Woods::MCP::IndexReader` resolves. Published generations
  # never change, so a flow is cached per index identity, generation, entry
  # and depth. Mixed into {Repository}, which supplies `@reader` and
  # `generation_key`.
  module RepositoryFlows
    CACHE_SIZE = 32
    @cache = {}
    @mutex = Mutex.new

    class << self
      # @return [Object] the cached value, or the block's
      def fetch(key)
        @mutex.synchronize { return @cache[key] if @cache.key?(key) }
        value = yield
        @mutex.synchronize do
          @cache.shift while @cache.size >= CACHE_SIZE
          @cache[key] = value
        end
      end

      # Woods capabilities the Trail leans on, named as limits when the
      # bundled Woods lacks them (W-5, woods#755).
      #
      # @return [Hash{Symbol => Boolean}]
      def capabilities
        { model_events: Woods::FlowAssembler.respond_to?(:model_event),
          mail_deliveries: Woods::FlowAssembler.const_defined?(:DELIVERY_METHODS) }
      end

      # Drop the cache (specs).
      # @return [void]
      def reset!
        @mutex.synchronize { @cache.clear }
      end
    end

    # @param entry [String] a flow entry (`Job#perform`, `Post@create`)
    # @param max_depth [Integer]
    # @return [Hash] the flow document as `FlowDocument#to_h` gives it, with
    #   symbol keys (steps, operations), frozen
    def flow(entry, max_depth:)
      RepositoryFlows.fetch([generation_key, entry, max_depth]) do
        assembler = Woods::FlowAssembler.new(graph: @reader.dependency_graph, extracted_dir: @reader.payload_dir.to_s)
        assembler.assemble(entry, max_depth: max_depth).to_h.freeze
      end
    end
  end
end
