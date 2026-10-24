# frozen_string_literal: true

module WoodsMap
  # Who calls a unit (B-13, the B8-Code margin's "called from"): every
  # published constant reference span (W-1) in the pinned generation, keyed by
  # its typed target and grouped by the method it names (W-6). Built once per
  # generation from the units' own metadata and kept in a small process cache.
  #
  # Only `verified` and `static` constant spans count; an ambiguous span names
  # no single callee. A unit's references to itself are not callers. Absence
  # here is not proof of no callers: dynamic dispatch and receiverless calls
  # publish no span.
  class Callers
    Call = Struct.new(:caller, :caller_type, :method, :line, :confidence, keyword_init: true)

    CACHE_SIZE = 4
    @cache = {}
    @mutex = Mutex.new

    class << self
      # @param repository [WoodsMap::Repository]
      # @return [Callers]
      def for(repository)
        key = repository.generation_key
        @mutex.synchronize do
          @cache.fetch(key) do
            @cache.shift while @cache.size >= CACHE_SIZE
            @cache[key] = build(repository)
          end
        end
      end

      # @return [void]
      def reset!
        @mutex.synchronize { @cache.clear }
      end

      # Read every unit of the generation once, uncached.
      #
      # @param repository [WoodsMap::Repository]
      # @return [Callers]
      def build(repository)
        index = Hash.new { |hash, key| hash[key] = [] }
        repository.units.each do |entry|
          unit = repository.unit(entry['identifier'], type: entry['type'])
          calls_in(unit).each { |target, call| index[target] << call } if unit.is_a?(Hash)
        rescue IOError
          next
        end
        new(index.transform_values { |calls| calls.uniq.sort_by { |call| call.to_h.values.map(&:to_s) } })
      end

      private

      def calls_in(unit)
        Array(unit.dig('metadata', 'references')).filter_map do |record|
          next unless countable?(record)

          target = record.values_at('target', 'target_type')
          next if target == unit.values_at('identifier', 'type')

          [target, Call.new(caller: unit['identifier'], caller_type: unit['type'], method: record['method'],
                            line: References.file_line(unit, record['line']), confidence: record['confidence'])]
        end
      end

      def countable?(record)
        record.is_a?(Hash) && record['kind'] == 'constant' && %w[verified static].include?(record['confidence']) &&
          record['target'].is_a?(String) && record['target_type'].is_a?(String) && record['line'].is_a?(Integer)
      end
    end

    # @param index [Hash{Array(String, String) => Array<Call>}]
    def initialize(index)
      @index = index
    end

    # @param identifier [String]
    # @param type [String]
    # @return [Array<Call>] the calls into the typed unit, by caller and line
    def of(identifier, type)
      @index.fetch([identifier, type], [])
    end

    # @return [Hash{String, nil => Array<Call>}] calls grouped by the method they
    #   name; nil collects reads of the constant without a selector
    def by_method(identifier, type)
      of(identifier, type).group_by(&:method)
    end
  end
end
