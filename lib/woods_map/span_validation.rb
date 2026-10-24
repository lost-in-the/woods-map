# frozen_string_literal: true

module WoodsMap
  # Shape checks for published reference span records (W-1): known kinds and
  # confidences, integer byte positions, and either a typed target or, for an
  # ambiguous span, at least two typed candidates. Expects @source.
  module SpanValidation
    KINDS = %w[constant association callback_method scope].freeze
    CONFIDENCES = %w[verified static ambiguous].freeze

    private

    def valid_record?(record)
      return false unless record.is_a?(Hash) && KINDS.include?(record['kind']) &&
                          CONFIDENCES.include?(record['confidence']) && valid_position?(record)
      return false if record.key?('method') && !valid_identity?(record['method'])
      return valid_candidates?(record['candidates']) if record['confidence'] == 'ambiguous'

      %w[target target_type].all? { |key| valid_identity?(record[key]) }
    end

    def valid_candidates?(candidates)
      candidates.is_a?(Array) && candidates.size > 1 && candidates.all? do |candidate|
        candidate.is_a?(Hash) && %w[target target_type].all? { |key| valid_identity?(candidate[key]) }
      end
    end

    def valid_position?(record)
      %w[line column length].all? { |key| record[key].is_a?(Integer) } &&
        record['line'].positive? && record['column'] >= 0 && record['length'].positive? &&
        record['length'] <= @source.bytesize
    end

    def valid_identity?(value)
      value.is_a?(String) && !value.empty? && value.dup.force_encoding(Encoding::UTF_8).valid_encoding?
    end
  end
end
