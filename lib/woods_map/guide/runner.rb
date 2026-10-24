# frozen_string_literal: true

module WoodsMap
  module Guide
    # Runs one turn of a conversation and reports what happens as events:
    # `tool` when a call starts and ends (the cards), `delta` for answer text
    # as it streams, then exactly one of `done`, `limit`, `cancelled` or
    # `error`. The controller writes the events to the SSE stream; specs
    # collect them.
    #
    # The chat is RubyLLM's (or a host factory's) and is driven one step at a
    # time, so every limit is checked between steps and before each tool call:
    # a reached limit stops the answer, keeps the text streamed so far and
    # says which limit it was. Earlier turns of the conversation are replayed
    # as plain user and assistant messages, so no chat object outlives a
    # request.
    class Runner
      # Arguments a card shows bare, first: `lookup(Post)`, `dependents(Post, depth 1)`.
      PRIMARY_ARGUMENTS = %w[identifier query name entry_point unit].freeze

      # Raised by the emitter when the browser has gone; the answer stops.
      class Disconnected < StandardError; end

      # @param store [WoodsMap::Guide::Store]
      # @param turn [Hash] the claimed (running) turn
      # @param session [WoodsMap::Guide::Session] the chat and its MCP servers
      # @param emit [#call] (event, payload) => void; raises Disconnected when the client is gone
      # @param budget [WoodsMap::Guide::Budget] this answer's limits, started now
      def initialize(store:, turn:, session:, emit:, budget:)
        @store = store
        @turn = turn
        @session = session
        @chat = session.chat
        @emit = emit
        @budget = budget
        @clock = budget.clock
        @answer = +''
        @calls = []
      end

      # @return [Hash] the final turn record
      def run
        converse
        @clean = true
        finish('done', answer: final_text)
      rescue Budget::Exceeded => e
        # Limits are checked between steps and before a call runs, so no
        # request is left in flight on the server.
        @clean = true
        finish('limited', limit: { 'kind' => e.kind.to_s, 'message' => e.message })
      rescue Disconnected, CancelledByUser
        @chat.cancel if @chat.respond_to?(:cancel)
        finish('cancelled')
      rescue StandardError => e
        finish('failed', error: "#{e.class.name.split('::').last}: #{e.message}".slice(0, 300))
      ensure
        # A clean answer hands its Index MCP server back for the next one;
        # any other end stops it.
        @session.close(reuse: @clean == true)
      end

      # @return [WoodsMap::Guide::Budget]
      attr_reader :budget

      # Raised between steps when the person pressed stop.
      class CancelledByUser < StandardError; end

      private

      def converse
        prepare
        @chat.ask_later(@turn['prompt'])
        until @chat.complete?
          @budget.turn!
          @chat.step { |chunk| stream(chunk) }
          cancelled!
        end
      end

      def prepare
        replay
        @chat.before_tool_call { |call| tool_started(call) }
        @chat.after_tool_result { |result| tool_finished(result) }
        @chat.after_message { |message| count_tokens(message) }
      end

      def replay
        @store.turns.each do |earlier|
          break if earlier['id'] == @turn['id']
          next unless earlier['state'] == 'done' && earlier['answer'].to_s != ''

          @chat.add_message(role: :user, content: earlier['prompt'].to_s)
          @chat.add_message(role: :assistant, content: earlier['answer'].to_s)
        end
      end

      def stream(chunk)
        text = chunk.respond_to?(:content) ? chunk.content : chunk
        return if text.nil? || text.to_s.empty?

        @answer << text.to_s
        @emit.call('delta', 'text' => text.to_s)
        @budget.check_time!
      end

      def tool_started(call)
        @budget.tool_call!
        card = { 'id' => call.id.to_s, 'name' => call.name.to_s, 'args' => arguments(call.arguments),
                 'state' => 'running', 'started' => @clock.call }
        @calls << card
        @emit.call('tool', public_card(card))
      end

      def tool_finished(result)
        card = @calls.reverse.find { |candidate| candidate['state'] == 'running' }
        return unless card

        card['state'] = failed?(result) ? 'failed' : 'done'
        card['ms'] = ((@clock.call - card.delete('started')) * 1000).round
        @emit.call('tool', public_card(card))
        @budget.check_time!
      end

      def count_tokens(message)
        tokens = message.respond_to?(:tokens) ? message.tokens : nil
        count = tokens ? tokens.input.to_i + tokens.output.to_i : 0
        return if count.zero?

        @store.add_tokens(count)
        @budget.tokens!(count)
      end

      def cancelled!
        raise CancelledByUser if @store.turn(@turn['id'])&.dig('cancel')
      end

      def failed?(result)
        result.respond_to?(:error?) && result.error?
      end

      # A short rendering of the arguments for the card: `Post`, `Post, depth 1`.
      def arguments(arguments)
        values = arguments.respond_to?(:to_h) ? arguments.to_h : {}
        values = values.sort_by { |key, _| PRIMARY_ARGUMENTS.include?(key.to_s) ? 0 : 1 }
        values.map do |key, value|
          value = value.to_s
          value = "#{value[0, 60]}…" if value.size > 60
          PRIMARY_ARGUMENTS.include?(key.to_s) ? value : "#{key} #{value}"
        end.join(', ')
      end

      def public_card(card)
        card.except('started')
      end

      def final_text
        if @chat.respond_to?(:messages)
          last = @chat.messages.reverse.find do |message|
            message.role.to_s == 'assistant'
          end
        end
        content = last&.content
        content = content.to_s if content
        content.to_s.strip.empty? ? @answer : content
      end

      def finish(state, answer: @answer, limit: nil, error: nil)
        record = @store.update_turn(@turn['id']) do |turn|
          turn['state'] = state
          turn['answer'] = answer.to_s
          turn['tool_calls'] = @calls.map { |card| public_card(card) }
          turn['tokens'] = @budget.tokens
          turn['elapsed'] = @budget.elapsed.round(1)
          turn['limit'] = limit if limit
          turn['error'] = error if error
        end
        safely_emit(state, record || @turn)
        record
      end

      def safely_emit(state, record)
        @emit.call(state, record.merge('budget' => @budget.to_h))
      rescue Disconnected
        nil
      end
    end
  end
end
