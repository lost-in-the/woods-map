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
        @steps.select { |s| s.lane == lane }.each { |s| lines << "    s#{s.n}[#{quoted("#{s.n} · #{s.label}")}]" }
        lines << '  end'
      end
      @steps.each_cons(2) { |a, b| lines << edge(a, b) }
      lines.join("\n")
    end

    private

    # Flow order within a process; an async hop starts from the step that
    # made it, so the dashed edge joins the caller to the work it hands off.
    def edge(previous, step)
      return "  s#{previous.n} --> s#{step.n}" unless step.hop

      from = @steps.find { |s| s.label == step.hop.from } || previous
      "  s#{from.n} -.->|#{quoted(step.via == :graph ? 'job_enqueue edge' : 'async hop')}| s#{step.n}"
    end

    # A quoted Mermaid label; a double quote cannot be escaped inside one.
    def quoted(text)
      "\"#{text.to_s.tr('"', "'")}\""
    end
  end
end
