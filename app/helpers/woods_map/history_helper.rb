# frozen_string_literal: true

module WoodsMap
  # The History tab's and `/woods/history`'s small pieces: query links that
  # keep the page's state, file status marks, generation labels.
  module HistoryHelper
    # File statuses the commit table publishes => the word a row shows; a
    # modified file shows none.
    FILE_STATUS = { 'added' => 'new', 'deleted' => 'deleted', 'type_changed' => 'type changed' }.freeze

    # The History tab's URL with the current range, week, all and diff
    # parameters, overridden by +changes+ (nil removes one).
    #
    # @param page [WoodsMap::UnitPage]
    # @param changes [Hash{Symbol => Object}]
    # @return [String]
    def history_tab_url(page, **changes)
      query = request.query_parameters.slice('range', 'week', 'all', 'from', 'to').symbolize_keys.merge(changes).compact
      woods_map.unit_history_path(type: page.type, identifier: page.identifier, **query)
    end

    # @param status [String]
    # @return [ActiveSupport::SafeBuffer, nil] the status mark beside a file path
    def file_status(status)
      word = FILE_STATUS[status.to_s]
      word && tag.span(word, class: status.to_s == 'deleted' ? 'mut' : 'fresh')
    end

    # @param generation [WoodsMap::CommitLedger::Generation, nil]
    # @return [ActiveSupport::SafeBuffer, String] "42", "≤ 41" for a commit
    #   already in the oldest retained table, or a dash
    def commit_generation(generation)
      return empty_value unless generation

      number = generation.number
      if generation.baseline
        tag.abbr("≤ #{number}", title: "already in generation #{number}, the oldest retained table")
      else
        tag.abbr(number.to_s, title: "first carried by generation #{number}")
      end
    end

    # The detail block of one commit row (D-17): description, files with
    # their status, what the table cannot say about hunks, co-changed units.
    #
    # @param commit [WoodsMap::HistoryView::Commit]
    # @param own [Array(String, String)] the page's identifier and type, left out of co-changes
    # @return [ActiveSupport::SafeBuffer]
    def commit_detail(commit, own: nil)
      rows = [description_row(commit), files_row(commit),
              ['hunks', tag.span('line counts and hunks are not in the commit table (woods#804)', class: 'mut')],
              co_changed_row(commit, own), parents_row(commit)]
      render('woods_map/components/detail', rows: rows.compact)
    end

    # @param commit [WoodsMap::HistoryView::Commit]
    # @return [ActiveSupport::SafeBuffer]
    def commit_files(commit)
      lines = commit.files.map do |file|
        safe_join([tag.span(file.path, class: file.indexed ? nil : 'mut'), (file_status(file.status) ? ' ' : nil),
                   file_status(file.status)].compact)
      end
      lines << tag.span("#{commit.files_omitted} more not listed", class: 'mut') if commit.files_omitted.positive?
      safe_join(lines, tag.br)
    end

    private

    def description_row(commit)
      ['description', tag.span(commit.description, class: 'desc')] if commit.description.present?
    end

    def files_row(commit)
      ['files', commit_files(commit)] if commit.files.any? || commit.files_omitted.positive?
    end

    def co_changed_row(commit, own)
      others = commit.units.reject { |unit| unit == own }
      ['co-changed with', safe_join(others.map { |identifier, type| unit_link(identifier, type) }, ', ')] if others.any?
    end

    def parents_row(commit)
      ['parents', safe_join(commit.parents.map { |sha| tag.span(short_sha(sha), title: sha) }, ', ')] if commit.merge?
    end

    public

    # @param commit [#file_count, #units]
    # @return [String] "2 files, 2 units"
    def files_and_units(commit)
      files = commit.file_count
      units = commit.units.size
      "#{files} #{files == 1 ? 'file' : 'files'}, #{units} #{units == 1 ? 'unit' : 'units'}"
    end
  end
end
