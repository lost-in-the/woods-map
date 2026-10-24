# frozen_string_literal: true

module WoodsMap
  # The file tree as its own response (M10): the sheet fetches it the first
  # time it opens, so a page carries none of it. The fragment depends only on
  # the pinned generation and the `?since=` selector, so it is rendered once
  # per pair and kept in a small process cache; the browser revalidates it by
  # ETag and keeps it for an hour when the URL names the current generation.
  # Which file is current is marked in the browser, from the page.
  class TreesController < ApplicationController
    CACHE_SIZE = 8
    @cache = {}
    @mutex = Mutex.new

    class << self
      # @param key [Array] the generation, selector and mount
      # @return [String] the rendered fragment
      def fragment(key)
        @mutex.synchronize { @cache[key] } || yield.tap do |html|
          @mutex.synchronize do
            @cache.shift while @cache.size >= CACHE_SIZE
            @cache[key] = html
          end
        end
      end

      # @return [void]
      def reset!
        @mutex.synchronize { @cache.clear }
      end
    end

    def show
      with_repository do |repository|
        since = current_since if current_since&.available?
        key = [repository.generation_key, since&.selector, request.script_name]
        cache_headers(repository)
        next unless stale?(etag: key, public: false)

        html = self.class.fragment(key) do
          render_to_string(partial: 'woods_map/shared/tree',
                           locals: { tree: WoodsMap::FileTree.for(repository), since: since })
        end
        render html: html.html_safe, layout: false # rubocop:disable Rails/OutputSafety
      end
    end

    private

    def cache_headers(repository)
      current = params[:gen].to_s == repository.generation_number.to_s
      response.headers['Cache-Control'] = current ? 'private, max-age=3600' : 'private, no-cache'
    end
  end
end
