# frozen_string_literal: true

require 'woods_map/guide/actions'
require 'woods_map/guide/budget'
require 'woods_map/guide/store'
require 'woods_map/guide/context'
require 'woods_map/guide/answer'
require 'woods_map/guide/handoff'
require 'woods_map/guide/heartbeat'
require 'woods_map/guide/runner'
require 'woods_map/guide/server_pool'

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

    # One answer's chat and the MCP server it borrowed.
    Session = Struct.new(:chat, :servers, :pool) do
      # Hand the server back to the pool, or stop it: after an answer that
      # did not end cleanly, and always when there is no pool.
      #
      # @param reuse [Boolean] whether the answer ended cleanly
      # @return [void]
      def close(reuse: false)
        servers.each do |server|
          pool ? pool.checkin(server, reuse: reuse) : server.close
        rescue StandardError
          nil
        end
      end
    end

    # A chat for one answer: the host's factory, or the agent with the
    # configured chat options and an Index MCP server attached, borrowed from
    # the process's {ServerPool} for this index and generation.
    #
    # @param config [WoodsMap::Configuration]
    # @param generation_key [Array, nil] the pinned generation's identity
    #   ({WoodsMap::Repository#generation_key}); a new one restarts the servers
    # @return [Session]
    def open_session(config = WoodsMap.configuration, generation_key: nil)
      return Session.new(config.guide_chat_factory.call, [], nil) if config.guide_chat_factory

      agent = backend
      server_class = WoodsMap::Guide::IndexMcp.for(config)
      pool = server_pool(config)
      server = pool ? pool.checkout(server_key(config, generation_key)) { server_class.new } : server_class.new
      begin
        chat = agent.chat(**config.guide_chat_options.to_h.transform_keys(&:to_sym))
        chat.with_mcp(server)
      rescue StandardError
        pool ? pool.checkin(server, reuse: true) : server.close
        raise
      end
      Session.new(chat, [server], pool)
    end

    # The process's pool of Index MCP servers, or nil when
    # `guide_mcp_servers` is 0. A change to the pool settings stops the old
    # pool's servers and starts a new pool.
    #
    # @param config [WoodsMap::Configuration]
    # @return [ServerPool, nil]
    def server_pool(config = WoodsMap.configuration)
      settings = [config.guide_mcp_servers.to_i, config.guide_mcp_idle_seconds.to_f, config.guide_mcp_wait_seconds.to_f]
      POOL_LOCK.synchronize do
        if @pool_settings != settings
          @pool&.shutdown
          @pool_settings = settings
          @pool = if settings.first.positive?
                    ServerPool.new(size: settings[0], idle: settings[1],
                                   wait: settings[2])
                  end
          register_shutdown
        end
        @pool
      end
    end

    # Stop the pooled servers: the idle ones now and the busy ones when their
    # answers end, or, with `force` (at exit), all of them now.
    #
    # @param force [Boolean]
    # @return [void]
    def shutdown_servers(force: false)
      pool = POOL_LOCK.synchronize do
        current = @pool
        @pool = nil
        @pool_settings = nil
        current
      end
      pool&.shutdown(force: force)
    end

    # The key a pooled server serves: the transport and the generation.
    #
    # @param config [WoodsMap::Configuration]
    # @param generation_key [Array, nil]
    # @return [Array]
    def server_key(config, generation_key)
      transport = config.guide_mcp_url ? ['url', config.guide_mcp_url.to_s] : ['stdio', *IndexMcp.command_for(config)]
      [transport, Array(generation_key)]
    end

    POOL_LOCK = Mutex.new
    private_constant :POOL_LOCK

    # @return [void]
    def register_shutdown
      return if @shutdown_registered

      @shutdown_registered = true
      at_exit { WoodsMap::Guide.shutdown_servers(force: true) }
    end
    private_class_method :register_shutdown
  end
end
