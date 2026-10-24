# frozen_string_literal: true

module WoodsMap
  # `?since=` on any page that reads one pinned generation (E-8): Woods' range
  # report from that selector to now, built once per request on first use and
  # never a map-side diff.
  module SinceParam
    extend ActiveSupport::Concern

    included do
      helper_method :current_since
    end

    private

    # @return [WoodsMap::Since, nil] nil when the page was not opened with `since`
    def current_since
      return @current_since if defined?(@current_since)

      repository = current_repository
      @current_since = repository && WoodsMap::Since.from_param(params[:since], index_dir: woods_map_config.index_path,
                                                                                repository: repository)
    end
  end
end
