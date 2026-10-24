# frozen_string_literal: true

module WoodsMap
  # Builds a unit's {Lifecycle} for the Lifecycle tab, the Passage ladder and
  # the Code outline: the concerns it inlines and, under `?since=` (E-8),
  # what moved in its source (`Since#changed_members`).
  module UnitLifecycle
    extend ActiveSupport::Concern

    private

    def lifecycle_for(unit, dynamic: nil)
      WoodsMap::Lifecycle.new(unit, concern_methods: concern_methods(unit), dynamic: dynamic,
                                    changed: current_since&.changed_members(unit))
    end

    # concern name => the instance methods it defines, for each concern the unit inlines
    def concern_methods(unit)
      Array(unit.dig('metadata', 'inlined_concerns')).to_h do |name|
        concern = @repository.unit(name, type: 'concern')
        [name, Array(concern&.dig('metadata', 'instance_methods')).map(&:to_s)]
      end
    end
  end
end
