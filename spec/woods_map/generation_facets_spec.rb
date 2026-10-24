# frozen_string_literal: true

RSpec.describe WoodsMap::GenerationFacets do
  let(:repository) { instance_double(WoodsMap::Repository, generation_key: ['k'], index_dir: Pathname('/idx')) }
  let(:unit) { { 'identifier' => 'Post', 'type' => 'model' } }
  let(:facets) { described_class.new(repository, unit, [1, 3, 4]) }

  def diff(status, categories, state: :available)
    instance_double(WoodsMap::SourceDiff, state: state, status: status, categories: categories)
  end

  it "labels each generation by Woods' record against the retained generation before it" do
    diffs = { 3 => diff('modified', %w[behaviour edges]), 4 => diff('added', %w[schema]) }
    allow(WoodsMap::SourceDiff).to receive(:new) { |_dir, to:, **| diffs.fetch(to) }

    expect([facets.label(3), facets.label(4), facets.label(3)]).to eq(['behaviour, edges', 'added, schema',
                                                                       'behaviour, edges'])
    expect(WoodsMap::SourceDiff).to have_received(:new)
      .with(Pathname('/idx'), identifier: 'Post', type: 'model', from: 1, to: 3).once
  end

  it 'gives nothing for the oldest generation, an unknown one, or a diff Woods could not make' do
    allow(WoodsMap::SourceDiff).to receive(:new).and_return(diff(nil, nil, state: :invalid))

    expect([facets.label(1), facets.label(2), facets.label(nil), facets.label(4)]).to all(be_nil)
  end

  it 'says unchanged when the unit did not move and needs a Woods with the unit diff' do
    allow(WoodsMap::SourceDiff).to receive_messages(new: diff('unchanged', []), backend: Class.new)
    expect([facets.label(4), facets.available?]).to eq(['unchanged', true])

    allow(WoodsMap::SourceDiff).to receive(:backend).and_return(nil)
    expect(facets.available?).to be(false)
    expect(described_class.new(repository, unit, [4]).available?).to be(false)
  end
end
