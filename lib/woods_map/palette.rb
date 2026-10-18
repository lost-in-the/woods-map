# frozen_string_literal: true

module WoodsMap
  # The search palette's hits (B8-Search): units, routes, tables and files
  # matching a few typed characters, grouped with counts and a completeness
  # line, all from the pinned generation.
  class Palette
    GROUPS = %w[units routes tables files].freeze
    PER_GROUP = 5

    # @param repository [WoodsMap::Repository]
    # @param query [String]
    def initialize(repository, query)
      @repository = repository
      @query = query.to_s.strip
    end

    # @return [Hash] groups with hits, and the completeness line
    def to_h
      return { 'query' => @query, 'groups' => [], 'complete' => true } if @query.empty?

      { 'query' => @query, 'groups' => [units_group, routes_group, tables_group, files_group].reject do |g|
        g['total'].zero?
      end,
        'complete' => @complete != false, 'generation' => @repository.generation_number }
    end

    private

    def search(types)
      result = @repository.search(Regexp.escape(@query), fields: %w[identifier], types: types, limit: 40)
      @complete = false if result['partial'] || result['complete'] == false
      Array(result['results'])
    rescue ArgumentError
      []
    end

    def units_group
      results = search(nil).reject { |r| %w[route database_table].include?(r['type']) }
      group('units', results.map do |r|
        { 'label' => r['identifier'], 'type' => r['type'],
          'detail' => [r['type'].to_s.tr('_', ' '), r['file_path']].compact.join(', ') }
      end)
    end

    def routes_group
      results = search(%w[route])
      group('routes', results.map { |r| { 'label' => r['identifier'], 'type' => 'route', 'detail' => 'route' } })
    end

    def tables_group
      results = search(%w[database_table])
      group('tables', results.map do |r|
        { 'label' => r['identifier'].sub('table:', ''), 'identifier' => r['identifier'],
          'type' => 'database_table', 'detail' => 'table' }
      end)
    end

    def files_group
      needle = @query.downcase
      files = @repository.file_map.select { |path, _| path.downcase.include?(needle) }
      items = files.map do |path, identifiers|
        { 'label' => path, 'identifier' => identifiers.first,
          'type' => @repository.graph.dig('nodes', identifiers.first, 'type'),
          'detail' => "#{identifiers.size} #{'unit'.pluralize(identifiers.size)}" }
      end
      group('files', items)
    end

    def group(name, items)
      { 'name' => name, 'total' => items.size, 'items' => items.first(PER_GROUP).map do |i|
        i.merge('identifier' => i['identifier'] || i['label'])
      end }
    end
  end
end
