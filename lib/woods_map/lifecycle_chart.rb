# frozen_string_literal: true

module WoodsMap
  # The flowchart and lanes renderings of one lifecycle chain (B6-Lifecycle
  # view control), built from the same numbered steps as the sequence and
  # the steps table.
  class LifecycleChart
    # Lanes in chain order: where each step runs. Validation runs inside the
    # save's transaction too; it keeps its own lane because it can halt the
    # chain before any write.
    LANES = { 'validation' => 'validation', 'transaction' => 'in the transaction',
              'commit' => 'after commit', 'async' => 'another process' }.freeze

    # @param steps [Array<Lifecycle::Step>] one event's chain, numbered
    # @param title [String] the start node, such as "Post create"
    def initialize(steps, title)
      @steps = steps
      @title = title
      @targets = steps.flat_map(&:async_targets).uniq
    end

    # Mermaid flowchart text, the branching view: each conditional step is a
    # decision whose "no" branch skips it, the commit is a node of its own,
    # and an async step hands off along a dotted edge to every job or mailer
    # it enqueues.
    #
    # @return [String]
    def flowchart
      lines = ['flowchart TD', "  start([#{label(@title)}])"]
      exits = [['start', nil]]
      @steps.each_with_index do |s, i|
        exits = commit(lines, exits) if s.commit? && (i.zero? || !@steps[i - 1].commit?)
        exits = flow_step(lines, exits, s)
      end
      lines << "  done([#{label('done')}])"
      link(lines, exits, 'done')
      @targets.each_with_index { |target, i| lines << "  a#{i}[/#{label(target)}/]" }
      (lines + async_edges).join("\n")
    end

    # Mermaid swimlane text (`swimlane-beta`, verified on the vendored Pele):
    # one lane per place a step runs, steps in chain order and async
    # hand-offs dotted into the last lane. Empty lanes are left out.
    #
    # @return [String]
    def lanes
      lines = ['swimlane-beta TB']
      @steps.group_by(&:phase).sort_by { |phase, _| LANES.keys.index(phase) }.each do |phase, members|
        lines.concat(lane(phase, members.map { |s| ["s#{s.n}", step_text(s)] }))
      end
      lines.concat(lane('async', @targets.each_with_index.map { |target, i| ["a#{i}", target] })) if @targets.any?
      @steps.each_cons(2) { |a, b| lines << "  s#{a.n} --> s#{b.n}" }
      (lines + async_edges).join("\n")
    end

    # @return [Integer] nodes in the flowchart: start, done, the commit,
    #   every step, every decision and every async target
    def flowchart_size
      @steps.size + @steps.count { |s| s.conditions.present? } + @targets.size + 2 + (@steps.any?(&:commit?) ? 1 : 0)
    end

    # @return [Integer] nodes in the lanes: every step and async target
    def lanes_size
      @steps.size + @targets.size
    end

    private

    # A quoted Mermaid label. A double quote cannot be escaped inside one,
    # so it reads as a single quote.
    def label(text)
      "\"#{text.to_s.tr('"', "'")}\""
    end

    def step_text(step)
      "#{step.n} · #{step.type} #{step.filter}"
    end

    def lane(key, nodes)
      ["  subgraph l_#{key} [#{label(LANES[key])}]", *nodes.map { |id, text| "    #{id}[#{label(text)}]" }, '  end']
    end

    def commit(lines, exits)
      lines << "  commit[[#{label('transaction commits')}]]"
      link(lines, exits, 'commit')
    end

    # Draws one step, behind a decision when it is conditional, and returns
    # the edges still open for the next node: [from, edge label or nil].
    def flow_step(lines, exits, step)
      lines << "  s#{step.n}[#{label(step_text(step))}]"
      return link(lines, exits, "s#{step.n}") if step.conditions.blank?

      lines << "  c#{step.n}{#{label(step.condition)}}"
      link(lines, exits, "c#{step.n}")
      lines << "  c#{step.n} -->|yes| s#{step.n}"
      [["s#{step.n}", nil], ["c#{step.n}", 'no']]
    end

    # Joins every open edge to a node; a skipped branch is dotted and labelled.
    def link(lines, exits, node)
      exits.each { |from, text| lines << (text ? "  #{from} -.->|#{text}| #{node}" : "  #{from} --> #{node}") }
      [[node, nil]]
    end

    def async_edges
      @steps.flat_map do |s|
        jobs = Array((s.side_effects || {})['jobs_enqueued'])
        s.async_targets.uniq.map do |target|
          "  s#{s.n} -.->|#{jobs.include?(target) ? 'enqueues' : 'mails'}| a#{@targets.index(target)}"
        end
      end
    end
  end
end
