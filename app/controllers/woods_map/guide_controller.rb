# frozen_string_literal: true

module WoodsMap
  # The guide's writes (M7): ask a question or run an action, stop an answer,
  # start a new conversation, list the session's conversations and open an
  # earlier one. Asking records a pending turn and answers with the URL of
  # its event stream; the answer itself streams from
  # {GuideStreamsController}.
  class GuideController < ApplicationController
    include WoodsMap::GuideSession

    prepend_before_action :json_response
    woods_map_rate_limit :guide, only: :create

    CONTEXT_KEYS = %i[page type identifier lines action_name focus from to].freeze
    MAX_QUESTION = 2000
    TURN = /\A[0-9a-f]{16}\z/

    def create
      store = guide_store
      return render_budget_exhausted(store) if WoodsMap::Guide::Budget.exhausted?(woods_map_config, store.tokens)

      key = params[:action_key].presence
      return invalid('That is not one of the guide actions.') if key && !WoodsMap::Guide::Actions.known?(key)

      question = params[:question].to_s.strip.slice(0, MAX_QUESTION)
      return invalid('Ask a question or pick an action.') if key.nil? && question.empty?

      with_repository { |repository| ask(store, repository, key, question) }
    end

    def cancel
      turn = guide_store.update_turn(params[:id].to_s) { |record| record['cancel'] = true }
      turn ? head(:no_content) : head(:not_found)
    end

    def destroy
      guide_store.reset!
      head :no_content
    end

    # The session's conversations, for the panel's history list.
    def history
      conversations = guide_store.conversations
      render json: { 'conversations' => conversations.size,
                     'html' => render_to_string(partial: 'woods_map/guide/history', formats: [:html],
                                                locals: { conversations: conversations }) }
    end

    # Make an earlier conversation current; answers with its thread.
    def resume
      store = guide_store
      return head(:not_found) unless store.open!(params[:id].to_s)

      with_repository do
        render json: { 'conversation' => store.conversation,
                       'html' => render_to_string(partial: 'woods_map/guide/turns', formats: [:html],
                                                  locals: { turns: store.turns, about: nil }) }
      end
    rescue WoodsMap::Guide::Store::Busy => e
      render json: { 'error' => 'busy', 'message' => "#{e.message} Stop it first." }, status: :conflict
    end

    private

    def ask(store, repository, key, question)
      context = WoodsMap::Guide::Context.from(repository, context_params)
      refusal = missing_context(key, context)
      return invalid(refusal) if refusal

      source = source_turn(store, key)
      return invalid('Pick a finished answer to draft the issue from.') if key && needs(key) == :answer && source.nil?

      turn = store.add_turn(turn_attributes(key, question, context, source))
      render json: { 'id' => turn['id'], 'stream' => woods_map.guide_stream_path(id: turn['id']),
                     'cancel' => woods_map.guide_cancel_path(id: turn['id']),
                     'html' => render_to_string(partial: 'woods_map/guide/asked', formats: [:html],
                                                locals: { turn: turn }) }
    end

    # What the turn records: the action, the question, the prompt built from
    # the context (and, for an answer action, the answer it works from).
    def turn_attributes(key, question, context, source)
      prompt = WoodsMap::Guide::Actions.prompt(key, context: context.to_prompt, question: question,
                                                    answer: source&.dig('answer'))
      { 'action' => key, 'label' => key && WoodsMap::Guide::Actions.label(key), 'question' => question,
        'prompt' => prompt, 'context' => context.to_h,
        'kind' => ('issue' if key == 'draft_issue'), 'source' => source&.dig('id') }.compact
    end

    def needs(key)
      WoodsMap::Guide::Actions::LIST[key][:needs]
    end

    def missing_context(key, context)
      return unless key

      case needs(key)
      when :lines then 'Select lines in the code first.' if context.lines.nil?
      when :nodes then if context.nodes.empty?
                         'Select units on the graph first: Shift+click them, or Space on the canvas.'
                       end
      end
    end

    # The finished answer an answer action works from, in this conversation.
    def source_turn(store, key)
      return unless key && needs(key) == :answer

      id = params[:source].to_s
      return unless id.match?(TURN)

      turn = store.turn(id)
      turn if turn && %w[done limited].include?(turn['state']) && turn['answer'].to_s.strip != ''
    end

    def context_params
      raw = params[:context]
      return {} unless raw.respond_to?(:permit)

      raw.permit(*CONTEXT_KEYS, focus: [], nodes: []).to_h
    end

    def json_response
      request.format = :json
      response.headers['Cache-Control'] = 'no-store'
    end

    # 422 by number: Rack 3.1 renamed the symbol and the Rails 6.0 floor knows only the old one.
    def invalid(message)
      render json: { 'error' => 'invalid', 'message' => message }, status: 422 # rubocop:disable Rails/HttpStatus
    end

    def render_budget_exhausted(store)
      budget = woods_map_config.guide_token_budget
      render json: { 'error' => 'budget', 'tokens' => store.tokens, 'token_budget' => budget,
                     'message' => "This session has spent its #{budget} tokens. " \
                                  'The guide answers again in a new browser session.' },
             status: :too_many_requests
    end

    def render_unavailable(_error)
      render json: { 'error' => 'index_unavailable', 'message' => 'No published Woods index.' },
             status: :service_unavailable
    end

    def refuse(_reason)
      render json: { 'error' => 'forbidden' }, status: :forbidden
    end
  end
end
