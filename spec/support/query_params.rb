# frozen_string_literal: true

require 'uri'

module WoodsMap
  # CGI.parse is gone in Ruby 4.0; this keeps its `{ 'key' => [values] }` shape.
  module QueryParams
    # @param query [String, nil] a URL query string
    # @return [Hash{String => Array<String>}]
    def parse_query(query)
      URI.decode_www_form(query.to_s).group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
    end
  end
end
