# frozen_string_literal: true

module WoodsMap
  # The impact page's "render by name" unknowns. Woods' render-target
  # resolver publishes +{ name:, reason: }+ for a component render that names
  # no component (+render Ghost.new+), on controllers and components alike.
  # Reading them opens every unit around the radius, most of the generation
  # at a hub, so they are kept per generation and involved set.
  module UnresolvedRenders
    MEMO = GenerationMemo.new(16)

    module_function

    # @param repository [WoodsMap::Repository]
    # @param radius [WoodsMap::BlastRadius]
    # @return [Array<ImpactReview::Unknown>]
    def for(repository, radius)
      involved = radius.involved.map { |id| [id, radius.type_of(id)] }
      MEMO.fetch([repository.generation_key, involved]) { read(repository, involved) }
    end

    # @api private
    def read(repository, involved)
      involved.flat_map do |id, type|
        renders = Array(repository.unit(id, type: type)&.dig('metadata', 'unresolved_renders'))
        renders.grep(Hash).map do |render|
          reason = render['reason'] && " (#{render['reason'].tr('_', ' ')})"
          ImpactReview::Unknown.new(kind: 'render by name', where: id, why: "render #{render['name']}#{reason}",
                                    resolves: 'a component class the index knows')
        end
      end
    end
  end
end
