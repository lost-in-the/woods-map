# frozen_string_literal: true

module WoodsMap
  # The explorer's overlays for the Graph tab and the full-screen graph: the
  # flows the centre takes part in with the one `?flow=` selects (A-4, W-13),
  # and the commits that touched the units drawn (A-6, W-3). Both read the
  # request's pinned generation; neither runs when the explorer is not shown.
  module GraphOverlays
    extend ActiveSupport::Concern

    private

    # @param repository [Repository]
    # @param neighbourhood [Neighbourhood]
    # @param identifier [String]
    # @param type [String]
    def load_graph_overlays(repository, neighbourhood, identifier, type)
      @flows = WoodsMap::GraphFlow.entries(repository, identifier, type)
      entry = params[:flow].to_s
      @flow = WoodsMap::GraphFlow.new(repository, neighbourhood, entry) unless entry.empty?
      @timeline = WoodsMap::GraphTimeline.new(repository, neighbourhood)
    end
  end
end
