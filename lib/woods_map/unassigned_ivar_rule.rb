# frozen_string_literal: true

require 'set'

module WoodsMap
  # Advisory comparison of template ivar mentions with recorded action/filter
  # assignments. Missing action bodies and template facts remain explicit limits.
  class UnassignedIvarRule
    NAME = 'template reads unassigned ivar'
    OWNER_TYPES = %w[controller mailer].freeze

    # What the impact page reads from a rule run: its findings, unknowns and result.
    Outcome = Struct.new(:findings, :unknowns, :result, keyword_init: true)

    # The rule reads every passage of the controllers and mailers a change
    # reaches: one unit and its templates each. Outcomes are kept per
    # generation and reach, so a hub's impact page reads them once.
    MEMO = GenerationMemo.new(16)

    # @param repository [WoodsMap::Repository]
    # @param radius [WoodsMap::BlastRadius]
    # @return [Outcome] the rule's outcome for that radius, computed once per generation
    def self.outcome(repository, radius)
      key = [repository.generation_key, radius.focus, radius.direct.map { |a| [a.identifier, a.type] }]
      MEMO.fetch(key) do
        rule = new(repository, radius)
        Outcome.new(findings: rule.findings.freeze, unknowns: rule.unknowns.freeze, result: rule.result)
      end
    end

    # @param repository [WoodsMap::Repository]
    # @param radius [WoodsMap::BlastRadius]
    def initialize(repository, radius)
      @repository = repository
      @radius = radius
    end

    # @return [Boolean] whether every admitted action and rendered template has facts
    def runnable?
      missing_actions.zero? && missing_templates.empty? && unresolved.empty?
    end

    # @return [Integer, String] finding count, or an explicit incomplete-coverage result
    def result
      return findings.size if runnable?
      return 'needs W-7' if passages.empty?

      "#{findings.size} #{'finding'.pluralize(findings.size)}; incomplete: #{incomplete_parts.join(', ')}"
    end

    # @return [Array<PassageTemplates::Unresolved>] dynamic render targets and unresolved partials of
    #   the covered actions, each named once
    def unresolved
      @unresolved ||= passages.flat_map(&:unresolved_renders).uniq
    end

    # @return [Array<ImpactReview::Finding>] findings from actions whose facts are available
    def findings
      @findings ||= passages.flat_map { |passage| passage.flags.map { |flag| finding(passage, flag) } }
                            .uniq { |finding| [finding.where, finding.evidence] }
    end

    # @return [Array<ImpactReview::Unknown>] each dynamic render target and unresolved partial (#47)
    def unknowns
      unresolved.map do |item|
        next unknown_render(item) if item.render_target?

        candidates = item.candidates.any? ? ", candidates #{item.candidates.join(', ')}" : ''
        ImpactReview::Unknown.new(kind: 'unresolved partial', where: item.where,
                                  why: "render #{item.name} (#{item.kind}#{candidates})",
                                  resolves: "a literal partial path the template's callers agree on")
      end
    end

    private

    def unknown_render(item)
      ImpactReview::Unknown.new(kind: 'dynamic render', where: item.where, why: "render #{item.name}",
                                resolves: 'a literal template or partial name')
    end

    def owners
      @owners ||= owner_ids.uniq.filter_map { |id| @repository.unit(id, type: @radius.type_of(id)) }
    end

    def passages
      @passages ||= owners.flat_map do |unit|
        Array(unit.dig('metadata', 'actions')).filter_map do |action|
          Passage.new(@repository, unit, action: action) if ActionFacts.for(unit, action)
        end
      end
    end

    def incomplete_parts
      targets = unresolved.count(&:render_target?)
      partials = unresolved.size - targets
      parts = ["#{missing_actions} #{'action'.pluralize(missing_actions)}",
               "#{missing_templates.size} #{'template'.pluralize(missing_templates.size)}"]
      parts << "#{targets} dynamic render #{'target'.pluralize(targets)}" if targets.positive?
      parts << "#{partials} unresolved #{'partial'.pluralize(partials)}" if partials.positive?
      parts
    end

    def missing_actions
      owners.sum do |unit|
        Array(unit.dig('metadata', 'actions')).count { |action| ActionFacts.for(unit, action).nil? }
      end
    end

    def missing_templates
      passages.flat_map(&:missing_template_facts).uniq
    end

    def owner_ids
      near = @radius.focus + @radius.direct.map(&:identifier)
      rendered_by = template_callers(near).flat_map do |id|
        Array(@repository.graph.dig('edges', id)).select { |e| e['via'] == 'view_render' }.pluck('target')
      end
      (near + rendered_by).select { |id| OWNER_TYPES.include?(@radius.type_of(id)) }
    end

    # Follow reverse render edges, including shared partials with no owner edge of their own.
    def template_callers(near)
      pending = near.select { |id| @radius.type_of(id) == 'view_template' }
      seen = Set.new
      until pending.empty?
        id = pending.shift
        next unless seen.add?(id)

        callers = Array(@repository.graph.dig('reverse_via', id)).select do |edge|
          edge['via'] == 'render' && edge['source_type'] == 'view_template'
        end
        pending.concat(callers.pluck('source'))
      end
      seen.to_a
    end

    def finding(passage, flag)
      ImpactReview::Finding.new(
        severity: 'note', text: 'Template mentions an instance variable with no recorded assignment',
        where: flag.template,
        evidence: "#{flag.template} mentions #{flag.ivar}; #{passage.identifier}##{passage.action} and its analyzed " \
                  'filter bodies have no recorded assignment. Helpers, conditions and template-local assignments ' \
                  'are not resolved.',
        layer: 'template ivars + per-action facts', rule: NAME
      )
    end
  end
end
