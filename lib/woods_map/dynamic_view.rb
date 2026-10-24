# frozen_string_literal: true

module WoodsMap
  # The C4 dynamic rendering (B-23) of a model event's callback chain, alone
  # (the Lifecycle view control) or behind an action's passage: the numbered
  # steps grouped by the container they run in, the write landing in the
  # model's database, and every job or mailer a step hands work to in the
  # container W-9 attributes it to (woods#759). A Mermaid flowchart in C4
  # notation, drawn by Pele (D-21): each box names its container and
  # technology, each arrow its mechanism, and dashed arrows are asynchronous.
  #
  # Container names and technologies come from {Landscape}, so the view and
  # the Landscape page agree. A generation without container attribution has
  # no dynamic view ({#attributed?} is false).
  class DynamicView
    # Node budget (R-4), the same as the flowchart and the lanes.
    BUDGET = 150

    # The statement each event ends in.
    WRITES = { 'create' => 'INSERT', 'update' => 'UPDATE', 'destroy' => 'DELETE' }.freeze

    # One box inside a container: an id, its text and its Mermaid shape.
    Node = Struct.new(:id, :text, :shape, keyword_init: true)

    # A model event's save: the model unit, its numbered chain and the event.
    Save = Struct.new(:model, :steps, :event, keyword_init: true)

    # @param repository [Repository]
    # @param landscape [Landscape, nil] for container names and technologies; built when nil
    def initialize(repository, landscape: nil)
      @repository = repository
      @graph = repository.graph
      @landscape = landscape || Landscape.new(repository)
    end

    # @!method attributed?
    #   @return [Boolean] whether the generation publishes container attribution
    delegate :attributed?, to: :@landscape

    # A model event on its own: the chain runs in whichever process saves the
    # model, which the index cannot know, so that box says so.
    #
    # @param model [Hash] the model unit
    # @param steps [Array<Lifecycle::Step>] the event's numbered chain
    # @param event [String] create, update or destroy
    # @return [String] Mermaid text
    def lifecycle(model, steps, event)
      build do |b|
        b.box('proc', "Process that saves #{model['identifier']} · web or job runner",
              [Node.new(id: 'start', text: "#{model['identifier']} #{event}", shape: :stadium)])
        b.chain('start', Save.new(model: model, steps: steps, event: event), 'proc')
      end
    end

    # An action's passage with the chain its model event runs, all in the web
    # process. The save branches off the action; the render and the response
    # follow the action, since the index does not say which outcome renders.
    #
    # @param passage [Passage]
    # @param model [Hash, nil] the callback ladder's model
    # @param steps [Array<Lifecycle::Step>] that model's chain for the event; empty without one
    # @param event [String, nil]
    # @return [String] Mermaid text
    def passage(passage, model, steps, event)
      build do |b|
        web = container('web')
        b.box('web', box_label(web, 'Web process'), passage_nodes(passage))
        b.sequence(%w[request] + passage_ids(passage, :before) + %w[action])
        b.sequence(%w[action] + passage_ids(passage, :templates) + %w[response])
        next unless model && event

        b.chain('action', Save.new(model: model, steps: steps, event: event), 'web', via: "save #{model['identifier']}")
      end
    end

    # @param text [String] the Mermaid text
    # @return [Integer] nodes in it
    def self.size(text)
      text.scan(/^\s+(\w+)(?:\(\[|\[\(|\[\[|\[")/).size
    end

    # @param text [String]
    # @return [String, nil] why it is not drawn, nil within the budget
    def self.refusal(text)
      nodes = size(text)
      "#{nodes} nodes is over the dynamic view's budget of #{BUDGET}" if nodes > BUDGET
    end

    # @param id [String] web, jobs, or db_<name>
    # @return [Landscape::Container, nil]
    def container(id)
      @landscape.containers.find { |c| c.id == id }
    end

    # @param id [String] such as mail
    # @return [Landscape::Container, nil] an external system on the Landscape
    def external(id)
      @landscape.externals.find { |c| c.id == id }
    end

    # @param identifier [String]
    # @return [Hash, nil] the published graph node
    def node_for(identifier)
      Hash(@graph['nodes'])[identifier.to_s]
    end

    # @param container [Landscape::Container, nil]
    # @param fallback [String]
    # @return [String] "name · technology"
    def box_label(container, fallback)
      return fallback unless container

      [container.name, container.technology].compact.join(' · ')
    end

    private

    def build
      builder = Builder.new(self)
      yield builder
      builder.to_s
    end

    def passage_nodes(passage)
      filters = before_filters(passage).each_with_index.map do |f, i|
        Node.new(id: "f#{i}", text: "#{f.kind} #{f.name}", shape: :box)
      end
      templates = passage.action_templates.each_with_index.map do |t, i|
        Node.new(id: "t#{i}", text: "render #{t.identifier}", shape: :box)
      end
      [Node.new(id: 'request', text: passage.request_label, shape: :stadium), *filters,
       Node.new(id: 'action', text: "#{passage.identifier}##{passage.action}", shape: :box), *templates,
       Node.new(id: 'response', text: passage.formats.join(', ').presence || 'response', shape: :stadium)]
    end

    def before_filters(passage)
      passage.filters_for.select { |f| %w[before around].include?(f.kind) }
    end

    def passage_ids(passage, part)
      if part == :before
        before_filters(passage).each_index.map { |i| "f#{i}" }
      else
        passage.action_templates.each_index.map { |i| "t#{i}" }
      end
    end

    # Accumulates the subgraphs, then the edges, of one dynamic view.
    class Builder
      def initialize(view)
        @view = view
        @boxes = {}
        @order = []
        @edges = []
      end

      # @param id [String] subgraph id
      # @param label [String]
      # @param nodes [Array<Node>]
      def box(id, label, nodes)
        @order << id unless @boxes.key?(id)
        (@boxes[id] ||= { label: label, nodes: [] })[:nodes].concat(nodes)
      end

      # Solid arrows along ids, skipping nils.
      def sequence(ids)
        ids.compact.each_cons(2) { |from, to| @edges << "  #{from} --> #{to}" }
      end

      # The model chain from +from+: the steps in +box+, the write in the
      # model's database, the commit callbacks back in +box+, and the async
      # hops. +via+ labels the first arrow (an action's save).
      #
      # @param from [String] the node the chain starts from
      # @param save [Save]
      # @param box [String] the subgraph the steps run in
      # @param via [String, nil]
      # @return [String] the id the chain ends on
      def chain(from, save, box, via: nil)
        transaction, commit = save.steps.partition { |s| !s.commit? }.map { |list| list.map { |s| "s#{s.n}" } }
        box(box, nil, save.steps.map { |s| step_node(s) })
        enter(from, transaction, via, write_node(save.model, save.event))
        sequence(['w'] + commit)
        save.steps.each { |s| async(s) }
        commit.last || 'w'
      end

      # @return [String] Mermaid text
      def to_s
        lines = ['flowchart LR']
        @order.each do |id|
          box = @boxes[id]
          lines << "  subgraph #{id} [#{q(box[:label])}]"
          lines << '    direction TB'
          box[:nodes].each { |node| lines << "    #{node.id}#{shape(node)}" }
          lines << '  end'
        end
        (lines + @edges).join("\n")
      end

      private

      # The database box and its write node; returns the write arrow's label.
      def write_node(model, event)
        database = @view.node_for(model['identifier'])&.dig('database') || 'primary'
        table = model.dig('metadata', 'table_name') || model['identifier'].to_s.tableize
        statement = WRITES.fetch(event, 'write')
        box("db_#{database}", @view.box_label(@view.container("db_#{database}"), "#{database.to_s.humanize} database"),
            [Node.new(id: 'w', text: "#{table} · #{statement}", shape: :cylinder)])
        "#{statement} #{table}, commit"
      end

      def step_node(step)
        Node.new(id: "s#{step.n}", text: "#{step.n} · #{step.type} #{step.filter}", shape: :box)
      end

      # From +from+ through the transaction steps to the write.
      def enter(from, ids, via, write_label)
        return @edges << arrow(from, 'w', [via, write_label].compact.join(', ')) if ids.empty?

        @edges << arrow(from, ids.first, via)
        sequence(ids)
        @edges << arrow(ids.last, 'w', write_label)
      end

      def arrow(from, to, label)
        label.present? ? "  #{from} -->|#{q(label)}| #{to}" : "  #{from} --> #{to}"
      end

      def async(step)
        jobs = Array((step.side_effects || {})['jobs_enqueued'])
        step.async_targets.uniq.each do |target|
          id = "a_#{target.gsub(/\W/, '_')}"
          kind = @view.node_for(target)&.dig('container')
          holder = kind && @view.container(kind)
          box(holder ? kind : 'elsewhere', @view.box_label(holder, 'Another process'),
              [Node.new(id: id, text: "#{target} · #{jobs.include?(target) ? 'job' : 'mailer'}", shape: :box)])
          @edges << "  s#{step.n} -.->|#{q("#{step.n} · #{jobs.include?(target) ? 'enqueues' : 'mails'}")}| #{id}"
          mail(id) unless jobs.include?(target)
        end
      end

      def mail(id)
        mail = @view.external('mail')
        return unless mail

        box('ext_mail', @view.box_label(mail, 'Mail delivery'),
            [Node.new(id: 'mail', text: 'mail delivery', shape: :subroutine)])
        edge = "  #{id} -.->|#{q('delivers')}| mail"
        @edges << edge unless @edges.include?(edge)
      end

      def shape(node)
        text = q(node.text)
        case node.shape
        when :stadium then "([#{text}])"
        when :cylinder then "[(#{text})]"
        when :subroutine then "[[#{text}]]"
        else "[#{text}]"
        end
      end

      # A quoted Mermaid label; a double quote cannot be escaped inside one.
      def q(text)
        "\"#{text.to_s.tr('"', "'")}\""
      end
    end
  end
end
