# frozen_string_literal: true

require 'securerandom'

module WoodsMap
  # The engine's Content-Security-Policy (M8). Engine controllers send it on
  # every response under the mount, so the host's own pages are untouched and
  # the host's policy middleware, which leaves a response that already carries
  # a policy alone, does not replace it.
  #
  # Scripts, styles and fonts load only from the engine's digested assets
  # route (`<mount>/assets/<digest>/`); the layout's three inline scripts (the
  # no-js switch, the literal import map and the module entry) carry the
  # per-response nonce. No directive allows `'unsafe-inline'` or
  # `'unsafe-eval'`: views carry no `style` attributes and Pele's inline SVG
  # styles are applied through the CSSOM by the diagram controller.
  #
  # The host amends the policy with `config.content_security_policy`, a
  # callable that receives the `ActionDispatch::ContentSecurityPolicy` and the
  # request, or turns the engine header off with `false`.
  class ContentSecurityPolicy
    # @return [String] a fresh nonce for one response
    def self.nonce
      SecureRandom.base64(16)
    end

    # @param request [ActionDispatch::Request] the engine request
    # @param nonce [String] this response's nonce
    # @param config [WoodsMap::Configuration]
    def initialize(request, nonce:, config: WoodsMap.configuration)
      @request = request
      @nonce = nonce
      @config = config
    end

    # @return [String] the `<mount>/assets/<digest>/` source the policy admits
    def asset_source
      "#{@request.base_url}#{@request.script_name}/assets/#{WoodsMap::Assets.digest}/"
    end

    # @return [ActionDispatch::ContentSecurityPolicy] the engine policy,
    #   amended by the host's callable when one is configured
    def policy
      require 'action_dispatch/http/content_security_policy'
      policy = ActionDispatch::ContentSecurityPolicy.new { |p| engine_directives(p) }
      @config.content_security_policy.call(policy, @request) if @config.content_security_policy.respond_to?(:call)
      policy
    end

    # @return [String] the header value
    def header
      policy.build(@request, @nonce, %w[script-src])
    end

    private

    def engine_directives(policy)
      assets = asset_source
      policy.default_src :none
      policy.script_src assets
      policy.style_src assets
      policy.font_src assets
      # Pele draws inline SVG; data: covers SVG and images it may inline.
      policy.img_src :self, :data
      # The palette, peek and graph JSON today; the M7 guide's EventSource later.
      policy.connect_src :self
      policy.object_src :none
      policy.base_uri :none
      policy.form_action :self
      policy.frame_ancestors :none
    end
  end
end
