# frozen_string_literal: true

RSpec.describe WoodsMap::Repository do
  it 'opens the published generation and reports its status' do
    status = described_class.open(FIXTURE_INDEX, &:status)
    expect(status['generation']).to eq(1)
    expect(status['total_units']).to eq(21)
    expect(status['git_branch']).to eq('main')
  end

  it 'reads units through the pinned generation' do
    identifiers = described_class.open(FIXTURE_INDEX) { |repo| repo.units(type: 'model').map { |u| u['identifier'] } }
    expect(identifiers).to contain_exactly('User', 'Micropost', 'Relationship')
  end

  it 'raises Unavailable for a missing index' do
    expect { described_class.open('/nonexistent/woods') { |_| nil } }.to raise_error(described_class::Unavailable)
  end

  describe 'typed graph lookup' do
    let(:primary) { { 'type' => 'factory', 'file_path' => 'spec/factories/reports.rb' } }
    let(:variant) do
      { 'identifier' => 'Report', 'type' => 'model', 'file_path' => 'app/models/report.rb', 'edges' => [] }
    end
    let(:graph) { { 'nodes' => { 'Report' => primary }, 'variants' => [variant] } }
    let(:reader) { instance_double(Woods::MCP::IndexReader) }
    let(:repository) do
      described_class.new(synthetic_published_index)
    end

    before do
      allow(Woods::MCP::IndexReader).to receive(:new).and_return(reader)
      allow(repository).to receive(:graph).and_return(graph)
    end

    it 'finds every type from the primary node and the published flat variants array' do
      expect(repository.identifier_types('Report')).to eq(%w[factory model])
    end

    it 'retains primary-node precedence for consumers that choose the first type' do
      primary['type'] = 'service'
      expect(repository.identifier_types('Report')).to eq(%w[service model])
    end

    it 'leaves an unknown constant unresolved when the graph contains variants' do
      expect(repository.identifier_types('Missing')).to eq([])
      expect(repository.graph_node('Missing')).to be_nil
    end

    it 'selects the matching typed node without falling back to a different type' do
      expect(repository.graph_node('Report', type: 'model')).to eq(variant)
      expect(repository.graph_node('Report', type: 'controller')).to be_nil
      expect(repository.graph_node('Report')).to eq(primary)
    end

    it 'retains compatibility with graphs that have no variants section' do
      graph.delete('variants')
      expect(repository.identifier_types('Report')).to eq(['factory'])
      expect(repository.identifier_types('Missing')).to eq([])
      expect(repository.graph_node('Report', type: 'factory')).to eq(primary)
    end

    it 'attaches the matching file path to each typed search result' do
      rows = %w[factory model].map { |type| { identifier: 'Report', type: type, match_field: 'identifier' } }
      allow(reader).to receive(:search).with('Report').and_return(results: rows, complete: true)
      results = repository.search('Report')['results']
      expect(results.pluck('file_path')).to eq(%w[spec/factories/reports.rb app/models/report.rb])
      expect(results.pluck('type')).to eq(%w[factory model])
    end
  end
end
