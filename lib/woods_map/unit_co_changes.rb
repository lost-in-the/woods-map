# frozen_string_literal: true

module WoodsMap
  # What moves with a unit (C-5): `CommitTable#co_changes` over the unit's
  # files, folded onto the units of this generation that own the co-changed
  # files. A unit's count is the most commits any of its files shared.
  class UnitCoChanges
    # One unit that changed in the same commits.
    CoChange = Struct.new(:identifier, :type, :commits, keyword_init: true)

    # Units with two or more shared commits that make single-commit ones noise.
    MIN_REPEATED = 3

    # @param repository [WoodsMap::Repository]
    # @param table [Woods::PublishedIndex::CommitTable]
    # @param paths [Array<String>] the unit's files
    # @param own [Array(String, String)] the unit's identifier and type, left out
    def initialize(repository, table, paths, own:)
      @repository = repository
      @table = table
      @paths = paths
      @own = own
    end

    # Units sharing a single commit are left out once enough units share
    # more: one sweeping commit (an initial import, a mass rename) touches
    # everything once and says nothing about coupling.
    #
    # @param limit [Integer]
    # @return [Array<CoChange>] most shared commits first, then by identifier and type
    def top(limit)
      ranked = counts.sort_by { |(identifier, type), count| [-count, identifier.to_s, type.to_s] }
      ranked = ranked.reject { |_, count| count < 2 } if ranked.count { |_, count| count >= 2 } >= MIN_REPEATED
      ranked.first(limit).map do |(identifier, type), count|
        CoChange.new(identifier: identifier, type: type, commits: count)
      end
    end

    private

    def counts
      result = Hash.new(0)
      @table.co_changes(*@paths).each do |row|
        @repository.file_owners(row['path']).each do |owner|
          key = [owner['identifier'], owner['type']]
          result[key] = [result[key], row['commits']].max unless key == @own
        end
      end
      result
    end
  end
end
