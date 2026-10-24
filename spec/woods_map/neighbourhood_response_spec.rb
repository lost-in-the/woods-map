# frozen_string_literal: true

RSpec.describe WoodsMap::NeighbourhoodResponse do
  let(:graph) do
    { 'nodes' => { 'Focus' => { 'type' => 'model' }, 'Shared' => { 'type' => 'model', 'package' => 'billing' },
                   'Other' => { 'type' => 'job', 'package' => 'other' } },
      'variants' => [{ 'identifier' => 'Shared', 'type' => 'job', 'package' => 'billing', 'edges' => [] }],
      'edges' => { 'Focus' => [
        { 'target' => 'Shared', 'type' => 'model', 'via' => 'has_many', 'through' => 'links',
          'cross_database' => true },
        { 'target' => 'Shared', 'type' => 'job', 'via' => 'enqueues' },
        { 'target' => 'Other', 'type' => 'job', 'via' => 'enqueues' }
      ] }, 'pagerank' => { 'Shared' => 0.25 } }
  end
  let(:repository) do
    allow(Woods::MCP::IndexReader).to receive(:new).and_return(instance_double(Woods::MCP::IndexReader))
    repo = WoodsMap::Repository.new(synthetic_published_index)
    allow(repo).to receive_messages(graph: graph, graph_analysis: {}, generation_facts: { 'generation' => 'pinned' })
    repo
  end

  def response(**options)
    query = WoodsMap::NeighbourhoodQuery.new({ 'centre' => 'Focus', 'type' => 'model' }.merge(options.stringify_keys))
    described_class.new(repository, query).to_h
  end

  it 'keeps typed collisions distinct with stable IDs and published edge attributes' do
    elements = response['elements']
    expect(elements['nodes'].pluck('data').pluck('id').uniq.size).to eq(4)
    expect(elements['edges'].first['data']).to include('through' => 'links', 'cross_database' => true)
    expect(response['elements']).to eq(elements)
  end

  it 'caps edges independently and identifies retained boundary nodes' do
    json = response(edge_limit: 1)
    ids = json['elements']['nodes'].pluck('data').pluck('id')
    expect(json['elements']['edges'].size).to eq(1)
    expect(json['elements']['edges']).to all(satisfy { |e| (e['data'].values_at('source', 'target') - ids).empty? })
    expect(json['truncation']).to include('total_nodes' => 4, 'total_edges' => 3, 'omitted_nodes' => 2,
                                          'omitted_edges' => 2)
    expect(json['truncation']['boundaries']).to contain_exactly(hash_including('hidden_nodes' => 2,
                                                                               'hidden_edges' => 2))
  end

  it 'keeps the typed focus while filtering by explicitly published packages' do
    json = response(package: 'billing')
    expect(json['elements']['nodes'].pluck('data').pluck('identifier')).to eq(%w[Focus Shared Shared])
    expect(json['truncation']).to include('total_edges' => 2, 'truncated' => false)
    expect(response(package: 'missing')['elements']['nodes'].size).to eq(1)
  end

  it 'leaves missing analysis unknown and labels identifier-scoped evidence' do
    json = response
    expect(json['elements']['nodes'].first['data']).to include('hub' => nil, 'cycle' => nil, 'package' => nil)
    expect(json['elements']['nodes'][1]['data']).to include('pagerank' => 0.25)
    expect(json['provenance']).to include('generation' => 'pinned', 'analysis_scope' => 'identifier')
  end

  it 'bounds a large published neighbourhood without dangling links' do
    graph['edges']['Focus'] = Array.new(1200) { |i| { 'target' => "N#{i}", 'type' => 'model', 'via' => 'has_many' } }
    json = response
    expect(json['elements']['nodes'].size).to eq(300)
    expect(json['elements']['edges'].size).to eq(299)
    expect(json['truncation']).to include('total_nodes' => 1201, 'omitted_nodes' => 901, 'omitted_edges' => 901)
  end
end
