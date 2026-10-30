# frozen_string_literal: true

module WoodsMap
  # A model's published callbacks split the way the Lifecycle tab reads them.
  # Steps follow Woods' own builder's rule (woods#826): a callback whose method
  # the unit's source or an inlined concern defines, never an internal method
  # or a proc ({Lifecycle::INTERNAL}). What is not drawn is counted by the
  # `origin` Woods publishes (woods#936, {CallbackOrigin}) when every callback
  # carries it, else inferred to be the framework's.
  class LifecycleCallbacks
    # @param unit [Hash] a model unit
    # @param concern_methods [Hash{String => Array<String>}] concern name => method names it defines
    def initialize(unit, concern_methods)
      raw = Array(unit.dig('metadata', 'callbacks'))
      defined = unit['source_code'].to_s.scan(Lifecycle::DEFINITION).flatten.to_set |
                concern_methods.values.flatten.to_set
      @callbacks, @undefined = raw.reject { |cb| cb['filter'].to_s.match?(Lifecycle::INTERNAL) }
                                  .partition { |cb| defined.include?(cb['filter'].to_s) }
      @origin = CallbackOrigin.published?(raw)
      @hidden = @origin ? CallbackOrigin.group(raw - @callbacks) : {}
    end

    # @return [Array<Hash>] the application's own callbacks, file order: the steps
    attr_reader :callbacks

    # @return [Hash{String => Array<Hash>}] origin => callbacks not drawn, in
    #   {CallbackOrigin::ORIGINS} order and empty origins left out; empty on a
    #   generation without `origin`, where {#framework} is the inferred count
    attr_reader :hidden

    # @return [Boolean] whether every callback carries the `origin` Woods
    #   publishes; false on an older generation, where what is not drawn is
    #   inferred to be the framework's and the page names the limit
    def origin?
      @origin
    end

    # @return [Array<Hash>] the framework's callbacks, kept out of the chains
    #   and counted in the limits: those with `origin` framework, or, without
    #   origin, those whose method the unit does not define (Rails' or a gem's)
    def framework
      @origin ? @hidden.fetch('framework', []) : @undefined
    end

    # @return [Array<Hash>] drawn callbacks whose published origin is not the
    #   application (a method the source defines that a gem or Rails
    #   overrides); drawn as Woods draws them and named in the limits
    def drawn_elsewhere
      @origin ? @callbacks.reject { |cb| cb['origin'] == 'app' } : []
    end
  end
end
