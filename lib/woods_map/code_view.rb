# frozen_string_literal: true

require 'erb'

module WoodsMap
  # The Code tab: the composite source as lines with their numbers, syntax
  # classes, marginalia and reference links, in one of the two lenses (D-6).
  #
  # - *as written*: the file's own lines with the file's numbers;
  # - *effective class*: the schema header folded above the class, the file's
  #   lines, and each inlined concern de-commented under an "included from"
  #   fold with `c:N` numbers.
  class CodeView
    Row = Struct.new(:kind, :number, :label, :html, :note, :fold, :concern, keyword_init: true)

    LENSES = %w[written effective].freeze

    # @param unit [Hash]
    # @param lens [String] one of {LENSES}
    # @param references [WoodsMap::References]
    # @param marginalia [WoodsMap::Marginalia]
    # @param unit_path [#call] identifier, type => URL
    def initialize(unit, lens:, references:, marginalia:, unit_path:)
      @unit = unit
      @lens = LENSES.include?(lens.to_s) ? lens.to_s : 'effective'
      @composite = CompositeSource.new(unit)
      @references = references
      @marginalia = marginalia
      @unit_path = unit_path
    end

    attr_reader :lens, :composite

    # @return [Array<Row>] what the view renders, in order
    def rows
      @rows ||= @lens == 'written' ? written_rows : effective_rows
    end

    # @return [Integer] lines in the file itself
    def line_count
      @composite.file_lines.size
    end

    # @return [Integer, nil] the file line of the first class or module definition
    delegate :definition_line, to: :@composite

    private

    def written_rows
      links = @references.by_source_line(@composite.file_lines)
      highlighted = highlight(@composite.file_lines, links)
      @composite.file_lines.zip(highlighted).map do |line, html|
        file_line = line.label.to_i
        Row.new(kind: :line, number: file_line, label: line.label, html: html,
                note: @marginalia.for_line(line.text))
      end
    end

    def effective_rows
      rows = []
      header = @composite.header.reject(&:empty?)
      rows << Row.new(kind: :fold, html: header_summary(header), fold: :header) if header.any?
      rows.concat(written_rows)
      @composite.concerns.each do |name, lines|
        rows << Row.new(kind: :fold, html: "included from #{ERB::Util.html_escape(name)}, #{lines.size} lines",
                        fold: :concern, concern: name)
        highlight(lines).each_with_index do |html, index|
          rows << Row.new(kind: :line, label: lines[index].label, html: html,
                          note: @marginalia.for_line(lines[index].text), concern: name)
        end
      end
      rows
    end

    def header_summary(header)
      table = header.find { |line| line.start_with?('Table:') }.to_s.sub('Table:', '').strip
      columns = header.grep(/\A\s{2}\w+\s{2,}/).map { |line| line.strip.split(/\s+/).first(2).join(':') }
      shown = columns.first(6)
      rest = columns.size - shown.size
      more = rest.positive? ? ", #{rest} more" : ''
      ERB::Util.html_escape("# schema: #{table}, #{shown.join(', ')}#{more}")
    end

    def highlight(lines, links = {})
      references = lines.each_with_index.to_h { |line, index| [index + 1, links.fetch(line.number, [])] }
      source = "#{lines.map(&:text).join("\n")}\n"
      Highlighter.lines(source, language: Highlighter.language_for(@unit['file_path']),
                                references: references, unit_path: @unit_path)
    end
  end
end
