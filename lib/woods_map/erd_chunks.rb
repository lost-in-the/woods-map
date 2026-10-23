# frozen_string_literal: true

module WoodsMap
  # Cuts an {Erd}'s tables into numbered chunks: grouped by database and the
  # model's namespace (or by database alone), in reading order, each group
  # cut at the ER table budget (R-4) along its relations, so related tables
  # stay together where they can.
  class ErdChunks
    # @param erd [Erd]
    def initialize(erd)
      @erd = erd
    end

    # @param by [String] namespace or database
    # @return [Array<Erd::Chunk>]
    def call(by)
      number = 0
      groups(by).flat_map do |(db, group), members|
        slices = connected_order(members).each_slice(SchemaView::TABLE_BUDGET).to_a
        slices.each_with_index.map do |slice, i|
          Erd::Chunk.new(number: number += 1, database: db, group: group, part: i + 1, parts: slices.size,
                         tables: slice.map(&:name))
        end
      end
    end

    private

    def groups(by)
      databases = @erd.databases
      @erd.tables.group_by { |t| [t.database, by == 'database' ? t.database : t.namespace] }
          .sort_by { |(db, group), _| [databases.index(db), group == Erd::NO_NAMESPACE ? 1 : 0, group] }
    end

    # Breadth-first along relations from each table in name order, so a cut
    # at the budget splits the group between loosely related tables.
    def connected_order(members)
      neighbours = neighbours_within(members.map(&:name))
      seen = {}
      members.each do |table|
        next if seen[table.name]

        seen[table.name] = true
        queue = [table.name]
        queue.concat(visit(neighbours[queue.shift], seen)) until queue.empty?
      end
      seen.keys.map { |name| @erd.table_named(name) }
    end

    # Marks the unseen neighbours seen and returns them, in name order.
    def visit(names, seen)
      names.uniq.sort.reject { |n| seen[n] }.each { |n| seen[n] = true }
    end

    def neighbours_within(names)
      relations = @erd.relations.select { |r| names.include?(r.from) && names.include?(r.to) }
      relations.each_with_object(Hash.new { |h, k| h[k] = [] }) do |r, map|
        map[r.from] << r.to
        map[r.to] << r.from
      end
    end
  end
end
