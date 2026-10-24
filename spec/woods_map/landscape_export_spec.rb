# frozen_string_literal: true

RSpec.describe WoodsMap::LandscapeExport do
  def export(&block)
    WoodsMap::Repository.open(WoodsMap::LandscapeIndex.path) do |repository|
      block.call(described_class.new(WoodsMap::Landscape.new(repository, system_name: 'Blog "main"'), generation: 1))
    end
  end

  it 'draws the containers as a Mermaid flowchart with the system as a subgraph' do
    export do |e|
      expect(e.mermaid).to start_with("flowchart LR\n  subgraph system[\"Blog #quot;main#quot; · software system\"]")
      expect(e.mermaid).to include('db_primary[("', 'mail[["', 'web -->|"reads, writes [Active Record]"| db_primary')
    end
  end

  it 'writes a Structurizr DSL workspace with one container view' do
    export do |e|
      expect(e.structurizr).to start_with(%(workspace "Blog 'main'" "Containers from a Woods index, gen 1" {))
      expect(e.structurizr).to include(
        %(db_primary = container "Primary database" "tables and the models over them" "postgresql" "Database"),
        %(web -> db_primary "reads, writes" "Active Record"), 'container system "Containers" {'
      )
    end
  end

  it 'writes a LikeC4 model whose relationships name nested containers by path' do
    export do |e|
      expect(e.likec4).to include("app = system 'Blog \"main\"' {", "app.web -> app.db_primary 'reads, writes' {",
                                  "app.jobs -> mail 'delivers' {", 'view containers of app {')
      expect(e.filename('likec4')).to eq('blog-main-containers.c4')
    end
  end
end
