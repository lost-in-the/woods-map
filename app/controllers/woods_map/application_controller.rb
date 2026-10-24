# frozen_string_literal: true

module WoodsMap
  # Base controller: authentication, origin check, and the one-generation
  # repository every page reads from.
  #
  # Order of checks on every request:
  # 0. the engine's Content-Security-Policy header, so every response under
  #    the mount carries it, refusals included (M8);
  # 1. the host's `authorize` hook, when configured;
  # 2. the origin check for non-GET requests (Origin, Referer, Sec-Fetch-Site);
  # 3. a `?token=` on a GET, exchanged once for the signed cookie (D-4);
  # 4. the token gate: a bearer header, the exchanged cookie, or a loopback
  #    request naming a loopback host while no token is configured;
  # 5. on search, the palette, graph JSON, impact and the `.mmd` text routes:
  #    the per-client budget, 429 when it is spent (plain text for `.mmd`).
  #
  # A refused request gets the 403 panel from the States board, rendered
  # without the frame and before the repository opens anything, so nothing
  # from the index reaches a client that is not allowed in.
  class ApplicationController < ActionController::Base
    include WoodsMap::Authentication
    include WoodsMap::RawRequestPath
    include WoodsMap::MermaidText
    include WoodsMap::SinceParam
    include WoodsMap::GuidePage
    include WoodsMap::PathExtension

    protect_from_forgery with: :exception
    layout 'woods_map/application'

    before_action :apply_content_security_policy
    before_action :authorize_host!
    before_action :check_origin!
    before_action :exchange_query_token!
    before_action :authenticate!
    # The `.mmd` text routes (D-25) are paced like the JSON endpoints.
    before_action(if: :mermaid_request?) { enforce_rate_limit!(:mermaid) }

    helper_method :woods_map_config, :current_repository, :woods_map, :primary_nav

    # Count the named actions against the per-client budget of a group.
    # Named apart from Rails 7.2's `rate_limit`, which the floor lacks.
    #
    # @param group [Symbol] the budget the actions share (:search, :graph, :impact)
    # @param options [Hash] `only:` / `except:` as for before_action
    # @return [void]
    def self.woods_map_rate_limit(group, **options)
      before_action(**options) { enforce_rate_limit!(group) }
    end

    rescue_from WoodsMap::Repository::Unavailable, with: :render_unavailable

    private

    # Use the engine helpers already mixed into this controller. A named
    # mounted proxy selects one host mount and can lose the current prefix
    # when the same engine is mounted more than once.
    #
    # @return [ApplicationController] route helpers in this request's context
    def woods_map
      self
    end

    # The global bar's pages that exist, in the order the boards give them
    # (coverage.md: Units, Landscape, Graph, ERD, Impact, History), then the Trail.
    #
    # @param current [String, Symbol, nil] the page being shown: its label or :units, :graph, :erd, :impact,
    #   :history, :trail
    # @return [Array<Array(String, String, Boolean)>] label, href, current?
    def primary_nav(current = nil)
      pages = [['Units', woods_map.units_path], ['Landscape', woods_map.landscape_path],
               ['Graph', woods_map.graph_path], ['ERD', woods_map.erd_path], ['Impact', woods_map.impact_path],
               ['History', woods_map.history_path], ['Trail', woods_map.trail_path]]
      pages.map { |label, href| [label, href, label.casecmp?(current.to_s)] }
    end

    # @return [WoodsMap::Configuration]
    def woods_map_config
      WoodsMap.configuration
    end

    # @return [WoodsMap::Repository, nil] the generation this request reads
    def current_repository
      @repository
    end

    # Open the configured index pinned to one generation for this request.
    # The generation facts are kept for the bar; the block gets the repository.
    #
    # @yieldparam repository [WoodsMap::Repository]
    # @return [Object] the block's value
    def with_repository
      WoodsMap::Repository.open do |repository|
        @repository = repository
        @generation = repository.generation_facts
        yield repository
      end
    end

    # The nonce the layout's inline scripts carry. It is the engine's own while
    # the engine sends its policy, and the host's (Rails' nonce generator)
    # when `config.content_security_policy = false` hands the header back.
    #
    # @return [String, nil]
    def content_security_policy_nonce
      return super if woods_map_config.content_security_policy == false

      @content_security_policy_nonce ||= WoodsMap::ContentSecurityPolicy.nonce
    end

    def apply_content_security_policy
      return if woods_map_config.content_security_policy == false

      policy = WoodsMap::ContentSecurityPolicy.new(request, nonce: content_security_policy_nonce,
                                                            config: woods_map_config)
      response.headers['Content-Security-Policy'] = policy.header
    end

    def enforce_rate_limit!(group)
      return unless woods_map_config.rate_limited?

      client = woods_map_config.rate_limit_key.call(request)
      decision = woods_map_config.rate_limiter.hit("#{group}:#{client}")
      return if decision.allowed?

      response.headers['Retry-After'] = decision.retry_after.to_s
      render_rate_limited(group, decision)
    end

    # The 429 state: an empty state in the frame, before the repository opens.
    #
    # @param group [Symbol]
    # @param decision [WoodsMap::RateLimiter::Decision]
    def render_rate_limited(group, decision)
      @rate_group = group
      @rate_decision = decision
      if mermaid_request?
        render plain: "#{rate_limited_message(decision)}\n", status: :too_many_requests, content_type: 'text/plain'
      elsif request.format.json?
        render json: { 'error' => 'rate_limited', 'retry_after' => decision.retry_after,
                       'message' => rate_limited_message(decision) }, status: :too_many_requests
      else
        render 'woods_map/refusals/rate_limited', layout: 'woods_map/bare', status: :too_many_requests
      end
    end

    # @param decision [WoodsMap::RateLimiter::Decision]
    # @return [String] one sentence the palette and JSON clients can show
    def rate_limited_message(decision)
      "Too many requests: #{decision.limit} per #{woods_map_config.rate_limit_period.to_i}s; " \
        "try again in #{decision.retry_after}s."
    end
    helper_method :rate_limited_message

    def authorize_host!
      hook = woods_map_config.authorize
      return if hook.nil? || hook.call(request)

      refuse(:host)
    end

    # Cross-origin writes are refused outright: Origin, else Referer, else
    # Sec-Fetch-Site must name the map's own origin (or a configured one). A
    # request with none of them is a non-browser client; the token check
    # still applies to it.
    def check_origin!
      return if request.get? || request.head?
      return if same_origin_write?

      refuse(:origin)
    end

    # `GET /woods?token=…` once: a matching token becomes the cookie and the
    # browser is sent to the same URL without it, so the secret does not stay
    # in the address bar or the history. Ignored while no token is configured.
    def exchange_query_token!
      return if mermaid_request? # text for agents: the header or the cookie, never a token in the URL

      presented = query_token
      return if presented.nil?

      if token_matches?(presented)
        store_session_cookie
        redirect_to url_without_token
      else
        flash[:alert] = REJECTED
        respond_to_unauthenticated
      end
    end

    def authenticate!
      return if authenticated?

      if woods_map_config.token?
        respond_to_unauthenticated
      elsif loopback_request? && !woods_map_config.require_token
        refuse(:rebinding)
      else
        refuse(:token)
      end
    end

    def respond_to_unauthenticated
      if request.format.html? && !mermaid_request?
        redirect_to woods_map.new_session_path
      else
        response.headers['WWW-Authenticate'] = 'Bearer realm="Woods Map"'
        next_step = 'Send the token as an Authorization: Bearer header.'
        mermaid_request? ? render_text(:unauthorized, next_step) : head(:unauthorized)
      end
    end

    # The 403 panel: no frame and no index facts (States board, D-4).
    #
    # @param reason [Symbol] :token, :host, :origin or :rebinding
    def refuse(reason)
      return render_text(:forbidden, "Woods Map refused the request (#{reason}).") if mermaid_request?

      @reason = reason
      render 'woods_map/refusals/show', layout: 'woods_map/bare', status: :forbidden
    end

    def render_unavailable(error)
      return render_text(:service_unavailable, 'No published Woods index.') if mermaid_request?

      @error = error
      render 'woods_map/status/unavailable', status: :service_unavailable
    end
  end
end
