# frozen_string_literal: true

module WoodsMap
  # A published-index double for specs that stub the repository's graph: it
  # answers what a repository needs to name its generation (the snapshot key).
  module IndexDouble
    def synthetic_published_index
      instance_double(Woods::PublishedIndex, payload_dir: Pathname.new('/synthetic/index'),
                                             index_dir: Pathname.new('/synthetic'), generation_number: 1, manifest: {})
    end
  end
end
