# frozen_string_literal: true

module WoodsMap
  # One search over the pinned generation in one of three modes (B8-Search):
  # name (identifiers, routes, tables), code (full text over source_code,
  # with the matching lines as snippets) and path (the file map). Every
  # result page says whether the scan was complete, and if not, why.
  class SearchResults
    Hit = Struct.new(:identifier, :type, :file_path, :hits, :match, :snippet, :lines, :owners, keyword_init: true)

    MODES = %w[name code path].freeze
    LIMIT = 50
    # Code search reads unit bodies. An in-app page is not bound by an
    # agent's token budget, so it asks Woods to read up to every unit of the
    # generation, to this ceiling.
    MAX_SCAN = 20_000
    # Why a search stopped, by Woods' completeness reason.
    STOP_REASONS = {
      'result_limit' => 'showing the first %<limit>d matches; there are more',
      'scan_budget' => 'stopped at the scan budget',
      'regex_timeout' => 'the pattern took too long and was stopped',
      'unreadable_or_corrupt_source' => 'some units could not be read; run woods:validate'
    }.freeze

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
      hits
      status = raw.dig('completeness', 'status')
      return status == 'complete' if status

      raw['complete'] != false && !raw['partial']
    end

    # Why an incomplete search stopped, in words: the cap that stopped
    # it, with how many units' source it read of how many when Woods says.
    #
    # @return [String, nil] nil when the search was complete
    def stop_reason
      return nil if complete?

      reason = raw.dig('completeness', 'reason').to_s
      text = format(STOP_REASONS.fetch(reason, 'the search did not finish'), limit: LIMIT)
      scan = raw['scan']
      if reason == 'scan_budget' && scan.is_a?(Hash) && scan['candidate_units']
        text = "stopped after reading #{scan['scanned_units']} of #{scan['candidate_units']} units' source " \
               '(scan budget)'
      end
      text
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
                                                                          limit: LIMIT, **scan_budget)
               when 'name' then name_search
               else { 'results' => [], 'complete' => true }
               end
    rescue ArgumentError
      @raw = { 'results' => [], 'complete' => true }
    end

    # Woods' per-call scan budget, sized to the generation, when this Woods
    # accepts one; otherwise Woods' own default applies and the page says so.
    def scan_budget
      return {} unless @repository.respond_to?(:search_scan_budget?) && @repository.search_scan_budget?

      { max_scan: [@repository.status['total_units'].to_i, 1].max.clamp(1, MAX_SCAN) }
    end

    # Name search: the identifier search, plus literal prefix and
    # short-name searches and the matching tables and routes, so the exact
    # name and its table are never cut by the page limit of a broad match.
    # Hits are ranked here: the exact name, then an exact short name, then
    # prefixes, then other matches, shorter names first.
    def name_search
      main = identifier_search(Regexp.escape(@query), types: @types)
      rows = ([main] + name_side_searches).flat_map { |result| Array(result['results']) }
      rows = rows.uniq { |r| [r['identifier'], r['type']] }
      rows = rows.select { |r| @types.include?(r['type']) } if @types
      ranked = rows.sort_by { |r| [NameRank.call(r['identifier'], @query), r['identifier'], r['type']] }
      main.merge('results' => ranked.first(LIMIT), **name_completeness(main, ranked.size))
    end

    # The literal prefix and +::+ short-name searches, and tables and routes
    # when no type filter narrows the page.
    def name_side_searches
      searches = [identifier_search(nil, exact_prefix: @query, types: @types),
                  identifier_search(nil, exact_suffix: "::#{@query}", types: @types)]
      searches << identifier_search(Regexp.escape(@query), types: %w[database_table route]) unless @types
      searches
    end

    def name_completeness(main, found)
      status = main.dig('completeness', 'status')
      main_complete = status ? status == 'complete' : main['complete'] != false
      complete = main_complete && found <= LIMIT
      reason = main_complete ? 'result_limit' : main.dig('completeness', 'reason')
      { 'complete' => complete,
        'completeness' => { 'status' => complete ? 'complete' : 'partial',
                            'reason' => complete ? 'exhausted' : reason } }
    end

    def identifier_search(query, types:, **filters)
      @repository.search(query, fields: %w[identifier], types: types, limit: LIMIT, **filters)
    rescue ArgumentError
      { 'results' => [] }
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
      paths = @repository.file_map.keys.select { |path| path.downcase.include?(needle) }.sort
      @raw = { 'complete' => paths.size <= LIMIT }
      paths.first(LIMIT).map do |path|
        owners = @repository.file_owners(path).map { |node| [node['identifier'], node['type']] }
        Hit.new(type: 'file', file_path: path, hits: owners.size, match: path, owners: owners)
      end
    end
  end
end
