# frozen_string_literal: true

module WoodsMap
  # Schema findings over the whole database (B6-ERD), each the set
  # difference of published facts: the tables' foreign keys, the models'
  # associations and their databases. Nothing here ran against a database.
  class ErdFindings
    include Enumerable

    Finding = Struct.new(:severity, :rule, :where, :evidence, keyword_init: true)

    # @param erd [Erd]
    def initialize(erd)
      @erd = erd
      @list = unenforced + orphan_keys + cross_database_findings + unmodelled + polymorphic_findings
    end

    # @yieldparam finding [Finding]
    def each(&block)
      @list.each(&block)
    end

    # @return [Integer]
    delegate :size, to: :@list

    # @param table [Erd::Table]
    # @return [Array<String>] the rules of the findings that name this table
    def for_table(table)
      select { |f| f.where.any? { |w| w == table.name || w.start_with?("#{table.name}.") } }.map(&:rule)
    end

    # @return [Hash{Symbol => Integer}] the facts tiles' numbers
    def counts
      fks = @erd.relations.select(&:enforced)
      { tables: @erd.tables.size, modelled: @erd.tables.count(&:model), unmodelled: @erd.unmodelled.size,
        foreign_keys: fks.size, fks_with_association: fks.count(&:association),
        associations_without_fk: @erd.relations.count { |r| !r.enforced } + polymorphic.size,
        polymorphic: polymorphic.size, cross_database: cross_database.size }
    end

    # @return [Array<String>] "analytics ↔ primary" pairs crossed by an association
    def cross_database_pairs
      cross_database.map { |_, a| [a['from_db'], a['to_db']].sort.join(' ↔ ') }.uniq
    end

    private

    def polymorphic
      @erd.associations.select { |_, a| a['type'].to_s == 'belongs_to' && a['polymorphic'] }
    end

    def cross_database
      @erd.associations.select { |_, a| @erd.cross_db?(a) }
    end

    def unenforced
      @erd.relations.reject(&:enforced).map do |r|
        model, assoc = @erd.belongs_to.find do |m, a|
          m.dig('metadata', 'table_name') == r.from && a['foreign_key'].to_s == r.column
        end
        Finding.new(severity: :blocking, rule: 'association without a foreign key, not polymorphic',
                    where: ["#{model&.dig('identifier')} belongs_to :#{assoc&.dig('name')}", "#{r.from}.#{r.column}"],
                    evidence: 'associations ∖ foreign_keys')
      end
    end

    def orphan_keys
      @erd.relations.select { |r| r.enforced && !r.association && @erd.table_named(r.from)&.model }.map do |r|
        Finding.new(severity: :blocking, rule: 'foreign key without an association',
                    where: ["#{r.from}.#{r.column} → #{r.to}", "no belongs_to on #{@erd.table_named(r.from).model}"],
                    evidence: 'foreign_keys ∖ associations')
      end
    end

    def cross_database_findings
      cross_database.map do |model, a|
        Finding.new(severity: :note, rule: 'cross-database association, no FK, no join',
                    where: ["#{model['identifier']} #{a['type']} :#{a['name']}", "#{a['from_db']} → #{a['to_db']}"],
                    evidence: 'from_db ≠ to_db')
      end
    end

    def unmodelled
      @erd.unmodelled.map do |name|
        Finding.new(severity: :note, rule: 'unmodelled table', where: [name], evidence: 'database_table, no model')
      end
    end

    def polymorphic_findings
      tables = polymorphic.filter_map { |model, _| model.dig('metadata', 'table_name') }.uniq
      return [] if tables.empty?

      [Finding.new(severity: :note, rule: 'polymorphic columns without FK, by design', where: tables,
                   evidence: 'associations, polymorphic')]
    end
  end
end
