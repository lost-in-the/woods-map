# frozen_string_literal: true

module WoodsMap
  # Links from a method table entry (W-2) to the line that defines it: an
  # anchor on this page for the unit's own methods, the concern's page for a
  # method an inlined concern owns, at the concern's own line.
  module MethodLinks
    extend ActiveSupport::Concern

    private

    def code_view(unit, lens, lifecycle, callers: {})
      WoodsMap::CodeView.new(unit, lens: lens, references: WoodsMap::References.new(@repository, unit),
                                   marginalia: WoodsMap::Marginalia.new(unit, lifecycle: lifecycle, table: @page.table),
                                   unit_path: lambda { |identifier, type|
                                     woods_map.unit_path(type: type, identifier: identifier)
                                   }, callers: callers)
    end

    # @param unit [Hash]
    # @return [Proc] method table entry => URL, or nil when no line is placeable
    def method_href(unit)
      lambda do |entry|
        next own_method_href(unit, entry) if entry['owner'] == unit['identifier']

        concern_method_href(entry)
      rescue IOError
        nil
      end
    end

    def own_method_href(unit, entry)
      line = entry['line'].is_a?(Integer) && WoodsMap::References.file_line(unit, entry['line'])
      "#L#{line}" if line
    end

    def concern_method_href(entry)
      concern = @repository.unit(entry['owner'].to_s, type: 'concern')
      return unless concern

      own = Array(concern.dig('metadata', 'methods')).find do |candidate|
        candidate.is_a?(Hash) && candidate.values_at('name', 'kind') == entry.values_at('name', 'kind') &&
          candidate['owner'] == concern['identifier'] && candidate['line'].is_a?(Integer)
      end
      line = own && WoodsMap::References.file_line(concern, own['line'])
      woods_map.unit_path(type: 'concern', identifier: concern['identifier'], anchor: "L#{line}") if line
    end
  end
end
