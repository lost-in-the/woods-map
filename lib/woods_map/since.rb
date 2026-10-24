# frozen_string_literal: true

require 'set'

module WoodsMap
  # `?since=<generation>` on a unit page or the ERD (E-8): what Woods' range
  # report from that generation to now says about the units on the page. The
  # evidence is `Woods::Impact::Report.compare` through `WoodsMap::ImpactRange`
  # and nothing else; the map never diffs two payloads. A report says which
  # facets and metadata keys moved and, for a modified source, which lines
  # (`source_changes`, woods#802): the page marks those lines in the gutter
  # and what reads a moved key in the margin.
  class Since
    # The report's changed lines for one unit, in the current generation's
    # annotated `source_code` (the report's `to` side is now). `changed`
    # holds composite line numbers; `removed_after` maps a line to the count
    # of lines removed just after it.
    LineMarks = Struct.new(:changed, :removed_after, :added, :removed, :coverage, keyword_init: true) do
      # @param number [Integer, nil] a composite line
      # @return [Boolean]
      def changed?(number)
        changed.include?(number)
      end

      # @param number [Integer, nil]
      # @return [Integer] lines removed right after it (0 when none)
      def removed_count(number)
        removed_after.fetch(number, 0)
      end
    end

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

    # Which lines of the unit's current source changed since the selector.
    #
    # @param identifier [String]
    # @param type [String]
    # @return [LineMarks, nil] nil when the report has no line ranges for the
    #   unit, they are too large to compute, or its `now` is not the pinned
    #   generation (the lines would address another source)
    def line_marks(identifier, type)
      changes = change(identifier, type)&.dig('source_changes')
      return nil unless changes.is_a?(Hash) && current_generation?
      return nil unless %w[complete truncated].include?(changes['coverage'])

      marks = LineMarks.new(changed: Set.new, removed_after: {}, added: changes['added_lines'],
                            removed: changes['removed_lines'], coverage: changes['coverage'])
      Array(changes['hunks']).each { |hunk| mark(marks, hunk) }
      marks
    end

    # @param identifier [String]
    # @param type [String]
    # @return [Hash, nil] the unit's `source_changes` as Woods recorded it
    def source_changes(identifier, type)
      change(identifier, type)&.dig('source_changes')
    end

    # @return [Boolean] whether the report's `now` is the generation this page reads
    def current_generation?
      !@report.nil? && to_generation == @repository.generation_number
    end

    # @return [RangeReport::GraphBlast, nil] the emphasis for a graph canvas
    def graph_blast
      @report&.graph_blast
    end

    private

    def mark(marks, hunk)
      start, length = Array(hunk['after'])
      return unless start.is_a?(Integer) && length.is_a?(Integer)

      if length.positive?
        start.upto(start + length - 1) { |number| marks.changed << number }
      elsif start.positive?
        marks.removed_after[start] = Array(hunk['before'])[1].to_i
      end
    end

    def changes
      @changes ||= Array(@report&.changed).index_by { |c| c.values_at('identifier', 'type') }
    end

    def reaches
      @reaches ||= Array(@report&.affected).select { |a| a['endpoint'] == 'to' }
                                           .index_by { |a| a.values_at('identifier', 'type') }
    end
  end
end
