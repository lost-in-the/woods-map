# frozen_string_literal: true

module WoodsMap
  # The flow and retention reads of {Repository}: Woods' inverted flow
  # membership (W-13) and the precomputed flow documents of the pinned
  # generation, and the index's retention pins (W-11). Mixed into Repository,
  # which supplies `@index`.
  #
  # Flow artifacts are optional. Woods answers nil when the generation
  # publishes none ("cannot say"), never an empty list; {#flows_state} keeps
  # that distinction, and an artifact Woods refuses as corrupt reads as
  # :unreadable rather than as no flows.
  module RepositoryFlows
    # @param identifier [String]
    # @param type [String]
    # @return [Array<String>, nil] entry points whose flow documents expanded
    #   the typed unit; nil when the generation cannot say
    def flow_entry_points(identifier, type:)
      return nil unless flow_readers?

      entries = @index.flow_entry_points(identifier.to_s, type: type.to_s)
      @flows_state ||= entries.nil? ? :absent : :available
      entries
    rescue StandardError
      @flows_state = :unreadable
      nil
    end

    # @param entry_point [String] a flow index key, e.g. `UsersController#show`
    # @return [Hash, nil] the published document; nil when not listed or unreadable
    def flow_document(entry_point)
      return nil unless flow_readers?

      @flow_documents ||= {}
      return @flow_documents[entry_point] if @flow_documents.key?(entry_point)

      @flow_documents[entry_point] = @index.flow_document(entry_point.to_s)
    rescue StandardError
      @flows_state = :unreadable
      @flow_documents[entry_point] = nil
    end

    # @return [Symbol] :unsupported (no flow readers in this Woods), :unknown
    #   (nothing asked yet), :absent (no inverse published), :available or
    #   :unreadable
    def flows_state
      return :unsupported unless flow_readers?

      @flows_state || :unknown
    end

    # @return [WoodsMap::Retention] the index's retention pins, read once
    def retention
      @retention ||= Retention.read(@index.index_dir)
    end

    private

    def flow_readers?
      @index.respond_to?(:flow_entry_points) && @index.respond_to?(:flow_document)
    end
  end
end
