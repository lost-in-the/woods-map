# frozen_string_literal: true

module WoodsMap
  # One listed filter: its declared scope and, from W-8, the actions it
  # applies to, its owner and its applicability; with woods#936, who wrote it
  # (`origin`: app or gem on a listed filter, nil on an older generation).
  PassageFilter = Struct.new(:kind, :name, :only, :except, :if_condition, :unless_condition, :file, :line,
                             :owner, :applies_to, :applicability, :declaration, :origin, keyword_init: true) do
    # @return [Boolean] whether Woods places the filter in a gem (Devise's authenticate_user!), not the application
    def gem?
      origin == 'gem'
    end

    # @return [Hash] the shape {Since::Changed#callback} reads: name and declaration (woods#820)
    def since_entry
      { 'filter' => name, 'declaration' => declaration }
    end

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

    # @return [Boolean] whether the generation published this filter's resolved actions (W-8)
    def resolved?
      !applies_to.nil?
    end

    # @param action [String]
    # @return [Boolean] whether the filter applies: its published applies_to,
    #   else its declared only/except
    def applies?(action)
      resolved? ? applies_to.include?(action) : declared_for?(action)
    end

    # @return [Boolean] whether an if/unless condition Woods does not evaluate also decides it
    def conditional?
      applicability == 'conditional'
    end

    # @return [String, nil] the declared if/unless condition, e.g. "unless: :api_request?"
    def condition
      parts = [("if: #{if_condition}" if if_condition), ("unless: #{unless_condition}" if unless_condition)]
      parts.compact.join(', ').presence
    end
  end
end
