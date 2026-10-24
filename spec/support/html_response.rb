# frozen_string_literal: true

module WoodsMap
  # Rails 7.1 parses HTML responses into a document; older Rails returns text.
  module HtmlResponse
    # @return [Nokogiri::HTML::Document] HTML across the supported Rails floors
    def html_response_document
      parsed = response.parsed_body
      parsed.is_a?(String) ? Nokogiri::HTML(parsed) : parsed
    end
  end
end

# Below Rails 7.1, `response.parsed_body` returns an HTML body as text, and
# specs that call `css` on it fail on the railties 6.0 floor. Register the
# parser Rails 7.1 ships, so every floor hands specs a document.
if ActionPack.gem_version < Gem::Version.new('7.1')
  ActionDispatch::IntegrationTest.register_encoder(:html, response_parser: ->(body) { Nokogiri::HTML(body) })
end
