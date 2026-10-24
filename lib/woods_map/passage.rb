# frozen_string_literal: true

module WoodsMap
  # The data passage of one controller or mailer action (B8-Passage): what the
  # index publishes of request → filters → action → templates → response.
  # Filters follow the resolved chain Woods publishes (W-8, woods#758): the
  # actions each applies to, its owner and whether an if/unless condition
  # still decides it. On a generation without it the passage falls back to
  # the declared only/except and names the resolved chain as a limit; it never
  # derives the chain itself. With W-7's per-action facts the passage knows
  # what the action and its filters assign and render, and notes template ivar
  # mentions with no assignment recorded in those bodies.
  class Passage
    # One application filter (see {PassageFilter}).
    Filter = PassageFilter

    # A template ivar mention with no assignment recorded in the action or its filters.
    Flag = Struct.new(:ivar, :template, keyword_init: true)

    # Framework filters: procs from engines, the CSRF and origin checks.
    FRAMEWORK = /\A(#<|verify_authenticity_token\z|verify_same_origin_request\z)/
    # The model event an action name implies, for the callback ladder.
    EVENT_BY_ACTION = { 'create' => 'create', 'update' => 'update', 'destroy' => 'destroy' }.freeze
    # The Woods issue that would publish partial locals passed and read (B-18's partial-local flag).
    LOCALS_ITEM = 'woods#798'

    # @param repository [WoodsMap::Repository]
    # @param unit [Hash] a controller or mailer unit
    # @param action [String, nil] the action; the first one when nil or unknown
    def initialize(repository, unit, action: nil)
      @repository = repository
      @unit = unit
      @metadata = unit['metadata'] || {}
      @action = actions.include?(action.to_s) ? action.to_s : actions.first
    end

    attr_reader :action, :unit

    # @return [String]
    def identifier
      @unit['identifier'].to_s
    end

    # @return [Boolean]
    def mailer?
      @unit['type'].to_s == 'mailer'
    end

    # @return [Array<String>] the actions the index lists, in its order
    def actions
      Array(@metadata['actions']).map(&:to_s)
    end

    # @return [Array<Hash>] the routes of the action: verb, path, name
    def routes
      Array(@metadata.dig('routes', action))
    end

    # @return [String] "GET /users/:id", or "deliver account_activation" for a mailer
    def request_label
      return "deliver #{action}" if mailer?

      routes.map { |r| "#{r['verb']} #{r['path']}" }.first || 'no route'
    end

    # @return [Hash, nil] owner, file and line of the action's method: action_sources, else the W-7 facts
    def declared
      @metadata.dig('action_sources', action) ||
        (facts&.line && { 'owner' => identifier, 'file' => facts.file, 'line' => facts.line })
    end

    # @return [Array<Filter>] the application's filters in chain order; framework ones are counted, not listed
    def filters
      @filters ||= raw_filters.reject { |f| framework?(f) }.map do |f|
        Filter.new(kind: f['kind'] || f['type'].to_s.sub('_action', ''), name: f['filter'].to_s,
                   only: f['only'], except: f['except'], if_condition: f['if'], unless_condition: f['unless'],
                   file: f['file'], line: f['line'], owner: f['owner'], applies_to: f['applies_to'],
                   applicability: f['applicability'], declaration: f['declaration'])
      end
    end

    # @return [Boolean] whether every filter carries the resolved chain (W-8); false on an older
    #   generation, where the passage shows declared scopes and names the limit
    def resolved?
      raw_filters.any? && raw_filters.all? { |f| f['applies_to'].is_a?(Array) }
    end

    # @return [Integer] filters the framework adds (engines, CSRF, origin), hidden from the passage
    def framework_filter_count
      raw_filters.count { |f| framework?(f) }
    end

    # @param for_action [String]
    # @return [Array<Filter>] the filters that apply to the action, in chain order: the published
    #   applies_to (W-8), else the declared scope
    def filters_for(for_action = action)
      filters.select { |f| f.applies?(for_action) }
    end

    # @return [Array<String>] path parameters named by the action's routes
    def path_params
      routes.flat_map { |r| r['path'].to_s.scan(/:([a-z_]+)/).flatten }.uniq
    end

    # @return [Array<Hash>] the permitted-params methods: method, model, permitted keys
    def permitted
      (@metadata['permitted_params'] || {}).map do |method, facts|
        { 'method' => method.to_s, 'model' => facts['model'].to_s,
          'permitted' => Array(facts['permitted']).map(&:to_s) }
      end
    end

    # @return [Array<PermittedAttributes>] each permitted-params method set against its model's published facts
    def permitted_attributes
      @permitted_attributes ||= permitted.map { |entry| PermittedAttributes.new(@repository, entry) }
    end

    # @return [WoodsMap::PartialLocals] the locals each partial here is passed, set against what it reads
    def partial_locals
      @partial_locals ||= PartialLocals.new(@repository, templates, "#{identifier}##{action}")
    end

    # @return [Array<PassageTemplates::Template>] the action's templates (depth 0) and their partial chain
    def templates
      template_resolver.all
    end

    # @return [WoodsMap::ActionFacts, nil] the action's W-7 facts, nil on an index without them
    def facts
      return @facts if defined?(@facts)

      @facts = ActionFacts.for(@unit, action)
    end

    # @return [Array<PassageTemplates::Template>] the templates the action renders
    def action_templates
      template_resolver.rendered
    end

    # @return [Array<String>] templates whose ivar facts or deeper partial chain are unavailable
    def missing_template_facts
      template_resolver.missing_facts
    end

    # @return [Array<PassageTemplates::Unresolved>] dynamic render targets and unresolved partials
    def unresolved_renders
      template_resolver.unresolved
    end

    # @return [Boolean] whether every template the action can render is known and has facts
    def coverage_complete?
      missing_template_facts.empty? && unresolved_renders.empty?
    end

    # @return [Array<Flag>, nil] lexical template ivar mentions without a recorded assignment;
    #   nil when the index has no facts to decide with
    def flags
      return nil unless facts

      templates.flat_map do |t|
        (t.instance_variables - facts.assigned.to_a).map { |ivar| Flag.new(ivar: ivar, template: t.identifier) }
      end.uniq
    end

    # @return [Array<String>] response formats: responds_to, or a mailer's template formats
    def formats
      return action_templates.filter_map { |t| t.identifier[/\.(\w+)\.\w+\z/, 1] }.uniq if mailer?
      return facts.formats if facts&.formats&.any?

      Array(@metadata['responds_to']).map(&:to_s)
    end

    # @return [String, nil] the mailer's layout; a controller's is not in the index (W-7)
    def layout
      mailer? ? @metadata['layout'] : nil
    end

    # @return [Array<String>] every instance variable the templates and partials read
    def instance_variables_read
      templates.flat_map(&:instance_variables).uniq
    end

    # @return [Hash, nil] the model whose save the action implies: the permitted model, else the first referenced
    def ladder_model
      referenced = Array(@unit['dependencies']).select { |d| d['type'] == 'model' }
      names = permitted.map { |p| p['model'].camelize } + referenced.map { |d| d['target'].to_s }
      names.uniq.lazy.filter_map { |name| @repository.unit(name, type: 'model') }.first
    end

    # @return [String, nil] the model event the action name implies
    def ladder_event
      EVENT_BY_ACTION[action]
    end

    # @return [String] a Mermaid sequence diagram of the passage; the numbers match the stages
    def mermaid
      caller_name = mailer? ? 'App' : 'Browser'
      participants = ['sequenceDiagram', '  autonumber', "  participant #{caller_name}",
                      "  participant C as #{identifier}"]
      action_templates.each_with_index { |t, i| participants << "  participant T#{i} as #{t.identifier}" }
      calls = ["  #{caller_name}->>C: #{request_label}"] + filter_calls('before') + ["  C->>C: #{action}"]
      action_templates.each_index { |i| calls << "  C->>T#{i}: render" }
      calls += filter_calls('after')
      calls << "  C-->>#{caller_name}: #{formats.join(', ').presence || 'response'}"
      (participants + calls).join("\n")
    end

    private

    def template_resolver
      @template_resolver ||= PassageTemplates.new(@repository, @unit, action, facts: facts)
    end

    def filter_calls(kind)
      filters_for.select { |f| f.kind == kind }.map { |f| "  C->>C: #{kind} #{f.name}" }
    end

    def raw_filters
      Array(@metadata['filters'] || @metadata['callbacks'])
    end

    def framework?(filter)
      filter['filter'].to_s.match?(FRAMEWORK)
    end
  end
end
