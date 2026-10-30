# frozen_string_literal: true

module WoodsMap
  # Who wrote a model callback, a controller filter or a mailer callback, as
  # Woods publishes it beside `analysis_status` (woods#936): `app` (under
  # `Rails.root`, a concern under `app/` included), `framework` (a Rails
  # gem), `gem` (any other bundled gem or the standard library) or
  # `unknown` (no source: a native method, a string filter). Readers
  # feature-detect it: a record set where any record lacks it is read as an
  # older generation and keeps the map's inference.
  module CallbackOrigin
    # The published values, in the order the limits name them.
    ORIGINS = %w[framework gem app unknown].freeze

    # A proc's label, `#<Proc app/controllers/x.rb:7>` or
    # `#<lambda devise-4.9.4/lib/...:12>`: never listed, whoever wrote it.
    PROC = /\A#</

    module_function

    # @param records [Array<Hash>] callback or filter records
    # @return [Boolean] whether there are records and every one carries a published origin
    def published?(records)
      records.any? && records.all? { |record| ORIGINS.include?(record['origin']) }
    end

    # @param records [Array<Hash>] callback or filter records that carry an origin
    # @return [Hash{String => Array<Hash>}] origin => records, in {ORIGINS} order, empty origins left out
    def group(records)
      groups = records.group_by { |record| record['origin'] }
      ORIGINS.filter_map { |origin| [origin, groups[origin]] if groups[origin] }.to_h
    end

    # Whether a listing of filters hides a record: with a published origin,
    # the framework's and every proc (an `unknown` one by name); without it,
    # by name alone.
    #
    # @param record [Hash] a filter or callback record
    # @param published [Boolean] whether the record set carries origin ({.published?})
    # @param by_name [Regexp] the names recognised as the framework's without origin
    # @return [Boolean]
    def hidden?(record, published:, by_name:)
      name = record['filter'].to_s
      return name.match?(by_name) unless published

      case record['origin']
      when 'framework' then true
      when 'unknown' then name.match?(by_name)
      else name.match?(PROC)
      end
    end
  end
end
