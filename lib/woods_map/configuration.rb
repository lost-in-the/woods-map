# frozen_string_literal: true

require 'pathname'

module WoodsMap
  # Host-facing settings. Every value has a default that works for a
  # development mount on loopback; staging needs {#token} and usually
  # {#authorize}.
  class Configuration
    # @return [Pathname, String] the Woods index root (holds generation.json).
    #   Defaults to `Rails.root/tmp/woods` when Rails is loaded.
    attr_accessor :index_dir

    # @return [String, nil] bearer token. Required for any request that does
    #   not arrive from a loopback address. Browsers exchange it once for a
    #   signed cookie at the session route.
    attr_accessor :token

    # @return [Proc, nil] host gate called with the Rack request; a falsy
    #   result refuses the request with 403 before any token check.
    attr_accessor :authorize

    # @return [Boolean] refuse unauthenticated loopback requests too. Off by
    #   default so a development mount needs no token.
    attr_accessor :require_token

    # @return [Boolean] enable the RubyLLM guide panel (M7). Off by default.
    attr_accessor :guide_enabled

    # @return [String] cookie name holding the exchanged token digest.
    attr_accessor :cookie_name

    # @return [Proc, false, nil] the engine's Content-Security-Policy. Nil
    #   (the default) sends the engine's own strict policy on every engine
    #   response; a callable receives that policy (an
    #   `ActionDispatch::ContentSecurityPolicy`) and the request to amend it,
    #   for example with a `report_uri`; false sends no engine header, so the
    #   host's own policy middleware applies instead. See docs/DEPLOYMENT.md.
    attr_accessor :content_security_policy

    # @return [Integer, nil] requests one client may make to each expensive
    #   group (search and palette, graph JSON, impact) per {#rate_limit_period};
    #   nil or 0 turns the limit off. Counted in this process only.
    attr_accessor :rate_limit

    # @return [Numeric] the window, in seconds, that {#rate_limit} counts over.
    attr_accessor :rate_limit_period

    # @return [Proc] maps the request to the client the budget is counted
    #   for; the remote IP by default. A host behind SSO may key by user.
    attr_accessor :rate_limit_key

    # @return [Array<String>] extra origins (`https://map.example.com`) whose
    #   Host the token-less loopback mode accepts and whose Origin the write
    #   routes accept, besides the request's own origin. Loopback host names
    #   are always accepted.
    attr_accessor :allowed_origins

    def initialize
      @index_dir = default_index_dir
      @rate_limiter_mutex = Mutex.new
      @token = ENV.fetch('WOODS_MAP_TOKEN', nil)
      @authorize = nil
      @require_token = false
      @guide_enabled = false
      @cookie_name = 'woods_map_session'
      @content_security_policy = nil
      @rate_limit = 120
      @rate_limit_period = 60
      @rate_limit_key = ->(request) { request.remote_ip }
      @allowed_origins = []
    end

    # @return [Boolean] whether expensive endpoints are rate limited
    def rate_limited?
      rate_limit.to_i.positive? && rate_limit_period.to_f.positive?
    end

    # The in-process counter behind {#rate_limit}, built on first use so a
    # budget set in a host initializer is the one counted.
    #
    # @return [WoodsMap::RateLimiter]
    def rate_limiter
      @rate_limiter_mutex.synchronize do
        if @rate_limiter.nil? || !@rate_limiter.configured_for?(rate_limit, rate_limit_period)
          @rate_limiter = RateLimiter.new(limit: rate_limit.to_i, period: rate_limit_period.to_f)
        end
        @rate_limiter
      end
    end

    # @return [Boolean] whether a usable token is configured
    def token?
      !token.nil? && !token.to_s.strip.empty?
    end

    # @return [Pathname]
    def index_path
      Pathname.new(index_dir.to_s)
    end

    # The one-line warning the engine logs after the host has initialized, or
    # nil when the mount is gated by a token.
    #
    # @return [String, nil]
    def boot_warning
      return nil if token?

      if require_token
        'Woods Map refuses every request: config.require_token is set and no token is configured ' \
          '(config.token or WOODS_MAP_TOKEN).'
      else
        'Woods Map serves loopback requests only: no token is configured (config.token or ' \
          'WOODS_MAP_TOKEN). Set one, or config.authorize, before exposing the mount beyond this machine.'
      end
    end

    private

    def default_index_dir
      if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
        Rails.root.join('tmp/woods')
      else
        Pathname.new('tmp/woods')
      end
    end
  end
end
