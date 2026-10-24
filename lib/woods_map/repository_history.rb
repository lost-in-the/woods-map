# frozen_string_literal: true

module WoodsMap
  # The history reads of {Repository} (M4): the pinned generation's commit
  # table and the other retained generations, each opened through
  # `Woods::PublishedIndex` and locked like the request's own. Mixed into
  # Repository, which supplies `@index` and `generation_number`.
  module RepositoryHistory
    # The pinned generation's commit table (Woods W-3), read once.
    #
    # @return [Woods::PublishedIndex::CommitTable, nil] nil when the generation
    #   publishes none, the table is unreadable, or this Woods has no reader;
    #   {#commit_table_state} says which
    def git_commits
      commit_table_state
      @git_commits
    end

    # Why {#git_commits} answers what it does.
    #
    # @return [Symbol] :available, :absent (no readable history at extraction,
    #   or an older writer), :unreadable (the file exists but Woods refused it)
    #   or :unsupported (this Woods has no commit table reader)
    def commit_table_state
      @commit_table_state ||= begin
        @git_commits = @index.git_commits if @index.respond_to?(:git_commits)
        if !@index.respond_to?(:git_commits) then :unsupported
        elsif @git_commits then :available
        else :absent
        end
      rescue StandardError
        @git_commits = nil
        :unreadable
      end
    end

    # Open another published generation of the same index for one block, as
    # pinned and locked as this one. Retained generations are immutable, so
    # what they answer never changes.
    #
    # @param number [Integer] a published generation number
    # @yieldparam repository [WoodsMap::Repository]
    # @return [Object] the block's value
    # @raise [Repository::Unavailable] when the generation is not published
    def with_generation(number)
      return yield self if number == generation_number

      index = open_generation(number)
      begin
        yield self.class.new(index)
      ensure
        index.close
      end
    end

    private

    def open_generation(number)
      Woods::PublishedIndex.new(@index.index_dir, generation: number)
    rescue ArgumentError, Woods::PublishedIndex::CorruptPointerError, Errno::ENOENT => e
      raise Repository::Unavailable, "Generation #{number} is not published: #{e.message}"
    end
  end
end
