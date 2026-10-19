# frozen_string_literal: true

module WoodsMap
  # The impact rule "template reads unassigned ivar" (E-5) over a blast
  # radius: for every controller or mailer in the focus or one edge away, and
  # the owner of every template in the focus, each action's passage flags.
  # Runs on W-7's per-action facts; on an index without them it cannot run.
  class UnassignedIvarRule
    NAME = 'template reads unassigned ivar'
    OWNER_TYPES = %w[controller mailer].freeze

    # @param repository [WoodsMap::Repository]
    # @param radius [WoodsMap::BlastRadius]
    def initialize(repository, radius)
      @repository = repository
      @radius = radius
    end

    # @return [Boolean] whether the owners in reach carry per-action facts; true when there are none to check
    def runnable?
      owners.empty? || owners.any? { |unit| unit.dig('metadata', 'action_facts').is_a?(Hash) }
    end

    # @return [Array<ImpactReview::Finding>]
    def findings
      found = owners.flat_map do |unit|
        Hash(unit.dig('metadata', 'action_facts')).keys.flat_map do |action|
          Array(Passage.new(@repository, unit, action: action).flags).map { |flag| finding(unit, action, flag) }
        end
      end
      found.uniq { |finding| [finding.where, finding.evidence] }
    end

    private

    def owners
      @owners ||= owner_ids.uniq.filter_map { |id| @repository.unit(id, type: @radius.type_of(id)) }
    end

    def owner_ids
      near = @radius.focus + @radius.direct.map(&:identifier)
      templates = @radius.focus.select { |id| @radius.type_of(id) == 'view_template' }
      rendered_by = templates.flat_map do |id|
        Array(@repository.graph.dig('edges', id)).select { |e| e['via'] == 'view_render' }.pluck('target')
      end
      (near + rendered_by).select { |id| OWNER_TYPES.include?(@radius.type_of(id)) }
    end

    def finding(unit, action, flag)
      ImpactReview::Finding.new(
        severity: 'blocking', text: 'Template reads an instance variable nothing assigns', where: flag.template,
        evidence: "#{flag.ivar} is read in #{flag.template}; #{unit['identifier']}##{action} and its filters never " \
                  'assign it, so it renders nil',
        layer: 'template ivars + per-action facts', rule: NAME
      )
    end
  end
end
