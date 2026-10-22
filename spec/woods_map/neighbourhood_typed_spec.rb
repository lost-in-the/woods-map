# frozen_string_literal: true

RSpec.describe WoodsMap::Neighbourhood do
  let(:graph) do
    {
      'nodes' => { 'Report' => { 'type' => 'factory' }, 'Target' => { 'type' => 'factory' },
                   'Caller' => { 'type' => 'service' } },
      'edges' => { 'Report' => [{ 'target' => 'Target', 'type' => 'factory', 'via' => 'code_reference' }] },
      'variants' => [
        { 'identifier' => 'Report', 'type' => 'model', 'edges' => [
          { 'target' => 'Target', 'type' => 'model', 'via' => 'code_reference' },
          { 'target' => 'Report', 'type' => 'factory', 'via' => 'code_reference' }
        ] },
        { 'identifier' => 'Target', 'type' => 'model', 'edges' => [
          { 'target' => 'Caller', 'type' => 'service', 'via' => 'code_reference' }
        ] }
      ],
      'reverse_via' => { 'Report' => [
        { 'source' => 'Caller', 'source_type' => 'service', 'type' => 'model', 'via' => 'code_reference' },
        { 'source' => 'Caller', 'source_type' => 'service', 'type' => 'factory', 'via' => 'code_reference' }
      ] }
    }
  end
  let(:repository) do
    allow(Woods::MCP::IndexReader).to receive(:new).and_return(instance_double(Woods::MCP::IndexReader))
    repo = WoodsMap::Repository.new(instance_double(Woods::PublishedIndex,
                                                    payload_dir: Pathname.new('/synthetic/index')))
    allow(repo).to receive_messages(graph: graph, graph_analysis: {})
    repo
  end

  def typed_edges(neighbourhood)
    neighbourhood.edges.map { |edge| [edge.from, edge.from_type, edge.to, edge.to_type, edge.depth] }
  end

  it 'reads the selected variant rather than the primary outgoing edges' do
    neighbourhood = described_class.new(repository, 'Report', type: 'model', direction: 'dependencies')
    expect(typed_edges(neighbourhood)).to contain_exactly(['Report', 'model', 'Target', 'model', 1],
                                                          ['Report', 'model', 'Report', 'factory', 1])
  end

  it 'keeps source and destination types throughout traversal and deduplication' do
    neighbourhood = described_class.new(repository, 'Report', type: 'model', direction: 'dependencies', depth: 2)
    expect(typed_edges(neighbourhood)).to contain_exactly(['Report', 'model', 'Target', 'model', 1],
                                                          ['Report', 'model', 'Report', 'factory', 1],
                                                          ['Target', 'model', 'Caller', 'service', 2],
                                                          ['Report', 'factory', 'Target', 'factory', 2])
  end

  it 'filters a second-hop collision edge by the newly reached endpoint type' do
    graph['variants'].first['edges'].shift
    graph['edges']['Report'].first['type'] = 'model'
    models = described_class.new(repository, 'Report', type: 'model', direction: 'dependencies', depth: 2,
                                                       filters: { types: ['model'] })
    factories = described_class.new(repository, 'Report', type: 'model', direction: 'dependencies', depth: 2,
                                                          filters: { types: ['factory'] })
    expect(typed_edges(models)).to eq([['Report', 'factory', 'Target', 'model', 2]])
    expect(typed_edges(factories)).to eq([['Report', 'model', 'Report', 'factory', 1]])
  end

  it 'filters reverse relationships by their destination type' do
    neighbourhood = described_class.new(repository, 'Report', type: 'model', direction: 'dependents')
    expect(typed_edges(neighbourhood)).to eq([['Caller', 'service', 'Report', 'model', 1]])
  end

  it 'gives coexisting types distinct Mermaid identities and identifies the typed focus' do
    neighbourhood = described_class.new(repository, 'Report', type: 'model', direction: 'dependencies', depth: 2)
    labels = neighbourhood.mermaid.scan(/(\w+)\["Report \((\w+)\)"\]/).uniq
    expect(labels.map(&:last)).to contain_exactly('model', 'factory')
    expect(labels.map(&:first).uniq.size).to eq(2)
    expect(neighbourhood).to be_focus('Report', 'model')
    expect(neighbourhood).not_to be_focus('Report', 'factory')
  end

  it 'retains primary-type traversal for older graphs without variants or typed reverse metadata' do
    graph.delete('variants')
    graph['reverse_via']['Report'] = [{ 'source' => 'Caller', 'via' => 'code_reference' }]
    neighbourhood = described_class.new(repository, 'Report')
    expect(typed_edges(neighbourhood)).to contain_exactly(['Report', 'factory', 'Target', 'factory', 1],
                                                          ['Caller', 'service', 'Report', 'factory', 1])
  end

  it 'does not borrow primary edges when the selected variant has no dependencies' do
    graph['variants'].first['edges'] = []
    neighbourhood = described_class.new(repository, 'Report', type: 'model', direction: 'dependencies')
    expect(neighbourhood.edges).to eq([])
  end
end
