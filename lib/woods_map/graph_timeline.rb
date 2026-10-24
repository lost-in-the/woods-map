# frozen_string_literal: true

module WoodsMap
  # The graph's timeline (A-6): the commits of the pinned generation's commit
  # table (Woods W-3) that touched a unit the explorer draws, each with the
  # drawn units it touched, so a window of commits can tint them. A unit's
  # files are its graph node's `file_path` and `source_paths`; the files of
  # inlined concerns count only through the concern's own node.
  class GraphTimeline
    # Commits kept, newest first.
    LIMIT = 80

    # One commit with the drawn units it touched.
    Commit = Struct.new(:sha, :date, :author, :message, :units, keyword_init: true)

    # @param repository [Repository]
    # @param neighbourhood [Neighbourhood] what the explorer draws
    # @param author [String, nil] only commits whose author, as git recorded it, is exactly this
    def initialize(repository, neighbourhood, author: nil)
      @repository = repository
      @neighbourhood = neighbourhood
      @author = author.to_s.presence
    end

    # @return [String, nil] the author the commits are narrowed to (woods-map#92)
    attr_reader :author

    # @return [Array<String>] authors of the commits that touched a drawn unit, most commits first
    def authors
      return [] unless table?

      rows = @repository.git_commits.commits_for(*path_owners.keys)
      rows.group_by { |row| row['author'] }.sort_by { |name, list| [-list.size, name.to_s] }.map(&:first).compact
    end

    # @return [Symbol] the commit table's state (Repository#commit_table_state)
    def state
      @repository.commit_table_state
    end

    # @return [Boolean] whether there is a table to read
    def table?
      state == :available
    end

    # @return [Array<Commit>] newest first, at most {LIMIT}
    def commits
      @commits ||= table? ? build : []
    end

    # @return [Integer] commits that touched a drawn unit, before {LIMIT}
    def total
      commits
      @total.to_i
    end

    # @return [Boolean] whether the published table stopped at its own bound
    def truncated?
      table? && @repository.git_commits.truncated?
    end

    # @return [Integer] distinct drawn units any listed commit touched
    def touched_units
      commits.flat_map(&:units).uniq.size
    end

    # The canvas's copy: oldest first, so a window reads left to right.
    #
    # @return [Array<Hash>]
    def payload
      commits.reverse.map do |commit|
        { 'sha' => commit.sha[0, 7], 'date' => commit.date.to_s[0, 10], 'message' => commit.message,
          'units' => commit.units.map { |identifier, type| { 'identifier' => identifier, 'type' => type } } }
      end
    end

    private

    def build
      table = @repository.git_commits
      owners = path_owners
      rows = table.commits_for(*owners.keys)
      rows = rows.select { |row| row['author'] == @author } if @author
      @total = rows.size
      rows.first(LIMIT).map { |row| commit_for(row, owners) }
    end

    def commit_for(row, owners)
      units = Array(row['files']).flat_map { |file| owners.fetch(file['path'].to_s, []) }.uniq
      Commit.new(sha: row['sha'].to_s, date: row['date'], author: row['author'],
                 message: row['message'].to_s.lines.first.to_s.strip, units: units)
    end

    # @return [Hash{String => Array<Array(String, String)>}] path => drawn typed units
    def path_owners
      owners = Hash.new { |hash, key| hash[key] = [] }
      identities.each do |identifier, type|
        node = @repository.graph_node(identifier, type: type)
        next unless node

        ([node['file_path']] + Array(node['source_paths'])).grep(String).reject(&:empty?).uniq.each do |path|
          owners[path] << [identifier, type]
        end
      end
      owners
    end

    def identities
      @neighbourhood.edges.flat_map { |e| [[e.from, e.from_type], [e.to, e.to_type]] }
                    .push(@neighbourhood.focus).uniq
    end
  end
end
