# frozen_string_literal: true

require 'tmpdir'

RSpec.describe WoodsMap::Guide do
  let(:config) { WoodsMap.configuration }

  it 'is disabled by default' do
    expect(described_class.status(config)).to eq(:disabled)
    expect(described_class.notice(config)).to be_nil
  end

  it 'is unavailable below Ruby 3.2 with a notice naming the running Ruby' do
    config.guide_enabled = true
    allow(described_class).to receive(:ruby_supported?).and_return(false)
    expect(described_class.status(config)).to eq(:ruby)
    expect(described_class.notice(config))
      .to eq("RubyLLM 2.1 needs Ruby 3.2 and this host runs #{RUBY_VERSION}; everything else works.")
  end

  it 'is unavailable without ruby_llm in the bundle' do
    config.guide_enabled = true
    allow(described_class).to receive_messages(ruby_supported?: true, backend: nil)
    expect(described_class.status(config)).to eq(:missing)
  end

  it 'compares Ruby versions numerically' do
    stub_const('RUBY_VERSION', '3.10.0')
    expect(described_class.ruby_supported?).to be(true)
    stub_const('RUBY_VERSION', '3.0.6')
    expect(described_class.ruby_supported?).to be(false)
  end

  it 'keeps the tool allow-list read-only' do
    expect(described_class::TOOLS).not_to include('pipeline_extract', 'pipeline_embed', 'retrieval_rate', 'notion_sync',
                                                  'snapshot_create', 'session_trace')
  end

  describe WoodsMap::Guide::Actions do
    it 'offers each action on its pages and types' do
      expect(described_class.for(:code,
                                 type: 'model')).to eq(%w[explain_unit explain_method why_fail plan_feature
                                                          blast_radius])
      expect(described_class.for(:code, type: 'concern')).not_to include('why_fail')
      expect(described_class.for(:range)).to eq(%w[review_change])
      expect(described_class.for(nil)).to eq([])
    end

    it 'has a prompt for every action that takes the context and the question' do
      described_class::LIST.each_key do |key|
        prompt = described_class.prompt(key, context: 'CTX', question: 'Q?')
        expect(prompt).to start_with('CTX').and include('Q?')
      end
      expect(described_class.prompt(nil, context: 'CTX', question: 'Free?')).to eq("CTX\n\nQuestion: Free?\n")
    end

    it 'offers the graph actions, the selection one only on graphs, and draft-issue under answers only' do
      expect(described_class.for(:graph, type: 'model')).to eq(%w[explain_unit blast_radius explain_selection])
      expect(described_class.for(:code, type: 'model')).not_to include('explain_selection', 'draft_issue')
      expect(described_class.known?('draft_issue')).to be(true)
    end

    it 'puts the earlier answer into the draft-issue prompt, in one pass' do
      prompt = described_class.prompt('draft_issue', context: 'CTX {{answer}}', question: '',
                                                     answer: 'Post has {{question}}')
      expect(prompt).to start_with('CTX {{answer}}').and include('Post has {{question}}').and include('Open questions')
    end

    it 'uses the host override when one exists' do
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(File.join(root, 'config/woods_map/prompts'))
        File.write(File.join(root, 'config/woods_map/prompts/explain_unit.md'), 'House style: {{context}}')
        allow(described_class).to receive(:host_prompts).and_return(Pathname.new(root).join('config/woods_map/prompts'))
        expect(described_class.prompt('explain_unit', context: 'CTX', question: '')).to eq('House style: CTX')
      end
    end
  end

  describe WoodsMap::Guide::Store do
    it 'refuses ids it did not issue, so a cookie never names a path' do
      expect { described_class.new('/tmp', '../../etc/passwd') }.to raise_error(WoodsMap::Guide::Store::InvalidId)
    end

    def finished(store, question)
      turn = store.add_turn('question' => question, 'context' => { 'summary' => 'Post' })
      store.update_turn(turn['id']) { |record| record['state'] = 'done' }
      turn
    end

    it 'keeps the conversation "new" leaves as history, newest first, the current one listed first' do
      Dir.mktmpdir do |dir|
        store = described_class.new(dir, described_class.generate_id)
        finished(store, 'What is Post?')
        first = store.conversation
        store.reset!
        finished(store, 'What is User?')
        expect(store.conversations.map { |c| [c['title'], c['current']] })
          .to eq([['What is User?', true], ['What is Post?', false]])
        expect(store.conversations.last).to include('id' => first, 'turns' => 1, 'summary' => 'Post')
      end
    end

    it 'opens an earlier conversation and keeps the one it leaves' do
      Dir.mktmpdir do |dir|
        store = described_class.new(dir, described_class.generate_id)
        finished(store, 'What is Post?')
        first = store.conversation
        store.reset!
        finished(store, 'What is User?')
        expect(store.open!(first)).to be(true)
        expect(store.turns.map { |turn| turn['question'] }).to eq(['What is Post?'])
        expect(store.conversations.map { |c| c['title'] }).to eq(['What is Post?', 'What is User?'])
        expect([store.open!('0123456789abcdef'), store.open!('../x')]).to eq([false, false])
      end
    end

    it 'refuses to switch while an answer is pending, and keeps at most HISTORY conversations' do
      Dir.mktmpdir do |dir|
        store = described_class.new(dir, described_class.generate_id)
        (described_class::HISTORY + 3).times do |n|
          finished(store, "Question #{n}")
          store.reset!
        end
        expect(store.conversations.size).to eq(described_class::HISTORY)
        expect(store.conversations.first['title']).to eq("Question #{described_class::HISTORY + 2}")
        store.add_turn('question' => 'pending')
        expect { store.open!(store.conversations.last['id']) }.to raise_error(described_class::Busy)
      end
    end

    it 'claims a pending turn once' do
      Dir.mktmpdir do |dir|
        store = described_class.new(dir, described_class.generate_id)
        turn = store.add_turn('question' => 'x')
        expect(store.claim(turn['id'])).to include('state' => 'running')
        expect(store.claim(turn['id'])).to be_nil
      end
    end
  end
end
