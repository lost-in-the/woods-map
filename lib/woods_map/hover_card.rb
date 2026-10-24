# frozen_string_literal: true

module WoodsMap
  # The hover card on a reference (B-3): what a reader needs before following
  # a link, from one pinned generation. Type, path and churn come from the
  # typed graph node, PageRank from the graph's identifier-level scores, and
  # the last author from the unit's `metadata.git`. The code view renders the
  # cards of the units it links with the page (B-3's prefetched per-page
  # data), so a card opens without a request; the target units are the ones
  # the reference check already read.
  class HoverCard
    # The cards of the units a code view links, in first-link order.
    #
    # @param repository [WoodsMap::Repository]
    # @param targets [Array<Array(String, String)>] identifier and type pairs
    # @return [Array<HoverCard>] the cards of targets present in the generation
    def self.for(repository, targets)
      scores = Scores.new(repository.graph['pagerank'])
      targets.uniq.map { |identifier, type| new(repository, identifier, type, scores: scores) }.select(&:found?)
    end

    # PageRank scores sorted once per page, for each card's place.
    class Scores
      # @param pagerank [Hash, nil] identifier => score, as the graph publishes it
      def initialize(pagerank)
        @scores = pagerank.is_a?(Hash) ? pagerank.select { |_, score| score.is_a?(Numeric) } : {}
        @descending = @scores.values.sort.reverse
      end

      # @return [Float, nil]
      def [](identifier)
        @scores[identifier]&.to_f
      end

      # @return [Integer] 1-based position, ties sharing a place
      def place(score)
        (@descending.bsearch_index { |other| other <= score } || @descending.size) + 1
      end

      # @return [Integer] how many identifiers carry a score
      delegate :size, to: :@descending
    end

    # @param repository [WoodsMap::Repository]
    # @param identifier [String]
    # @param type [String]
    # @param scores [Scores, nil] shared across the cards of one page
    def initialize(repository, identifier, type, scores: nil)
      @repository = repository
      @identifier = identifier.to_s
      @type = type.to_s
      @node = repository.graph_node(@identifier, type: @type)
      @scores = scores
    end

    attr_reader :identifier, :type

    # @return [Boolean] whether the typed unit is in the generation
    def found?
      !@node.nil? || !unit.nil?
    end

    # @return [String, nil] the unit's file, relative to the application root
    def path
      @node&.dig('file_path') || unit&.dig('file_path')
    end

    # @return [Float, nil] the PageRank score the graph publishes for the identifier
    def pagerank
      scores[@identifier]
    end

    # @return [Integer, nil] 1-based position among every scored identifier, ties sharing a place
    def rank
      score = pagerank
      score && scores.place(score)
    end

    # @return [Integer] how many identifiers carry a score
    def ranked
      scores.size
    end

    # @return [String, nil]
    def last_author
      git['last_author'].presence
    end

    # @return [String, nil] an ISO 8601 time
    def last_modified
      git['last_modified'].presence
    end

    # @return [Integer, nil]
    def commit_count
      value = git['commit_count'] || @node&.dig('commit_count')
      value&.to_i
    end

    # @return [String, nil] hot, active, stable, dormant or new, as Woods classifies it
    def change_frequency
      (git['change_frequency'] || @node&.dig('change_frequency')).presence&.to_s
    end

    # @return [Boolean] whether the index recorded any git facts for the unit
    def git?
      !git.empty? || !@node&.dig('commit_count').nil?
    end

    private

    def unit
      return @unit if defined?(@unit)

      @unit = @repository.unit(@identifier, type: @type)
    end

    def git
      @git ||= unit&.dig('metadata', 'git').is_a?(Hash) ? unit.dig('metadata', 'git') : {}
    end

    def scores
      @scores ||= Scores.new(@repository.graph['pagerank'])
    end
  end
end
