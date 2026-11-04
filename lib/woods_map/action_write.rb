# frozen_string_literal: true

module WoodsMap
  # Conservative write evidence from one pinned generation's published action flow.
  # No source parsing, action-name inference or receiver guessing is performed.
  module ActionWrite
    # @param repository [Repository] pinned reader
    # @param passage [Passage] exact controller action
    # @param model [Hash] selected model unit
    # @param event [String] selected model event
    # @return [Boolean] a matching operation in this action's own published step
    def self.published?(repository, passage, model, event)
      entry = "#{passage.unit['identifier']}##{passage.action}"
      document = repository.flow_document(entry)
      Array(document && document['steps']).grep(Hash).any? do |step|
        step['unit'] == entry && step['type'] == 'controller' &&
          explicit_write?(step['operations'], model['identifier'], event)
      end
    end

    # @param operations [Array<Hash>, nil] operations of the exact controller action
    # @param target [String] model identifier
    # @param event [String] create, update or destroy
    # @return [Boolean] an unambiguous matching write, including conditional branches
    def self.explicit_write?(operations, target, event)
      Array(operations).grep(Hash).any? do |operation|
        match = operation['type'] == 'call' && operation['target'] == target &&
                operation['method'].to_s.delete_suffix('!') == event &&
                Array(operation['ambiguous_candidates']).empty?
        match || %w[nested then_ops else_ops].any? { |key| explicit_write?(operation[key], target, event) }
      end
    end
    private_class_method :explicit_write?
  end
end
