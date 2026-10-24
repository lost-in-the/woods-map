# frozen_string_literal: true

module WoodsMap
  # The keys one params method permits, set against what the published model
  # unit names (B-18): its columns, associations, attachments, rich-text fields
  # and writers. A match names the fact that proves it. When the model publishes
  # +attribute_writers+ (woods#797), every writer it accepts, a key that matches
  # none is a mismatch, raised as an advisory flag. An older index publishes
  # only the class body's writers, so there an unmatched key stays unverified:
  # +has_secure_password+, the attribute API, nested attributes and module
  # writers are not in it, and absence proves nothing.
  class PermittedAttributes
    # One permitted key and the model fact that matches it, nil when none does.
    Key = Struct.new(:name, :via, keyword_init: true) do
      # @return [Boolean]
      def matched?
        !via.nil?
      end
    end

    # The Woods issue that would let an unmatched key become a flag.
    WRITERS_ITEM = 'woods#797'
    # Associations whose collection writer is +<singular>_ids=+.
    COLLECTIONS = %w[has_many has_and_belongs_to_many].freeze

    # @param repository [WoodsMap::Repository]
    # @param entry [Hash] +method+, +model+ (the require key) and +permitted+ keys, as Passage#permitted gives them
    def initialize(repository, entry)
      @repository = repository
      @entry = entry
    end

    # @return [String] the params method, e.g. +user_params+
    def method_name
      @entry['method'].to_s
    end

    # @return [String] the model the require key names, e.g. +User+ for +user+
    def model_name
      @entry['model'].to_s.camelize
    end

    # @return [Hash, nil] the model unit, nil when the index holds no model by that name
    def model
      return @model if defined?(@model)

      @model = @repository.unit(model_name, type: 'model')
    end

    # @return [Array<Key>] every permitted key with its match, in declared order
    def keys
      @keys ||= Array(@entry['permitted']).map(&:to_s).map { |key| Key.new(name: key, via: model && match(key)) }
    end

    # @return [Boolean] whether the model publishes every attribute writer it accepts (woods#797)
    def writers_published?
      !model.nil? && metadata['attribute_writers'].is_a?(Array)
    end

    # @return [Array<Key>] keys no published fact matches, on a model whose writers are all published
    def mismatches
      writers_published? ? keys.reject(&:matched?) : []
    end

    # @return [Array<Key>] keys no published fact matches, on a model without the full writer list
    def unverified
      writers_published? ? [] : keys.reject(&:matched?)
    end

    # @return [Hash{String => Array<String>}] matched key names grouped by the fact that matches them
    def matched_by_fact
      keys.select(&:matched?).group_by(&:via).transform_values { |list| list.map(&:name) }
    end

    private

    def metadata
      model['metadata'] || {}
    end

    # The first fact that names the key wins, in this order.
    def match(key)
      facts_by_name[key]
    end

    def facts_by_name
      @facts_by_name ||= named_facts.reverse.each_with_object({}) do |(via, names), map|
        names.each { |name| map[name] = via }
      end
    end

    def named_facts
      [['column', strings('column_names')], ['association', associations.map { |a| a['name'].to_s }],
       ['association ids', collection_ids], ['attachment', attachments], ['rich text', strings('action_text_fields')],
       ['writer', writers], ['attribute writer', strings('attribute_writers')]]
    end

    def strings(key)
      Array(metadata[key]).map(&:to_s)
    end

    def writers
      Array(metadata['instance_methods']).map(&:to_s).select { |m| m.end_with?('=') }.map { |m| m.delete_suffix('=') }
    end

    def associations
      Array(metadata['associations']).grep(Hash)
    end

    def collection_ids
      associations.select { |a| COLLECTIONS.include?(a['type'].to_s) }.map { |a| "#{a['name'].to_s.singularize}_ids" }
    end

    def attachments
      Array(metadata['active_storage_attachments']).map { |a| (a.is_a?(Hash) ? a['name'] : a).to_s }
    end
  end
end
