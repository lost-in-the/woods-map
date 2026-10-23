# frozen_string_literal: true

RSpec.describe WoodsMap::UnitsHelper, type: :helper do
  let(:nodes) do
    { 'Report' => { 'type' => 'factory', 'file_path' => 'spec/factories/reports.rb' } }
  end
  let(:graph) do
    { 'nodes' => nodes,
      'variants' => [{ 'identifier' => 'Report', 'type' => 'model', 'file_path' => 'app/models/report.rb',
                       'source_paths' => %w[app/models/report.rb app/models/report/query.rb], 'edges' => [] }],
      'file_map' => { 'spec/factories/reports.rb' => ['Report'], 'app/models/report.rb' => ['Report'],
                      'app/models/report/query.rb' => ['Report'] } }
  end
  let(:index) do
    instance_double(Woods::PublishedIndex, index_dir: Pathname.new('/synthetic/one'),
                                           payload_dir: Pathname.new('/synthetic/one/payloads/gen-91'),
                                           generation_number: 91,
                                           manifest: { 'extracted_at' => '2026-01-01T00:00:00Z', 'total_units' => 2 })
  end
  let(:repository) { WoodsMap::Repository.new(index) }

  before do
    WoodsMap::FileTree.reset!
    allow(Woods::MCP::IndexReader).to receive(:new).and_return(instance_double(Woods::MCP::IndexReader))
    allow(repository).to receive_messages(graph: graph, search: { 'results' => [], 'complete' => true })
    allow(helper).to receive(:current_repository).and_return(repository)
  end

  it 'resolves the type belonging to each distinct file of a colliding identifier' do
    expect(repository.file_owner('app/models/report.rb')).to include('identifier' => 'Report', 'type' => 'model')
    expect(repository.file_owner('spec/factories/reports.rb')).to include('identifier' => 'Report', 'type' => 'factory')
    expect(repository.file_owner('missing.rb')).to be_nil
  end

  it 'resolves additional source files of a typed unit' do
    expect(repository.file_owner('app/models/report/query.rb')).to include('identifier' => 'Report', 'type' => 'model')
  end

  it 'keeps file lookup working without a variants section' do
    graph.delete('variants')
    expect(repository.file_owner('spec/factories/reports.rb')).to include('identifier' => 'Report', 'type' => 'factory')
    expect(repository.file_owner('app/models/report.rb')).to be_nil
  end

  it 'gives the file tree a typed link to the unit at that file' do
    rows = WoodsMap::FileTree.for(repository).rows.select { |row| row.kind == :file }
    expect(rows.to_h { |row| [row.path, row.type] })
      .to eq('app/models/report.rb' => 'model', 'app/models/report/query.rb' => 'model',
             'spec/factories/reports.rb' => 'factory')
  end

  it 'keeps cached trees separate for indexes sharing the same generation and manifest facts' do
    other_index = instance_double(Woods::PublishedIndex, index_dir: Pathname.new('/synthetic/two'),
                                                         payload_dir: Pathname.new('/synthetic/two/payloads/gen-91'),
                                                         generation_number: 91, manifest: index.manifest)
    other = WoodsMap::Repository.new(other_index)
    allow(other).to receive(:graph).and_return(graph.deep_dup)
    expect(WoodsMap::FileTree.for(repository)).not_to equal(WoodsMap::FileTree.for(other))
  end

  it 'reuses a cached tree when another reader opens the same pinned generation' do
    other = WoodsMap::Repository.new(index)
    allow(other).to receive(:graph).and_return(graph.deep_dup)
    expect(WoodsMap::FileTree.for(repository)).to equal(WoodsMap::FileTree.for(other))
  end

  it 'preserves the FileTree initializer for legacy node-only callers' do
    tree = WoodsMap::FileTree.new({ 'spec/factories/reports.rb' => ['Report'] }, nodes)
    expect(tree.rows.find { |row| row.kind == :file }.type).to eq('factory')
  end

  it 'identifies palette file results as files with the exact selected path' do
    group = WoodsMap::Palette.new(repository, 'models/report.rb').to_h['groups'].find { |item| item['name'] == 'files' }
    expect(group['items'].first).to include('file_path' => 'app/models/report.rb', 'type' => 'file')
    expect(group['items'].first).not_to have_key('identifier')
  end

  it 'identifies path search results as files without selecting a unit owner' do
    hit = WoodsMap::SearchResults.new(repository, 'models/report.rb', mode: 'path').hits.first
    expect([hit.identifier, hit.type, hit.file_path]).to eq([nil, 'file', 'app/models/report.rb'])
  end

  it 'links source lines to the secondary type at the recorded file' do
    expect(helper.code_line_link('app/models/report.rb', 12))
      .to include('href="/woods/units/model/Report#L12"')
    expect(helper.code_line_link('spec/factories/reports.rb', 3))
      .to include('href="/woods/units/factory/Report#L3"')
  end

  it 'does not link a file whose typed owner is unavailable' do
    graph.delete('variants')
    expect(helper.code_line_link('app/models/report.rb', 12)).to eq('app/models/report.rb:12')
  end
end
