# frozen_string_literal: true

module WoodsMap
  # `?since=<generation>` on a unit page or the ERD (E-8): what Woods' range
  # report from that generation to now says about the units on the page. The
  # evidence is `Woods::Impact::Report.compare` through `WoodsMap::ImpactRange`
  # and nothing else; the map never diffs two payloads. A report says which
  # facets and metadata keys moved, not which lines (woods#802), so the page
  # marks what reads those keys and names the rest as a limit.
  class Since
    SELECTOR = /\A(?:gen:[1-9]\d{0,8}|[0-9a-f]{7,40})\z/i

    # What a marginal note or a page section reads, by metadata key.
    KEYS = {
      associations: %w[associations], callbacks: %w[callbacks callback_count], validations: %w[validations],
      concerns: %w[inlined_concerns included_concerns], filters: %w[filters filter_count],
      actions: %w[actions action_sources action_facts routes], columns: %w[columns column_count indexes foreign_keys],
      templates: %w[instance_variables partials_rendered renders]
    }.freeze

    # @param selector [String, nil] the `since` query value
    # @param index_dir [Pathname, String]
    # @param repository [WoodsMap::Repository] the pinned current generation
    # @return [Since, nil] nil when the page was not opened with `since`
    def self.from_param(selector, index_dir:, repository:)
      return nil if selector.blank?

      new(selector.to_s, index_dir: index_dir, repository: repository)
    end

    # @param selector [String]
    # @param index_dir [Pathname, String]
    # @param repository [WoodsMap::Repository]
    def initialize(selector, index_dir:, repository:)
      @selector = selector
      @repository = repository
      @range = SELECTOR.match?(selector) ? ImpactRange.new(index_dir, from: selector, to: 'now') : nil
      @report = RangeReport.new(@range.data, repository: repository) if @range&.state == :available
    end

    # @return [String] the selector as given, for links that keep it
    attr_reader :selector

    # @return [RangeReport, nil]
    attr_reader :report

    # @return [Boolean] whether Woods answered with a report
    def available?
      !@report.nil?
    end

    # @return [String] why there is no report, when there is none
    def message
      return 'Use since=gen:N or a retained commit SHA (7–40 characters).' unless @range

      @range.message.to_s
    end

    # @return [Integer, nil]
    def from_generation
      @report&.from_generation
    end

    # @return [Integer, nil]
    def to_generation
      @report&.to_generation
    end

    # @param identifier [String]
    # @param type [String]
    # @return [Hash, nil] the changed record for the typed unit
    def change(identifier, type)
      changes[[identifier.to_s, type.to_s]]
    end

    # @param identifier [String]
    # @param type [String]
    # @return [Hash, nil] the affected record for the typed unit at the current endpoint
    def reach(identifier, type)
      reaches[[identifier.to_s, type.to_s]]
    end

    # @param identifier [String]
    # @param type [String]
    # @param area [Symbol] a key of {KEYS}
    # @return [Boolean] whether the unit's changed metadata keys include what the area reads
    def area_changed?(identifier, type, area)
      keys = Array(change(identifier, type)&.dig('metadata_keys'))
      (KEYS.fetch(area) & keys).any?
    end

    # @return [RangeReport::GraphBlast, nil] the emphasis for a graph canvas
    def graph_blast
      @report&.graph_blast
    end

    private

    def changes
      @changes ||= Array(@report&.changed).index_by { |c| c.values_at('identifier', 'type') }
    end

    def reaches
      @reaches ||= Array(@report&.affected).select { |a| a['endpoint'] == 'to' }
                                           .index_by { |a| a.values_at('identifier', 'type') }
    end
  end
end
