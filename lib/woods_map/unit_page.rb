# frozen_string_literal: true

module WoodsMap
  # What every tab of a unit page shares (C5-Chrome): the title block, the
  # breadcrumbs, the tabs with one count each and the facts tiles, derived
  # from the unit and the graph of the pinned generation.
  class UnitPage
    TYPE_LABELS = {
      'model' => 'model', 'controller' => 'controller', 'view_template' => 'view template', 'job' => 'job',
      'mailer' => 'mailer', 'service' => 'service', 'concern' => 'concern', 'serializer' => 'serializer',
      'database_table' => 'table', 'route' => 'route', 'migration' => 'migration', 'component' => 'component',
      'view_component' => 'view component', 'poro' => 'plain Ruby object', 'rails_source' => 'framework source'
    }.freeze

    # Tabs by unit type; every type gets Code, Graph and History.
    TABS = {
      'model' => %w[code schema lifecycle graph history],
      'database_table' => %w[schema graph],
      'controller' => %w[code passage lifecycle graph history],
      'mailer' => %w[code passage lifecycle graph history],
      'job' => %w[code lifecycle graph history]
    }.freeze
    DEFAULT_TABS = %w[code graph history].freeze

    # Dependency labels grouped the way the Depends-on tile reads them.
    DEPENDENCY_GROUPS = {
      'belongs_to' => 'belongs_to', 'has_many' => 'has_many', 'has_one' => 'has_one',
      'has_and_belongs_to_many' => 'habtm', 'through' => 'through', 'include' => 'include',
      'job_enqueue' => 'enqueue', 'render' => 'render', 'view_render' => 'render', 'code_reference' => 'references',
      'redirect_to' => 'redirect', 'link_to' => 'link', 'form_action' => 'form', 'route_dispatch' => 'route',
      'test_coverage' => 'tests', 'mailer_call' => 'mail'
    }.freeze

    # @param repository [WoodsMap::Repository]
    # @param unit [Hash]
    def initialize(repository, unit)
      @repository = repository
      @unit = unit
      @metadata = unit['metadata'] || {}
    end

    attr_reader :unit

    # @return [String]
    def identifier
      @unit['identifier'].to_s
    end

    # @return [String] the singular unit type
    def type
      @unit['type'].to_s
    end

    # @return [String] what the unit is, for the subtitle: "model, table posts"
    def subtitle
      label = TYPE_LABELS.fetch(type) { type.tr('_', ' ') }
      detail = case type
               when 'model' then @metadata['table_name'] && "table #{@metadata['table_name']}"
               when 'controller' then "#{Array(@metadata['actions']).size} actions"
               when 'view_template' then [@metadata['template_engine'],
                                          (@metadata['is_partial'] ? 'partial' : nil)].compact.join(', ')
               when 'job' then @metadata['queue'] && "queue #{@metadata['queue']}"
               when 'database_table' then "#{@metadata['column_count']} columns"
               end
      [label, detail].compact.join(', ')
    end

    # @return [String, nil] the unit's file, relative to the application root
    def path
      @unit['file_path']
    end

    # @return [Array<Array(String, String)>] breadcrumb labels and types
    def crumbs
      [['units', nil], [type.pluralize.tr('_', ' '), type], [identifier, :current]]
    end

    # @return [Array<String>] the tab keys this type shows
    def tabs
      TABS.fetch(type, DEFAULT_TABS)
    end

    # The count each tab shows (C5: one count per tab).
    #
    # @param tab [String]
    # @return [String, Integer, nil]
    def tab_count(tab)
      case tab
      when 'code' then @metadata['loc'] && "#{@metadata['loc']} lines"
      when 'schema' then @metadata['column_count']
      when 'passage' then Array(@metadata['actions']).size.nonzero?
      when 'lifecycle' then lifecycle_count
      when 'graph' then dependencies.size + dependents.size
      when 'history' then @metadata.dig('git', 'commit_count')
      end
    end

    # @return [Array<Hash>] typed forward edges
    def dependencies
      Array(@unit['dependencies'])
    end

    # @return [Array<Hash>] reverse edges with their mechanism, from the graph
    def dependents
      Array(@repository.graph.dig('reverse_via', identifier)).presence ||
        Array(@unit['dependents']).map { |d| { 'source' => d['identifier'], 'source_type' => d['type'], 'via' => nil } }
    end

    # @return [Array<Hash>] the facts tiles (eyebrow, rows)
    def tiles
      [table_tile, used_by_tile, depends_on_tile, history_tile].compact
    end

    # @return [Hash, nil] the database table unit behind a model
    def table
      name = @metadata['table_name']
      return nil unless name

      @table ||= @repository.unit("table:#{name}", type: 'database_table')
    end

    private

    def lifecycle_count
      Array(@metadata['callbacks']).count { |cb| !cb['filter'].to_s.match?(Lifecycle::INTERNAL) }.nonzero? ||
        Array(@metadata['filters']).size.nonzero?
    end

    def table_tile
      return nil unless type == 'model' && @metadata['table_name']

      indexes = Array(table&.dig('metadata', 'indexes')).size
      fks = Array(table&.dig('metadata', 'foreign_keys'))
      { eyebrow: 'Table', rows: [
        ['name', { link: ["table:#{@metadata['table_name']}", 'database_table', @metadata['table_name']] }],
        ['columns', "#{@metadata['column_count']}, #{indexes} #{'index'.pluralize(indexes)}"],
        ['FK', fks.any? ? fks.map { |fk| "#{fk['column']} → #{fk['to_table']}" }.join(', ') : 'none'],
        ['source', { layer: 'model metadata' }]
      ] }
    end

    def used_by_tile
      groups = dependents.group_by { |d| d['source_type'].to_s }
      return nil if groups.empty?

      rows = groups.sort_by { |_, list| -list.size }.first(4).map do |source_type, list|
        [source_type.pluralize.tr('_', ' '), { links: list.map { |d| [d['source'], source_type] }.uniq }]
      end
      { eyebrow: "Used by #{dependents.pluck('source').uniq.size}", rows: rows }
    end

    def depends_on_tile
      groups = dependencies.group_by { |d| DEPENDENCY_GROUPS.fetch(d['via'].to_s, d['via'].to_s) }
      return nil if groups.empty?

      rows = groups.first(5).map { |via, list| [via, { links: list.map { |d| [d['target'], d['type']] }.uniq }] }
      { eyebrow: "Depends on #{dependencies.pluck('target').uniq.size}", rows: rows }
    end

    def history_tile
      git = @metadata['git']
      return nil unless git

      { eyebrow: 'History', rows: [
        ['last', { who: git['last_author'], date: git['last_modified'] }],
        ['churn',
         { text: "#{git['commit_count']} #{'commit'.pluralize(git['commit_count'].to_i)}",
           hot: git['change_frequency'].to_s == 'hot' }],
        ['people', "#{Array(git['contributors']).size} #{'contributor'.pluralize(Array(git['contributors']).size)}"],
        ['frequency', git['change_frequency'].to_s]
      ] }
    end
  end
end
