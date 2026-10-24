# frozen_string_literal: true

module WoodsMap
  # Commit rows for the History tab: the commit table's rows with their
  # files, the units of this generation those files belong to, and the
  # retained generation that first carried each one; or, without a table,
  # the five commits `metadata.git` keeps per unit.
  class CommitRows
    # One commit row.
    Commit = Struct.new(:sha, :author, :date, :message, :description, :files, :files_omitted, :units,
                        :generation, :parents, keyword_init: true) do
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
    # status, and whether the table indexes it (a unit's file).
    FileChange = Struct.new(:path, :status, :indexed, keyword_init: true)

    # @param git [Hash] a unit's `metadata.git`
    # @return [Array<Commit>] its recent commits, without files
    def self.fallback(git)
      Array(git['recent_commits']).map do |row|
        Commit.new(sha: row['sha'], author: row['author'], date: row['date'], message: row['message'], description: '',
                   files: [], files_omitted: 0, units: [], generation: nil, parents: [])
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
      files = Array(row['files']).map do |file|
        FileChange.new(path: file['path'], status: file['status'], indexed: @table.paths.key?(file['path']))
      end
      Commit.new(sha: row['sha'], author: row['author'], date: row['date'], message: row['message'],
                 description: row['description'].to_s, files: files, files_omitted: row['files_omitted'].to_i,
                 units: units_for(files), generation: @ledger.generation_for(row['sha']),
                 parents: Array(row['parents']))
    end

    private

    def units_for(files)
      files.flat_map { |file| @repository.file_owners(file.path) }
           .map { |owner| [owner['identifier'], owner['type']] }.uniq
    end
  end
end
