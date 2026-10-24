# frozen_string_literal: true

require_relative '../support/action_facts_fixture'

RSpec.describe WoodsMap::GenerationMemo do
  include ActionFactsFixture

  it 'computes a key once, keeps the most recently used and freezes what it keeps' do
    memo = described_class.new(2)
    calls = 0
    value = lambda do
      calls += 1
      [calls]
    end
    first = memo.fetch(%w[gen a], &value)
    memo.fetch(%w[gen b], &value)
    memo.fetch(%w[gen a], &value)
    memo.fetch(%w[gen c], &value)
    expect(memo.fetch(%w[gen a], &value)).to equal(first).and be_frozen
    expect(calls).to eq(3)
  end

  it 'reads the unresolved renders around a radius once per generation and reach' do
    owner = action_owner
    owner['metadata']['unresolved_renders'] = [{ 'name' => 'Ghost', 'reason' => 'constant_missing' }]
    repository = action_repository([owner])
    expect_any_instance_of(WoodsMap::ImpactUnknowns) # rubocop:disable RSpec/AnyInstance -- each review builds its own
      .to receive(:read_unresolved_renders).once.and_call_original
    first = action_review(repository, owner['identifier']).unknowns.map(&:why)
    expect(action_review(repository, owner['identifier']).unknowns.map(&:why)).to eq(first)
    expect(first).to eq(['render Ghost (constant missing)'])
  end
end
