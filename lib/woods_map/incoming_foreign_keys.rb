# frozen_string_literal: true

module WoodsMap
  # What the index says about the database constraint behind a has_many or
  # has_one: the foreign key the far table publishes to this table. Only a
  # published key counts; anything else is unchecked, with the reason, and
  # never reads as an absent constraint.
  class IncomingForeignKeys
    # @param table_name [String] the table the foreign key must point at
    # @param lookup [#call, nil] table name => its database_table unit, nil
    #   when the index does not hold it; read now, for every far table
    # @param far_tables [Array<String>] the tables to read
    def initialize(table_name, lookup, far_tables)
      @table_name = table_name
      @far_tables = lookup ? far_tables.uniq.index_with { |name| lookup.call(name) } : {}
    end

    # @param far_table [String]
    # @param column [String, nil] the association's foreign key column
    # @return [String]
    def state(far_table, column)
      return 'unchecked: association publishes no foreign key' if column.blank?

      unit = @far_tables[far_table]
      return "unchecked: table #{far_table} not in the index" unless unit

      key = key_for(far_table, column)
      return "✓ FK #{far_table}.#{column} → #{@table_name}" if key

      "unchecked: no foreign key to #{@table_name} published on #{far_table}"
    end

    # @param far_table [String]
    # @param column [String, nil]
    # @return [Hash, nil] the published foreign key from far_table.column to this table
    def key_for(far_table, column)
      unit = @far_tables[far_table]
      return unless unit

      Array(unit.dig('metadata', 'foreign_keys')).find do |fk|
        fk['column'].to_s == column.to_s && fk['to_table'].to_s == @table_name.to_s
      end
    end
  end
end
