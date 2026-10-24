# frozen_string_literal: true

require 'tmpdir'

RSpec.describe WoodsMap::Guide::Runner do
  let(:dir) { Dir.mktmpdir('woods-map-guide') }
  let(:store) { WoodsMap::Guide::Store.new(dir, WoodsMap::Guide::Store.generate_id) }
  let(:events) { [] }
  let(:now) { [0.0] }

  def two_tools
    [{ tools: [['lookup', { 'identifier' => 'Post' }], ['dependents', { 'identifier' => 'User', 'depth' => 1 }]] },
     { text: 'Post enqueues a job.', tokens: [900, 120] }]
  end

  after { FileUtils.rm_rf(dir) }

  def run(steps, question: 'Why?', chat: WoodsMap::FakeGuideChat.new(steps), emit: nil)
    turn = store.add_turn('question' => question, 'prompt' => "prompt: #{question}")
    claimed = store.claim(turn['id'])
    budget = WoodsMap::Guide::Budget.new(config, tokens_spent: store.tokens, clock: -> { now.first })
    described_class.new(store: store, turn: claimed, session: WoodsMap::Guide::Session.new(chat, []),
                        emit: emit || ->(event, payload) { events << [event, payload] }, budget: budget).run
  end

  def config
    WoodsMap.configuration
  end

  def payloads(name)
    events.filter_map { |event, payload| payload if event == name }
  end

  it 'reports tool cards as they start and end' do
    run(two_tools)
    expect(events.first(4).map(&:first)).to eq(%w[tool tool tool tool])
    expect(events.first.last).to include('name' => 'lookup', 'args' => 'Post', 'state' => 'running')
    expect(events[3].last).to include('name' => 'dependents', 'args' => 'User, depth 1', 'state' => 'done')
  end

  it 'streams the text, finishes once and records the tokens' do
    record = run(two_tools)
    expect(events.map(&:first).count('done')).to eq(1)
    expect(payloads('delta').map { |payload| payload['text'] }.join).to eq('Post enqueues a job.')
    expect(record).to include('state' => 'done', 'answer' => 'Post enqueues a job.', 'tokens' => 1020)
    expect(store.tokens).to eq(1020)
  end

  it 'marks a failed tool call on its card' do
    run([{ tools: [['lookup', { 'identifier' => 'Nope' }, true]] }, { text: 'Not found.' }])
    expect(payloads('tool').last['state']).to eq('failed')
  end

  context 'with a cap of two tool calls' do
    before { config.guide_tool_calls = 2 }

    let(:record) do
      run([{ text: 'Looking. ' }, { tools: [['lookup', {}], ['lookup', {}], ['lookup', {}]] }, { text: 'never' }])
    end

    it 'stops before the third call, keeping what streamed' do
      expect(record).to include('state' => 'limited', 'answer' => 'Looking. ')
      expect(record['limit']).to include('kind' => 'tool_calls', 'message' => include('2 tool calls'))
      expect(record['tool_calls'].size).to eq(2)
    end

    it 'ends the stream with the limit and the budget line' do
      record
      expect(events.last.first).to eq('limited')
      expect(events.last.last['budget']).to include('tool_calls' => 2, 'tool_call_limit' => 2)
    end
  end

  it 'stops after the turn limit' do
    config.guide_turns = 1
    record = run([{ tools: [['lookup', {}]] }, { text: 'never' }])
    expect(record['limit']['kind']).to eq('turns')
  end

  it 'stops once the session token budget is spent' do
    config.guide_token_budget = 500
    record = run([{ text: 'first part', tokens: [400, 200] }, { text: 'never' }])
    expect(record['limit']['kind']).to eq('tokens')
  end

  it 'stops an answer that runs past its seconds' do
    config.guide_seconds = 5
    chat = WoodsMap::FakeGuideChat.new([{ text: 'slow' }, { text: 'never' }], on_step: ->(_) { now[0] += 3 })
    record = run(nil, chat: chat)
    expect(record['limit']['kind']).to eq('seconds')
  end

  it 'stops when the person presses stop, and cancels the chat' do
    chat = nil
    chat = WoodsMap::FakeGuideChat.new([{ text: 'one ' }, { text: 'two' }],
                                       on_step: lambda { |_|
                                         if chat.messages.size > 1
                                           store.update_turn(store.turns.last['id']) do |t|
                                             t['cancel'] = true
                                           end
                                         end
                                       })
    record = run(nil, chat: chat)
    expect(record['state']).to eq('cancelled')
    expect(chat.cancelled).to be(true)
  end

  it 'stops when the browser goes away' do
    gone = ->(event, _) { raise WoodsMap::Guide::Runner::Disconnected if event == 'delta' }
    record = run([{ text: 'hello' }], emit: gone)
    expect(record['state']).to eq('cancelled')
  end

  it 'reports a provider error as a failed turn without raising' do
    chat = WoodsMap::FakeGuideChat.new([{ text: 'x' }], on_step: ->(_) { raise ArgumentError, 'no API key' })
    record = run(nil, chat: chat)
    expect(record).to include('state' => 'failed', 'error' => 'ArgumentError: no API key')
    expect(events.last.first).to eq('failed')
  end

  it 'replays earlier answered turns as messages before the new prompt' do
    first = store.add_turn('question' => 'a', 'prompt' => 'first prompt')
    store.update_turn(first['id']) do |turn|
      turn['state'] = 'done'
      turn['answer'] = 'first answer'
    end
    chat = WoodsMap::FakeGuideChat.new([{ text: 'second answer' }])
    run(nil, chat: chat, question: 'b')
    expect(chat.messages.map { |message| [message.role, message.content] }.first(3))
      .to eq([[:user, 'first prompt'], [:assistant, 'first answer'], [:user, 'prompt: b']])
  end
end
