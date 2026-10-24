# frozen_string_literal: true

module WoodsMap
  # The Landscape's Hotspots tab (B6-Overview): structure, coupling and churn
  # from graph_analysis.json and the graph of one generation. Every figure is
  # a published fact or a count of published edges; the analysis is scoped to
  # identifiers, as Woods publishes it.
  class Hotspots
    # One structural-risk row: what kind, which unit, why, what to do.
    Risk = Struct.new(:kind, :identifier, :type, :why, :action, :severity, keyword_init: true)

    # Rows and columns of the layer coupling matrix, as unit types.
    LAYERS = %w[controller view_template component job mailer model].freeze
    # The quadrant's axes and quadrants, top right first as Mermaid numbers them.
    QUADRANT_HEAD = ['quadrantChart', '  x-axis Few commits --> Many commits',
                     '  y-axis Few dependents --> Many dependents', '  quadrant-1 Review carefully',
                     '  quadrant-2 Stable hubs', '  quadrant-3 Quiet', '  quadrant-4 Churning leaves'].freeze

    # Edges that are tests, documentation or schema bookkeeping, not coupling.
    NOT_COUPLING = %w[test_coverage exercises_route documents migrates drawn_in].freeze

    # @param repository [Repository]
    # @param size [String, nil] the treemap's size ({CodeSizes::METRICS})
    def initialize(repository, size: nil)
      @repository = repository
      @graph = repository.graph
      @analysis = repository.graph_analysis
      @size = size
    end

    # @return [Boolean] whether this generation has a graph analysis at all
    def analysed?
      @analysis.any?
    end

    # @return [Array<Hash>] hubs as published: identifier, type, dependent_count
    def hubs
      Array(@analysis['hubs'])
    end

    # @return [Array<Hash>] bridges: identifier, type, score
    def bridges
      Array(@analysis['bridges'])
    end

    # @return [Array<Array<String>>]
    def cycles
      Array(@analysis['cycles'])
    end

    # @return [Array<String>]
    def orphans = Array(@analysis['orphans'])

    # @return [Array<String>]
    def dead_ends
      Array(@analysis['dead_ends'])
    end

    # @return [Array<Hash>]
    def undeclared_edges
      Array(@analysis['undeclared_package_edges'])
    end

    # @return [Array<Hash>] hubs no `test_coverage` edge reaches
    def uncovered_hubs
      covered = Hash(@graph['reverse_via']).transform_values do |edges|
        Array(edges).any? do |e|
          e['via'] == 'test_coverage'
        end
      end
      hubs.reject { |hub| covered[hub['identifier']] }
    end

    # @return [Boolean] whether any node carries a commit count (git enrichment)
    def churn?
      Hash(@graph['nodes']).values.any? { |node| node['commit_count'] }
    end

    # Units by commits and dependents, the quadrant's points as a ranked list:
    # most changed and most depended upon first.
    #
    # @param limit [Integer]
    # @return [Array<Hash>] identifier, type, commits, dependents, change_frequency
    def churn(limit: 18)
      rows = Hash(@graph['nodes']).filter_map do |identifier, node|
        next unless node['commit_count']

        { identifier: identifier, type: node['type'], commits: node['commit_count'].to_i,
          dependents: dependents(identifier), change_frequency: node['change_frequency'] }
      end
      rows.sort_by { |row| [-(row[:commits] * (row[:dependents] + 1)), row[:identifier]] }.first(limit)
    end

    # Edges from each layer to each layer, over the published typed edges.
    #
    # @return [Hash{String => Hash{String => Integer}}] from type => to type => count
    def coupling
      matrix = LAYERS.index_with { LAYERS.index_with(0) }
      Hash(@graph['edges']).each do |source, edges|
        from = @graph.dig('nodes', source, 'type').to_s
        next unless matrix.key?(from)

        Array(edges).each do |edge|
          next if NOT_COUPLING.include?(edge['via'].to_s)

          to = target_type(edge)
          matrix[from][to] += 1 if matrix[from].key?(to)
        end
      end
      matrix.reject { |_, row| row.values.sum.zero? }
    end

    # The churn × dependents quadrant (B6-Overview) as Mermaid: x is commits
    # against the most changed unit, y is dependents on a log scale against
    # the most depended upon, so the top right is what to review first.
    #
    # @param limit [Integer] units labelled
    # @return [String, nil] nil without commit counts
    def quadrant_mermaid(limit: 18)
      rows = churn(limit: limit)
      return nil if rows.empty?

      most = [rows.pluck(:commits).max, 1].max
      widest = Math.log(1 + [rows.pluck(:dependents).max, 1].max)
      points = rows.map { |row| quadrant_point(row, most, widest) }
      (QUADRANT_HEAD + points).join("\n")
    end

    delegate :code_sizes, :sized_by_package?, :treemap_mermaid, :metric, to: :sizes

    # The layer coupling in the layering direction only (B6-Overview's
    # forward flow) as a Mermaid sankey: edges from a layer to a later one in
    # {LAYERS}, so the flow has no cycle to draw.
    #
    # @return [String, nil] nil when no edge runs forward
    def sankey_mermaid
      rows = forward_flow
      return nil if rows.empty?

      (['sankey-beta', ''] + rows.map { |from, to, count| "#{from},#{to},#{count}" }).join("\n")
    end

    # @return [Array<Array(String, String, Integer)>] plural layer names and edge counts, forward only
    def forward_flow
      coupling.flat_map do |from, row|
        row.filter_map do |to, count|
          next unless count.positive? && LAYERS.index(to) > LAYERS.index(from)

          [from.tr('_', ' ').pluralize, to.tr('_', ' ').pluralize, count]
        end
      end
    end

    # @return [Array<Risk>] what the analysis can prove, most severe first
    def risks
      undeclared_rows + bridge_rows + cycle_rows + uncovered_rows + orphan_rows
    end

    private

    def undeclared_rows
      undeclared_edges.first(10).map do |edge|
        Risk.new(kind: 'undeclared edge', identifier: "#{edge['from']} → #{edge['to']}", type: edge['from_type'],
                 why: "#{edge['from_package']} depends on #{edge['to_package']} without a package.yml dependency",
                 action: 'declare or cut', severity: :blocking)
      end
    end

    def bridge_rows
      bridges.first(5).map do |bridge|
        Risk.new(kind: 'bridge', identifier: bridge['identifier'], type: bridge['type'],
                 why: "a single point of coupling, bridge score #{bridge['score']}, " \
                      "#{dependents(bridge['identifier'])} dependents",
                 action: 'read for contract', severity: :note)
      end
    end

    def cycle_rows
      cycles.first(5).map do |cycle|
        units = cycle.uniq
        why = units.one? ? 'depends on itself' : "#{units.size} units depend on each other"
        Risk.new(kind: 'cycle', identifier: units.join(' → '), type: nil, why: why, action: nil, severity: :note)
      end
    end

    def uncovered_rows
      uncovered_hubs.first(5).map do |hub|
        Risk.new(kind: 'uncovered hub', identifier: hub['identifier'], type: hub['type'],
                 why: "#{hub['dependent_count']} dependents, no mapped test", action: 'add a spec', severity: :note)
      end
    end

    def orphan_rows
      return [] if orphans.empty?

      [Risk.new(kind: 'orphans', identifier: orphans.first, type: nil,
                why: "#{orphans.size} #{'unit'.pluralize(orphans.size)} with no dependents, " \
                     "#{dead_ends.size} dead ends",
                action: 'candidates to delete', severity: :note)]
    end

    # One point: commits against the most changed, dependents on a log scale
    # against the most depended upon, kept off the chart's edges.
    def quadrant_point(row, most, widest)
      x = (row[:commits].to_f / most).clamp(0.02, 0.98)
      y = (Math.log(1 + row[:dependents]) / widest).clamp(0.02, 0.98)
      "  #{point_name(row[:identifier])}: [#{format('%.2f', x)}, #{format('%.2f', y)}]"
    end

    # A quadrant point's name: the identifier with only characters the
    # quadrant grammar reads as a name.
    def point_name(identifier)
      identifier.to_s.gsub('::', '.').gsub(%r{[^A-Za-z0-9 _./#-]}, ' ').squeeze(' ').strip.presence || 'unit'
    end

    def sizes = @sizes ||= CodeSizes.new(@graph, @analysis, metric: @size)

    def target_type(edge)
      (edge['type'] || @graph.dig('nodes', edge['target'], 'type')).to_s
    end

    def dependents(identifier)
      Array(@graph.dig('reverse_via', identifier)).pluck('source').uniq.size
    end
  end
end
