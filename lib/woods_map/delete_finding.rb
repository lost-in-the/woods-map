# frozen_string_literal: true

module WoodsMap
  # The delete radius of an association that Rails destroys or deletes
  # through: the Rails `dependent:` option beside the database action the
  # foreign key publishes. A nil action is a declared absence; a key without
  # an `on_delete` entry is an adapter that did not report one.
  module DeleteFinding
    module_function

    # @param assoc [Hash] a published association
    # @param key [Hash, nil] the foreign key behind it, when the index publishes one
    # @return [String, nil] nil when the association does not delete
    def text(assoc, key:)
      return 'polymorphic, no FK' if assoc['polymorphic']

      dependent = assoc.dig('options', 'dependent').to_s
      return unless dependent.start_with?('destroy', 'delete')

      "delete radius: Rails dependent #{dependent}; #{database_action(key)}"
    end

    # @param key [Hash, nil]
    # @return [String]
    def database_action(key)
      return 'database delete action not published' unless key&.key?('on_delete')

      "database on_delete #{key['on_delete'] || 'none declared'}"
    end
  end
end
