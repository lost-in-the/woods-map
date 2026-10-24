# frozen_string_literal: true

module WoodsMap
  # The request's path as the client sent it. Inside the engine Rails hands
  # `request.path` back normalized: a doubled slash squeezed and a trailing
  # one dropped. A unit whose identifier ends in "/" (the root route,
  # `GET /`) lives at `…/GET%20/` and its tabs at `…/GET%20//graph`, so
  # every link back to the current page builds from this path instead.
  module RawRequestPath
    extend ActiveSupport::Concern

    included do
      helper_method :raw_request_path
    end

    private

    # @return [String] the mount prefix and path, percent-encoded as sent, without the query
    def raw_request_path
      request.original_fullpath.split('?', 2).first
    end
  end
end
