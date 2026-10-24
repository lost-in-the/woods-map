# frozen_string_literal: true

module WoodsMap
  # The Mermaid text of the Trail's lanes (C-4 under D-25): a `flowchart LR`
  # with one subgraph per lane, the steps in flow order, and dashed edges
  # where an async hop starts another process. GitHub-safe syntax only.
  class TrailLanes
    # @param lanes [Array<String>] lanes in order
    # @param steps [Array<LifecycleBuilder::Step>] numbered steps
    def initialize(lanes, steps)
      @lanes = lanes
      @steps = steps
    end

    # @return [String]
    def mermaid
      lines = ['flowchart LR']
      @lanes.each do |lane|
        lines << "  subgraph lane_#{lane} [#{quoted(lane)}]"
        @steps.select { |s| s.lane == lane }.each { |s| lines << "    s#{s.n}[#{quoted("#{s.n} · #{s.title}")}]" }
        lines << '  end'
      end
      @steps.drop(1).each { |step| lines << edge(step) }
      lines.join("\n")
    end

    # @param step [LifecycleBuilder::Step]
    # @return [String] the edge's label: how the step was reached
    def self.reach_label(step)
      case step.via
      when :graph then 'job_enqueue edge'
      when :inferred then 'save implies'
      else step.hop ? 'async hop' : nil
      end
    end

    private

    # From the step whose operation reached it (the previous step when the
    # flow does not say); dashed where another process starts.
    def edge(step)
      from = @steps.find { |s| s.label == step.caller } || @steps[@steps.index(step) - 1]
      label = self.class.reach_label(step)
      arrow = step.hop || step.via == :graph ? '-.->' : '-->'
      "  s#{from.n} #{arrow}#{"|#{quoted(label)}|" if label} s#{step.n}"
    end

    # A quoted Mermaid label; a double quote cannot be escaped inside one.
    def quoted(text)
      "\"#{text.to_s.tr('"', "'")}\""
    end
  end
end
