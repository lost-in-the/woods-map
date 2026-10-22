# frozen_string_literal: true

RSpec.describe WoodsMap::Repository do
  let(:index) do
    instance_double(Woods::PublishedIndex, index_dir: Pathname.new('/synthetic/ownership'),
                                           payload_dir: Pathname.new('/synthetic/ownership/payloads/gen-1'),
                                           generation_number: 1, manifest: { 'total_units' => 6 })
  end
  let(:repository) { described_class.new(index) }
  let(:graph) do
    { 'nodes' => { 'Report' => { 'type' => 'model', 'file_path' => 'app/report.rb',
                                 'source_paths' => %w[app/report.rb app/report/query.rb] },
                   'Helper' => { 'type' => 'service', 'file_path' => 'app/report.rb' },
                   'Profile' => { 'type' => 'ruby_file', 'kind' => 'file_profile', 'file_path' => 'app/report.rb' },
                   'Elsewhere' => { 'type' => 'factory', 'file_path' => 'spec/report.rb' },
                   'Untyped' => { 'file_path' => 'app/report.rb' } },
      'variants' => [{ 'identifier' => 'Report', 'type' => 'factory', 'file_path' => 'spec/report.rb' },
                     { 'identifier' => 'Report', 'type' => 'service', 'file_path' => 'app/report.rb' },
                     { 'identifier' => 'Report', 'type' => 'model', 'file_path' => 'app/report.rb' }],
      'file_map' => { 'app/report.rb' => %w[Report Helper Report Profile Missing Elsewhere Untyped],
                      'app/report/query.rb' => ['Report'], 'spec/report.rb' => %w[Report Elsewhere] } }
  end

  before do
    allow(Woods::MCP::IndexReader).to receive(:new).and_return(instance_double(Woods::MCP::IndexReader))
    allow(repository).to receive(:graph).and_return(graph)
  end

  it 'preserves collisions in one file and deduplicates repeated typed membership' do
    expect(repository.file_owners('app/report.rb').map { |owner| owner.values_at('identifier', 'type') })
      .to eq([%w[Helper service], %w[Profile ruby_file], %w[Report model], %w[Report service]])
  end

  it 'selects the actual owner of each file and additional published source path' do
    expect(repository.file_owners('spec/report.rb').pluck('type')).to eq(%w[factory factory])
    expect(repository.file_owners('app/report/query.rb')).to contain_exactly(
      include('identifier' => 'Report', 'type' => 'model')
    )
  end

  it 'preserves file profiles without making their type a model' do
    expect(repository.file_owners('app/report.rb')).to include(
      include('identifier' => 'Profile', 'type' => 'ruby_file', 'kind' => 'file_profile')
    )
  end

  it 'makes unknown, misplaced and untyped membership explicit' do
    expect(repository.unresolved_file_identifiers('app/report.rb')).to eq(%w[Elsewhere Missing Untyped])
    expect(repository.file_owners('unindexed.rb')).to eq([])
    expect(repository.unresolved_file_identifiers('unindexed.rb')).to eq([])
  end

  it 'does not invent additional owners on old graphs without variants or source paths' do
    graph.delete('variants')
    graph['nodes']['Report'].delete('source_paths')
    expect(repository.file_owners('app/report/query.rb')).to eq([])
    expect(repository.unresolved_file_identifiers('app/report/query.rb')).to eq(['Report'])
    expect(repository.file_owners('app/report.rb').pluck('type')).to eq(%w[service ruby_file model])
  end

  it 'requires file-map membership even when a node records the path' do
    graph['file_map'].delete('app/report.rb')
    expect(repository.file_owners('app/report.rb')).to eq([])
    expect(repository.file_owner('app/report.rb')).to be_nil
  end

  it 'includes matching owners even when the file-map membership is incomplete' do
    graph['file_map']['app/report.rb'] = ['Report']
    expect(repository.file_owners('app/report.rb').pluck('identifier')).to eq(%w[Helper Profile Report Report])
  end

  it 'enumerates graph ownership once across different file lookups' do
    allow(repository).to receive(:nodes_by_identifier).and_call_original
    paths = %w[app/report.rb app/report/query.rb spec/report.rb]
    expect(paths.map { |path| repository.file_owners(path).size }).to eq([4, 1, 2])
    expect(repository).to have_received(:nodes_by_identifier).once
  end

  describe 'tree scope counts' do
    before { WoodsMap::FileTree.reset! }

    it 'counts distinct typed owners in each directory scope and across contributor paths' do
      tree = WoodsMap::FileTree.for(repository)
      counts = tree.rows.select { |row| row.kind == :dir }.to_h { |row| [row.path, row.count] }
      expect(counts).to eq('app' => 4, 'app/report' => 1, 'spec' => 2)
      expect(tree.unit_count).to eq(6)
      expect(tree.rows.find { |row| row.path == 'app/report.rb' }.units).to eq(4)
      expect(tree.rows.find { |row| row.path == 'app/report.rb' }.unresolved).to eq(3)
    end

    it 'keeps generations isolated even when a generation shares its index root' do
      tree = WoodsMap::FileTree.for(repository)
      other_index = instance_double(Woods::PublishedIndex, index_dir: index.index_dir,
                                                           payload_dir: Pathname.new('/synthetic/ownership/gen-2'),
                                                           generation_number: 2, manifest: index.manifest)
      other = described_class.new(other_index)
      allow(other).to receive(:graph).and_return('nodes' => {}, 'file_map' => {})
      expect(WoodsMap::FileTree.for(other).unit_count).to eq(0)
      expect(WoodsMap::FileTree.for(other)).not_to equal(tree)
      expect(tree.unit_count).to eq(6)
    end
  end

  describe 'file result identities' do
    before { allow(repository).to receive(:search).and_return('results' => [], 'complete' => true) }

    it 'preserves selected contributor paths in path search' do
      hit = WoodsMap::SearchResults.new(repository, 'query.rb', mode: 'path').hits.first
      expect([hit.type, hit.identifier, hit.file_path, hit.hits]).to eq(['file', nil, 'app/report/query.rb', 1])
    end

    it 'marks unresolved palette file membership without substituting a first owner' do
      result = WoodsMap::Palette.new(repository, 'app/report.rb').to_h
      item = result['groups'].find { |group| group['name'] == 'files' }['items'].first
      expect(item).to include('type' => 'file', 'file_path' => 'app/report.rb',
                              'detail' => 'file, 4 units, 3 unresolved')
      expect(item).not_to have_key('identifier')
    end

    it 'reports a capped path result as partial' do
      51.times { |number| graph['file_map']["app/other#{number}.rb"] = [] }
      results = WoodsMap::SearchResults.new(repository, 'other', mode: 'path')
      expect(results.hits.size).to eq(50)
      expect(results.complete?).to be(false)
    end
  end

  describe 'permitted exact keys' do
    invalid = ['', '/app/report.rb', 'C:/app/report.rb', 'C:app/report.rb', 'app\\report.rb',
               "app/\x00report.rb", "app/\nreport.rb", "app/\x7freport.rb", "app/\u0085report.rb", 'app/./report.rb',
               'app/../report.rb', '../report.rb', 'app//report.rb', 'app/report.rb/']

    invalid.each do |path|
      it "rejects #{path.inspect} without normalizing it" do
        graph['file_map'][path] = ['Report']
        expect(repository.permitted_file_path?(path)).to be(false)
        expect(repository.file_map).not_to have_key(path)
        expect(repository.file_owners(path)).to eq([])
      end
    end

    it 'preserves spaces, Unicode, extensions and literal percent text exactly' do
      paths = ['app/été report.html.erb', 'app/%2e%2e/report.rb', 'app/report%20one.rb']
      paths.each { |path| graph['file_map'][path] = [] }
      expect(paths.map { |path| repository.permitted_file_path?(path) }).to eq([true, true, true])
      expect(repository.file_map.keys).to include(*paths)
    end
  end
end
