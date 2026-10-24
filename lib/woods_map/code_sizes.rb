# frozen_string_literal: true

module WoodsMap
  # Where the code is (B6-Overview): lines of code by Packwerk package and
  # unit type, for the Hotspots treemap. Read from `graph_analysis.json`
  # `package_sizes` (woods#810) when packages are published, otherwise summed
  # over the graph nodes' `loc` with each distinct file once, as Woods totals
  # a package. Nothing is counted from host files.
  class CodeSizes
    # @param graph [Hash] the published dependency graph
    # @param analysis [Hash] the published graph analysis
    def initialize(graph, analysis)
      @graph = graph
      @analysis = analysis
    end

    # Blocks (packages, or the application) and their loc by unit type.
    #
    # @return [Hash{String => Hash{String => Integer}}] block => type => loc,
    #   largest block first; empty when the generation publishes no sizes
    def code_sizes
      @code_sizes ||= begin
        packages = Hash(@analysis['package_sizes'])
        sizes = if packages.any?
                  packages.transform_values { |size| Hash(size['types']) }
                else
                  application_sizes
                end
        sizes.transform_values { |types| types.select { |_, loc| loc.to_i.positive? } }
             .reject { |_, types| types.empty? }
             .sort_by { |name, types| [-types.values.sum, name] }.to_h
      end
    end

    # @return [Boolean] whether the sizes are by Packwerk package
    def sized_by_package?
      Hash(@analysis['package_sizes']).any?
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
