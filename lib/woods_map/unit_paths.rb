# frozen_string_literal: true

module WoodsMap
  # The source files a unit's history covers: its own file, every file the
  # index says contributes to it (`source_paths`), and the files of the
  # concerns it inlines, as the effective class shows them. Paths are the
  # application-relative keys the commit table and the file map share.
  module UnitPaths
    module_function

    # @param repository [WoodsMap::Repository]
    # @param unit [Hash] a published unit
    # @return [Array<String>] distinct paths, the unit's own file first
    def for(repository, unit)
      own = [unit['file_path']]
      node = repository.graph_node(unit['identifier'].to_s, type: unit['type'])
      contributors = Array(node&.dig('source_paths'))
      (own + contributors + concern_paths(repository, unit)).grep(String).reject(&:empty?).uniq
    end

    # @param repository [WoodsMap::Repository]
    # @param unit [Hash]
    # @return [Array<String>] the inlined concerns' own files
    def concern_paths(repository, unit)
      concern_files(repository, unit).values.compact
    end

    # @param repository [WoodsMap::Repository]
    # @param unit [Hash]
    # @return [Hash{String => String, nil}] inlined concern name => its file, nil when unindexed
    def concern_files(repository, unit)
      Array(unit.dig('metadata', 'inlined_concerns')).to_h do |name|
        [name.to_s, repository.unit(name.to_s, type: 'concern')&.dig('file_path')]
      end
    end
  end
end
