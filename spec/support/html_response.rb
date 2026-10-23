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
