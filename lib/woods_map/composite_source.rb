# frozen_string_literal: true

module WoodsMap
  # The structure of a unit's published `source_code`: the schema header the
  # extractor prepends, the file's own lines (located by `source_line_map`),
  # and the concern blocks it inlines as commented code. Nothing here reads a
  # file; the two lenses of D-6 are two readings of the same published text.
  class CompositeSource
    # One line of the composite with where it came from.
    Line = Struct.new(:number, :text, :origin, :label, :concern, keyword_init: true)

    INCLUDED_FROM = /\A# │ Included from: (\S+)/
    END_BLOCK = /\A# ─+ End (\S+) ─+\z/
    FRAME = /\A# [┌└]─+[┐┘]\z/
    DEFINITION = /\A\s*(class|module)\s/

    # @param unit [Hash] a published unit
    def initialize(unit)
      @source = unit['source_code'].to_s
      @map = Array(unit.dig('metadata', 'source_line_map'))
    end

    # Every composite line tagged with its origin: :header (the schema block),
    # :file (with the file's own line number), :concern (de-commented, labelled
    # `c:N`) or :frame (the concern block's decoration).
    #
    # @return [Array<Line>]
    def lines
      @lines ||= classify
    end

    # @return [Array<Line>] the file's own lines only (the as-written lens)
    def file_lines
      lines.select { |line| line.origin == :file }
    end

    # @return [Array<String>] the schema header's lines without the comment marks
    def header
      lines.select { |line| line.origin == :header }.map { |line| line.text.sub(/\A#\s?/, '') }
    end

    # @return [Hash{String => Array<Line>}] concern name => its de-commented lines
    def concerns
      lines.select { |line| line.origin == :concern }.group_by(&:concern)
    end

    # @return [Integer, nil] the file line of the first class or module definition
    def definition_line
      file_lines.find { |line| line.text.match?(DEFINITION) }&.label&.to_i
    end

    # @param file_line [Integer]
    # @return [Integer, nil] the composite line that holds a file line
    def composite_line_for(file_line)
      @map.each do |composite_start, file_start, length|
        return composite_start + (file_line - file_start) if file_line.between?(file_start, file_start + length - 1)
      end
      nil
    end

    private

    def classify
      raw = @source.split("\n", -1)
      raw.pop if raw.last == ''
      file_numbers = file_line_numbers(raw.size)
      state = { concern: nil, counter: 0 }
      raw.each_with_index.map do |text, index|
        number = index + 1
        if file_numbers.key?(number)
          Line.new(number: number, text: text, origin: :file, label: file_numbers[number].to_s)
        else
          decorated_line(number, text, state)
        end
      end
    end

    # A line outside the file: the header, a concern block's frame, or a
    # concern line (de-commented and counted).
    def decorated_line(number, text, state)
      if (match = text.match(INCLUDED_FROM))
        state[:concern] = match[1]
        state[:counter] = 0
        Line.new(number: number, text: text, origin: :frame, label: '', concern: match[1])
      elsif text.match?(END_BLOCK)
        state[:concern] = nil
        Line.new(number: number, text: text, origin: :frame, label: '')
      elsif state[:concern] && !text.match?(FRAME)
        state[:counter] += 1
        Line.new(number: number, text: text.sub(/\A#\s{0,3}/, ''), origin: :concern, label: "c:#{state[:counter]}",
                 concern: state[:concern])
      else
        origin = state[:concern] || text.match?(FRAME) ? :frame : :header
        Line.new(number: number, text: text, origin: origin, label: '')
      end
    end

    # composite line number => file line number, from the line map; a unit
    # without a map is all file.
    def file_line_numbers(total)
      return (1..total).to_h { |n| [n, n] } if @map.empty?

      @map.each_with_object({}) do |(composite_start, file_start, length), numbers|
        length.times { |offset| numbers[composite_start + offset] = file_start + offset }
      end
    end
  end
end
