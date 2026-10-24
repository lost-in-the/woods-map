# frozen_string_literal: true

RSpec.describe WoodsMap::StateMachineView do
  let(:unit) do
    { 'identifier' => 'Post::aasm', 'metadata' => {
      'gem_detected' => 'aasm', 'states' => %w[draft published], 'initial_state' => 'draft',
      'events' => [
        { 'name' => 'publish', 'transitions' => [{ 'from' => 'draft', 'to' => 'published', 'guard' => 'ready?' }] },
        { 'name' => 'archive', 'transitions' => [{ 'from' => 'published', 'to' => 'archived' }] }
      ],
      'transitions' => [], 'callbacks' => ['after_transition on: :publish, do: :notify']
    } }
  end
  let(:machine) { described_class.new(unit) }

  it 'finds the machines published for a model through its reverse state_machine edges' do
    machines = WoodsMap::Repository.open(FIXTURE_INDEX) { |repository| described_class.for_model(repository, 'User') }
    expect(machines.map(&:identifier)).to eq(['User::aasm'])
    expect(machines.first.events).to eq(%w[activate suspend reinstate])
    expect(WoodsMap::Repository.open(FIXTURE_INDEX) { |r| described_class.for_model(r, 'Micropost') }).to be_empty
  end

  it 'draws every state, the initial one entered from [*], each transition with its event and guard' do
    expect(machine.states).to eq(%w[draft published archived])
    expect(machine.mermaid).to eq(<<~MERMAID.chomp)
      stateDiagram-v2
        state "draft" as s0
        state "published" as s1
        state "archived" as s2
        [*] --> s0
        s0 --> s1 : publish [ready?]
        s1 --> s2 : archive
    MERMAID
    expect(machine.size).to eq(5)
    expect(machine.callbacks).to eq(['after_transition on: :publish, do: :notify'])
  end

  it 'falls back to the flat transitions of a gem without events, unlabelled' do
    flat = described_class.new('identifier' => 'Order::statesman', 'metadata' => {
                                 'states' => %w[pending paid], 'events' => [],
                                 'transitions' => [{ 'from' => 'pending', 'to' => 'paid' }]
                               })
    expect(flat.transitions.map(&:event)).to eq([nil])
    expect(flat.mermaid).to end_with('s0 --> s1')
    expect(flat.mermaid).not_to include('[*]')
  end

  it 'refuses above the state budget' do
    stub_const('WoodsMap::StateMachineView::STATE_BUDGET', 4)
    expect(machine).to be_over_budget
  end
end
