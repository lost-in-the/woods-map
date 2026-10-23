# frozen_string_literal: true

module WoodsMap
  # Published constant occurrences, admitted only by their exact typed identity
  # in this request's generation. Coordinates address annotated source bytes;
  # file gutter labels and the internal reference cache are never consulted.
  class References
    Link = Struct.new(:column, :length, :identifier, :type, :kind, :confidence, keyword_init: true)
    Span = Struct.new(:first, :last, :record)
    private_constant :Span
    FIELDS = %w[line column length target target_type kind confidence].freeze

    # @param repository [WoodsMap::Repository] pinned for the request
    # @param unit [Hash] published unit with annotated source and metadata
    def initialize(repository, unit)
      @repository = repository
      @source = unit['source_code'].to_s.dup.force_encoding(Encoding::UTF_8)
      metadata = unit['metadata']
      @records = metadata.is_a?(Hash) ? metadata['references'] : nil
      @raw = @source.lines
      @offsets = [0]
      @raw.each { |line| @offsets << (@offsets.last + line.bytesize) }
      @targets = {}
    end

    # Project whole occurrences only through consecutive, unchanged file rows.
    # Hidden annotations and de-commented concerns cannot acquire links.
    # @param lines [Array<CompositeSource::Line>] rows selected for rendering
    # @return [Hash{Integer => Array<Link>}] annotated line => balanced link fragments
    def by_source_line(lines)
      return {} unless @records.is_a?(Array) && @source.valid_encoding?

      rows = lines.index_by(&:number)
      admitted_spans.each_with_object({}) do |entry, result|
        fragments = project(entry, rows)
        next unless fragments && target?(entry.record)

        fragments.each { |number, link| (result[number] ||= []) << link }
      end
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

    def valid_record?(record)
      record.is_a?(Hash) && record['kind'] == 'constant' && record['confidence'] == 'verified' &&
        valid_position?(record) && %w[target target_type].all? { |key| valid_identity?(record[key]) }
    end

    def valid_position?(record)
      %w[line column length].all? { |key| record[key].is_a?(Integer) } &&
        record['line'].positive? && record['column'] >= 0 && record['length'].positive? &&
        record['length'] <= @source.bytesize
    end

    def valid_identity?(value)
      value.is_a?(String) && !value.empty? && value.dup.force_encoding(Encoding::UTF_8).valid_encoding?
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

    def project(entry, rows)
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
        fragments << [number, link(entry.record, column, length)] if length.positive?
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

    def link(record, column, length)
      Link.new(column: column, length: length, identifier: record['target'], type: record['target_type'],
               kind: record['kind'], confidence: record['confidence'])
    end

    def target?(record)
      identity = record.values_at('target', 'target_type')
      @targets.fetch(identity) do
        target = @repository.unit(identity.first, type: identity.last)
        @targets[identity] = target.is_a?(Hash) && target.values_at('identifier', 'type') == identity
      end
    rescue IOError
      @targets[identity] = false
    end
  end
end
