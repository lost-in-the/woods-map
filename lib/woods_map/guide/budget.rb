# frozen_string_literal: true

module WoodsMap
  module Guide
    # The limits one answer runs under (design study, section 11): tool calls
    # and model turns per answer, seconds per answer, and the tokens the
    # browser session may spend in all. Each limit is visible in the panel;
    # reaching one stops the answer and says which.
    class Budget
      # Raised when a limit is reached; the answer stops there.
      class Exceeded < StandardError
        # @return [Symbol] :tool_calls, :turns, :seconds or :tokens
        attr_reader :kind

        # @param kind [Symbol]
        # @param message [String]
        def initialize(kind, message)
          @kind = kind
          super(message)
        end
      end

      # @return [Integer]
      attr_reader :tool_calls, :turns, :tokens
      # @return [#call] the monotonic clock the budget times with
      attr_reader :clock

      # @param config [WoodsMap::Configuration]
      # @param tokens_spent [Integer] tokens the session spent before this answer
      # @param clock [#call] monotonic seconds
      def initialize(config, tokens_spent:, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
        @config = config
        @spent = tokens_spent.to_i
        @clock = clock
        @started = clock.call
        @tool_calls = 0
        @turns = 0
        @tokens = 0
      end

      # @param config [WoodsMap::Configuration]
      # @param tokens_spent [Integer]
      # @return [Boolean] whether the session has no tokens left for another answer
      def self.exhausted?(config, tokens_spent)
        tokens_spent.to_i >= config.guide_token_budget.to_i
      end

      # Count a tool call before it runs.
      #
      # @raise [Exceeded] past the per-answer cap; the call does not run
      def tool_call!
        if @tool_calls >= @config.guide_tool_calls.to_i
          raise Exceeded.new(:tool_calls, "Stopped at #{@config.guide_tool_calls} tool calls, the cap for one answer.")
        end

        @tool_calls += 1
      end

      # Count a model turn before it is requested.
      #
      # @raise [Exceeded] past the per-answer turn limit
      def turn!
        check_time!
        if @turns >= @config.guide_turns.to_i
          raise Exceeded.new(:turns, "Stopped after #{@config.guide_turns} model turns, the limit for one answer.")
        end

        @turns += 1
      end

      # @param count [Integer] tokens one response used
      # @raise [Exceeded] once the session budget is spent
      def tokens!(count)
        @tokens += count.to_i
        return if session_tokens < @config.guide_token_budget.to_i

        raise Exceeded.new(:tokens, "Stopped: this session has spent its #{@config.guide_token_budget} tokens.")
      end

      # @raise [Exceeded] once the answer has run its seconds
      def check_time!
        return if elapsed < @config.guide_seconds.to_f

        raise Exceeded.new(:seconds, "Stopped after #{@config.guide_seconds.to_i} s, the time limit for one answer.")
      end

      # @return [Float] seconds since the answer started
      def elapsed
        @clock.call - @started
      end

      # @return [Integer] tokens the session has spent, this answer included
      def session_tokens
        @spent + @tokens
      end

      # @return [Hash{String => Numeric}] what the budget line shows
      def to_h
        { 'tool_calls' => @tool_calls, 'tool_call_limit' => @config.guide_tool_calls.to_i,
          'turns' => @turns, 'turn_limit' => @config.guide_turns.to_i,
          'tokens' => @tokens, 'session_tokens' => session_tokens, 'token_budget' => @config.guide_token_budget.to_i,
          'seconds' => elapsed.round(1), 'second_limit' => @config.guide_seconds.to_i }
      end
    end
  end
end
