# frozen_string_literal: true

module WoodsMap
  # The structured transition callbacks of a state machine (woods#796) as
  # the Lifecycle tab's transitions table shows them: the method linked to
  # its line, the side effects Woods analysed, or why it was not analysed.
  module StateMachineHelper
    # @param callbacks [Array<StateMachineView::Callback>] one phase's callbacks
    # @param model [Hash, nil] the model unit that defines the methods
    # @return [ActiveSupport::SafeBuffer]
    def transition_callbacks_cell(callbacks, model)
      return empty_value(applicable: false) if callbacks.blank?

      safe_join(callbacks.map { |callback| transition_callback_entry(callback, model) }, tag.br)
    end

    # @param callback [StateMachineView::Callback]
    # @param model [Hash, nil]
    # @return [ActiveSupport::SafeBuffer]
    def transition_callback_entry(callback, model)
      name = callback.block ? tag.span('block', class: 'dim') : transition_callback_link(callback.method_name, model)
      unanalysed = callback.unanalysed unless callback.block
      notes = callback.effects.presence || [unanalysed && "not analysed: #{unanalysed}"].compact
      prefix = callback.phase == 'after_failure' ? 'on failure ' : ''
      safe_join([prefix, name, *notes.map { |note| tag.span(" #{note}", class: 'dim') }].compact)
    end

    # The method's line from the model's method table (W-2), else the model's page.
    #
    # @param method_name [String]
    # @param model [Hash, nil]
    # @return [ActiveSupport::SafeBuffer]
    def transition_callback_link(method_name, model)
      return ERB::Util.html_escape(method_name) unless model

      place = WoodsMap::MethodLine.new(current_repository, model).call(method_name, kind: 'instance')
      unless place
        return link_to(method_name,
                       woods_map.unit_path(type: model['type'], identifier: model['identifier']))
      end

      link_to(method_name,
              woods_map.unit_path(type: place[:type], identifier: place[:identifier], anchor: "L#{place[:line]}"))
    end
  end
end
