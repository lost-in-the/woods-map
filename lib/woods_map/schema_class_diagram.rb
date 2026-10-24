# frozen_string_literal: true

module WoodsMap
  # The Schema tab's class diagram (M3, woods-map#5): the model as a class
  # with its columns, scopes and own instance methods, its parent class, the
  # concerns it includes and one hop of associations, all from the model's
  # published metadata. Framework class methods are left out.
  class SchemaClassDiagram
    # Members listed per section before a count of the rest.
    MEMBERS = 14
    # Classes drawn before the panel names the budget instead (R-4), the ER's budget.
    CLASS_BUDGET = 40

    # @param unit [Hash] a model unit
    def initialize(unit)
      @unit = unit
      @metadata = unit['metadata'] || {}
    end

    # @return [String] Mermaid classDiagram text
    def mermaid
      lines = ['classDiagram', *class_block]
      lines << "  #{id(parent)} <|-- #{id(name)}" if parent
      concerns.each do |concern|
        lines << "  class #{id(concern)}#{label(concern)} {\n    <<module>>\n  }"
        lines << "  #{id(name)} ..|> #{id(concern)} : include"
      end
      associations.each { |a| lines.concat(association_lines(a)) }
      lines.join("\n")
    end

    # @return [Integer] classes drawn, the model included
    def class_count
      ([name, parent] + concerns + associations.map { |a| a['target'].to_s }).compact.uniq.size
    end

    # @return [String, nil] why the diagram is not drawn, nil within the budget
    def refusal
      "#{class_count} classes is over the class diagram budget of #{CLASS_BUDGET}" if class_count > CLASS_BUDGET
    end

    private

    def name = @unit['identifier'].to_s
    def parent = @metadata['parent_class'].presence
    def concerns = Array(@metadata['inlined_concerns']).map(&:to_s)
    def associations = Array(@metadata['associations']).reject { |a| a['through'] }

    def class_block
      members = columns + scopes + own_methods
      ["  class #{id(name)}#{label(name)} {", *members.map { |m| "    #{m}" }, '  }']
    end

    def columns
      list = Array(@metadata['columns']).map { |c| "+#{word(type_of(c))} #{word(c['name'])}" }
      capped(list, 'columns')
    end

    def scopes
      capped(Array(@metadata['scopes']).map { |s| "+#{word(s['name'])}()$" }, 'scopes')
    end

    def own_methods
      capped(Array(@metadata['instance_methods']).map { |m| "+#{word(m)}()" }, 'methods')
    end

    # A column type without its precision: `datetime(6)` reads as a method to Mermaid.
    def type_of(column)
      (column['type'] || column['sql_type']).to_s.sub(/\(.*\)/, '')
    end

    def capped(list, what)
      return list if list.size <= MEMBERS

      list.first(MEMBERS) + ["+#{list.size - MEMBERS} more #{what}"]
    end

    def association_lines(assoc)
      target = assoc['target'].to_s
      many = %w[has_many has_and_belongs_to_many].include?(assoc['type'].to_s)
      ["  class #{id(target)}#{label(target)}",
       %(  #{id(name)} --> "#{many ? '*' : '1'}" #{id(target)} : #{word(assoc['type'])} #{word(assoc['name'])})]
    end

    # A Mermaid class id: letters, digits and underscores.
    def id(value)
      value.to_s.gsub(/[^A-Za-z0-9_]/, '_')
    end

    # The class's own name as its label when the id had to change it.
    def label(value)
      id(value) == value.to_s ? '' : %(["#{value.to_s.tr('"', "'")}"])
    end

    # A member word: no braces, quotes or newlines, which would end the block.
    def word(value)
      value.to_s.gsub(/[{}"\n<>]/, ' ').squeeze(' ').strip.presence || '?'
    end
  end
end
