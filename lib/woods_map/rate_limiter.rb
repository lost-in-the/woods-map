# frozen_string_literal: true

module WoodsMap
  # An in-process, fixed-window request counter for the expensive endpoints
  # (M8): search and the palette, the graph JSON and impact. It needs no
  # cache store and nothing from Rails 7.2's `rate_limit`, so it works on the
  # railties 6.0 floor. Counts live in this process only: a host running
  # several workers grants each worker the budget, which the deployment guide
  # states.
  #
  # Memory is bounded: when more than {#max_keys} clients are tracked, expired
  # windows go first and then the oldest windows.
  class RateLimiter
    # The outcome of one request.
    #
    # @!attribute [r] allowed
    #   @return [Boolean] whether the request is within the budget
    # @!attribute [r] limit
    #   @return [Integer] the budget per window
    # @!attribute [r] remaining
    #   @return [Integer] requests left in this window
    # @!attribute [r] retry_after
    #   @return [Integer] whole seconds until the window resets
    Decision = Struct.new(:allowed, :limit, :remaining, :retry_after) do
      # @return [Boolean]
      def allowed?
        allowed
      end
    end

    # @return [Integer]
    attr_reader :limit
    # @return [Float]
    attr_reader :period
    # @return [Integer]
    attr_reader :max_keys

    # @param limit [Integer] requests allowed per window and key
    # @param period [Numeric] window length in seconds
    # @param max_keys [Integer] keys tracked before the oldest are dropped
    # @param clock [#call] monotonic seconds; specs pass a fake
    def initialize(limit:, period:, max_keys: 10_000, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @limit = Integer(limit)
      @period = Float(period)
      @max_keys = max_keys
      @clock = clock
      @windows = {}
      @mutex = Mutex.new
    end

    # @param limit [Integer]
    # @param period [Numeric]
    # @return [Boolean] whether this counter enforces the given budget
    def configured_for?(limit, period)
      @limit == limit.to_i && (@period - period.to_f).abs < Float::EPSILON
    end

    # Count one request for a key.
    #
    # @param key [String] the client and endpoint group
    # @return [Decision]
    def hit(key)
      now = @clock.call
      @mutex.synchronize do
        started, count = current_window(key, now)
        count += 1
        @windows[key] = [started, count]
        prune(now) if @windows.size > max_keys
        decide(started, count, now)
      end
    end

    # @return [Integer] keys currently tracked
    def size
      @mutex.synchronize { @windows.size }
    end

    private

    def current_window(key, now)
      started, count = @windows[key]
      return [started, count] if started && now - started < period

      # A new window moves the key to the end, so the oldest windows are first.
      @windows.delete(key)
      [now, 0]
    end

    def decide(started, count, now)
      retry_after = [(started + period - now).ceil, 1].max
      Decision.new(count <= limit, limit, [limit - count, 0].max, retry_after)
    end

    def prune(now)
      @windows.delete_if { |_, (started, _)| now - started >= period }
      @windows.shift while @windows.size > max_keys
    end
  end
end
