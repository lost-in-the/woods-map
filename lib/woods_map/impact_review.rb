# frozen_string_literal: true

module WoodsMap
  # What the impact tabs say about a blast radius on one generation: the risk
  # rules that can run without a range (E-5), the tests to run first and the
  # gaps, the unknowns the index reported and the boundary of every layer
  # (E-10). A rule that cannot run is listed as skipped, never dropped.
  class ImpactReview
    Finding = Struct.new(:severity, :text, :where, :evidence, :layer, :rule, keyword_init: true)
    Rule = Struct.new(:name, :severity, :needs, :layer, :result, keyword_init: true)
    TestRow = Struct.new(:spec, :covers, :reaches, :layer, keyword_init: true)
    Gap = Struct.new(:severity, :text, :why, :layer, keyword_init: true)
    Unknown = Struct.new(:kind, :where, :why, :resolves, keyword_init: true)

    # The rule registry of B8-Impact-Risks: name, severity, what it needs, layer, and what blocks it here.
    RULES = [
      ['template reads unassigned ivar', 'note', 'view instance_variables + action assigns', 'structural', 'W-7'],
      ['job without retry touched', 'note', 'job retry_on / discard_on', 'job metadata', nil],
      ['hub touched', 'blocking', 'graph_analysis.hubs', 'typed edges', nil],
      ['bridge touched', 'blocking', 'graph_analysis.bridges', 'typed edges', nil],
      ['cycle entered', 'note', 'graph_analysis.cycles', 'typed edges', nil],
      ['cross-database association added', 'blocking', 'association.through_db, both generations',
       'model metadata', 'a range'],
      ['callback side effect changed', 'note', 'callbacks.side_effects, both generations', 'resolved chain',
       'a range'],
      ['filter chain changed', 'note', 'filters.applies_to, both generations', 'resolved chain',
       'a range'],
      ['foreign key dropped', 'blocking', 'foreign_keys, both generations', 'model metadata', 'a range']
    ].freeze

    # What each layer of the index proves (B8-Impact-Unknown).
    LAYERS = [
      ['structural facts', 'the booted development environment that extracted gen %<gen>s',
       'another Rails env, a feature flag, a database-dependent column'],
      ['typed edges', 'a recorded dependency and its mechanism',
       'that changing the target breaks the source; code_reference edges are static reads'],
      ['static flows', 'operations in source order with async hops marked',
       'that the path ran; receiverless and dynamic calls stay unexpanded'],
      ['callback side effects', 'method-body analysis of symbol callbacks', 'proc and lambda callbacks, skipped'],
      ['history', 'HEAD-reachable commits, the recent ones per unit',
       'unmerged branches; older history until W-3 lands'],
      ['test coverage', 'heuristic spec ↔ unit mapping', 'that the spec exercises the changed lines'],
      ['outside the index', '—',
       'runtime values, query plans, latency, authorization, rendered output, external services']
    ].freeze

    # Unit types a test can be expected to cover.
    TESTABLE = %w[model controller mailer job service poro concern view_template component view_component
                  serializer].freeze

    # @param repository [WoodsMap::Repository]
    # @param radius [WoodsMap::BlastRadius]
    def initialize(repository, radius)
      @repository = repository
      @radius = radius
      @graph = repository.graph
      @analysis = repository.graph_analysis
      @ivar_rule = UnassignedIvarRule.new(repository, radius)
    end

    # @return [Array<Finding>] the findings of the rules that ran
    def findings
      @findings ||= @ivar_rule.findings + hub_findings + bridge_findings + cycle_findings + job_findings
    end

    # @return [Array<Rule>] every rule with its result, or what it needs to run
    def rules
      RULES.map do |name, severity, needs, layer, blocker|
        result = blocker ? "needs #{blocker}" : findings.count { |f| f.rule == name }
        result = @ivar_rule.result if name == UnassignedIvarRule::NAME
        Rule.new(name: name, severity: severity, needs: needs, layer: layer, result: result)
      end
    end

    # @return [Array<TestRow>] the specs mapped to the focus, then to the
    #   direct dependents, then to the units further out within the depth
    def tests
      @tests ||= begin
        rows = {}
        test_reaches.each do |ids, reach|
          ids.each do |id|
            coverage_of(id).each do |spec|
              row = rows[spec] ||= TestRow.new(spec: spec, covers: [], reaches: reach, layer: 'test_coverage')
              row.covers << id unless row.covers.include?(id)
            end
          end
        end
        rows.values
      end
    end

    # @return [Array<Gap>] units in the focus or one edge away with no mapped test
    def gaps
      ids = (@radius.focus + @radius.direct.map(&:identifier)).uniq
      ids.select { |id| TESTABLE.include?(@radius.type_of(id)) && coverage_of(id).empty? }.map do |id|
        blocking = findings.any? { |f| f.where == id && f.severity == 'blocking' }
        Gap.new(severity: blocking ? 'blocking' : 'note', text: "#{id} has no mapped test", layer: 'test_mapping',
                why: blocking ? 'a blocking finding names it; no spec reaches it' : 'no test_coverage edge reaches it')
      end
    end

    # @return [Array<Unknown>] what the index reported it could not resolve around the radius
    def unknowns
      @unknowns ||= begin
        radius = ImpactUnknowns.new(@repository, @radius, @analysis)
        radius.unresolved_renders + @ivar_rule.unknowns + radius.unresolvable_routes + radius.volatile_dependencies
      end
    end

    # @return [Array<Array(String, String, String)>] layer, true within, not proven
    def layers
      LAYERS.map { |layer, within, not_proven| [layer, format(within, gen: @repository.generation_number), not_proven] }
    end

    private

    # The focus, the direct dependents, then each further distance within the depth.
    def test_reaches
      reaches = [[@radius.focus, 'the focus'], [@radius.direct.map(&:identifier), 'a direct dependent']]
      reaches + @radius.transitive.group_by(&:distance).sort.map do |distance, units|
        [units.map(&:identifier), "#{distance} hops away"]
      end
    end

    def coverage_of(identifier)
      Array(@graph.dig('reverse_via', identifier)).select { |e| e['via'] == 'test_coverage' }.pluck('source')
    end

    def hub_findings
      @radius.focus.select { |id| @radius.hubs.key?(id) }.map do |id|
        Finding.new(severity: 'blocking', text: 'A hub is in the focus', where: id,
                    evidence: "#{@radius.hubs[id]} units depend on it", layer: 'typed edges', rule: 'hub touched')
      end
    end

    def bridge_findings
      @radius.focus.select { |id| @radius.bridges.include?(id) }.map do |id|
        Finding.new(severity: 'blocking', text: 'A bridge is in the focus', where: id,
                    evidence: 'the only edge between two parts of the graph', layer: 'typed edges',
                    rule: 'bridge touched')
      end
    end

    def cycle_findings
      @radius.focus.select { |id| @radius.cycles.include?(id) }.map do |id|
        cycle = Array(@analysis['cycles']).find { |c| c.include?(id) }
        Finding.new(severity: 'note', text: 'The focus is on a cycle', where: id,
                    evidence: Array(cycle).join(' → '), layer: 'typed edges', rule: 'cycle entered')
      end
    end

    def job_findings
      ids = @radius.involved.uniq.select { |id| @radius.type_of(id) == 'job' }
      ids.filter_map do |id|
        job = @repository.unit(id, type: 'job')
        next unless job && %w[retry_on discard_on].all? { |key| Array(job.dig('metadata', key)).empty? }

        Finding.new(severity: 'note', text: 'A job with no retry or discard policy is in the radius', where: id,
                    evidence: 'declares no retry_on / discard_on', layer: 'job metadata',
                    rule: 'job without retry touched')
      end
    end
  end
end
