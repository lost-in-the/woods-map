# frozen_string_literal: true

module WoodsMap
  # The constant references the extractor recorded for a file, resolved to
  # units of the pinned generation. A reference that came from a runtime
  # fact (an association target) is verified; one from the static scan is
  # marked `○ static`; a name the index cannot place is left plain (B-11).
  class References
    Link = Struct.new(:name, :identifier, :type, :confidence, keyword_init: true)

    # @param repository [WoodsMap::Repository]
    # @param unit [Hash]
    def initialize(repository, unit)
      @repository = repository
      @unit = unit
      @verified = Array(unit.dig('metadata', 'associations')).to_set { |a| a['target'].to_s }
      @cache = {}
    end

    # @return [Hash{Integer => Array<Link>}] file line => links on that line
    def by_file_line
      analysis = @repository.source_references(@unit['file_path'].to_s)
      return {} unless analysis

      Array(analysis['references']).each_with_object(Hash.new { |h, k| h[k] = [] }) do |ref, lines|
        link = resolve(ref['name'].to_s)
        lines[ref['line'].to_i] << link if link
      end
    end

    # Resolve a constant name to a unit, trying the name as written, then the
    # name inside the unit's own namespace.
    #
    # @param name [String]
    # @return [Link, nil]
    def resolve(name)
      @cache.fetch(name) do
        @cache[name] = candidates(name).lazy.filter_map { |candidate| lookup(name, candidate) }.first
      end
    end

    private

    def candidates(name)
      namespace = @unit['identifier'].to_s.split('::')[0...-1]
      [name] + namespace.size.downto(1).map { |depth| (namespace.first(depth) + [name]).join('::') }
    end

    def lookup(name, candidate)
      next_identifier = candidate
      return nil if next_identifier == @unit['identifier']

      types = @repository.identifier_types(next_identifier)
      return nil if types.empty?

      type = types.first
      confidence = @verified.include?(name) || @verified.include?(next_identifier) ? :verified : :static
      Link.new(name: name, identifier: next_identifier, type: type, confidence: confidence)
    end
  end
end
