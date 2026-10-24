# frozen_string_literal: true

require 'set'

module WoodsMap
  # Which retained generation first carried each commit (B-6).
  #
  # Every retained generation publishes its own commit table (Woods W-3). A
  # commit in generation N's table and not in the previous retained
  # generation's was introduced by N. Commits already in the oldest retained
  # table, or in a table that follows a generation without one, are only
  # known to be "at or before" it: the ledger says so instead of guessing.
  # Nothing here runs git or compares code; it compares published sha lists.
  class CommitLedger
    # One retained generation and what its table added.
    Generation = Struct.new(:number, :head, :extracted_at, :table, :baseline, :introduced, keyword_init: true) do
      # @return [Boolean] whether this generation published a commit table
      def table?
        table
      end
    end

    CACHE_SIZE = 8
    @cache = {}
    @mutex = Mutex.new

    class << self
      # The ledger of the generations up to the repository's, cached per index
      # identity: published generations never change.
      #
      # @param repository [WoodsMap::Repository]
      # @return [CommitLedger]
      def for(repository)
        numbers = repository.generations.select { |number| number <= repository.generation_number }
        key = [repository.generation_key, numbers]
        @mutex.synchronize { @cache[key] } || store(key, new(repository, numbers))
      end

      # Drop the cache (specs).
      # @return [void]
      def reset!
        @mutex.synchronize { @cache.clear }
      end

      private

      def store(key, ledger)
        @mutex.synchronize do
          @cache.shift while @cache.size >= CACHE_SIZE
          @cache[key] = ledger
        end
      end
    end

    # @param repository [WoodsMap::Repository]
    # @param numbers [Array<Integer>] retained generation numbers, ascending
    def initialize(repository, numbers)
      previous = nil
      @generations = numbers.map do |number|
        facts = read(repository, number)
        generation = build(number, facts, previous)
        previous = facts[:shas]
        generation
      end
      @by_sha = {}
      @generations.each do |generation|
        generation.introduced.each { |sha| @by_sha[sha] ||= generation }
      end
    end

    # @return [Array<Generation>] ascending
    attr_reader :generations

    # @param sha [String]
    # @return [Generation, nil] the generation whose table first lists the commit
    def generation_for(sha)
      @by_sha[sha]
    end

    # @param shas [Enumerable<String>]
    # @return [Array<Generation>] generations that introduced any of the commits, newest first
    def touching(shas)
      wanted = shas.to_set
      @generations.select { |generation| generation.introduced.any? { |sha| wanted.include?(sha) } }.reverse
    end

    private

    def read(repository, number)
      repository.with_generation(number) do |generation|
        table = generation.git_commits
        { head: table&.head || generation.manifest['git_sha'], extracted_at: generation.manifest['extracted_at'],
          shas: table&.commits&.map { |row| row['sha'] } }
      end
    rescue Repository::Unavailable
      { head: nil, extracted_at: nil, shas: nil }
    end

    def build(number, facts, previous)
      shas = facts[:shas]
      baseline = shas.nil? || previous.nil?
      introduced = if shas.nil? then []
                   elsif previous.nil? then shas
                   else shas - previous
                   end
      Generation.new(number: number, head: facts[:head], extracted_at: facts[:extracted_at], table: !shas.nil?,
                     baseline: baseline, introduced: introduced.to_set)
    end
  end
end
