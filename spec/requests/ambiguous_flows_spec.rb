# frozen_string_literal: true

RSpec.describe 'Ambiguous published flow operations', type: :request do
  let(:operation) do
    { 'type' => 'call', 'target' => 'Billing', 'method' => 'run',
      'ambiguous_candidates' => %w[A::Billing B::Billing User Missing Shared] }
  end
  let(:document) do
    { 'entry_point' => 'UsersController#show', 'steps' => [
      { 'unit' => 'UsersController#show', 'type' => 'controller', 'operations' => [operation] }
    ] }
  end

  after { WoodsMap::GenerationSnapshot.reset! }

  before do
    WoodsMap::GenerationSnapshot.reset!
    allow(Woods::MCP::IndexReader).to receive(:new).and_wrap_original do |build, *args, **options|
      build.call(*args, **options).tap do |reader|
        allow(reader).to receive(:raw_graph_data).and_wrap_original do |read|
          graph = Marshal.load(Marshal.dump(read.call))
          graph['nodes']['Shared'] = { 'type' => 'model' }
          graph['variants'] = [{ 'identifier' => 'Shared', 'type' => 'service' }]
          graph
        end
      end
    end
    allow(Woods::PublishedIndex).to receive(:open).and_wrap_original do |original, *args, &block|
      original.call(*args) do |index|
        allow(index).to receive(:flow_document).and_call_original
        allow(index).to receive(:flow_document).with('UsersController#show').and_return(document)
        block.call(index)
      end
    end
  end

  ['/woods/impact?focus=User&lens=flows', '/woods/trail?entry=UsersController%23show'].each do |path|
    it "labels published ambiguity and candidates at #{path}" do
      get path
      html = html_response_document
      expect(html.text).to include('? ambiguous', 'A::Billing', 'B::Billing', 'User', 'Missing', 'Shared')
      expect(html.css('.flow-candidates a').select { |a| %w[Missing Shared].include?(a.text) }).to be_empty
      expect(html.css('.flow-candidates a').select { |a| a.text == 'User' }.pluck('href'))
        .to include('/woods/units/model/User')
      expect(html.text).not_to include('Billing.run')
    end

    it "preserves an unambiguous operation at #{path}" do
      operation.delete('ambiguous_candidates')
      get path
      expect(html_response_document.text).to include('Billing.run')
      expect(html_response_document.text).not_to include('? ambiguous')
    end
  end
end
