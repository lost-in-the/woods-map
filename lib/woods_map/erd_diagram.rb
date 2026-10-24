# frozen_string_literal: true

module WoodsMap
  # The Mermaid erDiagram text of one ERD chunk: its tables with their key
  # columns (or every column) and the relations inside it, dotted where no
  # foreign key enforces them. Relations that leave the chunk are not drawn.
  class ErdDiagram
    # @param erd [Erd]
    # @param chunk [Erd::Chunk]
    # @param columns [String] keys or all
    def initialize(erd, chunk, columns: 'keys')
      @erd = erd
      @chunk = chunk
      @columns = columns
    end

    # @return [String]
    def mermaid
      lines = ['erDiagram']
      @chunk.tables.each { |name| lines.concat(entity_lines(@erd.table_named(name))) }
      @erd.inner_relations(@chunk).each do |r|
        lines << "  #{quoted(r.from)} }o#{r.enforced ? '--' : '..'}|| #{quoted(r.to)} : #{quoted(r.column)}"
      end
      lines.join("\n")
    end

    private

    def entity_lines(table)
      keys = key_marks(table)
      shown = table.columns.select { |c| @columns == 'all' || keys.key?(c['name'].to_s) }
      return ["  #{quoted(table.name)}"] if shown.empty?

      ["  #{quoted(table.name)} {", *shown.map { |c| "    #{attribute(c, keys[c['name'].to_s])}" }, '  }']
    end

    # Mermaid attribute names and types are words; anything else reads as an underscore.
    def attribute(column, marks)
      type = column['type'].to_s.gsub(/\W/, '_').presence || 'unknown'
      text = "#{type} #{column['name'].to_s.gsub(/[^\w-]/, '_')}"
      return text unless marks

      text += " #{marks[:keys].join(', ')}" if marks[:keys].any?
      text += ' "no FK"' if marks[:no_fk]
      text
    end

    # column => { keys: PK, FK, UK; no_fk: an association names it without a key }
    def key_marks(table)
      marks = Hash.new { |h, k| h[k] = { keys: [], no_fk: false } }
      key_columns(table).each { |column, key| marks[column][:keys] |= [key] }
      unenforced_columns(table).each { |column| marks[column][:no_fk] = true }
      marks
    end

    # [column, PK / FK / UK] pairs, the primary key only when the table has the column
    def key_columns(table)
      primary = (table.primary_key.presence || 'id').to_s
      pk = table.columns.any? { |c| c['name'].to_s == primary } ? [[primary, 'PK']] : []
      pk + table.foreign_keys.map { |fk| [fk['column'].to_s, 'FK'] } + unique_columns(table).map { |c| [c, 'UK'] }
    end

    def unenforced_columns(table)
      @erd.relations.select { |r| r.from == table.name && !r.enforced }.map(&:column)
    end

    def unique_columns(table)
      table.indexes.select { |i| i['unique'] && Array(i['columns']).size == 1 }.map { |i| i['columns'].first.to_s }
    end

    def quoted(text)
      "\"#{text.to_s.tr('"', "'")}\""
    end
  end
end
