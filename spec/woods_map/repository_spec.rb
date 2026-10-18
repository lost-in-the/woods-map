# frozen_string_literal: true

RSpec.describe WoodsMap::Repository do
  it 'opens the published generation and reports its status' do
    status = described_class.open(FIXTURE_INDEX, &:status)
    expect(status['generation']).to eq(1)
    expect(status['total_units']).to eq(17)
    expect(status['git_branch']).to eq('main')
  end

  it 'reads units through the pinned generation' do
    identifiers = described_class.open(FIXTURE_INDEX) { |repo| repo.units(type: 'model').map { |u| u['identifier'] } }
    expect(identifiers).to contain_exactly('User', 'Micropost', 'Relationship')
  end

  it 'raises Unavailable for a missing index' do
    expect { described_class.open('/nonexistent/woods') { |_| nil } }.to raise_error(described_class::Unavailable)
  end
end
