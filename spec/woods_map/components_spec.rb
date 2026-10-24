# frozen_string_literal: true

RSpec.describe WoodsMap::Components do
  def components(index, group: nil)
    WoodsMap::Repository.open(index) do |repository|
      c = described_class.new(repository, group: group)
      c.components
      c.relationships
      c
    end
  end

  context 'with Packwerk packages' do
    let(:c) { components(WoodsMap::PackageIndex.path) }

    it 'groups by package by default, with each package declared dependencies' do
      expect(c).to have_attributes(group: 'package', packages?: true, limit: nil)
      expect(c.components.map(&:name)).to eq(['.', 'packs/posts'])
      expect(c.components.find { |x| x.name == 'packs/posts' })
        .to have_attributes(members: [%w[Micropost model], %w[MicropostsController controller]], declared: ['.'],
                            types: { 'controller' => 1, 'model' => 1 })
    end

    it 'counts the edges between packages and marks the ones no package.yml declares' do
      into_posts = c.relationships.find { |r| r.from == '.' && r.to == 'packs/posts' }
      expect(into_posts.undeclared).to be(true)
      expect(into_posts.vias).to include('has_many')
      out_of_posts = c.relationships.find { |r| r.from == 'packs/posts' && r.to == '.' }
      expect(out_of_posts.undeclared).to be(false)
      expect(out_of_posts.vias).to include('belongs_to')
    end

    it 'draws the packages as a flowchart within the budget' do
      expect(c.mermaid).to start_with('flowchart LR').and include('packs/posts · 2 units').and include('undeclared')
      expect(c.refusal).to be_nil
      stub_const('WoodsMap::Components::BUDGET', 1)
      expect(c.refusal).to include('over the diagram budget of 1')
    end
  end

  context 'without packages' do
    it 'groups by namespace by default and names the package limit when asked for packages' do
      plain = components(WoodsMap::LandscapeIndex.path)
      expect(plain.group).to eq('namespace')
      expect(plain.components.map(&:name)).to include('(top level)')
      by_package = components(WoodsMap::LandscapeIndex.path, group: 'package')
      expect(by_package.limit).to eq(:no_packages)
      expect(by_package.components).to be_empty
    end

    it 'groups by the published domain clusters, the rest in no cluster' do
      c = components(WoodsMap::LandscapeIndex.path, group: 'cluster')
      expect(c.components.map(&:name)).to eq(['Users', '(no cluster)'])
      expect(c.components.first.members).to eq([%w[User model], %w[UsersController controller]])
      expect(c.relationships).not_to be_empty
    end

    it 'names the cluster limit for a generation that publishes none' do
      expect(components(FIXTURE_INDEX, group: 'cluster').limit).to eq(:no_clusters)
    end

    it 'leaves out framework units and bookkeeping' do
      c = components(WoodsMap::LandscapeIndex.path)
      types = c.components.flat_map { |x| x.members.map(&:last) }.uniq
      expect(types).not_to include('route', 'migration', 'database_table', 'configuration')
    end
  end
end
