# frozen_string_literal: true

module WoodsMap
  module Guide
    # Keeps an answer's event stream alive while nothing else is written
    # (DEPLOYMENT.md §8): every `interval` seconds of quiet it writes an SSE
    # comment line, which EventSource ignores and proxies and CDNs count as
    # traffic, so an idle stream is not timed out while the model thinks or a
    # tool runs. Writes share one lock with the answer's events, so a comment
    # never lands inside an event. A failed write marks the client gone.
    class Heartbeat
      # The comment line written.
      COMMENT = ": heartbeat\n\n"

      # @param interval [Numeric] seconds of quiet between comments; 0 or less disables it
      # @param lock [Mutex] the lock every write to the stream takes
      # @param write [#call] (String) => void, writes to the stream; raises when the client is gone
      def initialize(interval:, lock:, write:)
        @interval = interval.to_f
        @lock = lock
        @write = write
        @stopped = false
        @wake = ConditionVariable.new
        @last = now
      end

      # @return [Boolean] whether a heartbeat write failed (the client is gone)
      def gone?
        @gone == true
      end

      # Note a write by the answer itself; the next comment waits a full interval from here.
      #
      # @return [void]
      def wrote
        @last = now
      end

      # @return [self]
      def start
        return self unless @interval.positive?

        @thread = Thread.new { beat }
        self
      end

      # @return [void]
      def stop
        @lock.synchronize do
          @stopped = true
          @wake.signal
        end
        @thread&.join
      end

      private

      def beat
        @lock.synchronize do
          until @stopped
            wait = @last + @interval - now
            if wait.positive?
              @wake.wait(@lock, wait)
              next
            end
            @write.call(COMMENT)
            @last = now
          end
        end
      rescue StandardError
        @gone = true
      end

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
