# frozen_string_literal: true

module WoodsMap
  # Build provenance for the pinned generation.
  module RepositoryBuild
    # @return [Woods::BuildComparison] writer compared with this process, once per generation
    def build_comparison
      snapshot.fetch(:build_comparison) { Woods::BuildIdentity.compare(manifest) }
    end

    # The comparison can stop at a version gap before asking for the reader's revision.
    # Keep its lazy policy: only look up a revision when the writer recorded one.
    # @return [String, nil] this process's revision, or nil when absent or not compared
    def reader_revision
      snapshot.fetch(:reader_revision) do
        Woods::BuildIdentity.current.revision if build_comparison.writer_revision
      end
    end

    private

    # Wrap only typed payload reads, preserving optional readers' local rescues.
    # @yieldreturn [Object] the published unit or listing
    # @return [Object] the read result
    # @raise [UnreadableIndex] when Woods refuses the payload
    def typed_read
      yield
    rescue IOError => e
      raise Repository::UnreadableIndex, e.message
    end
  end
end
