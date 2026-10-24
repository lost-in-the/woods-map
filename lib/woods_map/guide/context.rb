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
      PAGES = %i[code unit lifecycle passage graph trail impact range].freeze
      LINES = /\A(\d{1,6})(?:-(\d{1,6}))?\z/
      SELECTOR = /\A(?:gen:\d{1,9}|now|[0-9a-f]{7,40})\z/
      # A graph selection names typed units as `type:identifier`.
      NODE = /\A([a-z0-9_]{1,40}):(.{1,300})\z/
      MAX_FOCUS = 20
      MAX_NODES = 20
      GENERATION = /\A[1-9][0-9]{0,8}\z/

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
      # @return [String, nil] a Trail board's entry (W-5 grammar) whose unit the generation has
      attr_reader :entry
      # @return [Array<Array(String, String)>] a Trail board's pins the generation has, as identifier and type
      attr_reader :pins

      # @param repository [WoodsMap::Repository]
      # @param params [Hash, ActionController::Parameters] page, type, identifier, lines, action_name, focus,
      #   nodes, from, to, and a Trail board's entry, pins, gen and hops
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
        @nodes = parse_typed(values['nodes'], MAX_NODES)
        parse_board(values)
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
        [[identifier, type&.tr('_', ' ')], [line_label, 'selected'], [@action_name, 'action'],
         [short_list(@focus), 'focus'], [short_list(@nodes.map(&:first)), 'selected'], [@entry, 'entry'],
         [short_list(@pins.map(&:first)), 'pinned'], [@range&.join(' → '), 'range']].select(&:first)
      end

      # @return [String] one line for the asked turn: "L61–L62, Post" or "Post, 2 graph units"
      def summary
        nodes = "#{@nodes.size} graph #{@nodes.size == 1 ? 'unit' : 'units'}" if @nodes.any?
        [line_label, identifier, @action_name, @focus.first(3).join(', ').presence, nodes, @entry,
         ("#{@pins.size} pinned" if @pins.any?)].compact.join(', ')
      end

      # @return [String] the block the prompt templates take as {{context}}
      def to_prompt
        facts = @repository.generation_facts
        lines = (@unit ? unit_lines : []) + page_lines
        lines = ['- no unit on this page'] if lines.empty?
        ["Page context, Woods generation #{facts['generation']}, HEAD #{facts['git_sha'] || 'unknown'}:", *lines]
          .join("\n")
      end

      # @return [Hash] what the turn records
      def to_h
        { 'page' => @page&.to_s, 'type' => type, 'identifier' => identifier, 'lines' => @lines,
          'action_name' => @action_name, 'focus' => @focus, 'nodes' => typed_params(@nodes),
          'range' => @range, 'summary' => summary }.merge(board_h)
      end

      private

      def page_lines
        [("- selected lines: #{line_label} of the unit's source" if @lines),
         ("- controller action: #{@action_name}" if @action_name),
         ("- impact focus: #{@focus.join(', ')}" if @focus.any?),
         ("- units selected on the graph: #{typed_list(@nodes)}" if @nodes.any?),
         ("- trail entry: #{@entry}, async hop budget #{@hops}" if @entry),
         ("- pinned on the trail board: #{typed_list(@pins)}" if @pins.any?),
         ("- range: #{@range.join(' to ')}" if @range)].compact
      end

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

      # "A, B, C +2", or nil for none.
      def short_list(names)
        names.first(3).join(', ') + (names.size > 3 ? " +#{names.size - 3}" : '') if names.any?
      end

      def typed_list(units)
        units.map { |name, kind| "#{name} (#{kind})" }.join(', ')
      end

      def typed_params(units)
        units.map { |name, kind| "#{kind}:#{name}" }
      end

      # Typed units the generation has, in the order given, at most `limit`.
      def parse_typed(value, limit)
        names = value.is_a?(Array) ? value : value.to_s.split(',')
        names.first(limit).filter_map { |name| NODE.match(name.to_s.strip) }.map { |match| [match[2], match[1]] }
             .uniq.select { |name, kind| @repository.unit(name, type: kind) }
      end

      # A Trail board (M6): its entry when the generation has the entry's
      # unit, its pins the generation has, its generation and hop budget.
      def parse_board(values)
        entry = values['entry'].to_s
        match = WoodsMap::TrailBoard::ENTRY.match(entry)
        @entry = entry if match && @repository.graph_node(match[:unit])
        @pins = parse_typed(values['pins'], WoodsMap::TrailBoard::MAX_PINS)
        @board_gen = values['gen'].to_s.match?(GENERATION) ? values['gen'].to_i : nil
        hops = values['hops'].to_s
        @hops = hops.match?(/\A[1-3]\z/) ? hops.to_i : WoodsMap::TrailBoard::DEFAULT_HOPS
      end

      def board_h
        return {} unless @entry || @pins.any?

        { 'entry' => @entry, 'pins' => typed_params(@pins), 'gen' => @board_gen, 'hops' => @hops }
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
