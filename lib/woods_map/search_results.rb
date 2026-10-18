# frozen_string_literal: true

module WoodsMap
  # One search over the pinned generation in one of three modes (B8-Search):
  # name (identifiers, routes, tables), code (full text over source_code,
  # with the matching lines as snippets) and path (the file map). Every
  # result page says whether the scan was complete.
  class SearchResults
    Hit = Struct.new(:identifier, :type, :file_path, :hits, :match, :snippet, :lines, keyword_init: true)

    MODES = %w[name code path].freeze
    LIMIT = 50

    # @param repository [WoodsMap::Repository]
    # @param query [String]
    # @param mode [String] one of {MODES}
    # @param types [Array<String>, nil]
    def initialize(repository, query, mode: 'name', types: nil)
      @repository = repository
      @query = query.to_s.strip
      @mode = MODES.include?(mode.to_s) ? mode.to_s : 'name'
      @types = types.presence
    end

    attr_reader :query, :mode

    # @return [Boolean]
    def blank?
      @query.empty?
    end

    # @return [Array<Hit>]
    def hits
      @hits ||= blank? ? [] : send("#{@mode}_hits")
    end

    # @return [Boolean] whether every unit was scanned
    def complete?
      raw['complete'] != false && !raw['partial']
    end

    # @return [Array<String>] notes the reader attached (broad pattern, caps)
    def notes
      Array(raw['note']).flatten.compact + Array(raw['notes']).flatten.compact
    end

    # @return [Hash{String => Integer}] type => hits, for the rail filter
    def type_counts
      hits.map(&:type).tally.sort.to_h
    end

    # Names near a query that found nothing (the empty state's nearest names).
    #
    # @return [Array<String>]
    def nearest
      return [] if blank?

      prefix = @query[0, [@query.size - 1, 2].max]
      result = @repository.search(nil, exact_prefix: prefix, limit: 5)
      Array(result['results']).pluck('identifier').uniq.first(3)
    rescue ArgumentError
      []
    end

    private

    def raw
      @raw ||= case @mode
               when 'code' then @repository.search(Regexp.escape(@query), fields: %w[source_code], types: @types,
                                                                          limit: LIMIT)
               when 'name' then @repository.search(Regexp.escape(@query), fields: %w[identifier], types: @types,
                                                                          limit: LIMIT)
               else { 'results' => [], 'complete' => true }
               end
    rescue ArgumentError
      @raw = { 'results' => [], 'complete' => true }
    end

    def name_hits
      Array(raw['results']).map do |r|
        Hit.new(identifier: r['identifier'], type: r['type'], file_path: r['file_path'], hits: 1,
                match: r['identifier'])
      end
    end

    def code_hits
      pattern = Regexp.new(Regexp.escape(@query), Regexp::IGNORECASE)
      Array(raw['results']).filter_map do |r|
        unit = @repository.unit(r['identifier'], type: r['type'])
        matches = unit ? CompositeSource.new(unit).file_lines.select { |line| line.text.match?(pattern) } : []
        code_hit(r, unit, matches) if matches.any?
      end
    end

    def code_hit(result, unit, matches)
      shown = matches.first(6)
      Hit.new(identifier: result['identifier'], type: result['type'], file_path: unit['file_path'], hits: matches.size,
              match: matches.first.text.strip, snippet: shown.map(&:text).join("\n"),
              lines: shown.map { |line| line.label.to_i })
    end

    def path_hits
      needle = @query.downcase
      @repository.file_map.select { |path, _| path.downcase.include?(needle) }.first(LIMIT).map do |path, identifiers|
        type = @repository.graph.dig('nodes', identifiers.first, 'type')
        Hit.new(identifier: identifiers.first, type: type, file_path: path, hits: identifiers.size, match: path)
      end
    end
  end
end
