# frozen_string_literal: true

module WoodsMap
  # What a column's default cell says. A published value is shown as
  # published; a published presence flag alone is never read as a value.
  module ColumnDefault
    # What the cell says when the index publishes only that a default exists.
    PRESENCE_ONLY = 'exists, value not published'

    # @param column [Hash] a published column
    # @return [String, nil] nil when the index says nothing about the default
    def self.text(column)
      if column.key?('default')
        value = column['default']
        return value.nil? ? nil : display(value.to_s)
      end
      return PRESENCE_ONLY if column['has_default']

      column['has_default'] == false ? 'none' : nil
    end

    # A value with no visible characters is quoted and escaped, so an empty
    # string and whitespace stay apart from each other and from no default.
    def self.display(text)
      text.strip.empty? ? text.inspect : text
    end
    private_class_method :display
  end
end
