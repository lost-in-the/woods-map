# frozen_string_literal: true

module WoodsMap
  # The History exports (D-25, design study "Commits over time"): a
  # `timeline` of the commits and an `xychart-beta` of commits per bar of the
  # strip. Text only; Pele draws it in the page and agents fetch it as `.mmd`.
  module HistoryMermaid
    # Commits one timeline draws (R-4); past it the timeline keeps the newest
    # and says how many it left out.
    TIMELINE_BUDGET = 40
    VIEWS = %w[timeline xychart].freeze

    module_function

    # @param title [String]
    # @param commits [Array<#sha, #date, #message, #author>] newest first
    # @return [String]
    def timeline(title, commits)
      shown = commits.first(TIMELINE_BUDGET)
      lines = ['timeline', "  title #{label(title)}"]
      omitted = commits.size - shown.size
      lines << "  section earlier\n    #{omitted} more : listed on the page" if omitted.positive?
      months = shown.reverse.group_by { |commit| commit.date.to_s[0, 7] }
      months.each { |month, group| lines.concat(section(month, group)) }
      "#{lines.join("\n")}\n"
    end

    # @param month [String] YYYY-MM
    # @param commits [Array] that month's commits, oldest first
    # @return [Array<String>] the section's lines, one per day
    def section(month, commits)
      days = commits.group_by { |commit| commit.date.to_s[0, 10] }
      ["  section #{month}"] + days.map { |date, list| "    #{date} : #{list.map { |c| event(c) }.join(' : ')}" }
    end

    # @param commit [#sha, #message, #author]
    # @return [String] one timeline event: short sha, subject, author
    def event(commit)
      "#{commit.sha.to_s[0, 7]} #{label(commit.message, 60)} (#{label(commit.author, 30)})"
    end

    # @param title [String]
    # @param strip [WoodsMap::CommitStrip]
    # @return [String]
    def xychart(title, strip)
      labels = strip.buckets.map { |bucket| "\"#{bucket.first.strftime('%m-%d')}\"" }
      top = [strip.peak, 1].max
      lines = ['xychart-beta', "  title \"#{label(title)}\"", "  x-axis [#{labels.join(', ')}]",
               "  y-axis \"commits per #{strip.step == 1 ? 'day' : 'week'}\" 0 --> #{top}",
               "  bar [#{strip.buckets.map(&:count).join(', ')}]"]
      "#{lines.join("\n")}\n"
    end

    # A label Mermaid's timeline and chart grammars read literally: no
    # separators, quotes, comments or brackets, one line, bounded.
    #
    # @param text [String, nil]
    # @param limit [Integer]
    # @return [String]
    def label(text, limit = 80)
      clean = text.to_s.gsub(/[:;#%"`<>{}\[\]|\\]/, ' ').gsub(/\s+/, ' ').strip
      clean.length > limit ? "#{clean[0, limit - 1]}…" : clean
    end
  end
end
