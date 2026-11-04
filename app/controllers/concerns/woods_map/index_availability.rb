# frozen_string_literal: true

module WoodsMap
  # Response formats for refused typed payload reads.
  module IndexAvailability
    private

    # A typed-read failure is different from a missing index. Never expose payload errors.
    # @param error [Repository::UnreadableIndex]
    # @return [void]
    def render_unreadable_index(error)
      @index_read_failure = true
      @build_message = if @build_comparison&.mismatch?
                         @build_comparison.message
                       else
                         'The published index is corrupt or incomplete. Run woods:extract or request a re-index.'
                       end
      @build_comparison = nil
      @repository = nil
      @files_sheet = false
      return render_text(:service_unavailable, @build_message) if mermaid_request?

      render_unavailable(error)
    end
  end
end
