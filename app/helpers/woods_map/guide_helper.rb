# frozen_string_literal: true

module WoodsMap
  # The guide panel's page context, state and budget line (B8-Guide, M7).
  module GuideHelper
    # @return [Symbol] :disabled, :ruby, :missing or :ready
    def guide_status
      WoodsMap::Guide.status(woods_map_config)
    end

    # @return [WoodsMap::Guide::Context, nil] the page's context, from its own generation
    def guide_context
      WoodsMap::Guide::Context.new(current_repository, guide_page_values) if current_repository
    end

    # @return [Boolean] whether this page shows the Guide button at all
    def guide_visible?
      guide_status != :disabled
    end

    # The browser's guide session, when it has one; the page never creates it.
    #
    # @return [WoodsMap::Guide::Store, nil]
    def guide_view_store
      id = cookies.signed[WoodsMap::GuideSession::COOKIE].to_s
      WoodsMap::Guide::Store.new(woods_map_config.guide_chats_path, id) if id.match?(WoodsMap::Guide::Store::ID)
    end

    # @return [String] "claude-sonnet via host config"
    def guide_model_label
      model = woods_map_config.guide_chat_options.to_h.transform_keys(&:to_s)['model']
      "#{model || 'default model'} via host config"
    end

    # @param count [Integer]
    # @return [String] 6.2k, 950
    def guide_tokens(count)
      count.to_i >= 1000 ? "#{(count.to_i / 100).fdiv(10).round(1)}k" : count.to_i.to_s
    end

    # The rendered answer of a finished turn, linked against this page's
    # generation.
    #
    # @param turn [Hash]
    # @return [ActiveSupport::SafeBuffer]
    def guide_answer_html(turn)
      identifiers = current_repository ? current_repository.identifier_index : {}
      html = WoodsMap::Guide::Answer.new(turn['answer'].to_s, identifiers: identifiers,
                                                              link: lambda { |identifier, type|
                                                                woods_map.unit_path(type: type, identifier: identifier)
                                                              }).to_html
      html.html_safe # rubocop:disable Rails/OutputSafety -- Answer escapes every input and emits only its own tags
    end

    # @param turn [Hash]
    # @return [String] "guide, 4 tool calls, 2.8 s"
    def guide_who(turn)
      calls = Array(turn['tool_calls']).size
      ['guide', ("#{calls} tool #{calls == 1 ? 'call' : 'calls'}" if calls.positive?),
       ("#{turn['elapsed']} s" if turn['elapsed'])].compact.join(', ')
    end
  end
end
