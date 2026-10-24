# frozen_string_literal: true

module WoodsMap
  # The Landscape's Context tab (C4 level 1, B8-Landscape): the people who use
  # the system, the system itself, and the external systems around it.
  #
  # People are not in the index; the host names them (`config.landscape_actors`).
  # External systems are what the index publishes: mail delivery and object
  # storage from the BehavioralProfile unit, and each declared external
  # consumer of the application's tables. The runtime gems of the Gemfile unit
  # are counted, but which of them call another system is not published, so
  # none becomes a box.
  class LandscapeContext
    # One person, as the host declared them.
    Person = Struct.new(:id, :name, :description, :uses, keyword_init: true)

    # One arrow on the context diagram, with where it comes from.
    Link = Struct.new(:from, :to, :label, :source, keyword_init: true)

    # Gemfile groups whose gems run with the application.
    RUNTIME_GROUPS = %w[default production].freeze

    # @param landscape [Landscape]
    # @param actors [Array<Hash>] `config.landscape_actors`: name, description, uses
    def initialize(landscape, actors: [])
      @landscape = landscape
      @actors = Array(actors)
    end

    # @return [Array<Person>]
    def people
      @people ||= @actors.each_with_index.map do |actor, index|
        Person.new(id: "person_#{index}", name: value(actor, :name).presence || "Person #{index + 1}",
                   description: value(actor, :description), uses: value(actor, :uses))
      end
    end

    # @return [Array<Landscape::Container>] mail delivery, object storage, external consumers
    delegate :externals, to: :@landscape

    # @return [String]
    delegate :system_name, to: :@landscape

    # @return [Array<Link>] people to the system, the system to and from each external system
    def links
      @links ||= people.map do |p|
        Link.new(from: p.id, to: 'system', label: p.uses.presence || 'uses', source: 'host')
      end +
                 externals.map { |external| external_link(external) }
    end

    # @return [Array<Hash>] the Gemfile unit's runtime gems: name and requirement
    def runtime_gems
      @runtime_gems ||= Array(gemfile.dig('metadata', 'gems')).select do |gem|
        (Array(gem['groups']).map(&:to_s) & RUNTIME_GROUPS).any?
      end
    end

    # @return [Boolean] whether the generation publishes a Gemfile unit
    def gemfile?
      gemfile.any?
    end

    # Mermaid flowchart of the context (C4 level 1).
    #
    # @return [String]
    def mermaid
      lines = ['flowchart LR']
      lines += people.map { |p| %(  #{p.id}(["#{text("«person»\n#{p.name}")}"])) }
      lines << %(  system["#{text("«software system»\n#{system_name}#{"\n#{@landscape.rails}" if @landscape.rails}")}"])
      lines += externals.map { |e| %(  #{e.id}[["#{text("«external»\n#{e.name}\n[#{e.technology}]")}"]]) }
      lines += links.map { |link| %(  #{link.from} -->|"#{text(link.label)}"| #{link.to}) }
      lines.join("\n")
    end

    private

    def external_link(external)
      case external.id
      when 'mail' then Link.new(from: 'system', to: 'mail', label: 'sends mail', source: 'BehavioralProfile')
      when 'storage' then Link.new(from: 'system', to: 'storage', label: 'stores uploads', source: 'BehavioralProfile')
      else Link.new(from: external.id, to: 'system', label: 'reads shared tables', source: 'declared consumer')
      end
    end

    def gemfile
      @gemfile ||= @landscape.configuration_unit('Gemfile', 'gemfile')
    end

    def value(actor, key)
      (actor[key] || actor[key.to_s]).to_s
    end

    # Mermaid label text: quotes and markup as entities, never live HTML.
    def text(value)
      value.to_s.gsub('"', '#quot;').gsub('<', '#lt;').gsub('>', '#gt;')
    end
  end
end
