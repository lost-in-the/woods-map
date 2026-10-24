# frozen_string_literal: true

module WoodsMap
  module Guide
    # Index MCP servers kept alive across answers (D-7). Starting
    # `woods-mcp` over stdio costs about two seconds, so an answer borrows a
    # running server for its index and generation and hands it back when it
    # ends cleanly. The pool is bounded:
    #
    # - at most `size` servers are alive in this process; an answer that
    #   finds them all busy waits up to `wait` seconds, then fails with
    #   {Busy};
    # - a server is kept for one key, the index's identity and the pinned
    #   generation. A new generation stops the servers of the old one: idle
    #   ones at once, busy ones when they come back;
    # - a server idle for `idle` seconds is stopped the next time the pool
    #   is used;
    # - a server that came back from a failed, cancelled or interrupted
    #   answer is stopped rather than reused, since a request may still be
    #   in flight on it.
    #
    # Every server is stopped at exit. A forked child (a Puma worker) starts
    # with an empty pool and never stops the parent's processes.
    #
    # The pool knows nothing of RubyLLM: a server is anything that answers
    # `close`, built by the factory the pool is given.
    class ServerPool
      # Raised when every server is busy for longer than the wait.
      class Busy < StandardError; end

      # One server and what the pool knows of it.
      Entry = Struct.new(:server, :key, :busy, :idle_since)

      # @return [Integer] the most servers alive at once
      attr_reader :size

      # @param size [Integer] the most servers alive at once
      # @param idle [Numeric] seconds an idle server is kept
      # @param wait [Numeric] seconds an answer waits for a free server
      # @param clock [#call] monotonic seconds
      def initialize(size:, idle:, wait:, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        @size = [size.to_i, 1].max
        @idle = idle.to_f
        @wait = wait.to_f
        @clock = clock
        @entries = []
        @lock = Mutex.new
        @freed = ConditionVariable.new
        @pid = Process.pid
      end

      # Borrow a server for `key`, starting one when none is idle and the pool
      # has room.
      #
      # @param key [Array] the index identity and generation
      # @yieldreturn [#close] a new server, built only when one is needed
      # @return [Object] the server
      # @raise [Busy] when no server frees up within the wait
      def checkout(key, &factory)
        deadline = @clock.call + @wait
        stopped = []
        entry = @lock.synchronize do
          forget_after_fork
          loop do
            stopped.concat(reap(key))
            found = idle_for(key) || reserve(key)
            break found if found

            remaining = deadline - @clock.call
            raise Busy, "All #{@size} guide index servers are busy; ask again in a moment." unless remaining.positive?

            @freed.wait(@lock, remaining)
          end
        end
        stop(stopped)
        entry.server ||= build(entry, &factory)
      end

      # Hand a server back.
      #
      # @param server [Object] what {#checkout} returned
      # @param reuse [Boolean] false after an answer that did not end cleanly
      # @return [void]
      def checkin(server, reuse:)
        stopped = []
        @lock.synchronize do
          entry = @entries.find { |candidate| candidate.server.equal?(server) }
          if entry.nil?
            stopped << server
          elsif reuse && current?(entry.key)
            entry.busy = false
            entry.idle_since = @clock.call
          else
            @entries.delete(entry)
            stopped << server
          end
          @freed.broadcast
        end
        stop(stopped)
      end

      # Stop every idle server and forget the busy ones' keys, so they stop
      # when they come back; with `force`, at exit, stop the busy ones too.
      #
      # @param force [Boolean] stop servers an answer still holds
      # @return [void]
      def shutdown(force: false)
        stopped = @lock.synchronize do
          next [] unless Process.pid == @pid

          @current = nil
          leaving = force ? @entries : @entries.reject(&:busy)
          @entries -= leaving
          @entries.each { |entry| entry.key = nil }
          @freed.broadcast
          leaving.filter_map(&:server)
        end
        stop(stopped)
      end

      # @return [Hash{Symbol => Integer}] servers alive, busy and idle
      def stats
        @lock.synchronize do
          { alive: @entries.size, busy: @entries.count(&:busy), idle: @entries.count { |entry| !entry.busy } }
        end
      end

      private

      def build(entry)
        yield
      rescue StandardError, ScriptError
        @lock.synchronize do
          @entries.delete(entry)
          @freed.broadcast
        end
        raise
      end

      # The key a checkout names becomes current; idle servers of any other
      # key, and idle servers past their time, are taken out to be stopped.
      def reap(key)
        @current = key
        now = @clock.call
        stale = @entries.select do |entry|
          !entry.busy && (!current?(entry.key) || now - entry.idle_since > @idle)
        end
        @entries -= stale
        stale.map(&:server)
      end

      def idle_for(key)
        entry = @entries.find { |candidate| !candidate.busy && candidate.key == key }
        entry&.busy = true
        entry
      end

      def reserve(key)
        return if @entries.size >= @size

        entry = Entry.new(nil, key, true, nil)
        @entries << entry
        entry
      end

      def current?(key)
        !key.nil? && key == @current
      end

      # After a fork the entries are the parent's processes: the child forgets
      # them without stopping them.
      def forget_after_fork
        return if Process.pid == @pid

        @pid = Process.pid
        @entries = []
        @current = nil
      end

      def stop(servers)
        servers.each do |server|
          server.close
        rescue StandardError
          nil
        end
      end
    end
  end
end
