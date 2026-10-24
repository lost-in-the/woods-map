# frozen_string_literal: true

module WoodsMap
  # The keys one params method permits, set against what the published model
  # unit names (B-18): its columns, associations, attachments, rich-text fields
  # and the writers its class body defines. A match names the fact that proves
  # it. A key that matches none is unverified, never flagged: the index does
  # not publish every writer a model accepts (+has_secure_password+, the
  # attribute API, nested attributes, module writers), so absence proves
  # nothing until it does (woods#797).
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

    # @return [Array<Key>] the keys no published model fact matches
    def unverified
      keys.reject(&:matched?)
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
      @facts_by_name ||= begin
        named = [['column', Array(metadata['column_names']).map(&:to_s)],
                 ['association', associations.map { |a| a['name'].to_s }],
                 ['association ids', collection_ids], ['attachment', attachments],
                 ['rich text', Array(metadata['action_text_fields']).map(&:to_s)],
                 ['writer', writers]]
        named.reverse.each_with_object({}) { |(via, names), map| names.each { |name| map[name] = via } }
      end
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
