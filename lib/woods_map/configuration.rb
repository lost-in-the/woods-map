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

    def initialize
      @index_dir = default_index_dir
      @token = ENV.fetch('WOODS_MAP_TOKEN', nil)
      @authorize = nil
      @require_token = false
      @guide_enabled = false
      @cookie_name = 'woods_map_session'
    end

    # @return [Boolean] whether a usable token is configured
    def token?
      !token.nil? && !token.to_s.strip.empty?
    end

    # @return [Pathname]
    def index_path
      Pathname.new(index_dir.to_s)
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
