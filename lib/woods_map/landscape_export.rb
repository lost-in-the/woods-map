# frozen_string_literal: true

module WoodsMap
  # The Landscape's container diagram as text (B8-Landscape "export"; D-25):
  # Mermaid for the panel Pele draws and for copying, Structurizr DSL and
  # LikeC4 for teams that keep their architecture in those tools. All three
  # are built from the same {Landscape}, so they say the same thing, and are
  # served as plain text beside the page. The Structurizr and LikeC4 models
  # also carry the host's people and a system context view (C4 level 1).
  class LandscapeExport
    # Format => [file extension, what the download is called].
    FORMATS = { 'mermaid' => %w[mmd Mermaid], 'structurizr' => ['dsl', 'Structurizr DSL'],
                'likec4' => %w[c4 LikeC4] }.freeze

    # The workspace's views: the system context (C4 level 1), then the containers.
    STRUCTURIZR_VIEWS = <<~DSL.chomp.gsub("\n", "\n  ").freeze
      views {
        systemContext system "Context" {
          include *
          autolayout lr
        }
        container system "Containers" {
          include *
          autolayout lr
        }
        styles {
          element "Database" {
            shape Cylinder
          }
        }
      }
    DSL

    # @param landscape [Landscape]
    # @param generation [Integer, nil]
    # @param actors [Array<Hash>] `config.landscape_actors`, the people of the context view
    def initialize(landscape, generation: nil, actors: [])
      @landscape = landscape
      @generation = generation
      @context = LandscapeContext.new(landscape, actors: actors)
    end

    # @return [String] a flowchart with the system as a subgraph (design study, "C4 in Mermaid")
    def mermaid
      lines = ['flowchart LR', %(  subgraph system["#{text("#{name} · software system")}"]), '    direction LR']
      lines += containers.map { |c| "    #{c.id}#{c.store? ? '[(' : '['}\"#{text(box(c))}\"#{c.store? ? ')]' : ']'}" }
      lines << '  end'
      lines += externals.map { |c| "  #{c.id}[[\"#{text(box(c))}\"]]" }
      lines += relationships.map { |r| "  #{r.from} -->|\"#{text("#{r.label} [#{r.mechanism}]")}\"| #{r.to}" }
      lines.join("\n")
    end

    # @return [String] a Structurizr DSL workspace with a system context and a container view
    def structurizr
      <<~DSL.chomp
        workspace "#{dsl(name)}" "Containers from a Woods index#{gen_note}" {
          model {
        #{dsl_people}
            system = softwareSystem "#{dsl(name)}" {
        #{containers.map { |c| "      #{structurizr_container(c)}" }.join("\n")}
            }
        #{externals.map { |c| structurizr_external(c) }.join("\n")}
        #{relationships.map { |r| structurizr_relationship(r) }.join("\n")}
        #{dsl_uses}
          }
          #{STRUCTURIZR_VIEWS}
        }
      DSL
    end

    # @return [String] a LikeC4 model with one view
    def likec4
      <<~C4.chomp
        specification {
          element system
          element container
          element database
          element external
          element person
        }

        model {
          app = system '#{c4(name)}' {
        #{containers.map { |c| likec4_container(c) }.join("\n")}
          }
        #{externals.map { |c| "  #{c.id} = external '#{c4(c.name)}' {\n    technology '#{c4(c.technology)}'\n  }" }.join("\n")}
        #{relationships.map { |r| likec4_relationship(r) }.join("\n")}
        #{likec4_people}
        }

        #{likec4_views}
      C4
    end

    # @param format [String] mermaid, structurizr or likec4
    # @return [String]
    def text_for(format)
      public_send(format)
    end

    # @param format [String]
    # @return [String] e.g. "blog-containers.dsl"
    def filename(format)
      "#{@landscape.system_name.parameterize.presence || 'application'}-containers.#{FORMATS.fetch(format).first}"
    end

    private

    def name = @landscape.system_name
    def people = @context.people
    def containers = @landscape.containers
    def externals = @landscape.externals
    def relationships = @landscape.relationships

    def likec4_views
      <<~C4.chomp
        views {
          view context {
            title 'Context#{gen_note}'
            include *
          }
          view containers of app {
            title 'Containers#{gen_note}'
            include *
          }
        }
      C4
    end

    def dsl_people = people.map { |p| %(    #{p.id} = person "#{dsl(p.name)}" "#{dsl(p.description)}") }.join("\n")
    def dsl_uses = people.map { |p| %(    #{p.id} -> system "#{dsl(p.uses.presence || 'uses')}") }.join("\n")

    def likec4_people
      people.map do |p|
        "  #{p.id} = person '#{c4(p.name)}' {\n    description '#{c4(p.description)}'\n  }\n  " \
          "#{p.id} -> app '#{c4(p.uses.presence || 'uses')}'"
      end.join("\n")
    end

    def structurizr_container(container)
      tags = container.store? ? ' "Database"' : ''
      %(#{container.id} = container "#{dsl(container.name)}" "#{dsl(container.description)}" ) +
        %("#{dsl(container.technology)}"#{tags})
    end

    def structurizr_external(container)
      %(    #{container.id} = softwareSystem "#{dsl(container.name)}" "#{dsl(container.technology)}" "External")
    end

    def structurizr_relationship(relationship)
      %(    #{relationship.from} -> #{relationship.to} "#{dsl(relationship.label)}" "#{dsl(relationship.mechanism)}")
    end

    def likec4_container(container)
      kind = container.store? ? 'database' : 'container'
      lines = ["    #{container.id} = #{kind} '#{c4(container.name)}' {"]
      lines << "      technology '#{c4(container.technology)}'" if container.technology
      lines += ["      description '#{c4(container.description)}'", '    }']
      lines.join("\n")
    end

    def likec4_relationship(relationship)
      "  #{ref(relationship.from)} -> #{ref(relationship.to)} '#{c4(relationship.label)}' {\n    " \
        "technology '#{c4(relationship.mechanism)}'\n  }"
    end

    def box(container)
      counts = container.counts.first(4).map { |type, n| "#{n} #{type.tr('_', ' ').pluralize(n)}" }
      ["«#{stereotype(container)}»", container.name, ("[#{container.technology}]" if container.technology),
       counts.join(', ').presence].compact.join("\n")
    end

    def stereotype(container)
      return 'container, db' if container.store?

      container.kind == 'external' ? 'external' : 'container'
    end

    def gen_note
      @generation ? ", gen #{@generation}" : ''
    end

    def ref(id)
      @landscape.externals.any? { |c| c.id == id } ? id : "app.#{id}"
    end

    # Mermaid label text: quotes and markup as entities, never live HTML.
    def text(value)
      value.to_s.gsub('"', '#quot;').gsub('<', '#lt;').gsub('>', '#gt;')
    end

    def dsl(value)
      value.to_s.tr('"', "'").gsub(/\s+/, ' ')
    end

    def c4(value)
      value.to_s.tr("'", '’').gsub(/\s+/, ' ')
    end
  end
end
