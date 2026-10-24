# frozen_string_literal: true

module WoodsMap
  # The notes beside the code: what the index knows about a line that the
  # file does not say. Associations get their foreign key, callbacks their
  # place in the resolved chain and their side effects, validations their
  # count, includes their concern. Line matching is by the macro the line
  # starts with, the same reading the extractor's own analysers use.
  class Marginalia
    # area names the metadata a note reads (a key of WoodsMap::Since::KEYS), so
    # ?since= can mark notes whose metadata moved.
    Note = Struct.new(:text, :layer, :link, :area, keyword_init: true)

    ASSOCIATION = /\A\s*(belongs_to|has_many|has_one|has_and_belongs_to_many)\s+:(\w+)/
    CALLBACK = /\A\s*((?:before|after|around)_\w+)\s+:(\w+)/
    VALIDATION = /\A\s*validates?(?:_\w+)?\s+:(\w+)/
    INCLUDE = /\A\s*include\s+([A-Z]\w*(?:::\w+)*)/
    DEFINITION = /\A\s*def\s+(self\.)?(\w+)/

    # @param unit [Hash]
    # @param lifecycle [WoodsMap::Lifecycle]
    # @param table [Hash, nil] the unit's database_table unit, when one exists
    def initialize(unit, lifecycle:, table: nil)
      @unit = unit
      @metadata = unit['metadata'] || {}
      @lifecycle = lifecycle
      @table = table
      @validation_count = Array(@metadata['validations']).size
      @seen_validations = 0
    end

    # @param text [String] one source line
    # @return [Note, nil]
    def for_line(text)
      if (match = text.match(ASSOCIATION)) then association_note(match[1], match[2])
      elsif (match = text.match(CALLBACK)) then callback_note(match[1], match[2])
      elsif text.match?(VALIDATION) then validation_note
      elsif (match = text.match(INCLUDE)) then include_note(match[1])
      end
    end

    private

    def association_note(macro, name)
      assoc = Array(@metadata['associations']).find { |a| a['name'].to_s == name }
      return nil unless assoc

      text = association_text(macro, assoc)
      Note.new(text: text, layer: 'model metadata', link: assoc['target'], area: :associations)
    end

    def association_text(macro, assoc)
      table = @metadata['table_name']
      fk = assoc['foreign_key']
      case macro
      when 'belongs_to'
        enforced = foreign_key_enforced?(fk) ? 'FK' : 'no FK'
        "#{table}.#{fk} → #{assoc['target']}, #{enforced}#{dependent(assoc)}"
      when 'has_many', 'has_one'
        if assoc['through']
          "through #{assoc['through']}, join to #{assoc['target']}"
        else
          "#{assoc['target']}.#{fk} → #{table}#{dependent(assoc)}"
        end
      else
        "join table to #{assoc['target']}"
      end
    end

    def dependent(assoc)
      value = assoc.dig('options', 'dependent')
      value ? ", dependent #{value}" : ''
    end

    def foreign_key_enforced?(column)
      Array(@table&.dig('metadata', 'foreign_keys')).any? { |fk| fk['column'].to_s == column.to_s } ||
        Array(@metadata['foreign_keys']).any? { |fk| (fk['column'] || fk['from_column']).to_s == column.to_s }
    end

    def callback_note(type, filter)
      event = Lifecycle::EVENTS.find { |e| Lifecycle::ORDER[e].include?(type) && chain_position(e, filter) }
      return Note.new(text: "#{type} #{filter}", layer: 'resolved chain', area: :callbacks) unless event

      position, step = chain_position(event, filter)
      total = @lifecycle.steps(event).size
      effects = step.effects.any? ? ", #{step.effects.join(', ')}" : ''
      Note.new(text: "chain #{position} of #{total} on #{event}#{effects}", layer: 'resolved chain',
               link: step.side_effects&.dig('jobs_enqueued')&.first, area: :callbacks)
    end

    def chain_position(event, filter)
      step = @lifecycle.steps(event).find { |s| s.filter == filter }
      step && [step.n, step]
    end

    def validation_note
      @seen_validations += 1
      Note.new(text: "validation #{@seen_validations} of #{@validation_count}", layer: 'model metadata',
               area: :validations)
    end

    def include_note(name)
      inlined = Array(@metadata['inlined_concerns']).include?(name.split('::').last)
      Note.new(text: inlined ? "concern #{name}, inlined below" : "concern #{name}, not in the index",
               layer: inlined ? 'resolved ancestors' : nil, link: name, area: :concerns)
    end
  end
end
