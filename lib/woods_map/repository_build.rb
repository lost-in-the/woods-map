# frozen_string_literal: true

module WoodsMap
  # Build provenance for the pinned generation.
  module RepositoryBuild
    # @return [Woods::BuildComparison] writer compared with this process, once per generation
    def build_comparison
      snapshot.fetch(:build_comparison) { Woods::BuildIdentity.compare(manifest) }
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
