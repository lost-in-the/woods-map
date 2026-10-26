# frozen_string_literal: true

module WoodsMap
  # Type-specific rows from the selected unit's published metadata only.
  # Missing facts stay unknown; an explicitly empty list is not an absent list.
  class UnitFacts
    FIELDS = {
      'job' => ['Job', [
        ['kind', 'job_type'], ['queue', 'queue'], ['perform params', 'perform_params', :parameters],
        ['scheduled', 'scheduled'], ['retry on', 'retry_on', :list], ['discard on', 'discard_on', :list],
        ['enqueues', 'enqueues_jobs', :list]
      ]],
      'mailer' => ['Mailer', [
        ['actions', 'actions', :list], %w[delivery delivery_method], %w[layout layout],
        ['templates', 'templates', :templates], ['helpers', 'helpers', :list], ['callbacks', 'callbacks', :count]
      ]],
      'view_template' => ['Template', [
        ['engine', 'template_engine'], ['partial', 'is_partial'], ['ivar mentions', 'instance_variables', :list],
        ['helpers', 'helpers_called', :list], ['partials', 'partials_rendered', :list]
      ]],
      'concern' => ['Concern', [
        ['kind', 'concern_type'], ['scope', 'concern_scope'], ['ActiveSupport', 'uses_active_support'],
        ['instance methods', 'instance_methods', :list], ['class methods', 'class_methods', :list],
        ['callbacks', 'callbacks_defined', :count], ['scopes', 'scopes_defined', :count]
      ]],
      'serializer' => ['Serializer', [
        %w[kind serializer_type], %w[model wrapped_model], ['attributes', 'attributes', :list],
        ['associations', 'associations', :count], ['views', 'views', :list], ['methods', 'custom_methods', :list]
      ]],
      'database_table' => ['Table', [
        ['name', 'table_name'], ['database', 'database'], ['primary key', 'primary_key', :primary_key],
        ['columns', 'column_count'], ['indexes', 'indexes', :count], ['foreign keys', 'foreign_keys', :count],
        ['models', 'models', :list]
      ]]
    }.freeze

    # @param unit [Hash] a typed unit from the pinned generation
    def initialize(unit)
      @type = unit['type']
      @metadata = unit['metadata'] || {}
    end

    # @param parameter [Hash] a published parameter record (name, splat, has_default)
    # @return [String] its name, a splat prefix and an optional marker, never a default value
    def self.parameter_label(parameter)
      prefix = { 'single' => '*', 'double' => '**' }[parameter['splat']]
      "#{prefix}#{parameter['name']}#{' (optional)' if parameter['has_default']}"
    end

    # @return [Hash, nil] a facts tile, or nil for types with existing generic tiles
    def tile
      title, fields = FIELDS[@type]
      return nil unless fields

      rows = fields.map { |label, key, format| [label, value(@metadata[key], format)] }
      { eyebrow: title, rows: rows + [['source', { layer: 'published unit metadata' }]] }
    end

    private

    def value(raw, format)
      return 'not recorded' if raw.nil?

      case format
      when :list then list(raw)
      when :count then raw.is_a?(Array) ? raw.size.to_s : 'not recorded'
      when :templates then template_count(raw)
      when :parameters then parameters(raw)
      when :primary_key then raw.is_a?(Array) ? list(raw) : scalar(raw)
      else scalar(raw)
      end
    end

    def list(raw)
      return 'not recorded' unless raw.is_a?(Array) && raw.all? { |v| v.is_a?(String) || v.is_a?(Numeric) }

      raw.empty? ? 'none recorded' : raw.join(', ')
    end

    def parameters(raw)
      return 'not recorded' unless raw.is_a?(Array) && raw.all? { |v| v.is_a?(Hash) && v['name'].is_a?(String) }
      return 'none recorded' if raw.empty?

      raw.map { |parameter| self.class.parameter_label(parameter) }.join(', ')
    end

    def template_count(raw)
      return 'not recorded' unless raw.is_a?(Hash) && raw.values.all?(Array)

      raw.values.sum(&:size).to_s
    end

    def scalar(raw)
      case raw
      when true then 'yes'
      when false then 'no'
      when String, Numeric then raw.to_s.presence || 'not recorded'
      else 'not recorded'
      end
    end
  end
end
