# frozen_string_literal: true

module WoodsMap
  # Base controller: authentication, origin check, and the one-generation
  # repository every page reads from.
  #
  # Order of checks on every request:
  # 1. the host's `authorize` hook, when configured;
  # 2. the origin check for non-GET requests;
  # 3. a `?token=` on a GET, exchanged once for the signed cookie (D-4);
  # 4. the token gate: a bearer header, the exchanged cookie, or a loopback
  #    request while no token is configured.
  #
  # A refused request gets the 403 panel from the States board, rendered
  # without the frame and before the repository opens anything, so nothing
  # from the index reaches a client that is not allowed in.
  class ApplicationController < ActionController::Base
    include WoodsMap::Authentication

    protect_from_forgery with: :exception
    layout 'woods_map/application'

    before_action :authorize_host!
    before_action :check_origin!
    before_action :exchange_query_token!
    before_action :authenticate!

    helper_method :woods_map_config, :current_repository, :woods_map, :primary_nav

    rescue_from WoodsMap::Repository::Unavailable, with: :render_unavailable

    private

    # Use the engine helpers already mixed into this controller. A named
    # mounted proxy selects one host mount and can lose the current prefix
    # when the same engine is mounted more than once.
    #
    # @return [ApplicationController] route helpers in this request's context
    # The primary bar's sections as [label, href, current?].
    #
    # @param current [Symbol, nil] :units, :graph or :impact
    # @return [Array<Array(String, String, Boolean)>]
    def primary_nav(current = nil)
      [['Units', woods_map.units_path, current == :units], ['Graph', woods_map.graph_path, current == :graph],
       ['Impact', woods_map.impact_path, current == :impact]]
    end

    def woods_map
      self
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

    def authorize_host!
      hook = woods_map_config.authorize
      return if hook.nil? || hook.call(request)

      refuse(:host)
    end

    # Cross-origin writes are refused outright. A missing Origin header is
    # allowed (same-origin navigations and non-browser clients) because the
    # token check still applies.
    def check_origin!
      return if request.get? || request.head?

      origin = request.headers['Origin']
      return if origin.nil? || origin == request.base_url

      refuse(:origin)
    end

    # `GET /woods?token=…` once: a matching token becomes the cookie and the
    # browser is sent to the same URL without it, so the secret does not stay
    # in the address bar or the history. Ignored while no token is configured.
    def exchange_query_token!
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
      else
        refuse(:token)
      end
    end

    def respond_to_unauthenticated
      if request.format.html?
        redirect_to woods_map.new_session_path
      else
        response.headers['WWW-Authenticate'] = 'Bearer realm="Woods Map"'
        head :unauthorized
      end
    end

    # The 403 panel: no frame and no index facts (States board, D-4).
    #
    # @param reason [Symbol] :token, :host or :origin
    def refuse(reason)
      @reason = reason
      render 'woods_map/refusals/show', layout: 'woods_map/bare', status: :forbidden
    end

    def render_unavailable(error)
      @error = error
      render 'woods_map/status/unavailable', status: :service_unavailable
    end
  end
end
