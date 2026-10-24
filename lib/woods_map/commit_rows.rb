# frozen_string_literal: true

module WoodsMap
  # Commit rows for the History tab: the commit table's rows with their
  # files, the units of this generation those files belong to, and the
  # retained generation that first carried each one; or, without a table,
  # the five commits `metadata.git` keeps per unit.
  class CommitRows
    # One commit row.
    Commit = Struct.new(:sha, :author, :date, :message, :description, :files, :files_omitted, :units,
                        :generation, :parents, :line_stats, keyword_init: true) do
      # @return [Integer] every file the commit touched, listed or not
      def file_count
        files.size + files_omitted.to_i
      end

      # @return [Boolean]
      def merge?
        parents.size > 1
      end
    end

    # One touched file: its application-relative path, the commit table's
    # status, whether the table indexes it (a unit's file), its added and
    # removed lines and hunks when the table has line stats (woods#804),
    # whether this commit is the file's latest (its hunks then address the
    # file the Code view shows), and the typed unit that owns it.
    FileChange = Struct.new(:path, :status, :indexed, :stats, :additions, :deletions, :hunks, :hunks_truncated,
                            :latest, :owner, keyword_init: true)

    # @param git [Hash] a unit's `metadata.git`
    # @return [Array<Commit>] its recent commits, without files
    def self.fallback(git)
      Array(git['recent_commits']).map do |row|
        Commit.new(sha: row['sha'], author: row['author'], date: row['date'], message: row['message'], description: '',
                   files: [], files_omitted: 0, units: [], generation: nil, parents: [], line_stats: false)
      end
    end

    # @param repository [WoodsMap::Repository]
    # @param table [Woods::PublishedIndex::CommitTable]
    # @param ledger [CommitLedger]
    def initialize(repository, table, ledger)
      @repository = repository
      @table = table
      @ledger = ledger
    end

    # @param row [Hash] a commit row of the table
    # @return [Commit]
    def build(row)
      files = Array(row['files']).map { |file| file_change(file, row['sha']) }
      Commit.new(sha: row['sha'], author: row['author'], date: row['date'], message: row['message'],
                 description: row['description'].to_s, files: files, files_omitted: row['files_omitted'].to_i,
                 units: units_for(files), generation: @ledger.generation_for(row['sha']),
                 parents: Array(row['parents']), line_stats: @table.respond_to?(:line_stats?) && @table.line_stats?)
    end

    private

    def file_change(file, sha)
      path = file['path']
      shas = @table.paths[path]
      owner = @repository.file_owners(path).first&.values_at('identifier', 'type')
      FileChange.new(path: path, status: file['status'], indexed: !shas.nil?, stats: file.key?('additions'),
                     additions: file['additions'], deletions: file['deletions'], hunks: Array(file['hunks']),
                     hunks_truncated: file['hunks_truncated'], latest: shas&.first == sha, owner: owner)
    end

    def units_for(files)
      files.flat_map { |file| @repository.file_owners(file.path) }
           .map { |owner| [owner['identifier'], owner['type']] }.uniq
    end
  end
end
