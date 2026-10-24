# frozen_string_literal: true

module WoodsMap
  # The line of a method a span names (W-6), from the target's method table
  # (W-2): in the target itself, or in the concern that owns the
  # definition. Absent table, unknown method or an unplaceable line: nil.
  class MethodLine
    def initialize(repository, unit)
      @repository = repository
      @unit = unit
    end

    # @param name [String, nil]
    # @param kind [String] span kind; a constant receiver calls a class-level method first
    # @return [Hash, nil] {identifier, type, line}
    def call(name, kind:)
      return unless name

      entry = pick(methods(@unit), name, kind)
      return unless entry

      return place(@unit, entry) if entry['owner'] == @unit['identifier']

      concern = @repository.unit(entry['owner'], type: 'concern')
      own = concern && pick(methods(concern), name, kind)
      own && own['owner'] == concern['identifier'] ? place(concern, own) : nil
    rescue IOError
      nil
    end

    private

    def methods(unit)
      Array(unit.dig('metadata', 'methods')).select { |entry| entry.is_a?(Hash) && entry['line'].is_a?(Integer) }
    end

    def pick(entries, name, kind)
      named = entries.select { |entry| entry['name'] == name }
      order = kind == 'constant' ? %w[singleton module_function instance] : %w[instance singleton module_function]
      order.each do |wanted|
        found = named.find { |entry| entry['kind'] == wanted }
        return found if found
      end
      nil
    end

    def place(unit, entry)
      line = References.file_line(unit, entry['line'])
      { identifier: unit['identifier'], type: unit['type'], line: line } if line
    end
  end
end
