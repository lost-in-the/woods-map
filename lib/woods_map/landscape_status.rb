# frozen_string_literal: true

module WoodsMap
  # The Landscape's Status tab (B8-Landscape): what this generation publishes
  # for the Landscape, item by item, with the Woods work that publishes it and
  # what the map draws from it. A missing item names its limit rather than
  # leaving a tab silently empty.
  class LandscapeStatus
    # One published fact the Landscape reads.
    Item = Struct.new(:name, :available, :detail, :source, :draws, keyword_init: true)

    # @param repository [Repository]
    # @param landscape [Landscape]
    # @param hotspots [Hotspots]
    # @param components [Components]
    def initialize(repository, landscape:, hotspots:, components:)
      @repository = repository
      @landscape = landscape
      @hotspots = hotspots
      @components = components
      @analysis = repository.graph_analysis
    end

    # @return [Array<Item>] in the order the tabs read them
    def items
      @items ||= [profile, containers, services, consumers, packages, sizes, clusters, analysis, churn]
    end

    # @return [Integer] items this generation publishes
    def available
      items.count(&:available)
    end

    private

    def item(name, available, detail, source, draws)
      Item.new(name: name, available: available, detail: detail, source: source, draws: draws)
    end

    def profile
      item('BehavioralProfile unit', @landscape.profile.any?, @landscape.rails || 'absent',
           'Woods configuration extractor', 'technologies on Containers; mail and storage on Context')
    end

    def containers
      item('container attribution', @landscape.attributed?, "#{@landscape.unit_count} application units",
           'W-9, woods#759', 'Containers and the unit count sizing')
    end

    def services
      services = @landscape.services
      item('external services', @landscape.external_services.published?,
           services.any? ? services.map(&:name).join(', ') : 'none named',
           'woods#814', 'external systems on Context and Containers')
    end

    def consumers
      count = @repository.units(type: 'external_consumer').size
      item('declared external consumers', count.positive?, "#{count} declared", 'Woods configuration',
           'external systems that read shared tables')
    end

    def packages
      item('Packwerk packages', @components.packages?, @components.packages? ? 'on graph nodes' : 'no package.yml',
           'Woods #280', 'Components by package, undeclared edges')
    end

    def sizes
      published = Hash(@repository.graph['nodes']).values.any? { |node| node['loc'] }
      item('source sizes', published, published ? 'lines and loc on nodes' : 'absent',
           'woods#810', 'the treemap by lines of code')
    end

    def clusters
      item('domain clusters', @analysis.key?('domain_clusters'), "#{Array(@analysis['domain_clusters']).size} clusters",
           'woods#799', 'Components by cluster, Domains and its mindmap')
    end

    def analysis
      item('graph analysis', @hotspots.analysed?, "#{@hotspots.hubs.size} hubs, #{@hotspots.cycles.size} cycles",
           'graph_analysis.json', 'Hotspots tiles and structural risk')
    end

    def churn
      item('commit counts', @hotspots.churn?, @hotspots.churn? ? 'on graph nodes' : 'no git history at extraction',
           'Woods git enrichment', 'the churn × dependents quadrant')
    end
  end
end
