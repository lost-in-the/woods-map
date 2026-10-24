# frozen_string_literal: true

module WoodsMap
  # Partial locals across one passage (B-18): each local a template or the
  # action passes to a partial, set against what that partial reads. Woods
  # publishes both sides (woods#798): +partial_renders+ on every ERB template,
  # +locals_read+ on every ERB partial. Reads are lexical and deliberately
  # wide, so a passed local missing from them is never read by name; the flag
  # is advisory all the same. A render is left unchecked, and named, when its
  # partial is not in the index, publishes no reads (another engine), or
  # reaches its locals dynamically.
  class PartialLocals
    # A local passed and never read by name.
    Flag = Struct.new(:local, :partial, :from, :line, keyword_init: true)
    # A render the check could not decide, and why.
    Unchecked = Struct.new(:partial, :from, :why, keyword_init: true)

    # @param repository [WoodsMap::Repository]
    # @param templates [Array<PassageTemplates::Template>] the passage's templates and partial chain
    # @param owner [String] +Controller#action+, for partials the action renders itself
    def initialize(repository, templates, owner)
      @repository = repository
      @templates = templates
      @owner = owner
    end

    # @return [Boolean] whether any template here publishes its partial renders
    def published?
      @templates.any? { |t| t.unit&.dig('metadata', 'partial_renders').is_a?(Array) }
    end

    # @return [Array<Flag>]
    def flags
      checked.first
    end

    # @return [Array<Unchecked>]
    def unchecked
      checked.last
    end

    private

    def checked
      @checked ||= renders.each_with_object([[], []]) do |render, (flags, unchecked)|
        why = unchecked_reason(render)
        next unchecked << Unchecked.new(partial: render[:partial], from: render[:from], why: why) if why

        reads = read_by(render[:partial])
        render[:locals].reject { |local| reads.include?(local) }.each do |local|
          flags << Flag.new(local: local, partial: render[:partial], from: render[:from], line: render[:line])
        end
      end.map(&:uniq)
    end

    # Renders with at least one named local: the action's own (W-7), then each template's.
    def renders
      own = @templates.select { |t| t.locals&.any? }.map do |t|
        { partial: t.identifier, from: @owner, line: nil, locals: t.locals, dynamic: false }
      end
      own + @templates.flat_map { |t| template_renders(t) }.select { |r| r[:locals].any? || r[:dynamic] }
    end

    def template_renders(template)
      Array(template.unit&.dig('metadata', 'partial_renders')).grep(Hash).filter_map do |render|
        next unless render['target']

        { partial: render['target'].to_s, from: template.identifier, line: render['line'],
          locals: Array(render['locals']).map(&:to_s), dynamic: render['dynamic_locals'] == true }
      end
    end

    def unchecked_reason(render)
      partial = partial_unit(render[:partial])
      return 'the partial is not in the index' unless partial
      return 'the partial publishes no locals it reads (not an ERB template)' unless reads_published?(partial)
      return 'the locals passed are computed' if render[:dynamic]

      'the partial reaches its locals dynamically' if partial.dig('metadata', 'locals_read_dynamic')
    end

    def read_by(identifier)
      Array(partial_unit(identifier).dig('metadata', 'locals_read')).map(&:to_s)
    end

    def reads_published?(partial)
      partial.dig('metadata', 'locals_read').is_a?(Array)
    end

    def partial_unit(identifier)
      @units ||= {}
      @units.fetch(identifier) { @units[identifier] = @repository.unit(identifier, type: 'view_template') }
    end
  end
end
