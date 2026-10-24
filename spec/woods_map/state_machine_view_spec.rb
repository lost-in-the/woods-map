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

  describe 'structured transition callbacks (woods#796)' do
    let(:structured) do
      callbacks = [
        { 'kind' => 'before_transition', 'on' => ['publish'], 'from' => [], 'to' => [], 'method' => 'stamp',
          'block' => false, 'side_effects' => { 'columns_written' => ['published_at'], 'jobs_enqueued' => [] } },
        { 'kind' => 'after_transition', 'on' => ['publish'], 'from' => [], 'to' => [], 'method' => 'notify',
          'block' => false, 'side_effects' => { 'jobs_enqueued' => ['NotifyJob'] } },
        { 'kind' => 'after_transition', 'on' => [], 'from' => [], 'to' => ['archived'], 'method' => nil,
          'block' => true, 'side_effects' => nil, 'unanalysed' => 'block' },
        { 'kind' => 'after_failure', 'on' => [], 'from' => [], 'to' => [], 'method' => 'log', 'block' => false },
        { 'kind' => 'before_transition', 'on' => [], 'from' => [], 'to' => [], 'method' => 'audit',
          'block' => false, 'unresolved' => ['from'] }
      ]
      described_class.new(unit.merge('metadata' => unit['metadata'].merge('transition_callbacks' => callbacks)))
    end

    it 'ties each callback to the transitions its literal scope admits, by phase' do
      publish, archive = structured.transitions
      expect(structured.callbacks_for(publish).transform_values { |list| list.map(&:label) })
        .to eq('before' => ['stamp'], 'after' => ['notify'], 'after_failure' => ['log'])
      expect(structured.callbacks_for(archive).transform_values { |list| list.map(&:label) })
        .to eq('after' => ['block'], 'after_failure' => ['log'])
    end

    it 'keeps a callback whose scope is not literal off every transition' do
      expect(structured.unplaced_callbacks.map(&:label)).to eq(['audit'])
      expect(structured.callbacks_for(structured.transitions.first)['before'].map(&:label)).not_to include('audit')
    end

    it 'names the side effects with the Lifecycle verbs' do
      expect(structured.transition_callbacks.first(2).map(&:effects)).to eq([['writes published_at'],
                                                                             ['enqueues NotifyJob']])
    end

    it 'labels the transitions that carry callbacks in the state diagram' do
      publish = 's0 --> s1 : publish [ready?] / before stamp, after notify, after failure log'
      expect(structured.mermaid).to include(publish, 's1 --> s2 : archive / after block, after failure log')
    end

    it 'is structured only when the unit publishes the list, keeping the raw lines for older generations' do
      expect(structured).to be_structured
      expect(machine).not_to be_structured
      expect(machine.mermaid).to include('s0 --> s1 : publish [ready?]')
    end
  end
end
