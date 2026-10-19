# frozen_string_literal: true

module WoodsMap
  # The data passage of one controller or mailer action (B8-Passage): what the
  # index publishes of request → filters → action → templates → response.
  # Filter scopes are shown as declared; the resolved chain and owner (W-8)
  # and the per-action assigns, params and renders (W-7) are named as limits,
  # never derived here.
  class Passage
    # One application filter with its declared scope.
    Filter = Struct.new(:kind, :name, :only, :except, :file, :line, keyword_init: true) do
      # @return [String] the declared scope as Rails reads it
      def scope
        return "only: #{only.join(', ')}" if only
        return "except: #{except.join(', ')}" if except

        'every action'
      end

      # @param action [String]
      # @return [Boolean] whether the declared only/except names the action
      def declared_for?(action)
        return only.include?(action) if only
        return except.exclude?(action) if except

        true
      end
    end

    # A template of the action, or a partial beneath it.
    Template = Struct.new(:identifier, :unit, :role, :depth, keyword_init: true) do
      # @return [Array<String>] the instance variables the template reads
      def instance_variables
        Array(unit&.dig('metadata', 'instance_variables')).map(&:to_s)
      end

      # @return [Array<String>] the helpers the template calls
      def helpers
        Array(unit&.dig('metadata', 'helpers_called')).map(&:to_s)
      end
    end

    # Framework filters: procs from engines, the CSRF and origin checks.
    FRAMEWORK = /\A(#<|verify_authenticity_token\z|verify_same_origin_request\z)/
    # The model event an action name implies, for the callback ladder.
    EVENT_BY_ACTION = { 'create' => 'create', 'update' => 'update', 'destroy' => 'destroy' }.freeze
    PARTIAL_DEPTH = 3

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

    # @return [Hash, nil] owner, defined_in, file and line of the action's method
    def declared
      @metadata.dig('action_sources', action)
    end

    # @return [Array<Filter>] the application's filters in declared order; framework ones are counted, not listed
    def filters
      @filters ||= raw_filters.reject { |f| framework?(f) }.map do |f|
        Filter.new(kind: f['kind'] || f['type'].to_s.sub('_action', ''), name: f['filter'].to_s,
                   only: f['only'], except: f['except'], file: f['file'], line: f['line'])
      end
    end

    # @return [Integer] filters the framework adds (engines, CSRF, origin), hidden from the passage
    def framework_filter_count
      raw_filters.count { |f| framework?(f) }
    end

    # @param for_action [String]
    # @return [Array<Filter>] the filters whose declared scope names the action
    def filters_for(for_action = action)
      filters.select { |f| f.declared_for?(for_action) }
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

    # @return [Array<Template>] the action's templates (depth 0) followed by their partial chain
    def templates
      @templates ||= action_templates.flat_map { |t| [t] + partials_of(t, 1, [t.identifier]) }
    end

    # @return [Array<Template>] the templates the index ties to this action
    def action_templates
      identifiers = if mailer?
                      mailer_templates
                    else
                      owned_templates.select { |id| File.basename(id).split('.').first == action }
                    end
      identifiers.map { |id| template(id, 'template', 0) }
    end

    # @return [Array<String>] response formats: responds_to, or a mailer's template formats
    def formats
      return action_templates.filter_map { |t| t.identifier[/\.(\w+)\.\w+\z/, 1] }.uniq if mailer?

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

    def mailer_templates
      Array(@metadata.dig('templates', action)).map { |path| path.to_s.delete_prefix('app/views/') }
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

    # Templates the graph ties to this controller: Woods' view_render edge.
    def owned_templates
      edges = Array(@repository.graph.dig('reverse_via', identifier)).select { |e| e['via'] == 'view_render' }
      edges.map { |e| e['source'].to_s }.sort
    end

    def template(identifier, role, depth)
      Template.new(identifier: identifier, unit: @repository.unit(identifier, type: 'view_template'), role: role,
                   depth: depth)
    end

    # The partials a template renders, from its own dependency list, to PARTIAL_DEPTH.
    def partials_of(template, depth, seen)
      return [] if depth > PARTIAL_DEPTH || template.unit.nil?

      Array(template.unit['dependencies']).select { |d| d['via'] == 'render' }.flat_map do |d|
        next [] if seen.include?(d['target'])

        child = template(d['target'].to_s, 'partial', depth)
        [child] + partials_of(child, depth + 1, seen + [d['target']])
      end
    end
  end
end
