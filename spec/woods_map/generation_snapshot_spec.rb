# frozen_string_literal: true

RSpec.describe WoodsMap::GenerationSnapshot do
  let(:payload) { Pathname.new(FIXTURE_INDEX).join('payloads/gen-1') }

  it 'shares one reader and the derived values across requests on one generation' do
    first = WoodsMap::Repository.open(FIXTURE_INDEX) { |repo| [repo.graph, repo.units, repo.identifier_index] }
    second = WoodsMap::Repository.open(FIXTURE_INDEX) { |repo| [repo.graph, repo.units, repo.identifier_index] }
    first.zip(second).each { |a, b| expect(a).to equal(b) }
  end

  it 'reads the graph once per generation' do
    reader = WoodsMap::Repository.open(FIXTURE_INDEX) { |repo| repo.send(:reader) }
    allow(reader).to receive(:raw_graph_data).and_call_original
    3.times { WoodsMap::Repository.open(FIXTURE_INDEX) { |repo| [repo.graph_node('User'), repo.file_map] } }
    expect(reader).to have_received(:raw_graph_data).once
  end

  it 'freezes what it keeps, so a caller cannot change it for the next request' do
    units = WoodsMap::Repository.open(FIXTURE_INDEX, &:units)
    expect(units).to be_frozen
    expect(units.first).to be_frozen
    expect { units.first['identifier'] << 'x' }.to raise_error(FrozenError)
  end

  it 'builds a value once while threads ask for it together' do
    snapshot = described_class.new(payload)
    calls = 0
    build = lambda do
      calls += 1
      sleep 0.01
      'built'
    end
    values = Array.new(4) { Thread.new { snapshot.fetch(:value, &build) } }.map(&:value)
    expect(calls).to eq(1)
    expect(values.uniq).to eq(['built'])
  end

  it 'keeps the generation every request touches and drops the least recently used' do
    current = described_class.for(%w[index current], payload)
    others = (1..described_class::CACHE_SIZE).map do |n|
      described_class.for(['index', n], payload).tap { described_class.for(%w[index current], payload) }
    end
    expect(described_class.for(%w[index current], payload)).to equal(current)
    expect(described_class.for(['index', 1], payload)).not_to equal(others.first)
  end
end
