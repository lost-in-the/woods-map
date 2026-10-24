# frozen_string_literal: true

module WoodsMap
  # The flow reads of {Repository} (A-4): which precomputed flows a typed unit
  # takes part in (Woods W-13, `flows/by_unit.json`) and one flow document,
  # both from the pinned generation through `Woods::PublishedIndex`. Mixed
  # into Repository, which supplies `@index`.
  module RepositoryFlows
    # Entry points whose flow documents expanded a step of this typed unit.
    #
    # @param identifier [String]
    # @param type [String]
    # @return [Array<String>, nil] sorted entry points; nil when the
    #   generation cannot say ({#flow_state} names why)
    def flow_entry_points(identifier, type:)
      return nil unless flow_state == :available

      @flow_entry_points ||= {}
      @flow_entry_points.fetch([identifier, type]) do
        @flow_entry_points[[identifier, type]] = Array(@index.flow_entry_points(identifier, type: type))
      end
    rescue StandardError
      @flow_state = :unreadable
      nil
    end

    # One precomputed flow document, as Woods publishes it (string keys).
    #
    # @param entry_point [String] e.g. `PostsController#create`
    # @return [Hash, nil] nil when the generation does not list it or cannot be read
    def flow_document(entry_point)
      return nil unless flow_state == :available

      @index.flow_document(entry_point.to_s)
    rescue StandardError
      nil
    end

    # Why {#flow_entry_points} answers what it does.
    #
    # @return [Symbol] :available, :absent (no flow inverse: flows were not
    #   precomputed, or an older Woods wrote them), :unreadable (Woods refused
    #   the artifact) or :unsupported (this Woods has no flow readers, W-13)
    def flow_state
      @flow_state ||= if !@index.respond_to?(:flow_entry_points) then :unsupported
                      elsif probe_flow_inverse.nil? then :absent
                      else :available
                      end
    rescue StandardError
      :unreadable
    end

    private

    # Any lookup reads the whole inverse once; nil when none is published.
    def probe_flow_inverse
      @index.flow_entry_points('', type: '')
    end
  end
end
