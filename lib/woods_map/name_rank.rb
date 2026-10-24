# frozen_string_literal: true

module WoodsMap
  # The rank of a name match, the same order Woods ranks identifier
  # matches in: the exact identifier (0), an exact short name such as the
  # last +::+ segment, a table's name after +table:+ or a path segment
  # (1), a prefix of any of those (2), any other match (3); a route is named
  # by its path, not its HTTP verb. Within a rank, shorter names come first.
  module NameRank
    module_function

    # @param identifier [String]
    # @param query [String] the literal the reader typed
    # @return [Array(Integer, Integer, Integer)] sortable rank
    def call(identifier, query)
      id = identifier.to_s.downcase
      literal = query.to_s.downcase
      return [0, id.length, 0] if id == literal

      forms = forms(id)
      exact = forms.index(literal)
      return [1, literal.length, exact] if exact

      prefixed = forms.each_with_index.select { |form, _| form.start_with?(literal) }
      return [3, id.length, 0] if prefixed.empty?

      form, index = prefixed.min_by { |candidate, position| [candidate.length, position] }
      [2, form.length, index]
    end

    # @param id [String] a downcased identifier
    # @return [Array<String>] the identifier and its short names
    def forms(id)
      named = id.sub(%r{\A[a-z]+ (?=/)}, '')
      [named, named.split('::').last, named.sub(/\A[a-z_]+:(?!:)/, ''), *named.split('/').reject(&:empty?)]
        .compact.uniq
    end
  end
end
