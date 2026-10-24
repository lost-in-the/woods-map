# frozen_string_literal: true

module WoodsMap
  # Where the code is (B6-Overview): lines of code by Packwerk package and
  # unit type, for the Hotspots treemap. Read from `graph_analysis.json`
  # `package_sizes` (woods#810) when packages are published, otherwise summed
  # over the graph nodes' `loc` with each distinct file once, as Woods totals
  # a package. Nothing is counted from host files. The board's other sizes
  # count application units (nodes with a container, W-9) or sum their
  # PageRank, by the same blocks.
  class CodeSizes
    # Treemap sizes: parameter => what a block's size is.
    METRICS = { 'loc' => 'lines of code', 'units' => 'unit count', 'pagerank' => 'PageRank × 1000' }.freeze

    # @param graph [Hash] the published dependency graph
    # @param analysis [Hash] the published graph analysis
    # @param metric [String] one of {METRICS}; anything else is `loc`
    def initialize(graph, analysis, metric: 'loc')
      @graph = graph
      @analysis = analysis
      @metric = METRICS.key?(metric.to_s) ? metric.to_s : 'loc'
    end

    # @return [String] the selected size
    attr_reader :metric

    # Blocks (packages, or the application) and their size by unit type.
    #
    # @return [Hash{String => Hash{String => Integer}}] block => type => size,
    #   largest block first; empty when the generation publishes nothing to size by
    def code_sizes
      @code_sizes ||= begin
        sizes = @metric == 'loc' ? loc_sizes : node_sizes
        sizes.transform_values { |types| types.select { |_, size| size.to_i.positive? } }
             .reject { |_, types| types.empty? }
             .sort_by { |name, types| [-types.values.sum, name] }.to_h
      end
    end

    # @return [Boolean] whether the blocks are Packwerk packages
    def sized_by_package?
      return Hash(@analysis['package_sizes']).any? if @metric == 'loc'

      application_nodes.any? { |_, node| node['package'] }
    end

    # The treemap of {#code_sizes} as Mermaid.
    #
    # @return [String, nil] nil when the generation publishes no sizes
    def treemap_mermaid
      return nil if code_sizes.empty?

      lines = ['treemap-beta']
      code_sizes.each do |block, types|
        lines << %("#{label(block)}")
        types.sort_by { |type, loc| [-loc, type] }.each do |type, loc|
          lines << %(    "#{label(type.tr('_', ' ').pluralize)}": #{loc.to_i})
        end
      end
      lines.join("\n")
    end

    private

    def loc_sizes
      packages = Hash(@analysis['package_sizes'])
      packages.any? ? packages.transform_values { |size| Hash(size['types']) } : application_sizes
    end

    # Unit counts or PageRank (× 1000, rounded) by package, else one block.
    def node_sizes
      ranks = Hash(@graph['pagerank'])
      by_package = sized_by_package?
      sizes = application_nodes.each_with_object({}) do |(identifier, node), out|
        block = by_package ? node['package'].to_s.presence || '(no package)' : 'application'
        types = out[block] ||= Hash.new(0)
        types[node['type'].to_s] += @metric == 'units' ? 1 : (ranks[identifier].to_f * 1000)
      end
      sizes.transform_values { |types| types.transform_values(&:round) }
    end

    def application_nodes
      @application_nodes ||= Hash(@graph['nodes']).select do |_, node|
        node['container'] && node['file_path'].present? && !node['file_path'].to_s.start_with?('/')
      end
    end

    # The application as one block when no package is published: each
    # distinct file's `loc` once, under the type that sorts first among the
    # nodes read from it, as Woods totals a package.
    def application_sizes
      files = {}
      Hash(@graph['nodes']).sort_by { |id, node| [node['type'].to_s, id] }.each do |_, node|
        next unless node['loc'].is_a?(Integer) && node['file_path']

        files[node['file_path']] ||= [node['type'].to_s, node['loc']]
      end
      return {} if files.empty?

      types = files.values.each_with_object(Hash.new(0)) { |(type, loc), sum| sum[type] += loc }
      { 'application' => types }
    end

    # A treemap label: no quotes, which would end it.
    def label(value)
      value.to_s.delete('"')
    end
  end
end
