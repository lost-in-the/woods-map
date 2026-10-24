# frozen_string_literal: true

require 'set'

module WoodsMap
  # The unknowns of an impact radius that come from the index rather than
  # from a rule (E-10): renders the index could not resolve, unresolvable
  # routes and volatile dependencies. Graph analysis lists the routes and
  # volatile edges of the whole application; only the ones that name a unit
  # within the radius are the radius's, so the count moves with the focus and
  # the depth.
  class ImpactUnknowns
    # The renders are read from every unit in the radius, most of the
    # generation at a hub, so they are kept per generation and involved set.
    MEMO = GenerationMemo.new(16)

    # @param repository [WoodsMap::Repository]
    # @param radius [WoodsMap::BlastRadius]
    # @param analysis [Hash] graph_analysis.json of the same generation
    def initialize(repository, radius, analysis)
      @repository = repository
      @radius = radius
      @analysis = analysis
    end

    # Woods' render-target resolver publishes +{ name:, reason: }+ for a component render that names no
    # component (+render Ghost.new+), on controllers and components alike.
    # Only the involved units the generation lists as having one are opened
    # (woods#837); without that list, from an older writer, every involved
    # unit is.
    # @return [Array<ImpactReview::Unknown>]
    def unresolved_renders
      units = @radius.involved.map { |id| [id, @radius.type_of(id)] }
      listed = @repository.units_with(:unresolved_renders)
      if listed
        typed = listed.to_set { |row| [row['identifier'], row['type']] }
        units = units.select { |unit| typed.include?(unit) }
      end
      MEMO.fetch([@repository.generation_key, units]) { read_unresolved_renders(units) }
    end

    # @api private
    # @param units [Array<Array(String, String)>] identifier and type
    def read_unresolved_renders(units)
      units.flat_map do |id, type|
        renders = Array(@repository.unit(id, type: type)&.dig('metadata', 'unresolved_renders'))
        renders.grep(Hash).map do |render|
          reason = render['reason'] && " (#{render['reason'].tr('_', ' ')})"
          ImpactReview::Unknown.new(kind: 'render by name', where: id, why: "render #{render['name']}#{reason}",
                                    resolves: 'a component class the index knows')
        end
      end
    end

    # Only the routes that name a unit in the radius: the analysis lists the
    # whole application's, which would not move with the focus or the depth.
    # @return [Array<ImpactReview::Unknown>]
    def unresolvable_routes
      Array(@analysis['unresolvable_routes']).filter_map do |route|
        where = route.is_a?(Hash) ? route['route'] || route['identifier'] : route.to_s
        names = route.is_a?(Hash) ? [where, route['controller']] : [where]
        next unless names.compact.any? { |name| involved.include?(name.to_s) }

        ImpactReview::Unknown.new(kind: 'unresolvable route', where: where,
                                  why: 'the route names no controller action the index knows',
                                  resolves: 'a resolvable controller#action')
      end
    end

    # Only the edges with an end in the radius (`from`/`to`, as Woods publishes them).
    # @return [Array<ImpactReview::Unknown>]
    def volatile_dependencies
      Array(@analysis['volatile_dependencies']).filter_map do |dep|
        next unless dep.is_a?(Hash)

        ends = [dep['from'] || dep['source'], dep['to'] || dep['target']].map(&:to_s)
        next unless ends.any? { |name| involved.include?(name) }

        where = ends.join(' → ')
        ImpactReview::Unknown.new(kind: 'volatile dependency', where: where,
                                  why: 'the edge comes and goes between extractions',
                                  resolves: 'a stable reference, or a re-extraction')
      end
    end

    private

    def involved
      @involved ||= @radius.involved.to_set
    end
  end
end
