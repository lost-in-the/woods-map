# frozen_string_literal: true

require 'rack/utils'
require 'digest'
require 'ipaddr'

module WoodsMap
  # Base controller: authentication, origin check, and the one-generation
  # repository every page reads from.
  #
  # Order of checks on every request:
  # 1. the host's `authorize` hook, when configured;
  # 2. the origin check for non-GET requests;
  # 3. the token gate: a bearer header, the exchanged signed cookie, or a
  #    loopback request while no token is configured.
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout 'woods_map/application'

    before_action :authorize_host!
    before_action :check_origin!
    before_action :authenticate!

    helper_method :woods_map_config

    rescue_from WoodsMap::Repository::Unavailable, with: :render_unavailable

    private

    # @return [WoodsMap::Configuration]
    def woods_map_config
      WoodsMap.configuration
    end

    def authorize_host!
      hook = woods_map_config.authorize
      return if hook.nil? || hook.call(request)

      head :forbidden
    end

    # Cross-origin writes are refused outright. A missing Origin header is
    # allowed (same-origin navigations and non-browser clients) because the
    # token check still applies.
    def check_origin!
      return if request.get? || request.head?

      origin = request.headers['Origin']
      return if origin.nil? || origin == request.base_url

      head :forbidden
    end

    def authenticate!
      return if authenticated_by_token? || authenticated_by_cookie? || loopback_without_token?

      if woods_map_config.token?
        respond_to_unauthenticated
      else
        render plain: 'Woods Map refuses non-loopback requests until config.token is set.', status: :forbidden
      end
    end

    def authenticated_by_token?
      return false unless woods_map_config.token?

      presented = request.authorization.to_s.sub(/\ABearer\s+/i, '')
      !presented.empty? && Rack::Utils.secure_compare(woods_map_config.token, presented)
    end

    def authenticated_by_cookie?
      return false unless woods_map_config.token?

      stored = cookies.signed[woods_map_config.cookie_name].to_s
      !stored.empty? && Rack::Utils.secure_compare(token_digest, stored)
    end

    def loopback_without_token?
      return false if woods_map_config.token? || woods_map_config.require_token

      loopback?(request.remote_ip)
    end

    def loopback?(address)
      IPAddr.new(address.to_s).loopback?
    rescue IPAddr::InvalidAddressError
      false
    end

    # @return [String] SHA-256 of the configured token; what the cookie holds
    def token_digest
      Digest::SHA256.hexdigest(woods_map_config.token.to_s)
    end

    def respond_to_unauthenticated
      if request.format.html?
        redirect_to woods_map.new_session_path
      else
        response.headers['WWW-Authenticate'] = 'Bearer realm="Woods Map"'
        head :unauthorized
      end
    end

    def render_unavailable(error)
      @error = error
      render 'woods_map/status/unavailable', status: :service_unavailable
    end
  end
end
