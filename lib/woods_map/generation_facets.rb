# frozen_string_literal: true

module WoodsMap
  # What moved in one unit at each retained generation (B6-History's
  # *facets moved* column): Woods' own record of the unit between a
  # generation and the retained generation before it
  # (`Woods::Impact::UnitDiff`, woods#802, through {SourceDiff}), so the map
  # compares nothing itself. A commit is attributed to the generation that
  # first carried it ({CommitLedger}); the oldest retained generation has no
  # predecessor and so no value. Results are cached per index identity:
  # published generations never change.
  class GenerationFacets
    CACHE_SIZE = 256
    @cache = {}
    @mutex = Mutex.new

    class << self
      # @return [SourceDiff] cached per index identity, unit and pair
      def fetch(key)
        @mutex.synchronize { @cache[key] } || store(key, yield)
      end

      # Drop the cache (specs).
      # @return [void]
      def reset!
        @mutex.synchronize { @cache.clear }
      end

      private

      def store(key, value)
        @mutex.synchronize do
          @cache.shift while @cache.size >= CACHE_SIZE
          @cache[key] = value
        end
      end
    end

    # @param repository [WoodsMap::Repository]
    # @param unit [Hash]
    # @param numbers [Array<Integer>] retained generations, ascending
    def initialize(repository, unit, numbers)
      @repository = repository
      @unit = unit
      @numbers = numbers
    end

    # @param number [Integer, nil] the generation that first carried a commit
    # @return [String, nil] the categories that moved ("behaviour, edges"),
    #   added, removed or unchanged; nil when no comparison is possible
    def label(number)
      diff = diff_for(number)
      return nil unless diff&.state == :available && diff.categories

      case diff.status
      when 'modified' then diff.categories.join(', ')
      when 'added', 'removed' then [diff.status, *diff.categories].join(', ')
      else 'unchanged'
      end
    end

    # @return [Boolean] whether there is a pair to compare and a Woods to compare it
    def available?
      @numbers.size >= 2 && !SourceDiff.backend.nil?
    end

    private

    def diff_for(number)
      index = number && @numbers.index(number)
      return nil unless index&.positive?

      from = @numbers[index - 1]
      key = [@repository.generation_key, @unit['identifier'], @unit['type'], from, number]
      self.class.fetch(key) do
        SourceDiff.new(@repository.index_dir, identifier: @unit['identifier'], type: @unit['type'], from: from,
                                              to: number)
      end
    end
  end
end
