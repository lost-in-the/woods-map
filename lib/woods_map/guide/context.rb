# frozen_string_literal: true

module WoodsMap
  module Guide
    # The compact context block a page contributes to a question: the
    # generation, the unit's identity and summary facts, the selected lines,
    # the units selected on a graph, the action or the impact focus. It is
    # rebuilt on the server from the
    # pinned generation; what the browser sends only names things, and any
    # name the generation does not know is dropped. Full source is not
    # included: the agent reads it with `lookup` when it needs it.
    class Context
      PAGES = %i[code unit lifecycle passage graph impact range].freeze
      LINES = /\A(\d{1,6})(?:-(\d{1,6}))?\z/
      SELECTOR = /\A(?:gen:\d{1,9}|now|[0-9a-f]{7,40})\z/
      # A graph selection names typed units as `type:identifier`.
      NODE = /\A([a-z0-9_]{1,40}):(.{1,300})\z/
      MAX_FOCUS = 20
      MAX_NODES = 20

      # @return [Symbol, nil] the page kind
      attr_reader :page
      # @return [Hash, nil] the unit, when the page has one
      attr_reader :unit
      # @return [Array(Integer, Integer), nil]
      attr_reader :lines
      # @return [String, nil]
      attr_reader :action_name
      # @return [Array<String>]
      attr_reader :focus
      # @return [Array(String, String), nil] range selectors
      attr_reader :range
      # @return [Array<Array(String, String)>] units selected on a graph, as identifier and type
      attr_reader :nodes

      # @param repository [WoodsMap::Repository]
      # @param params [Hash, ActionController::Parameters] page, type, identifier, lines, action_name, focus,
      #   nodes, from, to
      # @return [Context]
      def self.from(repository, params)
        new(repository, params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h)
      end

      # @param repository [WoodsMap::Repository]
      # @param values [Hash]
      def initialize(repository, values)
        values = values.transform_keys(&:to_s)
        @repository = repository
        @page = PAGES.find { |kind| kind.to_s == values['page'].to_s }
        @unit = find_unit(values['type'], values['identifier'])
        @lines = parse_lines(values['lines']) if @unit
        @action_name = values['action_name'].to_s[/\A\w{1,80}\z/] if @unit
        @focus = parse_focus(values['focus'])
        @nodes = parse_nodes(values['nodes'])
        @range = parse_range(values['from'], values['to'])
      end

      # @return [String, nil]
      def type
        @unit && @unit['type'].to_s
      end

      # @return [String, nil]
      def identifier
        @unit && @unit['identifier'].to_s
      end

      # @return [Array<Array(String, String)>] chips: bold part and plain part
      def chips
        chips = []
        chips << [identifier, type.tr('_', ' ')] if @unit
        chips << [line_label, 'selected'] if @lines
        chips << [@action_name, 'action'] if @action_name
        chips << [@focus.first(3).join(', ') + (@focus.size > 3 ? " +#{@focus.size - 3}" : ''), 'focus'] if @focus.any?
        chips << [nodes_label, 'selected'] if @nodes.any?
        chips << [@range.join(' → '), 'range'] if @range
        chips
      end

      # @return [String] one line for the asked turn: "L61–L62, Post" or "Post, 2 graph units"
      def summary
        [line_label, identifier, @action_name, @focus.first(3).join(', ').presence, nodes_count].compact.join(', ')
      end

      # @return [String] the block the prompt templates take as {{context}}
      def to_prompt
        facts = @repository.generation_facts
        lines = ["Page context, Woods generation #{facts['generation']}, HEAD #{facts['git_sha'] || 'unknown'}:"]
        lines.concat(unit_lines) if @unit
        lines << "- selected lines: #{line_label} of the unit's source" if @lines
        lines << "- controller action: #{@action_name}" if @action_name
        lines << "- impact focus: #{@focus.join(', ')}" if @focus.any?
        if @nodes.any?
          lines << "- units selected on the graph: #{@nodes.map do |name, kind|
            "#{name} (#{kind})"
          end.join(', ')}"
        end
        lines << "- range: #{@range.join(' to ')}" if @range
        lines << '- no unit on this page' if lines.size == 1
        lines.join("\n")
      end

      # @return [Hash] what the turn records
      def to_h
        { 'page' => @page&.to_s, 'type' => type, 'identifier' => identifier, 'lines' => @lines,
          'action_name' => @action_name, 'focus' => @focus, 'nodes' => @nodes.map { |name, kind| "#{kind}:#{name}" },
          'range' => @range, 'summary' => summary }
      end

      private

      def unit_lines
        page = WoodsMap::UnitPage.new(@repository, @unit)
        [
          "- unit: #{identifier} (#{type}), #{page.subtitle}",
          ("- file: #{page.path}" if page.path),
          "- dependencies: #{page.dependencies.size}, dependents: #{page.dependents.size}"
        ].compact
      end

      def line_label
        return unless @lines

        first, last = @lines
        first == last ? "L#{first}" : "L#{first}–L#{last}"
      end

      def nodes_count
        "#{@nodes.size} graph #{@nodes.size == 1 ? 'unit' : 'units'}" if @nodes.any?
      end

      def nodes_label
        return if @nodes.empty?

        @nodes.first(3).map(&:first).join(', ') + (@nodes.size > 3 ? " +#{@nodes.size - 3}" : '')
      end

      # Typed units the generation has, in the order given, at most MAX_NODES.
      def parse_nodes(value)
        names = value.is_a?(Array) ? value : value.to_s.split(',')
        names.first(MAX_NODES).filter_map { |name| NODE.match(name.to_s.strip) }.map { |match| [match[2], match[1]] }
             .uniq.select { |name, kind| @repository.unit(name, type: kind) }
      end

      def find_unit(type, identifier)
        return if type.to_s.empty? || identifier.to_s.empty?
        return unless type.to_s.match?(/\A[a-z0-9_]+\z/)

        @repository.unit(identifier.to_s, type: type.to_s)
      end

      def parse_lines(value)
        match = LINES.match(value.to_s)
        return unless match

        first = match[1].to_i
        last = (match[2] || match[1]).to_i
        first.positive? && last >= first ? [first, last] : nil
      end

      def parse_focus(value)
        names = value.is_a?(Array) ? value : value.to_s.split(',')
        names.map { |name| name.to_s.strip }.reject(&:empty?).uniq.first(MAX_FOCUS)
             .select { |name| @repository.identifier_types(name).any? }
      end

      def parse_range(from, to)
        from = from.to_s
        to = to.to_s.presence || 'now'
        return unless from.match?(SELECTOR) && to.match?(SELECTOR)

        [from, to]
      end
    end
  end
end
