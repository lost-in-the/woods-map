# frozen_string_literal: true

module WoodsMap
  # The "Used by" and "Depends on" tiles of a unit page's facts. Each groups
  # the unit's edges into a few rows, the groups with the most distinct units
  # first; when there are more groups than rows, the last row collects the
  # rest as "other", so every unit the eyebrow counts is linked. Equal sizes
  # order by a fixed rank, then by name: the published edge order decides nothing.
  class EdgeTiles
    # Rows the "Used by" tile shows at most.
    USED_BY_ROWS = 4
    # Rows the "Depends on" tile shows at most.
    DEPENDS_ON_ROWS = 5

    # @param dependents [Array<Hash>] reverse edges (source, source_type, via)
    # @param dependencies [Array<Hash>] forward edges (target, type, via)
    def initialize(dependents:, dependencies:)
      @dependents = dependents
      @dependencies = dependencies
    end

    # @return [Hash, nil] eyebrow and rows, nil without dependents
    def used_by
      groups = @dependents.group_by { |d| d['source_type'].to_s }
      return nil if groups.empty?

      links = groups.transform_values { |list| list.map { |d| [d['source'], d['source_type'].to_s] }.uniq }
      rows = used_by_groups(links).map { |label, list| [label, { links: list }] }
      { eyebrow: used_by_label(groups), rows: rows }
    end

    # Rows read in {UnitPage::DEPENDENCY_GROUPS}' order (associations, then includes, enqueues,
    # renders, references, navigation, routes, tests, mail; unmapped ones after), as the
    # guidelines board draws them. Distinct targets only decide which relationships keep a row
    # of their own when there are more than the tile holds.
    #
    # @return [Hash, nil] eyebrow and rows, nil without dependencies
    def depends_on
      groups = @dependencies.group_by { |d| UnitPage::DEPENDENCY_GROUPS.fetch(d['via'].to_s, d['via'].to_s) }
      return nil if groups.empty?

      links = groups.transform_values { |list| list.map { |d| [d['target'], d['type']] }.uniq }
      rows = in_reading_order(capped(ranked(links, DEPENDENCY_RANK), DEPENDS_ON_ROWS)).map do |label, list|
        [label, { links: list }]
      end
      { eyebrow: "Depends on #{@dependencies.pluck('target').uniq.size}", rows: rows }
    end

    DEPENDENCY_RANK = UnitPage::DEPENDENCY_GROUPS.values.uniq.freeze
    private_constant :DEPENDENCY_RANK

    private

    # @param groups [Hash] distinct source links by published source type
    # @return [Array<Array(String, Array<Array(String, String)>)>] row label and its links, documentation last
    def used_by_groups(groups)
      limit = groups.key?('doc') ? USED_BY_ROWS - 1 : USED_BY_ROWS
      code = ranked(groups.except('doc'), Landscape::TYPE_ORDER)
      rows = capped(code.map { |type, list| [type.pluralize.tr('_', ' '), list] }, limit)
      rows << ['documentation', groups['doc']] if groups.key?('doc')
      rows
    end

    # @param rows [Array<Array(String, Array)>] the rows the tile keeps
    # @return [Array<Array(String, Array)>] by relationship rank, then name, "other" last
    def in_reading_order(rows)
      rows.sort_by do |label, _|
        label == 'other' ? [1, 0, label] : [0, DEPENDENCY_RANK.index(label) || DEPENDENCY_RANK.size, label]
      end
    end

    # @param groups [Hash] distinct [identifier, type] links by group name
    # @param order [Array<String>] the rank of known names
    # @return [Array<Array(String, Array)>] most units first, then by rank, then by name
    def ranked(groups, order)
      groups.sort_by { |name, list| [-list.size, order.index(name) || order.size, name] }
    end

    # @param sorted [Array<Array(String, Array)>] groups of distinct links, as {#ranked} orders them
    # @param limit [Integer] rows at most
    # @return [Array<Array(String, Array)>] the first rows, and "other" holding the rest that no kept row
    #   links (omitted when that leaves nothing)
    def capped(sorted, limit)
      return sorted if sorted.size <= limit

      kept = sorted.first(limit - 1)
      rest = sorted.drop(limit - 1).flat_map(&:last).uniq - kept.flat_map(&:last)
      rest.empty? ? kept : kept << ['other', rest]
    end

    # @param groups [Hash] reverse edges grouped by published source type
    # @return [String] code and documentation counts labelled apart
    def used_by_label(groups)
      count = groups.except('doc').values.flatten.pluck('source').uniq.size
      docs = groups.fetch('doc', []).pluck('source').uniq.size
      ["Used by #{count}", ("#{docs} documentation" if docs.positive?)].compact.join(', ')
    end
  end
end
