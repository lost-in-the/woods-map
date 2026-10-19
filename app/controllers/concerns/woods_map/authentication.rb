# frozen_string_literal: true

require 'rack/utils'
require 'digest'
require 'ipaddr'

module WoodsMap
  # The token gate (D-4): a bearer header, the signed cookie the token was
  # exchanged for, or a loopback request while no token is configured. The
  # cookie holds a digest of the token, never the token itself.
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

      loopback_request?
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
