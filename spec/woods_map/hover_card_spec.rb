# frozen_string_literal: true

RSpec.describe WoodsMap::HoverCard do
  let(:graph) do
    { 'nodes' => {}, 'pagerank' => { 'A' => 0.5, 'B' => 0.2, 'C' => 0.2, 'D' => 0.1, 'Odd' => 'x' } }
  end
  let(:repository) do
    repo = instance_double(WoodsMap::Repository, graph: graph)
    allow(repo).to receive(:graph_node) do |identifier, type: nil|
      { 'type' => type, 'file_path' => "app/#{identifier}.rb", 'commit_count' => 3 } unless identifier == 'Gone'
    end
    allow(repo).to receive(:unit) { |identifier, type: nil|
      identifier == 'Gone' ? nil : { 'identifier' => identifier, 'type' => type }
    }
    repo
  end

  it 'places scores among numeric scores, ties sharing a place' do
    cards = described_class.for(repository, [%w[A model], %w[C model], %w[D model], %w[B model]])
    expect(cards.map(&:rank)).to eq([1, 2, 4, 2])
    expect(cards.map(&:ranked).uniq).to eq([4])
  end

  it 'drops targets absent from the generation and repeats' do
    cards = described_class.for(repository, [%w[A model], %w[Gone model], %w[A model]])
    expect(cards.map(&:identifier)).to eq(%w[A])
  end

  it 'falls back to the graph node for churn when metadata.git is absent' do
    card = described_class.new(repository, 'B', 'model')
    expect([card.commit_count, card.last_author, card.path]).to eq([3, nil, 'app/B.rb'])
  end
end
