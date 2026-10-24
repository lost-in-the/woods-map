# frozen_string_literal: true

module WoodsMap
  # The file tree's rows for the tree component (C3, D-18, M10).
  module TreeHelper
    # Folders above +open_below+ start open; the rest start folded, and every
    # row under a folded folder is hidden, so ▸ never sits above visible
    # children.
    #
    # @param rows [Array<WoodsMap::FileTree::Row>]
    # @param open_below [Integer] folder levels that start open
    # @yieldparam row [WoodsMap::FileTree::Row] a row, for its inline chips
    # @return [Array<Hash>] the tree component's row hashes
    def file_tree_rows(rows, open_below: 1)
      folded = nil
      rows.map do |row|
        folded = nil if folded && row.level <= folded
        open = row.level < open_below
        hidden = !folded.nil?
        folded = row.level if row.kind == :dir && !open && !hidden
        { kind: row.kind, name: row.name, level: row.level, path: row.path, count: row.count,
          owner_keys: row.owner_keys, open: open, hidden: hidden, unindexed: false,
          href: (row.kind == :file ? woods_map.file_path(path: row.path) : nil), chips: (yield(row) if block_given?) }
      end
    end

    # @param files [Boolean] whether the page offers the file tree
    # @return [String, nil] the URL the sheet fetches the tree from, or nil on pages without an index
    def files_sheet_tree_url(files)
      return nil unless files && current_repository

      since = current_since if current_since&.available?
      woods_map.tree_path(gen: current_repository.generation_number, since: since&.selector)
    end
  end
end
