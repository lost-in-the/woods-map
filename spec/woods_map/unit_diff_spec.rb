# frozen_string_literal: true

require_relative '../support/history_index'

RSpec.describe WoodsMap::UnitDiff do
  let(:root) { WoodsMap::HistoryIndex.build(generations: 3) }
  let(:unit) { { 'identifier' => 'Micropost', 'type' => 'model' } }
  let(:record) do
    { 'identifier' => 'Micropost', 'type' => 'model', 'status' => 'modified', 'facets' => %w[source metadata],
      'categories' => %w[behaviour], 'metadata_keys' => %w[callbacks],
      'diff_stats' => { 'source_before' => { 'lines' => 40 }, 'source_after' => { 'lines' => 44 } } }
  end

  after { FileUtils.rm_rf(root) }

  def range(data, state: :available)
    instance_double(WoodsMap::ImpactRange, state: state, data: data, message: 'unavailable here')
  end

  it 'accepts only two distinct retained generations, oldest first' do
    WoodsMap::Repository.open(root) do |repository|
      allow(WoodsMap::ImpactRange).to receive(:new).and_return(range({ 'changed' => [] }))
      expect(described_class.for(repository, unit, from: '3', to: '2')).to have_attributes(from: 2, to: 3)
      expect(WoodsMap::ImpactRange).to have_received(:new).with(repository.index_dir, from: 'gen:2', to: 'gen:3')
      [%w[2 2], %w[0 3], %w[9 3], ['', '3'], ['gen:1', '3']].each do |from, to|
        expect(described_class.for(repository, unit, from: from, to: to)).to be_nil
      end
    end
  end

  def diff_with(changed, state: :available)
    WoodsMap::Repository.open(root) do |repository|
      allow(WoodsMap::ImpactRange).to receive(:new).and_return(range({ 'changed' => changed }, state: state))
      yield described_class.for(repository, unit, from: '1', to: '3')
    end
  end

  it "shows this unit's record in Woods' report, never another type's" do
    diff_with([record.merge('type' => 'controller'), record]) do |diff|
      expect(diff.state).to eq(:changed)
      expect(diff.rows).to eq([%w[status modified], ['facets', 'source, metadata'], %w[categories behaviour],
                               ['metadata keys', 'callbacks'], ['source', '40 lines → 44 lines']])
    end
  end

  it 'says the unit did not change, or why there is no comparison' do
    diff_with([record.merge('type' => 'controller')]) { |diff| expect(diff.state).to eq(:unchanged) }
    diff_with([], state: :unavailable) do |diff|
      expect([diff.state, diff.message]).to eq([:unavailable, 'unavailable here'])
    end
  end
end
