# frozen_string_literal: true

module WoodsMap
  # The whole database by chunk (B6-ERD, `/woods/erd`): every published
  # `database_table` unit, grouped by database and by the namespace of its
  # model, each group cut into chunks no larger than the ER table budget
  # (R-4) so every chunk draws. Relations come from the tables' foreign keys
  # and the models' `belongs_to` associations. The text is {ErdDiagram}'s,
  # the findings {ErdFindings}'. Built once per generation.
  class Erd
    Table = Struct.new(:name, :identifier, :database, :model, :namespace, :columns, :primary_key, :indexes,
                       :foreign_keys, :model_less, keyword_init: true)
    # One relation between two tables: enforced when the database holds a
    # foreign key on the column, association when a model declares it.
    Relation = Struct.new(:from, :column, :to, :enforced, :association, keyword_init: true)
    # A numbered chunk of at most the table budget.
    Chunk = Struct.new(:number, :database, :group, :part, :parts, :tables, keyword_init: true) do
      # @return [String] "billing", "billing 2 of 3"
      def label
        parts > 1 ? "#{group} #{part} of #{parts}" : group
      end
    end

    GROUPINGS = %w[namespace database].freeze
    COLUMN_MODES = %w[keys all].freeze
    NO_NAMESPACE = '(no namespace)'
    CACHE_SIZE = 4
    @cache = {}
    @mutex = Mutex.new

    class << self
      # @param repository [WoodsMap::Repository]
      # @return [Erd] the generation's ERD, read once and kept in a small process cache
      def for(repository)
        key = repository.generation_key
        @mutex.synchronize do
          @cache.fetch(key) do
            @cache.shift while @cache.size >= CACHE_SIZE
            @cache[key] = build(repository)
          end
        end
      end

      # @return [void]
      def reset!
        @mutex.synchronize { @cache.clear }
      end

      # Read the generation's tables and models, uncached.
      #
      # @param repository [WoodsMap::Repository]
      # @return [Erd]
      def build(repository)
        unmodelled = Array(repository.graph_analysis['unmodelled_tables']).map do |t|
          t.is_a?(Hash) ? (t['table'] || t['name']).to_s : t.to_s
        end
        new(tables: read(repository, 'database_table'), models: read(repository, 'model'), unmodelled: unmodelled)
      end

      private

      # Full units of a type, each with the namespace its index entry records.
      def read(repository, type)
        repository.units(type: type).filter_map do |entry|
          unit = repository.unit(entry['identifier'], type: type)
          unit&.merge('namespace' => entry['namespace'] || unit['namespace'])
        end
      end
    end

    # @param tables [Array<Hash>] database_table units
    # @param models [Array<Hash>] model units, each with its index 'namespace'
    # @param unmodelled [Array<String>] graph_analysis.unmodelled_tables
    def initialize(tables:, models:, unmodelled: [])
      @models = models.index_by { |m| m['identifier'] }
      @model_tables = @models.transform_values { |m| m.dig('metadata', 'table_name') }.compact
      @tables = tables.filter_map { |unit| table(unit) }.sort_by(&:name).index_by(&:name)
      resolved, @unresolved_unmodelled = resolve_analysis_names(unmodelled)
      @unmodelled = (resolved + @tables.values.select(&:model_less).map(&:name)).uniq.sort
      @chunks = {}
    end

    # @return [Array<String>] published tables no model maps, by name
    attr_reader :unmodelled

    # @return [Array<String>] names the graph analysis calls unmodelled that
    #   no published table answers to; kept out of every physical count
    attr_reader :unresolved_unmodelled

    # @return [Array<Hash>] the model units
    def models
      @models.values
    end

    # @return [Array<Table>] every table, by name
    def tables
      @tables.values
    end

    # @param name [String]
    # @return [Table, nil]
    def table_named(name)
      @tables[name]
    end

    # @return [Array<String>] databases, primary first
    def databases
      tables.map(&:database).uniq.sort_by { |db| [db == 'primary' ? 0 : 1, db] }
    end

    # Chunks in reading order: by database, then group, then part. A group
    # larger than the budget is cut along its relations, so related tables
    # stay together where they can.
    #
    # @param by [String] namespace or database
    # @return [Array<Chunk>]
    def chunks(by)
      @chunks[by] ||= ErdChunks.new(self).call(by)
    end

    # @param by [String]
    # @param number [Integer] 1-based
    # @return [Chunk, nil]
    def chunk(by, number)
      chunks(by).find { |c| c.number == number }
    end

    # @return [Array<Relation>] foreign keys and belongs_to associations, one per table, column and target
    def relations
      @relations ||= begin
        found = foreign_key_relations
        belongs_to.each do |model, assoc|
          from = model.dig('metadata', 'table_name')
          to = @model_tables[assoc['target'].to_s]
          next unless from && to

          key = [from, assoc['foreign_key'].to_s, to]
          (found[key] ||= Relation.new(from: from, column: key[1], to: to, enforced: false)).association = true
        end
        found.values.sort_by { |r| [r.from, r.column, r.to] }
      end
    end

    # @return [Array<Array(Hash, Hash)>] model and association for every
    #   same-database, non-polymorphic belongs_to with a foreign key column
    def belongs_to
      associations.select do |_, a|
        a['type'].to_s == 'belongs_to' && !a['polymorphic'] && !a['through'] && a['foreign_key'].present? &&
          !cross_db?(a)
      end
    end

    # @return [Array<Array(Hash, Hash)>] every model and association
    def associations
      @associations ||= models.flat_map { |m| Array(m.dig('metadata', 'associations')).map { |a| [m, a] } }
    end

    # @param assoc [Hash]
    # @return [Boolean] whether the association joins two databases
    def cross_db?(assoc)
      assoc['from_db'].present? && assoc['to_db'].present? && assoc['from_db'] != assoc['to_db']
    end

    # @param chunk [Chunk]
    # @return [Array<Relation>] relations with both ends in the chunk
    def inner_relations(chunk)
      relations.select { |r| chunk.tables.include?(r.from) && chunk.tables.include?(r.to) }
    end

    # @param chunk [Chunk]
    # @param by [String]
    # @return [Array<Array(Relation, Chunk)>] relations leaving or entering the
    #   chunk, with the chunk at the other end; listed, never drawn
    def crossing_relations(chunk, by)
      owner = chunks(by).flat_map { |c| c.tables.map { |t| [t, c] } }.to_h
      relations.filter_map do |r|
        inside = [chunk.tables.include?(r.from), chunk.tables.include?(r.to)]
        [r, owner[inside.first ? r.to : r.from]] if inside.one?
      end
    end

    # @param chunk [Chunk]
    # @param columns [String] keys or all
    # @return [String] the chunk's erDiagram text (see {ErdDiagram})
    def mermaid(chunk, columns: 'keys', notes: {})
      ErdDiagram.new(self, chunk, columns: columns, notes: notes).mermaid
    end

    # @return [ErdFindings] the whole database's findings and facts
    def findings
      @findings ||= ErdFindings.new(self)
    end

    private

    # The analysis names a table typed ("table:x") or bare ("x"). Each name
    # is resolved to a published table; a name that matches none stays a name.
    def resolve_analysis_names(names)
      found = names.map { |raw| [raw, @tables[raw.delete_prefix('table:')]&.name] }
      unresolved = found.select { |_, name| name.nil? }.map { |raw, _| raw.delete_prefix('table:') }
      [found.filter_map(&:last), unresolved.uniq.sort]
    end

    def table(unit)
      meta = unit['metadata'] || {}
      name = meta['table_name'].presence || unit['identifier'].to_s.delete_prefix('table:')
      return nil if name.blank?

      model = meta['model'].presence || Array(meta['models']).first
      Table.new(name: name, identifier: unit['identifier'], model: model,
                model_less: meta['model_less'] == true || model.nil?,
                namespace: @models.dig(model, 'namespace').presence || NO_NAMESPACE, **table_facts(meta))
    end

    def table_facts(meta)
      { database: (meta['database'].presence || 'primary').to_s, columns: Array(meta['columns']),
        primary_key: meta['primary_key'], indexes: Array(meta['indexes']), foreign_keys: Array(meta['foreign_keys']) }
    end

    def foreign_key_relations
      tables.each_with_object({}) do |t, found|
        t.foreign_keys.each do |fk|
          key = [t.name, fk['column'].to_s, fk['to_table'].to_s]
          found[key] = Relation.new(from: key[0], column: key[1], to: key[2], enforced: true, association: false)
        end
      end
    end
  end
end
