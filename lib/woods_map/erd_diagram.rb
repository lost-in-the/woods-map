# frozen_string_literal: true

module WoodsMap
  # The Mermaid erDiagram text of one ERD chunk: its tables with their key
  # columns (or every column) and the relations inside it, dotted where no
  # foreign key enforces them. Relations that leave the chunk are not drawn.
  class ErdDiagram
    # @param erd [Erd]
    # @param chunk [Erd::Chunk]
    # @param columns [String] keys or all
    # @param notes [Hash{String => Hash{String => String}}] table name => column
    #   name => a note drawn as the attribute's comment (`?since=`, E-8); a
    #   noted column is drawn even in the keys-only view
    def initialize(erd, chunk, columns: 'keys', notes: {})
      @erd = erd
      @chunk = chunk
      @columns = columns
      @notes = notes
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
      notes = @notes.fetch(table.name, {})
      shown = table.columns.map { |c| c['name'].to_s }.zip(table.columns)
                   .select { |name, _| @columns == 'all' || keys.key?(name) || notes.key?(name) }
      return ["  #{quoted(table.name)}"] if shown.empty?

      attributes = shown.map { |name, c| "    #{attribute(c, keys.fetch(name, nil), notes[name])}" }
      ["  #{quoted(table.name)} {", *attributes, '  }']
    end

    # Mermaid attribute names and types are words; anything else reads as an underscore.
    def attribute(column, marks, note = nil)
      type = column['type'].to_s.gsub(/\W/, '_').presence || 'unknown'
      text = "#{type} #{column['name'].to_s.gsub(/[^\w-]/, '_')}"
      text += " #{marks[:keys].join(', ')}" if marks && marks[:keys].any?
      comment = [('no FK' if marks && marks[:no_fk]), note].compact.join(', ')
      comment.empty? ? text : "#{text} #{quoted(comment)}"
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
