# frozen_string_literal: true

require 'uri'

module WoodsMap
  # The address reviewers reach the host application at (woods-map#76), for
  # every absolute link the map hands out: focus URLs, `.mmd` and `.md` URLs
  # and the links in a pull-request comment. Behind a proxy or on a staging
  # host the request's own origin can be an internal name nobody else can
  # open; `config.public_url` replaces it. It only writes links: the origin
  # checks still use `config.allowed_origins` (D-27).
  module PublicUrl
    module_function

    # @param value [String, nil] `https://map.example.com`, optionally with a
    #   path prefix a proxy strips (`https://example.com/tools`)
    # @return [String, nil] the URL without a trailing slash, or nil when blank
    # @raise [ArgumentError] unless it is an absolute http(s) URL with a host
    #   and no credentials, query or fragment
    def normalize(value)
      text = value.to_s.strip
      return nil if text.empty?

      uri = URI.parse(text)
      unless uri.is_a?(URI::HTTP) && uri.host.to_s != '' && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
        raise ArgumentError, 'config.public_url must be an absolute http(s) URL with no credentials, query or ' \
                             "fragment: #{text.inspect}"
      end

      text.delete_suffix('/')
    rescue URI::InvalidURIError
      raise ArgumentError, "config.public_url is not a URL: #{text.inspect}"
    end

    # @param request [ActionDispatch::Request]
    # @param configured [String, nil] the normalized {Configuration#public_url}
    # @return [String] what an absolute link starts with, before the engine's path
    def base(request, configured = WoodsMap.configuration.public_url)
      configured || request.base_url
    end
  end
end
