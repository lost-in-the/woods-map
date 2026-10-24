# frozen_string_literal: true

module WoodsMap
  # The Landscape page's C4 container level (B8-Landscape, B-21): the
  # application's containers, the external systems around it, and the
  # relationships between them. Read from one pinned generation:
  #
  # - container membership from each graph node's `container` (W-9, woods#759);
  # - technologies from the BehavioralProfile configuration unit;
  # - external consumers and engines from their units;
  # - relationships from the published edges between members of different
  #   containers, counted by mechanism.
  #
  # It is logical, not physical: how many processes run, and where, is not in
  # the index. A generation extracted before W-9 has no `container` on any
  # node; {#attributed?} is then false and the page says what it needs.
  class Landscape
    # One box on the diagram.
    Container = Struct.new(:id, :name, :kind, :technology, :description, :counts, keyword_init: true) do
      # @return [Integer] units the container holds
      def size
        counts.values.sum
      end

      # @return [Boolean] a data store, drawn as a cylinder
      def store?
        %w[database cache].include?(kind)
      end
    end

    # One arrow: from, to, a label and the published edge count behind it.
    Relationship = Struct.new(:from, :to, :label, :mechanism, :edges, :source, keyword_init: true)

    # Unit types, plural, in the order the boxes list them.
    TYPE_ORDER = %w[controller view_template component view_component route helper middleware action_cable_channel
                    js_module job scheduled_job mailer model database_table database_view].freeze

    # @param repository [Repository]
    # @param system_name [String, nil] the host's name for the application
    def initialize(repository, system_name: nil)
      @repository = repository
      @graph = repository.graph
      @system_name = system_name
    end

    # @return [Boolean] whether this generation publishes container attribution
    def attributed?
      return @attributed if defined?(@attributed)

      @attributed = nodes.values.any? { |node| node['container'] }
    end

    # @return [String]
    def system_name
      @system_name.presence || 'Application'
    end

    # @return [Hash] the BehavioralProfile unit's metadata, or an empty hash
    def profile
      @profile ||= begin
        entry = @repository.units(type: 'configuration').find { |u| u['identifier'] == 'BehavioralProfile' }
        unit = entry && @repository.unit(entry['identifier'], type: 'configuration')
        Hash(unit&.dig('metadata')).then { |m| m['config_type'] == 'behavioral_profile' ? m : {} }
      end
    end

    # @return [String, nil] e.g. "Rails 8.0.0"
    def rails
      profile['rails_version'] && "Rails #{profile['rails_version']}"
    end

    # @return [Array<Container>] the processes first, then the stores
    def containers
      @containers ||= [web, jobs, *databases, cache].compact
    end

    # @return [Array<Container>] web and jobs
    def processes
      containers.reject(&:store?)
    end

    # @return [Array<Container>] databases and the cache
    def stores
      containers.select(&:store?)
    end

    # @return [Array<Container>] mail delivery, object storage and each external consumer
    def externals
      @externals ||= [mail, storage, *consumers].compact
    end

    # @return [Hash{String => Integer}] the shared units by type
    def shared
      counts_for { |node| node['container'] == 'shared' }
    end

    # @return [Array<String>] engine identifiers
    def engines
      @repository.units(type: 'engine').pluck('identifier').sort
    end

    # @return [Array<Relationship>] container to container, strongest first within each source
    def relationships
      @relationships ||= ContainerRelationships.new(@repository).to_a + configured_relationships
    end

    # @param container [Container, String]
    # @return [Array<Relationship>] the relationships leaving it
    def outgoing(container)
      id = container.is_a?(Container) ? container.id : container
      relationships.select { |r| r.from == id }
    end

    # @param id [String]
    # @return [String] the display name of a container or external system
    def name_of(id)
      (containers + externals).find { |c| c.id == id }&.name || id
    end

    # @return [Integer] application units with a container
    def unit_count
      Hash(@graph['nodes']).values.count { |node| node['container'] }
    end

    private

    def nodes
      Hash(@graph['nodes'])
    end

    def counts_for(&block)
      counts = nodes.values.select(&block).map { |node| node['type'].to_s }.tally
      counts.sort_by { |type, _| [TYPE_ORDER.index(type) || TYPE_ORDER.size, type] }.to_h
    end

    def web
      counts = counts_for { |node| node['container'] == 'web' }
      return nil if counts.empty?

      api = profile.dig('behavior_flags', 'api_only') ? ', API only' : ''
      Container.new(id: 'web', name: 'Web process', kind: 'web', technology: "#{rails || 'Rails'}#{api}",
                    description: 'controllers, views and routes', counts: counts)
    end

    def jobs
      counts = counts_for { |node| node['container'] == 'jobs' }
      return nil if counts.empty?

      adapter = profile.dig('background_processing', 'adapter')
      Container.new(id: 'jobs', name: 'Job runner', kind: 'jobs', technology: adapter ? adapter.to_s : 'Active Job',
                    description: 'jobs, scheduled jobs and mailers', counts: counts)
    end

    def databases
      stores = nodes.values.select { |node| node['container'] == 'database' }
      names = stores.map { |node| node['database'] || 'primary' }
      adapter = profile.dig('database', 'adapter')
      names.uniq.sort_by { |name| [name == 'primary' ? 0 : 1, name] }.map do |name|
        counts = counts_for { |node| node['container'] == 'database' && (node['database'] || 'primary') == name }
        Container.new(id: "db_#{name}", name: "#{name.to_s.humanize} database", kind: 'database',
                      technology: (adapter if name == 'primary'), description: 'tables and the models over them',
                      counts: counts)
      end
    end

    def cache
      store = profile.dig('caching', 'store')
      return nil if store.nil? || store.to_s == 'null_store'

      Container.new(id: 'cache', name: 'Cache', kind: 'cache', technology: store.to_s, description: 'Rails.cache',
                    counts: {})
    end

    def mail
      mailers = nodes.values.count { |node| node['type'] == 'mailer' }
      delivery = profile.dig('email', 'delivery_method')
      return nil if mailers.zero? && delivery.nil?

      Container.new(id: 'mail', name: 'Mail delivery', kind: 'external',
                    technology: delivery ? "#{delivery} via Action Mailer" : 'Action Mailer',
                    description: "#{mailers} #{'mailer'.pluralize(mailers)}", counts: {})
    end

    def storage
      return nil unless profile.dig('frameworks_active', 'active_storage')

      Container.new(id: 'storage', name: 'Object storage', kind: 'external', technology: 'Active Storage',
                    description: 'uploads and attachments', counts: {})
    end

    def consumers
      @repository.units(type: 'external_consumer').map do |entry|
        Container.new(id: "ext_#{entry['identifier'].parameterize(separator: '_')}", name: entry['identifier'],
                      kind: 'external', technology: 'external consumer', description: 'declared consumer', counts: {})
      end
    end

    # What the BehavioralProfile states and no edge records.
    def configured_relationships
      rows = []
      rows << configured('web', 'cache', 'reads, writes', 'Rails.cache') if cache && web
      rows << configured('jobs', 'mail', 'delivers', 'deliver_later') if mail && jobs
      rows << configured('web', 'storage', 'uploads', 'Active Storage') if storage && web
      rows
    end

    def configured(from, to, label, mechanism)
      Relationship.new(from: from, to: to, label: label, mechanism: mechanism, edges: nil, source: 'BehavioralProfile')
    end
  end
end
