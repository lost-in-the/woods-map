# frozen_string_literal: true

module WoodsMap
  # The templates of one controller or mailer action, for the passage: the
  # ones the action renders and the partial chain beneath them. With W-7's
  # facts the action's render calls name them; without, Woods' view_render
  # edge and the action name do (a mailer's own template list for a mailer).
  # A template the facts name that the index does not hold stays in the list
  # with no unit, so the page can say so.
  class PassageTemplates
    # A template of the action, or a partial beneath it.
    # +locals+ are the keys the action passes a partial it renders itself (W-7); nil when not published.
    Template = Struct.new(:identifier, :unit, :role, :depth, :locals, keyword_init: true) do
      # @return [Array<String>] the lexical instance-variable mentions published for the template
      def instance_variables
        Array(unit&.dig('metadata', 'instance_variables')).map(&:to_s)
      end

      # @return [Boolean] whether template ivar metadata is available, including a known-empty list
      def facts_available?
        unit&.dig('metadata', 'instance_variables').is_a?(Array)
      end

      # @return [Array<String>] the helpers the template calls
      def helpers
        Array(unit&.dig('metadata', 'helpers_called')).map(&:to_s)
      end
    end

    PARTIAL_DEPTH = 3

    # @param repository [WoodsMap::Repository]
    # @param unit [Hash] a controller or mailer unit
    # @param action [String]
    # @param facts [WoodsMap::ActionFacts, nil]
    def initialize(repository, unit, action, facts: nil)
      @repository = repository
      @unit = unit
      @metadata = unit['metadata'] || {}
      @action = action
      @facts = facts
    end

    # @return [Array<Template>] what the action renders: templates at depth 0, its own partials at depth 1
    def rendered
      @rendered ||= @facts ? from_facts : by_convention
    end

    # @return [Array<Template>] the rendered templates, each followed by its partial chain
    def all
      @all ||= rendered.flat_map { |t| [t] + partials_of(t, t.depth + 1, [t.identifier]) }
    end

    # @return [Array<String>] templates with missing ivar facts or an unexpanded partial chain
    def missing_facts
      all.reject(&:facts_available?).map(&:identifier).concat(@unexpanded || []).uniq
    end

    private

    def mailer?
      @unit['type'].to_s == 'mailer'
    end

    def by_convention
      identifiers = if mailer?
                      mailer_templates
                    else
                      owned_templates.select { |id| File.basename(id).split('.').first == @action }
                    end
      identifiers.map { |id| template(id, 'template', 0) }
    end

    # +users/show+ is +users/show.html.erb+ and any other format or engine the index holds;
    # for a mailer, its own template list answers when the index holds none.
    def from_facts
      named = @facts.template_paths.flat_map { |path| at(path) }.map { |id| template(id, 'template', 0) }
      named + @facts.partial_paths.flat_map do |path|
        at(path).map { |id| template(id, 'partial', 1, locals: @facts.partial_locals(path)) }
      end
    end

    def at(path)
      prefix = "#{path}."
      found = Array(@repository.graph.dig('type_index', 'view_template')).select do |id|
        id == path || (id.start_with?(prefix) && id.delete_prefix(prefix).exclude?('/'))
      end
      found = mailer_templates.select { |id| id.start_with?(prefix) } if found.empty? && mailer?
      found.empty? ? [path] : found.sort
    end

    def mailer_templates
      Array(@metadata.dig('templates', @action)).map { |path| path.to_s.delete_prefix('app/views/') }
    end

    # Templates the graph ties to this controller: Woods' view_render edge.
    def owned_templates
      edges = Array(@repository.graph.dig('reverse_via', @unit['identifier'].to_s)).select do |edge|
        edge['via'] == 'view_render'
      end
      edges.map { |edge| edge['source'].to_s }.sort
    end

    def template(identifier, role, depth, locals: nil)
      Template.new(identifier: identifier, unit: @repository.unit(identifier, type: 'view_template'), role: role,
                   depth: depth, locals: locals)
    end

    # The partials a template renders, from its own dependency list, to PARTIAL_DEPTH.
    def partials_of(template, depth, seen)
      return [] if template.unit.nil?

      dependencies = Array(template.unit['dependencies']).select do |dependency|
        dependency['via'] == 'render' && seen.exclude?(dependency['target'])
      end
      if depth > PARTIAL_DEPTH
        (@unexpanded ||= []).concat(dependencies.pluck('target'))
        return []
      end

      dependencies.flat_map do |dependency|
        child = template(dependency['target'].to_s, 'partial', depth)
        [child] + partials_of(child, depth + 1, seen + [dependency['target']])
      end
    end
  end
end
