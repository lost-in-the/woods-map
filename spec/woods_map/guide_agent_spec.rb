# frozen_string_literal: true

require 'json'
require 'tmpdir'

# The real stack with a fake provider: RubyLLM 2.1's agent, the Woods Index
# MCP server started over stdio on the fixture index, and an OpenAI-shaped
# chat-completions endpoint served in process, so no request leaves the
# machine. Runs where RubyLLM can load (Ruby 3.2+ with ruby_llm bundled);
# elsewhere the guide is unavailable by design and these are skipped.
module WoodsMap
  # An OpenAI-shaped chat-completions endpoint: the first request gets a
  # lookup tool call, the one carrying the tool's result gets text that names
  # units. Started once on an ephemeral loopback port, stopped at exit.
  module FakeCompletions
    @requests = []

    class << self
      # @return [Array<Hash>] the request bodies received
      attr_reader :requests

      # @return [Integer] the bound port
      def port
        @port ||= begin
          require 'puma'
          require 'puma/server'
          options = { min_threads: 1, max_threads: 2 }
          options[:log_writer] = Puma::LogWriter.null if defined?(Puma::LogWriter)
          server = Puma::Server.new(self, nil, options)
          bound = server.add_tcp_listener('127.0.0.1', 0).addr[1]
          server.run
          at_exit { server.stop(true) }
          bound
        end
      end

      def call(env)
        body = JSON.parse(env['rack.input'].read)
        requests << body
        chunks = body['messages'].any? { |message| message['role'] == 'tool' } ? text_chunks : tool_chunks
        events = chunks.map { |chunk| "data: #{JSON.generate(chunk)}\n\n" }.join
        [200, { 'content-type' => 'text/event-stream' }, ["#{events}data: [DONE]\n\n"]]
      end

      private

      def chunk(delta, finish = nil, usage = nil)
        payload = { 'id' => 'c1', 'object' => 'chat.completion.chunk', 'model' => 'fake-model',
                    'choices' => [{ 'index' => 0, 'delta' => delta, 'finish_reason' => finish }] }
        usage ? payload.merge('usage' => usage) : payload
      end

      def tool_chunks
        call = { 'index' => 0, 'id' => 'call_1', 'type' => 'function',
                 'function' => { 'name' => 'lookup', 'arguments' => JSON.generate('identifier' => 'User') } }
        [chunk('role' => 'assistant', 'tool_calls' => [call]),
         chunk({}, 'tool_calls', 'prompt_tokens' => 300, 'completion_tokens' => 20, 'total_tokens' => 320)]
      end

      def text_chunks
        ['User has many ', 'Posts; see `User`.'].map { |text| chunk('content' => text) } +
          [chunk({}, 'stop', 'prompt_tokens' => 500, 'completion_tokens' => 30, 'total_tokens' => 530)]
      end
    end
  end
end

RSpec.describe WoodsMap::Guide do
  before do
    skip 'RubyLLM 2.1 is not loadable on this Ruby' unless described_class.ruby_supported? && described_class.backend
  end

  let(:chats) { Dir.mktmpdir('woods-map-chats') }
  let(:requests) { WoodsMap::FakeCompletions.requests }
  let(:events) { [] }
  let(:record) do
    RubyLLM.configure do |config|
      config.openai_api_key = 'test-key'
      config.openai_api_base = "http://127.0.0.1:#{WoodsMap::FakeCompletions.port}/v1"
    end
    config = WoodsMap.configuration
    config.guide_chat_options = { model: 'fake-model', provider: :openai, protocol: :chat_completions,
                                  assume_model_exists: true }
    store = WoodsMap::Guide::Store.new(chats, WoodsMap::Guide::Store.generate_id)
    turn = store.claim(store.add_turn('question' => 'What is User?', 'prompt' => 'What is User?')['id'])
    WoodsMap::Guide::Runner.new(store: store, turn: turn, session: described_class.open_session(config),
                                emit: ->(event, payload) { events << [event, payload] },
                                budget: WoodsMap::Guide::Budget.new(config, tokens_spent: 0)).run
  end

  after do
    FileUtils.rm_rf(chats)
    requests.clear
  end

  it 'exposes exactly the read-only allow-list of the Index MCP server' do
    server = WoodsMap::Guide::IndexMcp.for(WoodsMap.configuration).new
    expect(server.tools.map(&:name)).to match_array(WoodsMap::Guide::TOOLS)
  ensure
    server&.close
  end

  it 'answers through a real tool call with streamed text, cards and token counts' do
    expect(record).to include('state' => 'done', 'answer' => 'User has many Posts; see `User`.', 'tokens' => 850)
    expect(record['tool_calls']).to contain_exactly(include('name' => 'lookup', 'args' => 'User', 'state' => 'done'))
    expect(events.map(&:first)).to include('tool', 'delta').and end_with('done')
  end

  it 'offers the model only the allow-list, with the guide instructions, and returns the index answer' do
    record
    expect(requests.first['tools'].map { |tool| tool.dig('function', 'name') }).to match_array(described_class::TOOLS)
    expect(requests.first['messages'].first['content'].to_s).to include('only the Woods index tools')
    tool_message = requests.last['messages'].find { |message| message['role'] == 'tool' }
    expect(tool_message['content'].to_s).to include('User')
  end
end
