# frozen_string_literal: true

# Whether the loaded Woods reads commit-table line stats (woods#804). CI
# resolves Woods from its main branch, which may predate the reader; specs
# of the hunk links skip there and the limits name the gap instead.
module WoodsLineStats
  # @return [Boolean]
  def self.supported?
    require 'woods/published_index'
    Woods::PublishedIndex::CommitTable.method_defined?(:line_stats?)
  rescue LoadError, NameError
    false
  end
end
