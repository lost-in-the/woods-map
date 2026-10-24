# frozen_string_literal: true

module WoodsMap
  # A small least-recently-used process memo for values that depend only on
  # a published generation and a request's inputs. Keys start with
  # {Repository#generation_key}; values are frozen and shared across requests.
  class GenerationMemo
    @all = []

    class << self
      # @return [void] empties every memo (specs, between examples)
      def reset_all!
        @all.each(&:clear)
      end

      # @api private
      def register(memo)
        @all << memo
      end
    end

    # @param size [Integer] entries kept
    def initialize(size)
      @size = size
      @values = {}
      @mutex = Mutex.new
      self.class.register(self)
    end

    # @param key [Array]
    # @yieldreturn [Object] the value, computed outside the lock
    # @return [Object] the kept value
    def fetch(key)
      @mutex.synchronize do
        return @values[key] = @values.delete(key) if @values.key?(key)
      end
      value = yield.freeze
      @mutex.synchronize do
        @values.shift while @values.size >= @size
        @values[key] = value
      end
    end

    # @return [void]
    def clear
      @mutex.synchronize { @values.clear }
    end
  end
end
