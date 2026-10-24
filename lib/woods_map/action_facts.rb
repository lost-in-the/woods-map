# frozen_string_literal: true

require 'set'

module WoodsMap
  # The per-action facts Woods publishes for a controller or mailer action
  # (W-7, woods#757): the instance variables the action and its filters
  # assign, the params they read, what the action renders, where it
  # redirects, and its formats, each with the method and line it came from.
  # Read from the unit's metadata; an index made before W-7 has none.
  class ActionFacts
    # @param unit [Hash] a controller or mailer unit
    # @param action [String]
    # @return [ActionFacts, nil] nil when the index does not record facts for the action
    def self.for(unit, action)
      facts = unit.dig('metadata', 'action_facts', action.to_s)
      return nil unless facts.is_a?(Hash) && %w[assigns renders].all? { |key| facts[key].is_a?(Array) }

      new(facts)
    end

    # @param facts [Hash] one action's facts as Woods publishes them
    def initialize(facts)
      @facts = facts
    end

    # @return [String, nil] the file holding the action's body
    def file
      @facts['file']
    end

    # @return [Integer, nil] the action's definition line
    def line
      @facts['line']
    end

    # @return [Array<Hash>] +ivar+, +line+, +method+, +file+ for every assignment, filters first
    def assigns
      Array(@facts['assigns'])
    end

    # @param method [String] the action or a filter
    # @return [Array<Hash>] the assignments that method makes
    def assigns_by(method)
      assigns.select { |fact| fact['method'] == method }
    end

    # @return [Set<String>] every instance variable the action and its filters assign
    def assigned
      @assigned ||= assigns.to_set { |fact| fact['ivar'] }
    end

    # @param method [String, nil] restrict to one method
    # @return [Array<Hash>] +key+, +line+, +permitted+, +via+, +method+, +file+
    def params(method = nil)
      list = Array(@facts['params'])
      method ? list.select { |fact| fact['method'] == method } : list
    end

    # @param method [String, nil]
    # @return [Array<Hash>] +target+, +line+, +method+, +file+
    def redirects(method = nil)
      list = Array(@facts['redirects'])
      method ? list.select { |fact| fact['method'] == method } : list
    end

    # @return [Array<Hash>] the renders as published, the implicit one included
    def renders
      Array(@facts['renders'])
    end

    # @return [Array<String>] the template paths the action renders, e.g. +users/show+
    def template_paths
      renders.filter_map { |fact| fact['template'] }.uniq
    end

    # @return [Array<String>] the partial paths the action renders itself, e.g. +users/_form+
    def partial_paths
      renders.filter_map { |fact| fact['partial'] }.uniq
    end

    # @return [Array<Hash>] the renders that name no template: formats, heads, objects
    def other_renders
      renders.reject { |fact| fact['template'] || fact['partial'] }
    end

    # Renders whose target only runtime knows (+render template: params[:t]+, +render @user+, a
    # +mail+ with a computed template name): Woods publishes the expression under +object+. A
    # format render, a +head+ and a redirect name their response and stay out of this list.
    #
    # @return [Array<Hash>] +object+, +line+, +method+, +file+
    def dynamic_renders
      other_renders.select { |fact| fact['object'] }
    end

    # @return [Array<String>] the formats a respond_to block names
    def formats
      Array(@facts['formats'])
    end
  end
end
