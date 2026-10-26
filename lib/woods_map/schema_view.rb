# frozen_string_literal: true

module WoodsMap
  # The Schema tab (B6-Schema): associations with their keys and whether the
  # database enforces them, the columns with their indexes, and the database
  # facts the schema and the graph analysis prove.
  class SchemaView
    Association = Struct.new(:macro, :name, :target, :options, :foreign_key, :enforced, :finding, keyword_init: true)
    Column = Struct.new(:name, :type, :null, :default, :index, :written_by, keyword_init: true)

    # ER table budget (R-4): above it the panel names the budget and keeps
    # the text, rather than drawing a diagram nobody can read.
    TABLE_BUDGET = 40

    # The Schema tab of a unit in one generation, its far tables read from the graph.
    #
    # @param repository [Repository]
    # @param unit [Hash]
    # @param table [Hash, nil]
    # @return [SchemaView]
    def self.for(repository, unit, table: nil)
      lookup = ->(name) { repository.unit("table:#{name}", type: 'database_table') }
      new(unit, table: table, graph_analysis: repository.graph_analysis, tables: repository.model_tables,
                repository: repository, table_lookup: lookup)
    end

    # @param unit [Hash] a model or database_table unit
    # @param table [Hash, nil] the database_table unit behind a model
    # @param graph_analysis [Hash]
    # @param tables [Hash{String => String}] model identifier => its table, from
    #   the graph nodes' `table`, so an association's far side is the table the
    #   model reads rather than a guess from its name
    # @param repository [Repository, nil] when given, the ER text comes from Woods' builder (woods#826)
    # @param table_lookup [#call, nil] table name => its database_table unit,
    #   read now for the far side of has_many and has_one
    def initialize(unit, table: nil, graph_analysis: {}, tables: {}, repository: nil, table_lookup: nil) # rubocop:disable Metrics/ParameterLists
      @unit = unit
      @repository = repository
      @tables = tables
      @metadata = unit['metadata'] || {}
      @table = table
      @table_metadata = (table || (unit['type'] == 'database_table' ? unit : nil))&.dig('metadata') || {}
      @analysis = graph_analysis
      @incoming = IncomingForeignKeys.new(table_name, table_lookup, incoming_associations.map { |a| target_table(a) })
    end

    # @return [SchemaClassDiagram] the class diagram of the same model
    def class_diagram = @class_diagram ||= SchemaClassDiagram.new(@unit)

    # @return [String, nil]
    def table_name
      @metadata['table_name'] || @table_metadata['table_name']
    end

    # @return [Array<Association>]
    def associations
      Array(@metadata['associations']).map do |a|
        fk = a['through'] ? nil : a['foreign_key']
        Association.new(macro: "#{a['type']} :#{a['name']}", name: a['name'], target: a['target'],
                        options: options_text(a), foreign_key: fk && key_text(a, fk),
                        enforced: enforcement(a, fk), finding: finding_for(a))
      end
    end

    # @return [Array<Column>]
    def columns
      Array(@metadata['columns'].presence || @table_metadata['columns']).map do |c|
        Column.new(name: c['name'], type: c['type'] || c['sql_type'], null: c['null'] == false ? 'no' : 'yes',
                   default: ColumnDefault.text(c),
                   index: index_for(c['name']), written_by: writers[c['name'].to_s])
      end
    end

    # @return [Array<Hash>] the indexes of the table
    def indexes
      Array(@table_metadata['indexes'])
    end

    # @return [Array<Array(String, String, String)>] fact, value, source
    def facts
      [
        ['association without FK', unenforced.presence&.join(', ') || 'none', 'associations ∖ foreign_keys'],
        ['FK without association', orphan_keys.presence&.join(', ') || 'none', 'foreign_keys ∖ associations'],
        ['cross-database', cross_database.presence&.join(', ') || "none, all on #{@metadata['database'] || 'primary'}",
         'from_db / to_db'],
        ['unmodelled tables', unmodelled.presence&.join(', ') || 'none', 'graph_analysis.unmodelled_tables']
      ]
    end

    # Mermaid erDiagram text for this table and one hop of associations. The
    # table is declared first, so a model without associations still draws.
    # Woods' own builder draws it when the loaded Woods has one (woods#826).
    #
    # @return [String]
    def mermaid
      WoodsDiagrams.schema(@repository, @unit) || local_mermaid
    end

    # The map's own ER text, for a Woods without the diagram builders.
    #
    # @return [String]
    def local_mermaid
      lines = ['erDiagram']
      lines << "  #{entity(table_name)}" if table_name.present?
      er_associations.each do |a|
        cardinality = a['type'].to_s.start_with?('belongs_to') ? '}o--||' : '||--o{'
        lines << "  #{entity(table_name)} #{cardinality} #{entity(target_table(a))} : \"#{a['name']}\""
      end
      lines.join("\n")
    end

    # @return [Integer] distinct tables the ER diagram draws, this one included
    def table_count
      # compact_blank arrived in Rails 6.1; the engine's floor is 6.0.
      ([table_name] + er_associations.map { |a| target_table(a) }).reject(&:blank?).uniq.size # rubocop:disable Rails/CompactBlank
    end

    # @return [Boolean] whether the ER diagram would exceed {TABLE_BUDGET}
    def over_budget?
      table_count > TABLE_BUDGET
    end

    # @return [String, nil] why the diagram is not drawn, nil within the budget
    def refusal
      "#{table_count} tables is over the ER budget of #{TABLE_BUDGET}" if over_budget?
    end

    private

    # The far table of an association: the target model's published table,
    # else Rails' default for the name (`ActiveStorage::Attachment` reads
    # `active_storage_attachments`, not `active_storage/attachments`).
    def target_table(assoc)
      target = assoc['target'].to_s
      @tables[target].presence || target.tableize.tr('/', '_')
    end

    def er_associations
      Array(@metadata['associations']).reject { |a| a['through'] }
    end

    # An ER entity as a quoted name: Mermaid keeps `audit.logs` and
    # `audit_logs` apart and shows each as written. A double quote cannot be
    # escaped inside the name, so it reads as a single one.
    def entity(name)
      "\"#{name.to_s.tr('"', "'")}\""
    end

    def options_text(assoc)
      opts = (assoc['options'] || {}).map { |k, v| "#{k}: #{v.inspect}" }
      opts << "through: :#{assoc['through']}" if assoc['through']
      opts << "as: :#{assoc['polymorphic']}" if assoc['polymorphic'].is_a?(String)
      opts.join(', ')
    end

    def key_text(assoc, key)
      assoc['type'].to_s == 'belongs_to' ? "#{table_name}.#{key}" : "#{target_table(assoc)}.#{key}"
    end

    def enforcement(assoc, key)
      return 'via join' if assoc['through']
      return 'none' if assoc['polymorphic'] || (key.nil? && owning?(assoc))
      return @incoming.state(target_table(assoc), key) unless owning?(assoc)

      foreign_keys.find { |fkey| fkey['column'].to_s == key.to_s } ? '✓ enforced' : 'none'
    end

    def owning?(assoc)
      assoc['type'].to_s == 'belongs_to'
    end

    def incoming_associations
      Array(@metadata['associations']).reject { |a| a['through'] || a['polymorphic'] || owning?(a) }
    end

    def foreign_keys
      Array(@table_metadata['foreign_keys'].presence || @metadata['foreign_keys'])
    end

    def finding_for(assoc)
      return 'polymorphic, no FK' if assoc['polymorphic']

      dependent = assoc.dig('options', 'dependent').to_s
      return unless dependent.start_with?('destroy', 'delete')

      "delete radius: Rails dependent #{dependent}; database delete action not published"
    end

    def index_for(column)
      hits = indexes.select { |i| Array(i['columns']).include?(column) }
      return 'PK' if column.to_s == (@metadata['primary_key'] || @table_metadata['primary_key'] || 'id').to_s

      hits.map { |i| i['unique'] ? "#{i['name']}, unique" : i['name'] }.join('; ').presence
    end

    def writers
      @writers ||= Array(@metadata['callbacks']).each_with_object(Hash.new { |h, k| h[k] = [] }) do |cb, map|
        Array(cb.dig('side_effects', 'columns_written')).each do |col|
          map[col.to_s] << "#{cb['type']} :#{cb['filter']}"
        end
      end
    end

    def unenforced
      missing = Array(@metadata['associations']).select do |a|
        a['type'].to_s == 'belongs_to' && enforcement(a, a['foreign_key']) == 'none'
      end
      missing.map { |a| "#{table_name}.#{a['foreign_key']}#{' (polymorphic)' if a['polymorphic']}" }
    end

    def orphan_keys
      columns_with_assoc = Array(@metadata['associations']).map { |a| a['foreign_key'].to_s }
      orphans = foreign_keys.reject { |fkey| columns_with_assoc.include?(fkey['column'].to_s) }
      orphans.map { |fkey| "#{fkey['column']} → #{fkey['to_table']}" }
    end

    def cross_database
      Array(@metadata['associations']).select { |a| a['from_db'] && a['to_db'] && a['from_db'] != a['to_db'] }
                                      .map { |a| "#{a['name']}: #{a['from_db']} → #{a['to_db']}" }
    end

    def unmodelled
      Array(@analysis['unmodelled_tables']).map { |t| t.is_a?(Hash) ? t['table'] || t['name'] : t.to_s }
    end
  end
end
