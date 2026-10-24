# frozen_string_literal: true

require 'woods/source_line_map'

module WoodsMap
  # Published reference spans (W-1, W-6), admitted only by their exact typed
  # identity in this request's generation. Coordinates address annotated
  # source bytes; file gutter labels and the internal reference cache are
  # never consulted.
  #
  # - `verified` and `static` spans link to their target unit. A span that
  #   names a method (W-6) the target's method table (W-2) defines links to
  #   that method's line, in the target or in the concern that owns it.
  # - `ambiguous` spans link nowhere: they open the disambiguation popover
  #   listing every published candidate. The map never picks one.
  class References
    include SpanValidation

    Link = Struct.new(:column, :length, :identifier, :type, :kind, :confidence, :method, :line, :popover, :text,
                      keyword_init: true)
    # One ambiguous occurrence: its popover id, spelling and typed candidates.
    Ambiguity = Struct.new(:id, :text, :method, :candidates, keyword_init: true)
    Span = Struct.new(:first, :last, :record)
    private_constant :Span
    FIELDS = %w[line column length target target_type kind confidence method candidates].freeze

    # @param repository [WoodsMap::Repository] pinned for the request
    # @param unit [Hash] published unit with annotated source and metadata
    def initialize(repository, unit)
      @repository = repository
      @unit = unit
      @source = unit['source_code'].to_s.dup.force_encoding(Encoding::UTF_8)
      metadata = unit['metadata']
      @records = metadata.is_a?(Hash) ? metadata['references'] : nil
      @raw = @source.lines
      @offsets = [0]
      @raw.each { |line| @offsets << (@offsets.last + line.bytesize) }
      @targets = {}
      @ambiguities = []
    end

    # @return [Array<Ambiguity>] the ambiguous occurrences linked by the last {#by_source_line}
    attr_reader :ambiguities

    # Project whole occurrences only through consecutive, unchanged file rows.
    # Hidden annotations and de-commented concerns cannot acquire links.
    # @param lines [Array<CompositeSource::Line>] rows selected for rendering
    # @return [Hash{Integer => Array<Link>}] annotated line => balanced link fragments
    def by_source_line(lines)
      @ambiguities = []
      return {} unless @records.is_a?(Array) && @source.valid_encoding?

      rows = lines.index_by(&:number)
      admitted_spans.each_with_object({}) do |entry, result|
        target = resolve(entry)
        next unless target

        fragments = project(entry, rows, target)
        next unless fragments

        record_ambiguity(entry, target) if target[:candidates]
        fragments.each { |number, link| (result[number] ||= []) << link }
      end
    end

    # @param unit [Hash] a published unit
    # @param annotated [Integer] a line of its annotated source
    # @return [Integer, nil] the file line, nil for a line an annotation added
    def self.file_line(unit, annotated)
      Woods::SourceLineMap.translate(unit.dig('metadata', 'source_line_map'), annotated)
    end

    private

    def admitted_spans
      unambiguous(@records.filter_map { |record| span(record) }.uniq.sort_by(&:first))
    end

    def span(record)
      return unless valid_record?(record)

      line, column, length = record.values_at('line', 'column', 'length')
      return unless line <= @raw.size

      raw = @raw[line - 1]
      return unless raw && column < raw.chomp.bytesize

      first = @offsets[line - 1] + column
      last = first + length
      return unless last <= @source.bytesize && boundary?(first) && boundary?(last)
      return if [10, 13].include?(@source.getbyte(last - 1))

      Span.new(first, last, record.slice(*FIELDS))
    end

    def boundary?(offset)
      byte = @source.getbyte(offset)
      byte.nil? || !byte.between?(0x80, 0xBF)
    end

    # Reject entire overlap clusters, including nested and chained conflicts.
    # Equal intervals with different identities conflict; adjacency does not.
    def unambiguous(spans)
      groups = []
      last = 0
      spans.each do |entry|
        if groups.empty? || entry.first >= last
          groups << [entry]
          last = entry.last
        else
          groups.last << entry
          last = [last, entry.last].max
        end
      end
      groups.select(&:one?).flatten
    end

    # The link target of an admitted span, or nil when nothing it names is in
    # this generation: {identifier, type, line} or {candidates}.
    def resolve(entry)
      record = entry.record
      return ambiguous_target(record) if record['confidence'] == 'ambiguous'

      identity = record.values_at('target', 'target_type')
      unit = target_unit(*identity)
      return unless unit

      method_line = WoodsMap::MethodLine.new(@repository, unit).call(record['method'], kind: record['kind'])
      return if identity == @unit.values_at('identifier', 'type') && !method_line

      method_line || { identifier: identity.first, type: identity.last, line: nil }
    end

    def ambiguous_target(record)
      candidates = record['candidates'].filter_map do |candidate|
        identity = candidate.values_at('target', 'target_type')
        unit = target_unit(*identity)
        { identifier: identity.first, type: identity.last, path: unit['file_path'] } if unit
      end
      { candidates: candidates } if candidates.any?
    end

    def target_unit(identifier, type)
      @targets.fetch([identifier, type]) do
        unit = @repository.unit(identifier, type: type)
        @targets[[identifier, type]] =
          unit.is_a?(Hash) && unit.values_at('identifier', 'type') == [identifier, type] ? unit : nil
      end
    rescue IOError
      @targets[[identifier, type]] = nil
    end

    def record_ambiguity(entry, target)
      @ambiguities << Ambiguity.new(id: "wm-amb-#{@ambiguities.size + 1}", text: spelling(entry),
                                    method: entry.record['method'], candidates: target[:candidates])
    end

    def spelling(entry)
      @source.byteslice(entry.first, entry.last - entry.first).to_s.delete("\n")
    end

    def project(entry, rows, target)
      number = entry.record['line']
      column = entry.record['column']
      remaining = entry.last - entry.first
      fragments = []
      while remaining.positive?
        raw = @raw[number - 1]
        text = unchanged_text(raw, rows[number])
        return unless text

        consumed = [remaining, raw.bytesize - column].min
        length = [consumed, text.bytesize - column].min
        fragments << [number, link(entry, target, column, length)] if length.positive?
        remaining -= consumed
        number += 1
        column = 0
      end
      fragments
    end

    def unchanged_text(raw, row)
      text = raw.delete_suffix("\n")
      text if row&.origin == :file && row.text.b == text.b
    end

    def link(entry, target, column, length)
      record = entry.record
      popover = "wm-amb-#{@ambiguities.size + 1}" if target[:candidates]
      Link.new(column: column, length: length, identifier: target[:identifier], type: target[:type],
               kind: record['kind'], confidence: record['confidence'], method: record['method'], line: target[:line],
               popover: popover, text: popover && spelling(entry))
    end
  end
end
