# frozen_string_literal: true

require 'woods_map/guide/actions'
require 'woods_map/guide/budget'
require 'woods_map/guide/store'
require 'woods_map/guide/context'
require 'woods_map/guide/answer'
require 'woods_map/guide/runner'

module WoodsMap
  # The guide (M7, FR-8): a RubyLLM agent over the Woods Index MCP server,
  # docked beside a page and streaming over server-sent events.
  #
  # RubyLLM is optional. The engine's floor stays Ruby 3.0; the guide needs
  # Ruby 3.2 and `ruby_llm` 2.1 in the host bundle, and is loaded only when
  # it is enabled and both are present. Everything RubyLLM-specific lives in
  # `woods_map/guide/agent`, which nothing else requires.
  module Guide
    # The Ruby RubyLLM 2.1 needs.
    MINIMUM_RUBY = '3.2'

    # Read-only Index MCP tools the agent may call (design study, section 11).
    # Operator, feedback, snapshot-write and Notion tools are never exposed.
    TOOLS = %w[
      woods_status search lookup structure dependencies dependents trace_flow
      recent_changes graph_analysis pagerank domain_clusters codebase_retrieve
    ].freeze

    # Why the guide is not offered, as the bar's notice says it.
    NOTICES = {
      ruby: 'RubyLLM 2.1 needs Ruby 3.2 and this host runs %<ruby>s; everything else works.',
      missing: 'Add ruby_llm (2.1 or later) to the host bundle and configure a provider; everything else works.'
    }.freeze

    module_function

    # @param config [WoodsMap::Configuration]
    # @return [Symbol] :disabled (off, the default: nothing is shown),
    #   :ruby or :missing (enabled but unavailable: the notice), or :ready
    def status(config = WoodsMap.configuration)
      return :disabled unless config.guide_enabled
      return :ready if config.guide_chat_factory
      return :ruby unless ruby_supported?
      return :missing unless backend

      :ready
    end

    # @param config [WoodsMap::Configuration]
    # @return [String, nil] the one-line reason the guide is unavailable
    def notice(config = WoodsMap.configuration)
      key = status(config)
      format(NOTICES[key], ruby: RUBY_VERSION) if NOTICES.key?(key)
    end

    # @return [Boolean] whether this Ruby can run RubyLLM 2.1
    def ruby_supported?
      Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(MINIMUM_RUBY)
    end

    # The RubyLLM-backed agent, loaded on first use; nil when `ruby_llm` is
    # not in the bundle.
    #
    # @return [Class, nil] {WoodsMap::Guide::Agent}
    def backend
      return @backend if defined?(@backend) && @backend

      require 'ruby_llm' unless defined?(RubyLLM::Agent)
      require 'woods_map/guide/agent'
      @backend = WoodsMap::Guide::Agent
    rescue LoadError => e
      raise unless e.path.to_s.start_with?('ruby_llm')

      nil
    end

    # One answer's chat and the MCP connection it holds open.
    Session = Struct.new(:chat, :servers) do
      # Stop the stdio server (or end the HTTP session) the answer used.
      #
      # @return [void]
      def close
        servers.each do |server|
          server.close
        rescue StandardError
          nil
        end
      end
    end

    # A chat for one answer: the host's factory, or the agent with the
    # configured chat options and the Index MCP server attached.
    #
    # @param config [WoodsMap::Configuration]
    # @return [Session]
    def open_session(config = WoodsMap.configuration)
      return Session.new(config.guide_chat_factory.call, []) if config.guide_chat_factory

      agent = backend
      server = WoodsMap::Guide::IndexMcp.for(config).new
      chat = agent.chat(**config.guide_chat_options.to_h.transform_keys(&:to_sym))
      chat.with_mcp(server)
      Session.new(chat, [server])
    end
  end
end
