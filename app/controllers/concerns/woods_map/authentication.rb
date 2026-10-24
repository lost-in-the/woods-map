# frozen_string_literal: true

require 'rack/utils'
require 'digest'
require 'ipaddr'
require 'uri'
require 'woods/mcp/origin_policy'

module WoodsMap
  # The token gate (D-4): a bearer header, the signed cookie the token was
  # exchanged for, or a loopback request while no token is configured. The
  # cookie holds a digest of the token, never the token itself.
  #
  # Two origin checks sit beside it (M8). The token-less loopback mode also
  # requires a loopback Host header, which is what stops a DNS-rebinding page
  # from reading the map through the developer's browser; Host names come
  # from `Woods::MCP::OriginPolicy`, the policy `woods-mcp-http` enforces.
  # State-changing requests must come from the map's own origin, judged by
  # Origin, then Referer, then Sec-Fetch-Site.
  module Authentication
    extend ActiveSupport::Concern

    # Shown when a presented token does not match the configured one.
    REJECTED = 'That token was not accepted.'

    included do
      helper_method :loopback_request?
    end

    private

    # @return [Boolean] whether the request arrived from a loopback address
    def loopback_request?
      IPAddr.new(request.remote_ip.to_s).loopback?
    rescue IPAddr::InvalidAddressError
      false
    end

    def authenticated?
      authenticated_by_token? || authenticated_by_cookie? || loopback_without_token?
    end

    def authenticated_by_token?
      presented = request.authorization.to_s.sub(/\ABearer\s+/i, '')
      !presented.empty? && token_matches?(presented)
    end

    def authenticated_by_cookie?
      return false unless woods_map_config.token?

      stored = cookies.signed[woods_map_config.cookie_name].to_s
      !stored.empty? && Rack::Utils.secure_compare(token_digest, stored)
    end

    def loopback_without_token?
      return false if woods_map_config.token? || woods_map_config.require_token

      loopback_request? && loopback_host?
    end

    # The raw Host header, never X-Forwarded-Host (a page can set that on a
    # same-origin fetch once it has rebound a name to 127.0.0.1).
    #
    # @return [Boolean] whether the request named a loopback or allowed host
    def loopback_host?
      origin_policy.host_allowed?(request.get_header('HTTP_HOST'))
    end

    # @return [Woods::MCP::OriginPolicy] loopback names plus the configured origins
    def origin_policy
      Woods::MCP::OriginPolicy.new(allowed_origins: Array(woods_map_config.allowed_origins))
    end

    # Whether a state-changing request came from the map's own origin. A
    # present Origin decides (`null` never matches); without one the Referer's
    # origin decides; without either, a browser's Sec-Fetch-Site must say
    # same-origin. A request with none of the three is a non-browser client,
    # which the token check still gates.
    #
    # @return [Boolean]
    def same_origin_write?
      origin = request.get_header('HTTP_ORIGIN')
      return trusted_origin?(origin) unless origin.nil?

      referer = request.get_header('HTTP_REFERER').to_s
      return trusted_origin?(origin_of(referer)) unless referer.empty?

      site = request.get_header('HTTP_SEC_FETCH_SITE')
      site.nil? || %w[same-origin none].include?(site)
    end

    # @param origin [String, nil] a serialized origin
    # @return [Boolean] the request's own origin or a configured one
    def trusted_origin?(origin)
      return false if origin.blank?

      normalized = origin.downcase.chomp('/')
      normalized == request.base_url.downcase ||
        Array(woods_map_config.allowed_origins).any? { |allowed| allowed.to_s.downcase.chomp('/') == normalized }
    end

    # @param url [String]
    # @return [String, nil] the URL's origin, without a default port
    def origin_of(url)
      uri = URI.parse(url)
      return nil unless %w[http https].include?(uri.scheme) && uri.host

      default = uri.scheme == 'https' ? 443 : 80
      "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless uri.port == default}"
    rescue URI::InvalidURIError
      nil
    end

    # @param presented [String]
    # @return [Boolean]
    def token_matches?(presented)
      woods_map_config.token? && Rack::Utils.secure_compare(woods_map_config.token, presented)
    end

    def store_session_cookie
      cookies.signed[woods_map_config.cookie_name] = {
        value: token_digest, httponly: true, same_site: :strict, secure: request.ssl?
      }
    end

    # @return [String] SHA-256 of the configured token; what the cookie holds
    def token_digest
      Digest::SHA256.hexdigest(woods_map_config.token.to_s)
    end

    # @return [String, nil] a `?token=` worth exchanging on this request
    def query_token
      return nil unless request.get? && woods_map_config.token?

      presented = params[:token].to_s
      presented.empty? ? nil : presented
    end

    # @return [String] the current URL with the `token` parameter removed
    def url_without_token
      path = request.path
      path = path.chomp('/') if path.length > 1
      query = request.query_parameters.except('token')
      query.empty? ? path : "#{path}?#{query.to_query}"
    end
  end
end
