# frozen_string_literal: true

module WoodsMap
  # The files of a commit in the History detail block: the page's own first,
  # a count for the rest.
  module CommitFilesHelper
    # Files of a commit listed beside the page's own before the rest fold behind a count.
    FILES_BESIDE_OWN = 6

    # The commit's files with +first+ ahead of the rest. Only {FILES_BESIDE_OWN} of the others
    # show before a count of the remainder, which opens in place.
    #
    # @param commit [WoodsMap::HistoryView::Commit]
    # @param first [Array<String>] paths to list first
    # @return [ActiveSupport::SafeBuffer]
    def commit_files(commit, first: [])
      own, others = commit.files.partition { |file| first.include?(file.path) }
      shown = others.first(FILES_BESIDE_OWN)
      folded = others.drop(FILES_BESIDE_OWN)
      lines = (own + shown).map { |file| file_line(file) }
      lines << folded_files(folded) if folded.any?
      lines << tag.span("#{commit.files_omitted} more not listed", class: 'mut') if commit.files_omitted.positive?
      safe_join(lines, tag.br)
    end

    private

    def file_line(file)
      safe_join([tag.span(file.path, class: file.indexed ? nil : 'mut'), line_counts(file), file_status(file.status)]
                  .compact, ' ')
    end

    def folded_files(files)
      tag.details(class: 'more-files') do
        safe_join([tag.summary("#{files.size} more #{'file'.pluralize(files.size)}"),
                   safe_join(files.map { |file| file_line(file) }, tag.br)])
      end
    end
  end
end
