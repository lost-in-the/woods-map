# frozen_string_literal: true

module WoodsMap
  # Woods' quick source check, kept per index and generation for a short
  # while. The check reads and hashes source files, so running it on
  # every request costs each page that time for an answer that rarely
  # changes within seconds. A source edit shows within {TTL} seconds; a new
  # generation is a new key and is checked at once.
  module FreshnessCache
    # Seconds a freshness answer is reused.
    TTL = 30
    # Keys kept; the oldest is dropped beyond this.
    MAX_ENTRIES = 16

    @mutex = Mutex.new
    @entries = {}

    class << self
      # @param key [Array] index directory, payload directory and generation
      # @yieldreturn [Hash] a fresh Woods freshness report
      # @return [Hash] the cached report, or the block's
      def fetch(key)
        now = Time.current
        cached = @mutex.synchronize { @entries[key] }
        return cached.last if cached && now - cached.first < TTL

        report = yield
        @mutex.synchronize do
          @entries.delete(key)
          @entries[key] = [now, report]
          @entries.shift while @entries.size > MAX_ENTRIES
        end
        report
      end

      # Forget every answer (specs, and a host that wants a check now).
      #
      # @return [void]
      def reset!
        @mutex.synchronize { @entries.clear }
      end
    end
  end
end
