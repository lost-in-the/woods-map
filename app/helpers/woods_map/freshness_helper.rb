# frozen_string_literal: true

module WoodsMap
  # Freshness in words: the bar's glyph and words, its tooltip, and the
  # status page's reasons and next steps, from Woods' quick source check.
  module FreshnessHelper
    # Woods' freshness reasons in plain words. A reason not listed here
    # is shown as written, with spaces.
    FRESHNESS_REASONS = {
      'scan_time_budget' => 'the quick check stopped at its time limit',
      'scan_file_budget' => 'the check stopped at its file limit',
      'scan_byte_budget' => 'the check stopped at its byte limit',
      'incomplete_verification' => 'not every recorded file was read',
      'incomplete_capture' => 'the extraction did not record every file it read',
      'incomplete_comparison_baseline' => 'the recorded baseline is incomplete',
      'unverified_boot_boundary' => 'the extraction did not run through woods-extract, ' \
                                    'so the files read while Rails booted are unverified',
      'unverified_consumption_scopes' => 'some extractors could not record every file they read',
      'source_root_unavailable' => 'the application source is not readable here',
      'identity_key_mismatch' => 'the index was extracted with another identity key',
      'identity_key_unavailable' => 'the identity key is missing',
      'generation_mismatch' => 'the source record belongs to another generation',
      'input_rules_changed' => 'the source input rules changed since extraction',
      'source_manifest_unavailable' => 'this generation has no source record',
      'atomic_source_manifest_unavailable' => 'this generation has no source record'
    }.freeze

    # Woods' freshness recommendations as steps.
    FRESHNESS_STEPS = {
      'deep_check' => 'read every recorded file once: woods_status with {"source_check":"deep"}',
      'fresh_capture' => 'extract again in a fresh process with bundle exec woods-extract full, ' \
                         'which records the files Rails reads while booting',
      'inspect_source_scan' => 'check that the application source is readable from this process',
      'inspect_source_limits' => 'the source record is over its size limit; the index itself still works'
    }.freeze

    # @param freshness [Hash, nil] the repository's freshness report
    # @return [Array<String>] Woods' recommendations as steps, in plain words
    def freshness_steps(freshness)
      Array(freshness.to_h['recommendations']).map do |step|
        FRESHNESS_STEPS.fetch(step.to_s) { step.to_s.tr('_', ' ') }
      end
    end

    # @param freshness [Hash, nil] the repository's freshness report
    # @return [Array<String>] each reason Woods gave, in plain words
    def freshness_reasons(freshness)
      Array(freshness.to_h['reasons']).map do |reason|
        FRESHNESS_REASONS.fetch(reason.to_s) { reason.to_s.tr('_', ' ') }
      end
    end

    # The reasons behind the freshness words, for the bar's tooltip: what the
    # quick check saw, and which of Woods' verifications it could not make.
    #
    # @param freshness [Hash, nil] the repository's freshness report
    # @return [String, nil]
    def freshness_detail(freshness)
      return nil unless freshness.is_a?(Hash)

      counts = freshness['counts'].to_h
      seen = %w[added changed removed].filter_map { |k| "#{counts[k]} #{k}" if counts[k].to_i.positive? }
      seen << freshness_coverage(freshness) if seen.empty?
      [seen.compact.join(', ').presence, freshness_reasons(freshness).join(', ').presence].compact.join('; ').presence
    end

    # @param state [String] a freshness state
    # @param freshness [Hash, nil] the report, which can turn an unknown
    #   state with no drift in what it read into "no drift seen"
    # @return [Array(String, String)] the glyph class and the words for the bar
    def freshness_words(state, freshness = nil)
      case state
      when 'current' then ['fresh', 'index current']
      when 'drifted' then ['hot', 'index drifted']
      when 'stale' then ['mod', 'index stale']
      else ['dim', no_drift_seen?(freshness) ? 'no drift seen' : 'freshness unknown']
      end
    end

    # @param freshness [Hash] the repository's freshness report
    # @return [String, nil] how much the check read without finding drift
    def freshness_coverage(freshness)
      coverage = freshness['coverage']
      if coverage.is_a?(Hash) && coverage['recorded_files'].is_a?(Integer)
        return "no drift in #{coverage['verified_files']} of #{coverage['recorded_files']} recorded files"
      end

      files = freshness.dig('metrics', 'visited_files')
      "#{files} files checked, no drift seen" if files
    end

    private

    def no_drift_seen?(freshness)
      return false unless freshness.is_a?(Hash) && freshness['coverage'].is_a?(Hash)

      freshness['counts'].to_h.values_at('added', 'changed', 'removed').all? { |count| count.to_i.zero? }
    end
  end
end
