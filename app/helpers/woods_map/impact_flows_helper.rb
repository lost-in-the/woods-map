# frozen_string_literal: true

module WoodsMap
  # The Flows tab's rows (B6-Impact-Flows): a flow's steps for the numbered
  # steps component, units linked only when they belong to the pinned
  # generation, changed steps marked M and affected steps with their distance.
  module ImpactFlowsHelper
    # @param row [WoodsMap::ImpactFlows::Row]
    # @return [Array<Hash>] steps for `components/steps`
    def flow_step_items(row)
      number = 0
      Array(row.steps).flat_map do |step|
        next [{ n: '', depth: 1, arrow: :return, text: step.label, mech: 'cycle, not expanded again' }] if step.cycle

        number += 1
        [{ n: number, depth: number == 1 ? 0 : 1, arrow: (number == 1 ? nil : :call), text: flow_step_text(step),
           mech: flow_step_mech(step) }] + step.lines.map { |line| flow_line_item(line, number == 1 ? 1 : 2) }
      end
    end

    # @param row [WoodsMap::ImpactFlows::Row]
    # @return [ActiveSupport::SafeBuffer] the entry point, its route above it
    def flow_entry(row)
      route = row.route ? "#{row.route['verb']} #{row.route['path']}".strip : nil
      safe_join([(route ? tag.div(route, class: 'b') : nil), tag.div(row.entry_point, class: 'mut')].compact)
    end

    # @param row [WoodsMap::ImpactFlows::Row]
    # @return [ActiveSupport::SafeBuffer] the changed units the flow passes through
    def flow_changed(row)
      return tag.span('none recorded', class: 'mut') if row.changed.empty?

      safe_join(row.changed.map { |identifier, _type| safe_join([chip(:modified, 'changed'), ' ', identifier]) }, ', ')
    end

    # @param row [WoodsMap::ImpactFlows::Row]
    # @return [String] where the steps come from
    def flow_layer(row)
      case row.steps_state
      when :shown then "precomputed, gen #{row.generation}"
      when :truncated then "precomputed, gen #{row.generation}, first #{WoodsMap::ImpactFlows::STEP_LIMIT} steps"
      when :historical then "gen #{row.generation}, steps not on this page"
      else "gen #{row.generation}, document unreadable"
      end
    end

    # A rail line for what flow evidence this page has.
    #
    # @param state [Symbol, nil] {WoodsMap::RepositoryFlows#flows_state}
    # @return [Hash] a rail item
    def flow_limit(state)
      text, own = case state
                  when :available then ['flow membership is bounded', 'W-13, expanded steps']
                  when :unreadable then ['flow evidence unreadable', 'refused by Woods']
                  when :unsupported then ['no flow readers', 'woods#805']
                  else ['no flows published', 'precompute_flows']
                  end
      { key: '·', text: text, own: layer_chip(own) }
    end

    # A rail line for whether a range's base generation survives retention (W-11).
    #
    # @param retention [WoodsMap::Retention]
    # @param generation [Integer, nil] the base generation
    # @return [Hash] a rail item
    def retention_limit(retention, generation)
      kept = retention.pinned?(generation) ? 'kept past retention' : "woods:pin[#{generation}] keeps it"
      own = case retention.state
            when :available then kept
            when :unreadable then 'pins unreadable'
            else 'no pin reader'
            end
      { key: '·', text: "base gen #{generation} #{retention.describe(generation)}", own: layer_chip(own) }
    end

    private

    def flow_step_text(step)
      label = if step.linkable
                link_to(step.label,
                        woods_map.unit_path(type: step.type, identifier: step.identifier))
              else
                step.label
              end
      safe_join([(step.distance&.zero? ? chip(:modified, 'changed in this comparison') : nil), label].compact, ' ')
    end

    def flow_step_mech(step)
      return step.type.tr('_', ' ') if step.distance.nil? || step.distance.zero?

      "#{step.type.tr('_', ' ')}, affected #{step.distance == 1 ? 'directly' : "at #{step.distance} hops"}"
    end

    def flow_line_item(line, depth)
      arrow = { response: :return, call: :call }[line.kind]
      text = %i[framework more].include?(line.kind) ? tag.span(line.text, class: 'mut') : line.text
      { n: '', depth: depth + line.depth, arrow: arrow, text: text, mech: line.mech }
    end
  end
end
