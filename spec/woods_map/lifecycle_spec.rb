# frozen_string_literal: true

RSpec.describe WoodsMap::Lifecycle do
  let(:unit) do
    {
      'identifier' => 'Post',
      'source_code' => "class Post\n  def set_slug; end\n  def notify; end\nend\n",
      'metadata' => { 'callbacks' => [
        { 'type' => 'after_commit', 'filter' => 'notify', 'kind' => 'after', 'conditions' => { 'on' => ['create'] },
          'side_effects' => { 'jobs_enqueued' => ['NotifySubscribersJob'], 'columns_written' => [] } },
        { 'type' => 'before_save', 'filter' => 'set_slug', 'kind' => 'before',
          'conditions' => { 'if' => ['title_changed?'] }, 'side_effects' => { 'columns_written' => ['slug'] } },
        { 'type' => 'before_save', 'filter' => 'normalize_tags', 'kind' => 'before', 'conditions' => {},
          'side_effects' => {} },
        { 'type' => 'after_validation', 'filter' => '_ensure_no_duplicate_errors', 'kind' => 'after',
          'conditions' => {} },
        { 'type' => 'before_destroy', 'filter' => '#<lambda /gems/activerecord/association.rb:142>',
          'kind' => 'before' },
        { 'type' => 'before_validation', 'filter' => 'normalize_changed_in_place_attributes', 'kind' => 'before' }
      ] }
    }
  end
  let(:lifecycle) { described_class.new(unit, concern_methods: { 'Taggable' => ['normalize_tags'] }) }
  let(:flowchart_text) do
    <<~MERMAID.chomp
      flowchart TD
        start(["Post create"])
        s1["1 · before_save set_slug"]
        c1{"if: title_changed?"}
        start --> c1
        c1 -->|yes| s1
        s2["2 · before_save normalize_tags"]
        s1 --> s2
        c1 -.->|no| s2
        commit[["transaction commits"]]
        s2 --> commit
        s3["3 · after_commit notify"]
        commit --> s3
        done(["done"])
        s3 --> done
        a0[/"NotifySubscribersJob"/]
        s3 -.->|enqueues| a0
    MERMAID
  end
  let(:lanes_text) do
    <<~MERMAID.chomp
      swimlane-beta TB
        subgraph l_transaction ["in the transaction"]
          s1["1 · before_save set_slug"]
          s2["2 · before_save normalize_tags"]
        end
        subgraph l_commit ["after commit"]
          s3["3 · after_commit notify"]
        end
        subgraph l_async ["another process"]
          a0["NotifySubscribersJob"]
        end
        s1 --> s2
        s2 --> s3
        s3 -.->|enqueues| a0
    MERMAID
  end

  it 'orders the create chain as Rails runs it and numbers the steps' do
    steps = lifecycle.steps('create')
    expect(steps.map(&:filter)).to eq(%w[set_slug normalize_tags notify])
    expect(steps.map(&:n)).to eq([1, 2, 3])
  end

  it 'keeps an on: :create callback off the update chain' do
    expect(lifecycle.steps('update').map(&:filter)).to eq(%w[set_slug normalize_tags])
  end

  describe 'on:-scoped callbacks' do
    let(:scoped) do
      methods = %w[check_new check_edit always created updated saved]
      callbacks = [%w[before_validation check_new create], %w[before_validation check_edit update],
                   %w[before_save always], %w[after_commit created create], %w[after_commit updated update],
                   ['after_commit', 'saved', 'create update']].map do |type, filter, on|
        { 'type' => type, 'filter' => filter, 'conditions' => on ? { 'on' => on.split } : {} }
      end
      { 'identifier' => 'Widget', 'metadata' => { 'callbacks' => callbacks },
        'source_code' => "class Widget\n#{methods.map { |name| "  def #{name}; end\n" }.join}end\n" }
    end

    it 'lists each under its own event only' do
      chains = described_class.new(scoped)
      expect(chains.steps('create').map(&:filter)).to eq(%w[check_new always created saved])
      expect(chains.steps('update').map(&:filter)).to eq(%w[check_edit always updated saved])
      expect(chains.steps('destroy')).to be_empty
    end
  end

  it 'hides framework callbacks and procs and counts them as a limit' do
    expect(lifecycle.callbacks.pluck('filter')).to contain_exactly('notify', 'set_slug', 'normalize_tags')
    expect(lifecycle.framework.pluck('filter')).to eq(['normalize_changed_in_place_attributes'])
  end

  it 'names the concern a step comes from, its condition and its effects' do
    step = lifecycle.steps('create').find { |s| s.filter == 'normalize_tags' }
    expect(step.owner).to eq('Taggable')
    slug = lifecycle.steps('create').first
    expect(slug.condition).to eq('if: title_changed?')
    expect(slug.effects).to eq(['writes slug'])
    expect(lifecycle.steps('create').last).to be_async.and be_commit
  end

  it 'writes the chain as a numbered sequence, the async step handing off to its job' do
    expect(lifecycle.mermaid('create')).to eq(<<~MERMAID.chomp)
      sequenceDiagram
        autonumber
        participant App
        participant M as Post
        participant A0 as NotifySubscribersJob
        App->>M: before_save set_slug
        App->>M: before_save normalize_tags
        M-)A0: notify
    MERMAID
  end

  it 'counts participants and messages against the sequence budget, refusing only above it' do
    chain = lambda do |n|
      names = (1..n).map { |i| "step_#{i}" }
      { 'identifier' => 'Post', 'source_code' => names.map { |m| "def #{m}; end" }.join("\n"),
        'metadata' => { 'callbacks' => names.map { |m| { 'type' => 'before_save', 'filter' => m } } } }
    end
    budget = WoodsMap::Lifecycle::SEQUENCE_BUDGET
    at_budget = described_class.new(chain.call(budget - 2))
    expect(at_budget.sequence_size('create')).to eq(budget)
    expect(at_budget).not_to be_over_budget('create')
    expect(described_class.new(chain.call(budget - 1))).to be_over_budget('create')
  end

  it 'draws the branching flowchart: a decision per condition, the commit as a node, async hops dotted' do
    expect(lifecycle.flowchart('create')).to eq(flowchart_text)
  end

  it 'draws lanes for where each step runs, leaving empty lanes out' do
    expect(lifecycle.lanes('create')).to eq(lanes_text)
    expect(lifecycle.lanes('update')).not_to include('l_commit', 'l_async')
  end

  it 'picks the text by view, the sequence by default' do
    expect(lifecycle.diagram('flowchart', 'create')).to eq(flowchart_text)
    expect(lifecycle.diagram('lanes', 'create')).to eq(lanes_text)
    expect(lifecycle.diagram('sequence', 'create')).to eq(lifecycle.mermaid('create'))
  end

  it 'counts flowchart and lanes nodes against the flowchart budget' do
    expect([lifecycle.size('flowchart', 'create'), lifecycle.size('lanes', 'create')]).to eq([8, 4])
    expect(lifecycle.budget('lanes')).to eq(WoodsMap::Lifecycle::FLOWCHART_BUDGET)
  end

  it 'refuses a view only above its own budget' do
    stub_const('WoodsMap::Lifecycle::FLOWCHART_BUDGET', 7)
    expect(lifecycle).to be_over_budget('create', view: 'flowchart')
    expect(lifecycle).not_to be_over_budget('create', view: 'lanes')
    expect(lifecycle).not_to be_over_budget('create')
  end

  it 'keeps a double quote in a label from closing it' do
    unit['metadata']['callbacks'][1]['conditions'] = { 'if' => ['say "hi"'] }
    expect(lifecycle.flowchart('create')).to include(%(c1{"if: say 'hi'"}))
  end
end
